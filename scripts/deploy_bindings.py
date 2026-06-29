#!/usr/bin/env python3
"""
NDO static-port-binding deployer for the V2 tenant redesign (schema AFRICOM-V2).

This is a fork of /Users/johbarbe/DC/NXOS/n5k/deploy_bindings_python_v2_prod.py
with default schema set to AFRICOM-V2 and the production NDO host removed
(must be supplied via the bindings JSON or env). All other behaviour is
identical:

  * Robust auth: tries Nexus Dashboard /login (domain=local, DefaultAuth)
    then NDO /api/v1/auth/login. Works against ND 4.x and standalone MSO.
  * Multi-site: groups bindings by binding['site'] and patches Kelley and
    Del-Din independently.
  * Multi-template auto-resolve: looks up each EPG's template name in NDO
    via epgRef so the bindings JSON does not have to know the template name.
    For the V2 redesign that name is Tenant_EUR_V2.
  * Existing-bindings dedup: skips bindings already on NDO (matches by path
    and portEncapVlan).
  * Batched JSON-Patch (50 patches per HTTP call).
  * --dry-run for preview, --no-vault for password-from-JSON instead of
    Ansible vault.

Bindings JSON shape -- see scripts/bindings.example.json. Minimum:
  {
    "ndo_host":      "<ip-or-hostname>",
    "ndo_username":  "admin",
    "ndo_password":  "<used only with --no-vault>",
    "schema_name":   "AFRICOM-V2",
    "static_port_bindings": [
      {
        "site":      "Kelley",
        "epg_name":  "EPG-WEB-SVR-V2",
        "vlan":      100,
        "path":      "topology/pod-1/paths-101/pathep-[eth1/1]",
        "deployment_immediacy": "immediate",
        "mode":      "regular"
      }
    ]
  }

Operational sequence (full V2 cutover):
  1. ndo/ Terraform root creates schema AFRICOM-V2 / template Tenant_EUR_V2
     in NDO (deploy_templates=false, no APIC push).
  2. Operator clicks Deploy in the NDO UI -- pushes the schema to Kelley and
     Del-Din. EPGs exist on the APICs at this point but have no static ports.
  3. This script reads bindings.json and PATCHes staticPorts onto each EPG
     in NDO. NDO reconciles down to APIC.
  4. Re-run NDO deploy from the UI to push the staticPorts changes.
"""
import requests
import json
import time
import urllib3
from collections import defaultdict
import sys
import re
import os
import subprocess
import yaml

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# V2 redesign defaults. NDO_HOST is intentionally empty so a stale
# production address cannot leak into a lab run; the bindings JSON must
# supply ndo_host (or set it via env / arg) -- the script will refuse to
# guess.
DEFAULT_NDO_HOST = ""
DEFAULT_NDO_USER = "admin"
DEFAULT_SCHEMA   = "AFRICOM-V2"

def load_password_from_vault(vault_file, vault_pass_file):
    """Decrypts an ansible-vault file and returns the NDO password."""
    print("Loading password from Ansible vault...")
    try:
        command = [
            "ansible-vault", "view",
            "--vault-id", f"default@{vault_pass_file}",
            vault_file
        ]
        decrypted_yaml = subprocess.check_output(command, text=True)
        vault_data = yaml.safe_load(decrypted_yaml)
        password = vault_data.get('ndo_password')
        if not password:
            print(f"Error: 'ndo_password' key not found in {vault_file}", file=sys.stderr)
            sys.exit(1)
        print("Password successfully loaded from vault.")
        return password
    except FileNotFoundError:
        print(f"Error: 'ansible-vault' command not found.", file=sys.stderr)
        sys.exit(1)
    except subprocess.CalledProcessError as e:
        print(f"Error: Failed to decrypt {vault_file}. Check vault password.", file=sys.stderr)
        sys.exit(1)

