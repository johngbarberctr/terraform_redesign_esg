#!/usr/bin/env python3
"""
NDO IPv6 Binding Generator - Intelligent Mapping
Maps each IPv6 EPG to the most appropriate IPv4 EPG based on function
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
    def __init__(self, ndo_host, username, password, schema_name="AEDCE"):
        self.ndo_host = ndo_host
        self.schema_name = schema_name
        self.session = requests.Session()
        self.session.verify = False
        
        print(f"Initializing connection to {ndo_host}...")
        self.auth_token = self._authenticate(username, password)
        
        # Starting VLAN for IPv6 EPGs
        self.starting_vlan = 3000
        
        # Intelligent mapping: IPv6 EPG → IPv4 reference EPG
        # Based on functional similarity
        self.epg_mapping = {
            # Infrastructure Management - Map to similar infra EPGs
            'EPG-NAC': {'reference': 'EPG-V0015', 'vlan': 3000, 'template': 'L2_Stretched'},
            'EPG-CFG-MGMT': {'reference': 'EPG-V0021', 'vlan': 3001, 'template': 'L2_Stretched'},
            'EPG-GEF-MGMT': {'reference': 'EPG-V0260', 'vlan': 3002, 'template': 'G-Specific_Only'},  # Uses GEF path
            'EPG-MECM': {'reference': 'EPG-V0033', 'vlan': 3003, 'template': 'L2_Stretched'},
            
            # Network Services - Map to network service EPGs
            'EPG-LB': {'reference': 'EPG-V0210', 'vlan': 3004, 'template': 'L2_Stretched'},  # Load balancer
            'EPG-DNS-MGMT': {'reference': 'EPG-V0216', 'vlan': 3005, 'template': 'L2_Stretched'},  # DNS
            'EPG-RCC-DNS': {'reference': 'EPG-V0218', 'vlan': 3006, 'template': 'L2_Stretched'},  # DNS
            'EPG-DHCP-SVR': {'reference': 'EPG-V0219', 'vlan': 3007, 'template': 'L2_Stretched'},  # DHCP
            'EPG-SMTP-SVR': {'reference': 'EPG-V0220', 'vlan': 3008, 'template': 'L2_Stretched'},  # SMTP
            
            # Voice and Communications - Map to voice EPGs
            'EPG-VVOIP-MGMT': {'reference': 'EPG-V0160', 'vlan': 3009, 'template': 'L2_Stretched'},  # VoIP mgmt
            'EPG-VVOIP-PROXY': {'reference': 'EPG-V0161', 'vlan': 3010, 'template': 'L2_Stretched'},  # VoIP proxy
            'EPG-LMR': {'reference': 'EPG-V0163', 'vlan': 3011, 'template': 'L2_Stretched'},  # Radio
            'EPG-E911-SVR': {'reference': 'EPG-V0178', 'vlan': 3012, 'template': 'L2_Stretched'},  # Emergency
            
            # Security Services - Map to security EPGs
            'EPG-ACAS-SCANNERS': {'reference': 'EPG-V0140', 'vlan': 3013, 'template': 'L2_Stretched'},  # Scanners
            'EPG-C2C-SCANNERS': {'reference': 'EPG-V0141', 'vlan': 3014, 'template': 'L2_Stretched'},  # Scanners
            'EPG-OCSP': {'reference': 'EPG-V0142', 'vlan': 3015, 'template': 'L2_Stretched'},  # Certificate
            'EPG-PKI-SRV': {'reference': 'EPG-V0144', 'vlan': 3016, 'template': 'L2_Stretched'},  # PKI
            
            # Directory and Authentication - Map to directory EPGs
            'EPG-AD': {'reference': 'EPG-V0150', 'vlan': 3017, 'template': 'L2_Stretched'},  # Active Directory
            'EPG-ADFS': {'reference': 'EPG-V0160', 'vlan': 3018, 'template': 'L2_Stretched'},  # ADFS
            
            # Proxy Services - Map to proxy EPGs
            'EPG-D64-PROXY': {'reference': 'EPG-V0260', 'vlan': 3019, 'template': 'L2_Stretched'},  # Proxy
            'EPG-RWEB-PROXY': {'reference': 'EPG-V0261', 'vlan': 3020, 'template': 'L2_Stretched'},  # Proxy
            'EPG-FWEB-PROXY': {'reference': 'EPG-V0262', 'vlan': 3021, 'template': 'L2_Stretched'},  # Proxy
            
            # Application and Web Servers - Map to app EPGs
            'EPG-APP-SVR': {'reference': 'EPG-V0420', 'vlan': 3022, 'template': 'L2_Stretched'},  # App servers
            'EPG-WEB-SVR': {'reference': 'EPG-V0420', 'vlan': 3023, 'template': 'L2_Stretched'},  # Web servers
            'EPG-FMWR-SVR': {'reference': 'EPG-V0450', 'vlan': 3024, 'template': 'L2_Stretched'},  # Firmware
            
            # RCC Services - Map to RCC-like EPGs
            'EPG-RCC-SVR': {'reference': 'EPG-V0470', 'vlan': 3025, 'template': 'L2_Stretched'},  # RCC servers
            'EPG-RCC-DCO': {'reference': 'EPG-V0471', 'vlan': 3026, 'template': 'L2_Stretched'},  # DCO
            'EPG-RCC-UNIX': {'reference': 'EPG-V0472', 'vlan': 3027, 'template': 'L2_Stretched'},  # UNIX
            
            # Storage Services - Map to storage EPGs
            'EPG-PRINT-SVR': {'reference': 'EPG-V0520', 'vlan': 3028, 'template': 'L2_Stretched'},  # Print
            'EPG-FILE-SVR': {'reference': 'EPG-V0521', 'vlan': 3029, 'template': 'L2_Stretched'},  # File
            'EPG-BACKUP-SVR': {'reference': 'EPG-V0522', 'vlan': 3030, 'template': 'K-Specific_Only'},  # Backup
            
            # Database and Logging - Map to data EPGs
            'EPG-DB-SVR': {'reference': 'EPG-V0570', 'vlan': 3031, 'template': 'L2_Non-Stretched'},  # Database
            'EPG-SYSLOG': {'reference': 'EPG-V0572', 'vlan': 3032, 'template': 'L2_Non-Stretched'},  # Syslog
        }
        
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
            print(f"Fetching schemas...")
            response = self.session.get(url)
            response.raise_for_status()
            schemas = response.json()['schemas']
            
            for schema in schemas:
                if schema['displayName'] == self.schema_name:
                    print(f"✓ Found schema: {self.schema_name} (ID: {schema['id']})")
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
            
            anps = template.get('anps', [])
            
            for anp in anps:
                anp_name = anp.get('name', '')
                
                # Look for AppProf-RCC
                if anp_name == 'AppProf-RCC':
                    print(f"\n✓ Found AppProf-RCC in template: {template_name}")
                    
                    epgs = anp.get('epgs', [])
                    
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
                        print(f"    - {epg_name} (BD: {bd_name})")
        
        print(f"\n✓ Total RCC EPGs discovered: {len(rcc_epgs)}")
        return sorted(rcc_epgs, key=lambda x: x['epg_name'])
    
    def extract_all_ipv4_bindings(self, schema):
        """Extract port bindings from ALL IPv4 EPGs (excluding leaves 101/102)"""
        print(f"\n" + "="*60)
        print(f"EXTRACTING ALL IPv4 EPG PORT BINDINGS")
        print("(Filtering out leaves 101/102)")
        print("="*60)
        
        try:
            sites_response = self.session.get(f"https://{self.ndo_host}/api/v1/sites")
            sites_response.raise_for_status()
            sites_map = {site['id']: site['name'] for site in sites_response.json()['sites']}
            
            # Dictionary to store bindings per EPG
            all_bindings = defaultdict(list)
            skipped_101_102 = 0
            
            sites = schema.get('sites', [])
            print(f"Note: {len(sites)} site/template deployment combinations")
            unique_sites = set()
            
            for site in sites:
                site_id = site.get('siteId', '')
                site_name = sites_map.get(site_id, 'Unknown')
                unique_sites.add(site_name)
                
                for anp in site.get('anps', []):
                    for epg in anp.get('epgs', []):
                        epg_ref = epg.get('epgRef', '')
                        parts = epg_ref.split('/')
                        
                        if len(parts) >= 8:
                            epg_name = parts[8]
                            static_ports = epg.get('staticPorts', [])
                            
                            if static_ports:
                                for port in static_ports:
                                    path = port.get('path', '')
                                    
                                    # Skip bindings on leaves 101/102 (including VPCs between them)
                                    if re.search(r'/(?:paths|protpaths)-10[12](?:/|-10[12])', path):
                                        skipped_101_102 += 1
                                        continue
                                    
                                    binding = {
                                        'site': site_name,
                                        'type': port.get('type', 'port'),
                                        'path': path,
                                        'deployment_immediacy': port.get('deploymentImmediacy', 'immediate'),
                                        'mode': port.get('mode', 'regular')
                                    }
                                    all_bindings[epg_name].append(binding)
            
            print(f"✓ Unique physical sites: {sorted(unique_sites)}")
            print(f"✓ Found bindings for {len(all_bindings)} IPv4 EPGs")
            print(f"✓ Skipped {skipped_101_102} bindings on leaves 101/102")
            
            # Show reference EPGs we'll use
            print("\nReference EPGs found:")
            for ipv6_epg, mapping in sorted(self.epg_mapping.items()):
                ref_epg = mapping['reference']
                if ref_epg in all_bindings:
                    print(f"  ✓ {ref_epg} → {ipv6_epg} ({len(all_bindings[ref_epg])} bindings)")
                else:
                    print(f"  ✗ {ref_epg} → {ipv6_epg} (NOT FOUND - will use default)")
            
            return all_bindings
            
        except Exception as e:
            print(f"✗ Error extracting bindings: {str(e)}")
            traceback.print_exc()
            return {}
    
    def _get_default_bindings(self):
        """Provide default port bindings (VPC only, no leaves 101/102)"""
        return [
            {
                'site': 'AEDCG',
                'type': 'vpc',
                'path': 'topology/pod-1/protpaths-111-112/pathep-[VPC_D1A-B]',
                'deployment_immediacy': 'immediate',
                'mode': 'regular'
            },
            {
                'site': 'AEDCG',
                'type': 'vpc',
                'path': 'topology/pod-1/protpaths-111-112/pathep-[VPC_D2A-B]',
                'deployment_immediacy': 'immediate',
                'mode': 'regular'
            },
            {
                'site': 'AEDCK',
                'type': 'vpc',
                'path': 'topology/pod-1/protpaths-111-112/pathep-[VPC_D1A-B]',
                'deployment_immediacy': 'immediate',
                'mode': 'regular'
            },
            {
                'site': 'AEDCK',
                'type': 'vpc',
                'path': 'topology/pod-1/protpaths-111-112/pathep-[VPC_D2A-B]',
                'deployment_immediacy': 'immediate',
                'mode': 'regular'
            }
        ]
    
    def generate_ipv6_bindings(self, rcc_epgs, all_ipv4_bindings):
        """Generate IPv6 bindings using intelligent mapping"""
        print("\n" + "="*60)
        print("GENERATING IPv6 BINDINGS WITH INTELLIGENT MAPPING")
        print("="*60)
        
        ipv6_bindings = []
        
        for epg_info in rcc_epgs:
            epg_name = epg_info['epg_name']
            template = epg_info['template']
            bd_name = epg_info['bd_name']
            
            # Get mapping for this EPG
            if epg_name in self.epg_mapping:
                mapping = self.epg_mapping[epg_name]
                reference_epg = mapping['reference']
                vlan = mapping['vlan']
                
                print(f"\n{epg_name} (VLAN {vlan})")
                print(f"  Template: {template}")
                print(f"  Reference: {reference_epg}")
                
                # Get bindings from reference EPG
                if reference_epg in all_ipv4_bindings:
                    ports_to_use = all_ipv4_bindings[reference_epg]
                    print(f"  ✓ Found {len(ports_to_use)} port bindings from {reference_epg}")
                else:
                    print(f"  ⚠ Reference EPG not found, using defaults")
                    ports_to_use = self._get_default_bindings()
            else:
                # EPG not in mapping - use defaults
                print(f"\n{epg_name} - NOT IN MAPPING, using defaults")
                vlan = self.starting_vlan + len(ipv6_bindings)
                ports_to_use = self._get_default_bindings()
            
            # Filter by template/site
            filtered_ports = []
            for port in ports_to_use:
                include_port = False
                
                if template == 'G-Specific_Only':
                    if port['site'] == 'AEDCG':
                        include_port = True
                elif template == 'K-Specific_Only':
                    if port['site'] == 'AEDCK':
                        include_port = True
                else:
                    # L2_Stretched or L2_Non-Stretched: both sites
                    include_port = True
                
                if include_port:
                    filtered_ports.append(port)
            
            print(f"  Filtered to {len(filtered_ports)} ports for template {template}")
            
            epg_config = {
                'epg_name': epg_name,
                'vlan': str(vlan),
                'tenant': 'EUR',
                'app_profile': 'AppProf-RCC',
                'bd_name': bd_name,
                'template': template,
                'reference_epg': reference_epg if epg_name in self.epg_mapping else 'default',
                'ports': []
            }
            
            for port in filtered_ports:
                port_config = {
                    'description': f"{epg_name} VLAN {vlan}",
                    'is_trunk': True,
                    'path': port['path'],
                    'deployment_immediacy': port['deployment_immediacy'],
                    'mode': port['mode'],
                    'encap': f"vlan-{vlan}",
                    'site': port['site'],
                    'type': port['type']
                }
                epg_config['ports'].append(port_config)
                print(f"    {port['site']}: {port['path']}")
            
            ipv6_bindings.append(epg_config)
        
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
            
            # Summary
            total_ports = sum(len(epg['ports']) for epg in bindings)
            by_template = defaultdict(int)
            by_site = defaultdict(int)
            by_reference = defaultdict(int)
            
            for epg in bindings:
                by_template[epg['template']] += 1
                by_reference[epg.get('reference_epg', 'unknown')] += 1
                for port in epg['ports']:
                    by_site[port['site']] += 1
            
            print(f"\nSummary:")
            print(f"  EPGs: {len(bindings)}")
            print(f"  Total port bindings: {total_ports}")
            print(f"  VLAN range: {min(int(e['vlan']) for e in bindings)}-{max(int(e['vlan']) for e in bindings)}")
            
            print(f"\n  By Template:")
            for template, count in sorted(by_template.items()):
                print(f"    {template}: {count} EPGs")
            
            print(f"\n  By Site:")
            for site, count in sorted(by_site.items()):
                print(f"    {site}: {count} port bindings")
            
            print(f"\n  Reference EPGs Used:")
            for ref, count in sorted(by_reference.items()):
                print(f"    {ref}: {count} times")
                
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
            
            # Apply patches
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
                
        except Exception as e:
            print(f"\n✗ Deployment error: {str(e)}")
            traceback.print_exc()
            raise
    
    def _build_epg_cache(self, schema):
        """Build cache of EPG locations"""
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
    SCHEMA_NAME = "AEDCE"
    
    mode = sys.argv[1] if len(sys.argv) > 1 else "both"
    
    print("="*60)
    print("NDO IPv6 RCC BINDING GENERATOR")
    print("Intelligent mapping based on functional similarity")
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
        
        # Discover RCC EPGs
        rcc_epgs = generator.discover_rcc_epgs(schema)
        
        if not rcc_epgs:
            print("\n✗ No RCC EPGs found!")
            print("Run 'terraform apply' first.")
            sys.exit(1)
        
        # Extract ALL IPv4 bindings
        all_ipv4_bindings = generator.extract_all_ipv4_bindings(schema)
        
        if not all_ipv4_bindings:
            print("\n⚠ No IPv4 bindings found, using defaults for all EPGs")
        
        # Generate IPv6 bindings with intelligent mapping
        ipv6_bindings = generator.generate_ipv6_bindings(rcc_epgs, all_ipv4_bindings)
        
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
        
        end_time = time.time()
        print(f"\n✓ Total time: {end_time - start_time:.1f} seconds")
        
    except Exception as e:
        print(f"\n✗ FATAL ERROR: {str(e)}")
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()