#!/usr/bin/env python3
"""
NDO IPv6 Binding Generator and Deployer
- Auto-discovers all RCC EPGs across templates
- Extracts port bindings from reference IPv4 EPG
- Creates IPv6 bindings with VLANs 3000-3032
- Handles both Site1 and Site2 sites
- Future-proof: automatically handles new EPGs
"""
import requests
import json
import time
import urllib3
from collections import defaultdict
import sys
import re
import traceback

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

class NDOIPv6BindingGenerator:
    def __init__(self, ndo_host, username, password, schema_name="AFRICOM"):
        self.ndo_host = ndo_host
        self.schema_name = schema_name
        self.session = requests.Session()
        self.session.verify = False
        
        print(f"Initializing connection to {ndo_host}...")
        self.auth_token = self._authenticate(username, password)
        
        # Reference IPv4 EPG to copy port patterns from
        self.reference_ipv4_epg = "EPG-V0015"  # Standard production pattern
        self.reference_gef_epg = "EPG-V0260"   # GEF pattern with external connectivity
        
        # Starting VLAN for IPv6 EPGs
        self.starting_vlan = 3000
        
    def _authenticate(self, username, password):
        """Authenticate and get token"""
        try:
            auth_url = f"https://{self.ndo_host}/api/v1/auth/login"
            auth_data = {"username": username, "password": password}
            
            print(f"Authenticating to {auth_url}...")
            response = self.session.post(auth_url, json=auth_data)
            response.raise_for_status()
            
            token = response.json()['token']
            self.session.headers.update({'Authorization': f'Bearer {token}'})
            print(f"✓ Authenticated successfully")
            return token
        except Exception as e:
            print(f"✗ Authentication failed: {str(e)}")
            raise
    
    def get_schema_id(self):
        """Get schema ID"""
        try:
            url = f"https://{self.ndo_host}/api/v1/schemas"
            print(f"Fetching schemas from {url}...")
            response = self.session.get(url)
            response.raise_for_status()
            schemas = response.json()['schemas']
            
            print(f"Found {len(schemas)} schemas")
            for schema in schemas:
                print(f"  - {schema['displayName']}")
                if schema['displayName'] == self.schema_name:
                    print(f"✓ Found target schema: {self.schema_name}")
                    return schema['id']
            
            raise ValueError(f"Schema {self.schema_name} not found")
        except Exception as e:
            print(f"✗ Error getting schema: {str(e)}")
            raise
    
    def discover_rcc_epgs(self, schema):
        """Auto-discover all RCC EPGs across all templates"""
        print("\n" + "="*60)
        print("DISCOVERING RCC EPGs")
        print("="*60)
        
        rcc_epgs = []
        
        templates = schema.get('templates', [])
        print(f"Scanning {len(templates)} templates...")
        
        for template in templates:
            template_name = template.get('name', 'Unknown')
            print(f"\nTemplate: {template_name}")
            
            anps = template.get('anps', [])
            if anps:
                print(f"  Found {len(anps)} ANPs")
                
                for anp in anps:
                    anp_name = anp.get('name', '')
                    print(f"    ANP: {anp_name}")
                    
                    # Look for AppProf-RCC
                    if anp_name == 'AppProf-RCC':
                        print(f"    ✓ Found AppProf-RCC!")
                        
                        epgs = anp.get('epgs', [])
                        print(f"      EPGs in this ANP: {len(epgs)}")
                        
                        for epg in epgs:
                            epg_name = epg.get('name', '')
                            bd_ref = epg.get('bdRef', '')
                            bd_name = bd_ref.split('/')[-1] if bd_ref else 'Unknown'
                            
                            rcc_epgs.append({
                                'epg_name': epg_name,
                                'bd_name': bd_name,
                                'template': template_name,
                                'anp': anp_name
                            })
                            print(f"        - {epg_name} (BD: {bd_name})")
            else:
                print(f"  No ANPs in this template")
        
        print(f"\n" + "="*60)
        print(f"✓ Total RCC EPGs discovered: {len(rcc_epgs)}")
        print("="*60)
        
        if rcc_epgs:
            print("\nDiscovered EPGs by template:")
            by_template = defaultdict(list)
            for epg in rcc_epgs:
                by_template[epg['template']].append(epg['epg_name'])
            
            for template, epg_names in sorted(by_template.items()):
                print(f"  {template}: {len(epg_names)} EPGs")
                for name in epg_names:
                    print(f"    - {name}")
        
        return sorted(rcc_epgs, key=lambda x: x['epg_name'])
    
    def extract_reference_port_bindings(self, schema, reference_epg_name):
        """Extract port bindings from reference IPv4 EPG"""
        print(f"\n" + "="*60)
        print(f"EXTRACTING PORT BINDINGS FROM: {reference_epg_name}")
        print("="*60)
        
        try:
            sites_response = self.session.get(f"https://{self.ndo_host}/api/v1/sites")
            sites_response.raise_for_status()
            sites_map = {site['id']: site['name'] for site in sites_response.json()['sites']}
            
            print(f"Sites in fabric: {list(sites_map.values())}")
            
            reference_bindings = []
            bindings_by_site = defaultdict(list)
            
            sites = schema.get('sites', [])
            print(f"\nScanning {len(sites)} site deployments...")
            
            for site in sites:
                site_id = site.get('siteId', '')
                site_name = sites_map.get(site_id, 'Unknown')
                print(f"\n  Site: {site_name}")
                
                for anp in site.get('anps', []):
                    anp_ref = anp.get('anpRef', '')
                    anp_name = anp_ref.split('/')[-1] if anp_ref else 'Unknown'
                    
                    for epg in anp.get('epgs', []):
                        epg_ref = epg.get('epgRef', '')
                        parts = epg_ref.split('/')
                        
                        if len(parts) >= 8:
                            epg_name = parts[8]
                            
                            if epg_name == reference_epg_name:
                                static_ports = epg.get('staticPorts', [])
                                
                                print(f"    ✓ Found {reference_epg_name}")
                                print(f"      Static ports: {len(static_ports)}")
                                
                                for port in static_ports:
                                    binding = {
                                        'site': site_name,
                                        'type': port.get('type', 'port'),
                                        'path': port.get('path', ''),
                                        'deployment_immediacy': port.get('deploymentImmediacy', 'immediate'),
                                        'mode': port.get('mode', 'regular')
                                    }
                                    reference_bindings.append(binding)
                                    bindings_by_site[site_name].append(binding)
                                    print(f"        Path: {binding['path']}")
            
            if not reference_bindings:
                print(f"\n⚠ Warning: No port bindings found for {reference_epg_name}")
                print("  Using default pattern: VPC_D1A-B + VPC_D2A-B for both sites")
                reference_bindings = self._get_default_bindings()
            else:
                print(f"\n✓ Total bindings extracted: {len(reference_bindings)}")
                for site, bindings in bindings_by_site.items():
                    print(f"  {site}: {len(bindings)} bindings")
            
            return reference_bindings
            
        except Exception as e:
            print(f"✗ Error extracting bindings: {str(e)}")
            traceback.print_exc()
            return self._get_default_bindings()
    
    def _get_default_bindings(self):
        """Provide default port bindings if reference EPG not found"""
        print("\nUsing default port binding pattern...")
        return [
            {
                'site': 'Site1',
                'type': 'vpc',
                'path': 'topology/pod-1/protpaths-111-112/pathep-[VPC_D1A-B]',
                'deployment_immediacy': 'immediate',
                'mode': 'regular'
            },
            {
                'site': 'Site1',
                'type': 'vpc',
                'path': 'topology/pod-1/protpaths-111-112/pathep-[VPC_D2A-B]',
                'deployment_immediacy': 'immediate',
                'mode': 'regular'
            },
            {
                'site': 'Site2',
                'type': 'vpc',
                'path': 'topology/pod-1/protpaths-111-112/pathep-[VPC_D1A-B]',
                'deployment_immediacy': 'immediate',
                'mode': 'regular'
            },
            {
                'site': 'Site2',
                'type': 'vpc',
                'path': 'topology/pod-1/protpaths-111-112/pathep-[VPC_D2A-B]',
                'deployment_immediacy': 'immediate',
                'mode': 'regular'
            }
        ]
    
    def _get_gef_bindings(self, schema):
        """Get bindings for GEF-MGMT (includes VPC_GEF_A-B)"""
        print(f"\n" + "="*60)
        print(f"EXTRACTING GEF BINDINGS FROM: {self.reference_gef_epg}")
        print("="*60)
        
        gef_bindings = self.extract_reference_port_bindings(schema, self.reference_gef_epg)
        
        # Check if VPC_GEF_A-B is included
        has_gef_path = any('VPC_GEF_A-B' in b['path'] for b in gef_bindings)
        
        if not has_gef_path:
            print("\n⚠ No VPC_GEF_A-B found in reference, adding default GEF path")
            gef_bindings.append({
                'site': 'Site1',
                'type': 'vpc',
                'path': 'topology/pod-1/protpaths-111-112/pathep-[VPC_GEF_A-B]',
                'deployment_immediacy': 'immediate',
                'mode': 'regular'
            })
        
        return gef_bindings
    
    def generate_ipv6_bindings(self, rcc_epgs, reference_bindings, gef_bindings):
        """Generate IPv6 bindings for all discovered RCC EPGs"""
        print("\n" + "="*60)
        print("GENERATING IPv6 BINDINGS")
        print("="*60)
        
        ipv6_bindings = []
        vlan_counter = self.starting_vlan
        
        for epg_info in rcc_epgs:
            epg_name = epg_info['epg_name']
            template = epg_info['template']
            bd_name = epg_info['bd_name']
            
            print(f"\nProcessing: {epg_name}")
            print(f"  Template: {template}")
            print(f"  BD: {bd_name}")
            print(f"  VLAN: {vlan_counter}")
            
            # Determine which port pattern to use
            if 'GEF' in epg_name.upper():
                ports_to_use = gef_bindings
                print(f"  Pattern: GEF (includes VPC_GEF_A-B)")
            else:
                ports_to_use = reference_bindings
                print(f"  Pattern: Standard production")
            
            # Filter bindings by site/template
            filtered_ports = []
            for port in ports_to_use:
                include_port = False
                
                if template == 'Site1-Specific_Only':
                    if port['site'] == 'Site1':
                        include_port = True
                elif template == 'Site2-Specific_Only':
                    if port['site'] == 'Site2':
                        include_port = True
                else:
                    # L2_Stretched or L2_Non-Stretched: both sites
                    include_port = True
                
                if include_port:
                    filtered_ports.append(port)
                    print(f"    ✓ Port: {port['site']} - {port['path']}")
            
            epg_config = {
                'epg_name': epg_name,
                'vlan': str(vlan_counter),
                'tenant': 'EUR',
                'app_profile': 'AppProf-RCC',
                'bd_name': bd_name,
                'template': template,
                'ports': []
            }
            
            for port in filtered_ports:
                port_config = {
                    'description': f"{epg_name} VLAN {vlan_counter}",
                    'is_trunk': True,
                    'path': port['path'],
                    'deployment_immediacy': port['deployment_immediacy'],
                    'mode': port['mode'],
                    'encap': f"vlan-{vlan_counter}",
                    'site': port['site'],
                    'type': port['type']
                }
                epg_config['ports'].append(port_config)
            
            ipv6_bindings.append(epg_config)
            print(f"  ✓ Generated {len(epg_config['ports'])} port bindings")
            
            vlan_counter += 1
        
        return ipv6_bindings
    
    def save_bindings_to_file(self, bindings, filename='ipv6_rcc_port_bindings.json'):
        """Save generated bindings to JSON file"""
        print(f"\n" + "="*60)
        print("SAVING BINDINGS TO FILE")
        print("="*60)
        
        try:
            with open(filename, 'w') as f:
                json.dump(bindings, f, indent=2)
            print(f"✓ Bindings saved to: {filename}")
            
            # Summary statistics
            total_ports = sum(len(epg['ports']) for epg in bindings)
            by_template = defaultdict(int)
            by_site = defaultdict(int)
            
            for epg in bindings:
                by_template[epg['template']] += 1
                for port in epg['ports']:
                    by_site[port['site']] += 1
            
            print(f"\nSummary:")
            print(f"  EPGs: {len(bindings)}")
            print(f"  Total port bindings: {total_ports}")
            print(f"  VLAN range: {self.starting_vlan}-{self.starting_vlan + len(bindings) - 1}")
            
            print(f"\n  By Template:")
            for template, count in sorted(by_template.items()):
                print(f"    {template}: {count} EPGs")
            
            print(f"\n  By Site:")
            for site, count in sorted(by_site.items()):
                print(f"    {site}: {count} port bindings")
                
        except Exception as e:
            print(f"✗ Error saving file: {str(e)}")
            raise
    
    def deploy_bindings(self, bindings):
        """Deploy IPv6 bindings to NDO"""
        print("\n" + "="*60)
        print("DEPLOYING IPv6 BINDINGS TO NDO")
        print("="*60)
        
        try:
            schema_id = self.get_schema_id()
            schema_url = f"https://{self.ndo_host}/api/v1/schemas/{schema_id}"
            
            # Get current schema
            response = self.session.get(schema_url)
            response.raise_for_status()
            schema = response.json()
            
            # Build EPG cache
            epg_cache = self._build_epg_cache(schema)
            print(f"✓ Cached {len(epg_cache)} EPG locations")
            
            # Create patches
            all_patches = []
            skipped_epgs = []
            processed_epgs = set()
            
            for epg_config in bindings:
                epg_name = epg_config['epg_name']
                template = epg_config['template']
                vlan = int(epg_config['vlan'])
                
                for port in epg_config['ports']:
                    site_name = port['site']
                    cache_key = f"{site_name}/{template}/{epg_name}"
                    
                    if cache_key in epg_cache:
                        cache_entry = epg_cache[cache_key]
                        site_idx = cache_entry['site_idx']
                        anp_idx = cache_entry['anp_idx']
                        epg_idx = cache_entry['epg_idx']
                        
                        static_port = {
                            "type": port['type'],
                            "path": port['path'],
                            "portEncapVlan": vlan,
                            "deploymentImmediacy": port['deployment_immediacy'],
                            "mode": port['mode']
                        }
                        
                        patch = {
                            "op": "add",
                            "path": f"/sites/{site_idx}/anps/{anp_idx}/epgs/{epg_idx}/staticPorts/-",
                            "value": static_port
                        }
                        all_patches.append(patch)
                        processed_epgs.add(cache_key)
                    else:
                        if cache_key not in skipped_epgs:
                            skipped_epgs.append(cache_key)
            
            print(f"\n✓ Processed {len(processed_epgs)} EPG instances")
            
            if skipped_epgs:
                print(f"\n⚠ Warning: {len(skipped_epgs)} EPG instances not found:")
                for key in skipped_epgs:
                    print(f"  - {key}")
            
            if not all_patches:
                print("\n⚠ No bindings to deploy!")
                return
            
            print(f"\n✓ Ready to deploy {len(all_patches)} port bindings")
            
            # Apply patches in batches
            batch_size = 50
            successful = 0
            failed = 0
            start_time = time.time()
            
            print("\nDeploying...")
            for i in range(0, len(all_patches), batch_size):
                batch = all_patches[i:i + batch_size]
                batch_num = i // batch_size + 1
                total_batches = (len(all_patches) + batch_size - 1) // batch_size
                
                progress = (i + len(batch)) / len(all_patches) * 100
                print(f"  Batch {batch_num}/{total_batches} ({progress:.1f}%): ", end='', flush=True)
                
                try:
                    response = self.session.patch(schema_url, json=batch)
                    if response.status_code in [200, 202, 204]:
                        successful += len(batch)
                        print(f"✓ {len(batch)} bindings")
                    else:
                        failed += len(batch)
                        print(f"✗ Failed (HTTP {response.status_code})")
                        print(f"    Error: {response.text[:200]}")
                except Exception as e:
                    failed += len(batch)
                    print(f"✗ Exception: {str(e)}")
                
                time.sleep(0.5)
            
            end_time = time.time()
            deployment_time = end_time - start_time
            
            print("\n" + "="*60)
            print(f"DEPLOYMENT COMPLETE in {deployment_time:.1f} seconds")
            print("="*60)
            print(f"  ✓ Successful: {successful} bindings")
            print(f"  ✗ Failed: {failed} bindings")
            if successful > 0:
                print(f"  Rate: {successful / deployment_time:.1f} bindings/second")
                
        except Exception as e:
            print(f"\n✗ Deployment error: {str(e)}")
            traceback.print_exc()
            raise
    
    def _build_epg_cache(self, schema):
        """Build cache of EPG locations for all sites"""
        epg_cache = {}
        
        sites_response = self.session.get(f"https://{self.ndo_host}/api/v1/sites")
        sites_map = {site['id']: site['name'] for site in sites_response.json()['sites']}
        
        for site_idx, site in enumerate(schema.get('sites', [])):
            site_id = site.get('siteId', '')
            site_name = sites_map.get(site_id, 'Unknown')
            
            for anp_idx, anp in enumerate(site.get('anps', [])):
                for epg_idx, epg in enumerate(anp.get('epgs', [])):
                    epg_ref = epg.get('epgRef', '')
                    parts = epg_ref.split('/')
                    if len(parts) >= 8:
                        template_name = parts[4]
                        epg_name = parts[8]
                        
                        cache_key = f"{site_name}/{template_name}/{epg_name}"
                        epg_cache[cache_key] = {
                            'site_idx': site_idx,
                            'anp_idx': anp_idx,
                            'epg_idx': epg_idx
                        }
        
        return epg_cache

