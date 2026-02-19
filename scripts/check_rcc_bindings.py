#!/usr/bin/env python3
"""
Check what bindings actually exist on RCC EPGs
"""
import requests
import json
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

NDO_HOST = "198.18.1.12"
NDO_USER = "admin"
NDO_PASSWORD = "IRanthehoodtocoast2021@"
SCHEMA_NAME = "AEDCE"

# Authenticate
session = requests.Session()
session.verify = False

auth_response = session.post(
    f"https://{NDO_HOST}/api/v1/auth/login",
    json={"username": NDO_USER, "password": NDO_PASSWORD}
)
token = auth_response.json()['token']
session.headers.update({'Authorization': f'Bearer {token}'})

# Get schema
schemas_response = session.get(f"https://{NDO_HOST}/api/v1/schemas")
schemas = schemas_response.json()['schemas']

schema = None
for s in schemas:
    if s['displayName'] == SCHEMA_NAME:
        schema = s
        break

if not schema:
    print(f"Schema {SCHEMA_NAME} not found")
    exit(1)

# Get sites
sites_response = session.get(f"https://{NDO_HOST}/api/v1/sites")
sites_map = {site['id']: site['name'] for site in sites_response.json()['sites']}

print("="*60)
print("CURRENT RCC EPG STATIC PORT BINDINGS")
print("="*60)

total_bindings = 0

# Check each site
for site in schema.get('sites', []):
    site_id = site.get('siteId', '')
    site_name = sites_map.get(site_id, 'Unknown')
    
    for anp in site.get('anps', []):
        anp_ref = anp.get('anpRef', '')
        
        # Only check AppProf-RCC
        if 'AppProf-RCC' not in anp_ref:
            continue
        
        for epg in anp.get('epgs', []):
            epg_ref = epg.get('epgRef', '')
            parts = epg_ref.split('/')
            
            if len(parts) >= 8:
                template_name = parts[4]
                epg_name = parts[8]
                static_ports = epg.get('staticPorts', [])
                
                if static_ports:
                    print(f"\n{site_name}/{template_name}/{epg_name}")
                    print(f"  Static ports: {len(static_ports)}")
                    for port in static_ports:
                        print(f"    - Path: {port.get('path')}, VLAN: {port.get('portEncapVlan')}")
                        total_bindings += 1

print("\n" + "="*60)
print(f"TOTAL BINDINGS ON RCC EPGs: {total_bindings}")
print("="*60)