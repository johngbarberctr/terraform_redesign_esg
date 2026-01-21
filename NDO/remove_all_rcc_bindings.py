#!/usr/bin/env python3
"""
Remove ALL static port bindings from RCC EPGs
Simpler approach - just clears everything
"""
import requests
import json
import urllib3
import sys

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

NDO_HOST = "198.18.133.100"
NDO_USER = "admin"
NDO_PASSWORD = "C1sco12345"
SCHEMA_NAME = "AEDCE"

def authenticate():
    """Authenticate to NDO"""
    session = requests.Session()
    session.verify = False
    
    auth_response = session.post(
        f"https://{NDO_HOST}/api/v1/auth/login",
        json={"username": NDO_USER, "password": NDO_PASSWORD}
    )
    auth_response.raise_for_status()
    
    token = auth_response.json()['token']
    session.headers.update({'Authorization': f'Bearer {token}'})
    print(f"✓ Authenticated to NDO")
    return session

def get_schema(session):
    """Get schema"""
    schemas_response = session.get(f"https://{NDO_HOST}/api/v1/schemas")
    schemas = schemas_response.json()['schemas']
    
    for s in schemas:
        if s['displayName'] == SCHEMA_NAME:
            return s
    
    raise ValueError(f"Schema {SCHEMA_NAME} not found")

def remove_all_rcc_bindings(dry_run=True):
    """Remove all bindings from RCC EPGs"""
    
    session = authenticate()
    schema = get_schema(session)
    schema_id = schema['id']
    schema_url = f"https://{NDO_HOST}/api/v1/schemas/{schema_id}"
    
    # Get sites
    sites_response = session.get(f"https://{NDO_HOST}/api/v1/sites")
    sites_map = {site['id']: site['name'] for site in sites_response.json()['sites']}
    
    print("\n" + "="*60)
    print("REMOVING ALL RCC EPG BINDINGS")
    print("="*60)
    if dry_run:
        print("** DRY RUN MODE **\n")
    
    total_removed = 0
    
    # Process each site
    for site_idx, site in enumerate(schema.get('sites', [])):
        site_id = site.get('siteId', '')
        site_name = sites_map.get(site_id, 'Unknown')
        
        for anp_idx, anp in enumerate(site.get('anps', [])):
            anp_ref = anp.get('anpRef', '')
            
            # Only process AppProf-RCC
            if 'AppProf-RCC' not in anp_ref:
                continue
            
            for epg_idx, epg in enumerate(anp.get('epgs', [])):
                epg_ref = epg.get('epgRef', '')
                parts = epg_ref.split('/')
                
                if len(parts) >= 8:
                    template_name = parts[4]
                    epg_name = parts[8]
                    static_ports = epg.get('staticPorts', [])
                    
                    if static_ports:
                        print(f"\n{site_name}/{template_name}/{epg_name}")
                        print(f"  Bindings to remove: {len(static_ports)}")
                        
                        # Remove all bindings (in reverse order)
                        for port_idx in range(len(static_ports) - 1, -1, -1):
                            port = static_ports[port_idx]
                            print(f"    Removing: {port.get('path')} VLAN {port.get('portEncapVlan')}")
                            
                            if not dry_run:
                                patch = [{
                                    "op": "remove",
                                    "path": f"/sites/{site_idx}/anps/{anp_idx}/epgs/{epg_idx}/staticPorts/{port_idx}"
                                }]
                                
                                try:
                                    response = session.patch(schema_url, json=patch)
                                    if response.status_code in [200, 202, 204]:
                                        total_removed += 1
                                        print(f"      ✓ Removed")
                                    else:
                                        print(f"      ✗ Failed: {response.status_code}")
                                except Exception as e:
                                    print(f"      ✗ Error: {str(e)}")
                            else:
                                total_removed += 1
    
    print("\n" + "="*60)
    print(f"{'Would remove' if dry_run else 'Removed'}: {total_removed} bindings")
    print("="*60)
    
    return total_removed

def main():
    dry_run = '--dry-run' in sys.argv or '-d' in sys.argv
    
    print("="*60)
    print("RCC EPG Binding Removal Tool")
    print("="*60)
    print(f"Mode: {'DRY RUN' if dry_run else 'LIVE DELETION'}")
    print("="*60)
    
    if not dry_run:
        response = input("\nThis will DELETE ALL bindings from RCC EPGs. Continue? (yes/no): ")
        if response.lower() != 'yes':
            print("Aborted.")
            sys.exit(0)
    
    remove_all_rcc_bindings(dry_run)
    
    if not dry_run:
        print("\n✓ All RCC bindings removed!")
        print("\nNext steps:")
        print("  1. python3 generate_ipv6_bindings.py generate")
        print("  2. Review ipv6_rcc_port_bindings.json")
        print("  3. python3 generate_ipv6_bindings.py deploy")

if __name__ == "__main__":
    print("\nUsage:")
    print("  python3 remove_all_rcc_bindings.py --dry-run  # Test mode")
    print("  python3 remove_all_rcc_bindings.py            # Actually delete")
    print()
    main()