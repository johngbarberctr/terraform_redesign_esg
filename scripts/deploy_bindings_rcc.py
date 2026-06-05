#!/usr/bin/env python3
import requests
import json
import time
import urllib3
from collections import defaultdict
import sys
import re

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

class NDOBindingDeployer:
    def __init__(self, ndo_host, username, password, schema_name="AFRICOM"):
        self.ndo_host = ndo_host
        self.schema_name = schema_name
        self.session = requests.Session()
        self.session.verify = False
        self.auth_token = self._authenticate(username, password)
        self.epg_cache = {}
        
    def _authenticate(self, username, password):
        """Authenticate and get token"""
        auth_url = f"https://{self.ndo_host}/api/v1/auth/login"
        auth_data = {"username": username, "password": password}
        
        response = self.session.post(auth_url, json=auth_data)
        response.raise_for_status()
        
        token = response.json()['token']
        self.session.headers.update({'Authorization': f'Bearer {token}'})
        return token
    
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
        # Handle protpaths for vPC (nodes 111-112)
        match = re.match(r'topology/(pod-\d+)/protpaths-(\d+-\d+)/pathep-\[([^\]]+)\]', full_path)
        if match:
            pod = match.group(1)
            leaf = match.group(2)
            interface = match.group(3)
            
            return {
                'pod': pod,
                'leaf': leaf,
                'interface': interface,
                'is_vpc': True
            }
        
        # Handle regular paths
        match = re.match(r'topology/(pod-\d+)/paths-(\d+)/pathep-\[([^\]]+)\]', full_path)
        if match:
            pod = match.group(1)
            leaf = match.group(2)
            interface = match.group(3)
            
            return {
                'pod': pod,
                'leaf': leaf,
                'interface': interface,
                'is_vpc': False
            }
        
        return None
    
    def determine_port_type(self, binding):
        """Determine if a binding is for a regular port, DPC, or VPC"""
        path = binding.get('path', '')
        
        # Check if it's a VPC based on path
        if 'protpaths' in path:
            return 'vpc'
        
        # Check for port-channel patterns
        interface_match = re.search(r'pathep-\[([^\]]+)\]', path)
        if interface_match:
            interface = interface_match.group(1)
            if interface.startswith('Po'):
                return 'dpc'
        
        # Default to regular port
        return 'port'
    
    def normalize_interface_name(self, interface_name, port_type):
        """Normalize interface names to match what APIC actually creates"""
        # Keep the name as-is for VPC policy groups
        return interface_name
    
    def deduplicate_bindings(self, bindings):
        """Remove duplicate bindings"""
        seen = set()
        unique_bindings = []
        
        for binding in bindings:
            # Create a unique key for each binding based on ports array
            for port in binding.get('ports', []):
                key = (
                    binding.get('epg_name', ''),
                    port.get('path', ''),
                    port.get('encap', '')
                )
                
                if key not in seen:
                    seen.add(key)
                    # Create individual binding for each port
                    individual_binding = {
                        'epg_name': binding.get('epg_name'),
                        'vlan': binding.get('vlan'),
                        'tenant': binding.get('tenant'),
                        'app_profile': binding.get('app_profile'),
                        'bd_name': binding.get('bd_name'),
                        'vrf_name': binding.get('vrf_name'),
                        'site': 'Site1',  # Assuming Site1 site
                        'template': 'L2_Stretched',  # Assuming L2_Stretched template
                        'path': port.get('path'),
                        'deployment_immediacy': port.get('deployment_immediacy', 'immediate'),
                        'mode': port.get('mode', 'regular'),
                        'encap': port.get('encap')
                    }
                    unique_bindings.append(individual_binding)
        
        return unique_bindings
    
    def analyze_bindings(self, bindings):
        """Analyze and display binding statistics"""
        stats = {
            'total': len(bindings),
            'by_type': defaultdict(int),
            'by_epg': defaultdict(int)
        }
        
        for binding in bindings:
            # Determine type
            port_type = self.determine_port_type(binding)
            stats['by_type'][port_type] += 1
            
            # By EPG
            epg_name = binding.get('epg_name', 'Unknown')
            stats['by_epg'][epg_name] += 1
        
        # Display statistics
        print("\n" + "="*60)
        print("BINDING ANALYSIS")
        print("="*60)
        print(f"Total bindings: {stats['total']}")
        print(f"\nBy type:")
        for ptype, count in stats['by_type'].items():
            print(f"  - {ptype}: {count} ({count/stats['total']*100:.1f}%)")
        
        print(f"\nTop 10 EPGs by binding count:")
        sorted_epgs = sorted(stats['by_epg'].items(), key=lambda x: x[1], reverse=True)[:10]
        for epg, count in sorted_epgs:
            print(f"  - {epg}: {count} bindings")
        
        # Show sample bindings
        print("\nSample bindings:")
        for ptype in ['vpc', 'dpc', 'port']:
            samples = [b for b in bindings if self.determine_port_type(b) == ptype][:2]
            if samples:
                type_label = ptype.upper()
                print(f"\n  {type_label} examples:")
                for sample in samples:
                    print(f"    - EPG: {sample['epg_name']}, Path: {sample['path']}, VLAN: {sample.get('encap', 'N/A')}")
        
        print("="*60 + "\n")
    
    def build_epg_cache(self, schema):
        """Build a cache of EPG locations for faster lookups"""
        print("Building EPG location cache...")
        
        # Get site information
        sites_response = self.session.get(f"https://{self.ndo_host}/api/v1/sites")
        sites_map = {site['name']: site['id'] for site in sites_response.json()['sites']}
        
        # Build cache
        for site_idx, site in enumerate(schema.get('sites', [])):
            site_id = site.get('siteId', '')
            site_name = next((name for name, id in sites_map.items() if id == site_id), 'Unknown')
            
            for anp_idx, anp in enumerate(site.get('anps', [])):
                for epg_idx, epg in enumerate(anp.get('epgs', [])):
                    epg_ref = epg.get('epgRef', '')
                    # Extract template and EPG name from ref
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
        
        print(f"Cached {len(self.epg_cache)} EPG locations")
        
        # Return list of existing EPGs
        existing_epgs = set()
        for cache_key in self.epg_cache:
            parts = cache_key.split('/')
            if len(parts) >= 3:
                existing_epgs.add(parts[2])  # EPG name
        
        return existing_epgs
    
    def deploy_bindings(self, bindings_file):
        """Deploy all bindings from JSON file"""
        # Load bindings - MODIFIED TO HANDLE NEW JSON FORMAT
        with open(bindings_file, 'r') as f:
            data = json.load(f)
        
        # Check if it's the new format (list of EPG objects with ports arrays)
        if isinstance(data, list):
            print(f"Found {len(data)} EPGs in new format")
            bindings = data
        else:
            # Old format with 'static_port_bindings' key
            bindings = data.get('static_port_bindings', [])
            print(f"Found {len(bindings)} bindings in old format")
        
        # Convert to flat list and deduplicate
        bindings = self.deduplicate_bindings(bindings)
        print(f"After processing: {len(bindings)} unique bindings")
        
        # Analyze bindings
        self.analyze_bindings(bindings)
        
        # Get schema
        schema_id = self.get_schema_id()
        schema_url = f"https://{self.ndo_host}/api/v1/schemas/{schema_id}"
        
        # Get current schema
        response = self.session.get(schema_url)
        schema = response.json()
        
        # Build EPG cache and get existing EPGs
        existing_epgs = self.build_epg_cache(schema)
        print(f"Found {len(existing_epgs)} existing EPGs in schema")
        
        # Filter bindings to only existing EPGs
        filtered_bindings = [b for b in bindings if b.get('epg_name') in existing_epgs]
        skipped_epgs = set(b.get('epg_name') for b in bindings) - existing_epgs
        
        print(f"\nFiltered to {len(filtered_bindings)} bindings for existing EPGs")
        if skipped_epgs:
            print(f"Skipping {len(skipped_epgs)} EPGs that don't exist in schema:")
            for epg in sorted(skipped_epgs):
                print(f"  - {epg}")
        
        # Analyze binding types
        port_types = defaultdict(int)
        for binding in filtered_bindings:
            detected_type = self.determine_port_type(binding)
            port_types[detected_type] += 1
        
        print("\nBinding types detected:")
        for ptype, count in port_types.items():
            print(f"  - {ptype}: {count} bindings")
        
        # Group bindings by site, template, and EPG
        grouped_bindings = defaultdict(list)
        
        for binding in filtered_bindings:
            key = (binding['site'], binding.get('template', 'L2_Stretched'), binding['epg_name'])
            grouped_bindings[key].append(binding)
        
        print(f"\nGrouped into {len(grouped_bindings)} EPG configurations")
        
        # Create patches for all bindings
        all_patches = []
        
        # Process each EPG group
        for (site_name, template_name, epg_name), epg_bindings in grouped_bindings.items():
            cache_key = f"{site_name}/{template_name}/{epg_name}"
            
            if cache_key in self.epg_cache:
                cache_entry = self.epg_cache[cache_key]
                site_idx = cache_entry['site_idx']
                anp_idx = cache_entry['anp_idx']
                epg_idx = cache_entry['epg_idx']
                
                print(f"\nProcessing {cache_key} ({len(epg_bindings)} bindings)")
                
                # Get existing bindings for this EPG
                existing_static_ports = schema['sites'][site_idx]['anps'][anp_idx]['epgs'][epg_idx].get('staticPorts', [])
                
                # Create a set to track unique bindings for this EPG
                epg_binding_keys = set()
                epg_patches = []
                
                # Create patch operations for this EPG's bindings
                for binding in epg_bindings:
                    # Determine the actual port type
                    actual_type = self.determine_port_type(binding)
                    
                    # Parse the topology path
                    path_components = self.parse_topology_path(binding['path'])
                    
                    if not path_components:
                        print(f"  Warning: Could not parse path {binding['path']}, skipping")
                        continue
                    
                    # Extract VLAN from encap (e.g., "vlan-3000" -> 3000)
                    encap = binding.get('encap', '')
                    vlan_match = re.search(r'vlan-(\d+)', encap)
                    vlan = int(vlan_match.group(1)) if vlan_match else binding.get('vlan')
                    
                    print(f"  Creating binding: type={actual_type}, interface={path_components['interface']}, vlan={vlan}")
                    
                    # Create unique key for this binding
                    binding_key = (
                        path_components['pod'],
                        path_components['leaf'],
                        path_components['interface'],
                        vlan
                    )
                    
                    # Skip if we've already added this binding
                    if binding_key in epg_binding_keys:
                        print(f"  Skipping duplicate binding: {binding_key}")
                        continue
                    
                    epg_binding_keys.add(binding_key)
                    
                    # Use the path directly from the JSON
                    static_port_path = binding['path']
                    
                    # Create static port configuration
                    static_port = {
                        "type": actual_type,
                        "path": static_port_path,
                        "portEncapVlan": vlan,
                        "deploymentImmediacy": binding.get('deployment_immediacy', 'immediate'),
                        "mode": binding.get('mode', 'regular')
                    }
                    
                    print(f"    Static port: path={static_port_path}, vlan={vlan}")

                    patch = {
                        "op": "add",
                        "path": f"/sites/{site_idx}/anps/{anp_idx}/epgs/{epg_idx}/staticPorts/-",
                        "value": static_port
                    }
                    epg_patches.append(patch)
                
                # Add patches for this EPG to the overall list
                if epg_patches:
                    all_patches.extend(epg_patches)
                    print(f"  Created {len(epg_patches)} patches for this EPG")
            else:
                print(f"\n  Warning: EPG not found in schema: {cache_key}")
        
        if len(all_patches) == 0:
            print("\nNo new bindings to deploy!")
            return
        
        # Apply patches in batches
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
            
            # Small delay between batches
            time.sleep(0.5)
        
        end_time = time.time()
        deployment_time = end_time - start_time
        
        print(f"\nDeployment complete in {deployment_time:.1f} seconds!")
        print(f"  ✓ Successful: {successful} bindings")
        print(f"  ✗ Failed: {failed} bindings")
        if successful > 0:
            print(f"  Rate: {successful / deployment_time:.1f} bindings/second")