def main():
    # Configuration
    NDO_HOST = "198.18.1.12"
    NDO_USER = "admin"
    NDO_PASSWORD = "IRanthehoodtocoast2021@"
    SCHEMA_NAME = "AFRICOM"
    
    # Parse command line arguments
    if len(sys.argv) > 1:
        mode = sys.argv[1]
    else:
        mode = "both"
    
    print("="*60)
    print("NDO IPv6 RCC BINDING GENERATOR")
    print("="*60)
    print(f"NDO Host: {NDO_HOST}")
    print(f"Schema: {SCHEMA_NAME}")
    print(f"Mode: {mode}")
    print("="*60)
    
    start_time = time.time()
    
    try:
        generator = NDOIPv6BindingGenerator(NDO_HOST, NDO_USER, NDO_PASSWORD, SCHEMA_NAME)
        
        # Get schema
        print("\nFetching schema...")
        schema_id = generator.get_schema_id()
        schema_url = f"https://{generator.ndo_host}/api/v1/schemas/{schema_id}"
        response = generator.session.get(schema_url)
        response.raise_for_status()
        schema = response.json()
        print(f"✓ Schema loaded: {schema['displayName']}")
        
        # Discover all RCC EPGs
        rcc_epgs = generator.discover_rcc_epgs(schema)
        
        if not rcc_epgs:
            print("\n✗ No RCC EPGs found in schema!")
            print("\nPossible reasons:")
            print("  1. Terraform hasn't created the EPGs yet")
            print("  2. EPGs exist but not under 'AppProf-RCC'")
            print("  3. Wrong schema name")
            print("\nRun 'terraform apply' first, then retry this script.")
            sys.exit(1)
        
        # Extract reference port bindings
        reference_bindings = generator.extract_reference_port_bindings(
            schema, 
            generator.reference_ipv4_epg
        )
        
        # Get GEF-specific bindings
        gef_bindings = generator._get_gef_bindings(schema)
        
        # Generate IPv6 bindings
        ipv6_bindings = generator.generate_ipv6_bindings(
            rcc_epgs, 
            reference_bindings,
            gef_bindings
        )
        
        # Save to file
        generator.save_bindings_to_file(ipv6_bindings, 'ipv6_rcc_port_bindings.json')
        
        # Deploy if requested
        if mode in ['deploy', 'both']:
            print("\n" + "="*60)
            user_input = input("\nDeploy bindings to NDO now? (yes/no): ")
            if user_input.lower() == 'yes':
                generator.deploy_bindings(ipv6_bindings)
            else:
                print("\n✓ Bindings saved to file only.")
                print("\nTo deploy later:")
                print("  python3 generate_ipv6_bindings.py deploy")
        
        end_time = time.time()
        duration = end_time - start_time
        
        print(f"\n" + "="*60)
        print(f"✓ TOTAL EXECUTION TIME: {duration:.1f} seconds")
        print("="*60)
        
    except Exception as e:
        print(f"\n" + "="*60)
        print(f"✗ FATAL ERROR")
        print("="*60)
        print(f"Error: {str(e)}")
        print("\nFull traceback:")
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] in ['-h', '--help', 'help']:
        print("\nNDO IPv6 RCC Binding Generator")
        print("="*60)
        print("\nUsage:")
        print("  python3 generate_ipv6_bindings.py [mode]")
        print("\nModes:")
        print("  generate  - Generate JSON file only (no deployment)")
        print("  deploy    - Generate and deploy automatically")
        print("  both      - Generate and prompt for deployment (default)")
        print("\nExamples:")
        print("  python3 generate_ipv6_bindings.py")
        print("  python3 generate_ipv6_bindings.py generate")
        print("  python3 generate_ipv6_bindings.py deploy")
        print("\nOutput:")
        print("  - JSON file: ipv6_rcc_port_bindings.json")
        print("  - Deployed to NDO (if selected)")
        print()
        sys.exit(0)
    
    main()