class NDOBindingDeployer:
    def __init__(self, ndo_host, username, password, schema_name=DEFAULT_SCHEMA):
        self.ndo_host = ndo_host.rstrip('/')
        self.schema_name = schema_name
        self.session = requests.Session()
        self.session.verify = False
        self.dry_run = False
        self.auth_token = self._authenticate(username, password)
        self.epg_cache = {}

    def _authenticate(self, username, password):
        """Authenticate with NDO/ND.

        Tries multiple auth methods to handle different ND/NDO versions and
        domain configurations (local vs TACACS/RADIUS/LDAP).
        """
        base = f"https://{self.ndo_host}"
        print(f"Authenticating to {self.ndo_host} as '{username}' ...")

        # --- Attempt 1: Nexus Dashboard 4.x /login (local domain) ---
        nd_url = f"{base}/login"
        for domain in ["local", "DefaultAuth"]:
            nd_data = {
                "userName": username,
                "userPasswd": password,
                "domain": domain
            }
            print(f"  Trying ND /login with domain='{domain}' ...")
            try:
                response = self.session.post(nd_url, json=nd_data, timeout=30)
                if response.status_code == 200:
                    resp_json = response.json()
                    token = resp_json.get('token', resp_json.get('jwttoken', ''))
                    if token:
                        self.session.headers.update({'Authorization': f'Bearer {token}'})
                        print(f"  Authenticated via ND /login (domain={domain}).")
                        return token
                    if self.session.cookies:
                        print(f"  Authenticated via ND /login cookies (domain={domain}).")
                        return "cookie-auth"
                    print(f"  WARNING: 200 OK but no token. Keys: {list(resp_json.keys())}")
                else:
                    print(f"  HTTP {response.status_code}: {response.text[:150]}")
            except requests.exceptions.ConnectionError:
                print(f"  /login not reachable, skipping ND attempts.")
                break
            except Exception as e:
                print(f"  Error: {e}")

        # --- Attempt 2: NDO 3.x /api/v1/auth/login (with and without domain) ---
        auth_url = f"{base}/api/v1/auth/login"
        for auth_data in [
            {"username": username, "password": password, "domain": "local"},
            {"username": username, "password": password},
        ]:
            domain_str = auth_data.get('domain', '<none>')
            print(f"  Trying /api/v1/auth/login with domain='{domain_str}' ...")
            try:
                response = self.session.post(auth_url, json=auth_data, timeout=30)
                if response.status_code == 200:
                    token = response.json()['token']
                    self.session.headers.update({'Authorization': f'Bearer {token}'})
                    print(f"  Authenticated via /api/v1/auth/login (domain={domain_str}).")
                    return token
                else:
                    print(f"  HTTP {response.status_code}: {response.text[:150]}")
            except Exception as e:
                print(f"  Error: {e}")

        print("\n  ALL authentication methods failed!")
        print("  Possible causes:")
        print("    - Wrong password in vault.yml for this NDO instance")
        print("    - Admin account locked or disabled on this NDO")
        print("    - NDO requires a different auth domain (check ND Admin > Authentication)")
        print(f"    - NDO host '{self.ndo_host}' is not the correct NDO for this site")
        sys.exit(1)
    
    def get_schema_id(self):
        """Get schema ID"""
        url = f"https://{self.ndo_host}/api/v1/schemas"
        response = self.session.get(url)
        schemas = response.json()['schemas']
        
        for schema in schemas:
            if schema['displayName'] == self.schema_name:
                return schema['id']
        raise ValueError(f"Schema {self.schema_name} not found")
    
    def parse_topology_path(self, full_path):
        """Parse topology path to extract components needed for API"""
        match = re.match(r'topology/(pod-\d+)/paths-(\d+)/pathep-\[([^\]]+)\]', full_path)
        if match:
            return {
                'pod': match.group(1),
                'leaf': match.group(2),
                'interface': match.group(3)
            }
        
        match = re.match(r'topology/(pod-\d+)/protpaths-(\d+-\d+)/pathep-\[([^\]]+)\]', full_path)
        if match:
            return {
                'pod': match.group(1),
                'leaf': match.group(2),
                'interface': match.group(3)
            }
        
        return None
    
    def determine_port_type(self, binding):
        """Determine if a binding is for a regular port, DPC, or VPC"""
        if binding.get('path_type') in ['dpc', 'vpc']:
            return binding.get('path_type')
        
        if binding.get('port_type') in ['dpc', 'vpc']:
            return binding.get('port_type')
        
        path = binding.get('path', '')
        interface_match = re.search(r'pathep-\[([^\]]+)\]', path)
        
        if interface_match:
            interface = interface_match.group(1)
            if interface.lower().startswith('vpc') or 'protpaths' in path:
                return 'vpc'
            # Single-leaf port-channel policy groups: APIC `Po1` (auto-generated
            # name) and the redesign Design A naming convention `PC_*` (e.g.
            # `PC_FI_A`/`PC_FI_B` from access-policies.nac.yaml). Both ride a
            # `topology/.../paths-N/...` path (NOT protpaths), so they are dpc.
            elif interface.startswith('Po') or interface.startswith('PC_'):
                return 'dpc'

        return 'port'
    
    def normalize_interface_name(self, interface_name, port_type):
        """Normalize interface names to match what APIC actually creates"""
        return interface_name
    
    def deduplicate_bindings(self, bindings):
        """Remove duplicate bindings"""
        seen = set()
        unique_bindings = []
        
        for binding in bindings:
            key = (
                binding.get('site', ''),
                binding.get('epg_name', ''),
                binding.get('path', ''),
                binding.get('vlan', '')
            )
            
            if key not in seen:
                seen.add(key)
                unique_bindings.append(binding)
        
        return unique_bindings
    
    def analyze_bindings(self, bindings):
            """Analyze and display binding statistics"""
            stats = {
                'total': len(bindings),
                'by_type': defaultdict(int),
                'by_site': defaultdict(lambda: defaultdict(int)),
                'by_site_type': defaultdict(lambda: defaultdict(int))
            }
            
            for binding in bindings:
                port_type = self.determine_port_type(binding)
                stats['by_type'][port_type] += 1
                
                site = binding.get('site', 'Unknown')
                stats['by_site'][site]['total'] += 1
                stats['by_site_type'][site][port_type] += 1
            
            print("\n" + "="*60)
            print("BINDING ANALYSIS")
            print("="*60)
            print(f"Total bindings: {stats['total']}")
            print(f"\nBy type:")
            for ptype, count in stats['by_type'].items():
                print(f"  - {ptype}: {count} ({count/stats['total']*100:.1f}%)")
            
            print(f"\nBy site:")
            for site, site_stats in stats['by_site_type'].items():
                total = stats['by_site'][site]['total']
                print(f"\n  {site}: {total} total")
                for ptype, count in site_stats.items():
                    print(f"    - {ptype}: {count} ({count/total*100:.1f}%)")
            
            print("\nSample bindings:")
            for ptype in ['dpc', 'vpc', 'port']:
                samples = [b for b in bindings if self.determine_port_type(b) == ptype][:2]
                if samples:
                    type_label = 'DPC' if ptype == 'dpc' else ptype.upper()
                    print(f"\n  {type_label} examples:")
                    for sample in samples:
                        print(f"    - EPG: {sample['epg_name']}, Path: {sample['path']}, VLAN: {sample['vlan']}")
            
            print("="*60 + "\n")
    
    def build_epg_cache(self, schema):
        """Build a cache of EPG locations for faster lookups.
        
        Builds two indexes:
          epg_cache:        site/template/epg_name -> location
          epg_name_lookup:  (site, epg_name) -> cache_key  (auto-resolve template)
        """
        print("Building EPG location cache...")
        
        sites_response = self.session.get(f"https://{self.ndo_host}/api/v1/sites")
        sites_map = {site['name']: site['id'] for site in sites_response.json()['sites']}
        
        self.epg_name_lookup = {}
        template_counts = defaultdict(int)
        
        for site_idx, site in enumerate(schema.get('sites', [])):
            site_id = site.get('siteId', '')
            site_name = next((name for name, id in sites_map.items() if id == site_id), 'Unknown')
            
            for anp_idx, anp in enumerate(site.get('anps', [])):
                for epg_idx, epg in enumerate(anp.get('epgs', [])):
                    epg_ref = epg.get('epgRef', '')
                    parts = epg_ref.split('/')
                    if len(parts) >= 8:
                        template_name = parts[4]
                        epg_name = parts[8]
                        
                        cache_key = f"{site_name}/{template_name}/{epg_name}"
                        self.epg_cache[cache_key] = {
                            'site_idx': site_idx,
                            'anp_idx': anp_idx,
                            'epg_idx': epg_idx,
                            'existing_bindings': len(epg.get('staticPorts', []))
                        }
                        
                        name_key = (site_name, epg_name)
                        self.epg_name_lookup[name_key] = cache_key
                        template_counts[template_name] += 1
        
        print(f"Cached {len(self.epg_cache)} EPG locations across templates:")
        for tmpl, count in sorted(template_counts.items()):
            print(f"  {tmpl}: {count} EPGs")
        
        existing_epgs = set()
        for cache_key in self.epg_cache:
            parts = cache_key.split('/')
            if len(parts) >= 3:
                existing_epgs.add(parts[2])
        
        return existing_epgs
    
    def deploy_bindings(self, bindings_file, dry_run=False):
        """Deploy all bindings from JSON file"""
        self.dry_run = dry_run
        if dry_run:
            print("\n*** DRY RUN MODE - No changes will be made ***\n")
        with open(bindings_file, 'r') as f:
            data = json.load(f)
        
        bindings = data['static_port_bindings']
        print(f"Found {len(bindings)} bindings in file")
        
        ethernet_bindings = [b for b in bindings if 'eth' in b.get('path', '').lower()]
        pc_bindings = [b for b in bindings if 'po' in b.get('path', '').lower() or 'vpc' in b.get('path', '').lower()]
        print(f"  - Ethernet bindings: {len(ethernet_bindings)}")
        print(f"  - Port-channel bindings: {len(pc_bindings)}")

        if ethernet_bindings:
            print("\nSample Ethernet bindings from JSON:")
            for binding in ethernet_bindings[:3]:
                print(f"  - Path: {binding['path']}, Type: {binding.get('port_type', 'NOT SET')}")
        
        bindings = self.deduplicate_bindings(bindings)
        print(f"After deduplication: {len(bindings)} unique bindings")
        
        self.analyze_bindings(bindings)
        
        schema_id = self.get_schema_id()
        schema_url = f"https://{self.ndo_host}/api/v1/schemas/{schema_id}"
        
        response = self.session.get(schema_url)
        schema = response.json()
        
        existing_epgs = self.build_epg_cache(schema)
        print(f"Found {len(existing_epgs)} existing EPGs in schema")
        
        filtered_bindings = [b for b in bindings if b.get('epg_name') in existing_epgs]
        skipped_epgs = set(b.get('epg_name') for b in bindings) - existing_epgs
        
        print(f"\nFiltered to {len(filtered_bindings)} bindings for existing EPGs")
        if skipped_epgs:
            print(f"Skipping {len(skipped_epgs)} EPGs that don't exist in schema")
        
        port_types = defaultdict(int)
        for binding in filtered_bindings:
            detected_type = self.determine_port_type(binding)
            port_types[detected_type] += 1
        
        print("\nBinding types detected:")
        for ptype, count in port_types.items():
            print(f"  - {ptype}: {count} bindings")
        
        grouped_bindings = defaultdict(list)
        
        for binding in filtered_bindings:
            site = binding['site']
            epg = binding['epg_name']
            name_key = (site, epg)
            
            if name_key in self.epg_name_lookup:
                resolved_cache_key = self.epg_name_lookup[name_key]
                resolved_template = resolved_cache_key.split('/')[1]
            else:
                resolved_template = binding.get('template', 'Tenant_EUR_V2')
            
            key = (site, resolved_template, epg)
            grouped_bindings[key].append(binding)
        
        templates_used = set(t for (_, t, _) in grouped_bindings.keys())
        print(f"\nGrouped into {len(grouped_bindings)} EPG configurations across templates: {', '.join(sorted(templates_used))}")
        
        all_patches = []
        skipped_existing = 0
        
        for (site_name, template_name, epg_name), epg_bindings in grouped_bindings.items():
            cache_key = f"{site_name}/{template_name}/{epg_name}"
            
            if cache_key in self.epg_cache:
                cache_entry = self.epg_cache[cache_key]
                site_idx = cache_entry['site_idx']
                anp_idx = cache_entry['anp_idx']
                epg_idx = cache_entry['epg_idx']
                
                print(f"\nProcessing {cache_key} ({len(epg_bindings)} bindings)")
                
                existing_static_ports = schema['sites'][site_idx]['anps'][anp_idx]['epgs'][epg_idx].get('staticPorts', [])
                existing_keys = set()
                for ep in existing_static_ports:
                    existing_keys.add((ep.get('path', ''), str(ep.get('portEncapVlan', ''))))
                
                epg_binding_keys = set()
                epg_patches = []
                
                for binding in epg_bindings:
                    actual_type = self.determine_port_type(binding)
                    
                    path_components = self.parse_topology_path(binding['path'])
                    
                    if not path_components:
                        print(f"  Warning: Could not parse path {binding['path']}, skipping")
                        continue
                    
                    binding_key = (
                        path_components['pod'],
                        path_components['leaf'],
                        path_components['interface'],
                        binding['vlan']
                    )
                    
                    if binding_key in epg_binding_keys:
                        print(f"  Skipping duplicate binding: {binding_key}")
                        continue
                    
                    epg_binding_keys.add(binding_key)
                    
                    if actual_type in ['dpc', 'vpc']:
                        normalized_interface = self.normalize_interface_name(
                            path_components['interface'], 
                            actual_type
                        )
                        
                        if actual_type == 'vpc' and 'protpaths' in binding.get('path', ''):
                            static_port_path = f"topology/{path_components['pod']}/protpaths-{path_components['leaf']}/pathep-[{normalized_interface}]"
                        else:
                            static_port_path = f"topology/{path_components['pod']}/paths-{path_components['leaf']}/pathep-[{normalized_interface}]"
                        
                    else:
                        static_port_path = binding['path']
                        
                    
                    existing_check = (static_port_path, str(binding['vlan']))
                    if existing_check in existing_keys:
                        skipped_existing += 1
                        continue

                    static_port = {
                        "type": actual_type,
                        "path": static_port_path,
                        "portEncapVlan": binding['vlan'],
                        "deploymentImmediacy": binding.get('deployment_immediacy', 'immediate'),
                        "mode": binding.get('mode', 'regular')
                    }

                    patch = {
                        "op": "add",
                        "path": f"/sites/{site_idx}/anps/{anp_idx}/epgs/{epg_idx}/staticPorts/-",
                        "value": static_port
                    }
                    epg_patches.append(patch)
                
                if epg_patches:
                    all_patches.extend(epg_patches)
                    print(f"  Created {len(epg_patches)} patches for this EPG")
            else:
                print(f"\n  Warning: EPG not found in schema: {cache_key}")
        
        print(f"\nSkipped {skipped_existing} bindings already on NDO")
        
        if len(all_patches) == 0:
            print("No new bindings to deploy!")
            return
        
        print(f"\nApplying {len(all_patches)} patches in batches...")
        
        batch_size = 50
        successful = 0
        failed = 0
        
        start_time = time.time()
        
        for i in range(0, len(all_patches), batch_size):
            batch = all_patches[i:i + batch_size]
            batch_num = i // batch_size + 1
            total_batches = (len(all_patches) + batch_size - 1) // batch_size
            
            progress = (i + len(batch)) / len(all_patches) * 100
            
            if self.dry_run:
                print(f"  Batch {batch_num}/{total_batches} ({progress:.1f}%): Would deploy {len(batch)} bindings... [DRY RUN]")
                successful += len(batch)
            else:
                print(f"  Batch {batch_num}/{total_batches} ({progress:.1f}%): Deploying {len(batch)} bindings...", end='', flush=True)
                
                try:
                    response = self.session.patch(schema_url, json=batch)
                    if response.status_code in [200, 202, 204]:
                        successful += len(batch)
                        print(" ✓")
                    else:
                        failed += len(batch)
                        print(f" ✗ (HTTP {response.status_code})")
                        error_msg = response.text[:300]
                        print(f"    Error: {error_msg}")
                        
                except Exception as e:
                    failed += len(batch)
                    print(f" ✗ (Exception: {str(e)})")
                
                time.sleep(0.5)
        
        end_time = time.time()
        deployment_time = end_time - start_time
        
        if self.dry_run:
            print(f"\nDry run complete in {deployment_time:.1f} seconds!")
            print(f"  Would deploy: {successful} bindings")
        else:
            print(f"\nDeployment complete in {deployment_time:.1f} seconds!")
            print(f"  ✓ Successful: {successful} bindings")
        print(f"  ✗ Failed: {failed} bindings")
        if successful > 0:
            print(f"  Rate: {successful / deployment_time:.1f} bindings/second")