def main():
    if len(sys.argv) < 2:
        print("Usage: python deploy_bindings_rcc.py <bindings.json> [schema_name]")
        print("\nExamples:")
        print("  python deploy_bindings_rcc.py epg_port_bindings.json")
        print("  python deploy_bindings_rcc.py epg_port_bindings.json AFRICOM")
        sys.exit(1)
    
    # Configuration
    NDO_HOST = "198.18.1.12"
    NDO_USER = "admin"
    NDO_PASSWORD = "IRanthehoodtocoast2021@"
    
    # Allow schema name to be specified as argument
    schema_name = sys.argv[2] if len(sys.argv) > 2 else "AFRICOM"
    
    print("NDO Binding Deployment (Python) - RCC EPGs")
    print("="*50)
    print(f"NDO Host: {NDO_HOST}")
    print(f"Schema: {schema_name}")
    print(f"Bindings file: {sys.argv[1]}")
    print("="*50)
    
    start_time = time.time()
    
    deployer = NDOBindingDeployer(NDO_HOST, NDO_USER, NDO_PASSWORD, schema_name)
    deployer.deploy_bindings(sys.argv[1])
    
    end_time = time.time()
    duration = end_time - start_time
    print(f"\nTotal execution time: {duration:.1f} seconds ({duration/60:.1f} minutes)")

if __name__ == "__main__":
    main()