def main():
    import argparse
    
    parser = argparse.ArgumentParser(description='Deploy static port bindings to NDO (PRODUCTION)')
    parser.add_argument('bindings_file', help='Path to the bindings JSON file')
    parser.add_argument('schema_name', nargs='?', default=DEFAULT_SCHEMA, help=f'NDO schema name (default: {DEFAULT_SCHEMA})')
    parser.add_argument('--dry-run', action='store_true', help='Preview changes without deploying')
    parser.add_argument('--no-vault', action='store_true', help='Use credentials from JSON file instead of vault')
    
    args = parser.parse_args()
    
    with open(args.bindings_file, 'r') as f:
        data = json.load(f)
    
    NDO_HOST = data.get('ndo_host', DEFAULT_NDO_HOST) or os.environ.get('NDO_HOST', '')
    NDO_USER = data.get('ndo_username', DEFAULT_NDO_USER)
    if not NDO_HOST:
        print(
            "Error: ndo_host is required. Set it in the bindings JSON "
            "(\"ndo_host\": \"...\") or export NDO_HOST=...",
            file=sys.stderr,
        )
        sys.exit(1)

    if args.no_vault:
        NDO_PASSWORD = data.get('ndo_password', '')
        if not NDO_PASSWORD:
            print("Error: ndo_password not found in JSON file.", file=sys.stderr)
            sys.exit(1)
        auth_method = 'JSON credentials'
    else:
        NDO_PASSWORD = load_password_from_vault('vault.yml', 'vault_pass.txt')
        auth_method = 'vault'
    
    schema_name = data.get('schema_name', args.schema_name)
    
    print("NDO Binding Deployment (Python) - PRODUCTION")
    print("="*50)
    print(f"NDO Host: {NDO_HOST}")
    print(f"Schema: {schema_name}")
    print(f"Bindings file: {args.bindings_file}")
    print(f"Auth: {auth_method}")
    print(f"Dry run: {args.dry_run}")
    print("="*50)
    
    start_time = time.time()
    
    deployer = NDOBindingDeployer(NDO_HOST, NDO_USER, NDO_PASSWORD, schema_name)
    deployer.deploy_bindings(args.bindings_file, dry_run=args.dry_run)
    
    end_time = time.time()
    duration = end_time - start_time
    print(f"\nTotal execution time: {duration:.1f} seconds ({duration/60:.1f} minutes)")

if __name__ == "__main__":
    main()
