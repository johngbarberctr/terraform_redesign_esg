#!/usr/bin/env python3
"""
Export NDO Schema Configuration
Extracts BD and EPG mappings with template placement
"""

import requests
import json
import urllib3
from collections import defaultdict

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# Configuration
NDO_HOST = "198.18.1.12"
NDO_USER = "admin"
NDO_PASSWORD = "IRanthehoodtocoast2021@"
SCHEMA_NAME = "AFRICOM"

# Authenticate
session = requests.Session()
session.verify = False

auth_response = session.post(
    f"https://{NDO_HOST}/api/v1/auth/login",
    json={"username": NDO_USER, "password": NDO_PASSWORD}
)
token = auth_response.json()['token']
session.headers.update({'Authorization': f'Bearer {token}'})

print(f"Authenticated to NDO: {NDO_HOST}")

# Get all schemas
schemas_response = session.get(f"https://{NDO_HOST}/api/v1/schemas")
schemas = schemas_response.json()['schemas']

# Find AFRICOM schema
africom_schema = None
for schema in schemas:
    if schema['displayName'] == SCHEMA_NAME:
        africom_schema = schema
        break

if not africom_schema:
    print(f"Schema {SCHEMA_NAME} not found!")
    exit(1)

print(f"\nFound schema: {SCHEMA_NAME}")
print(f"Schema ID: {africom_schema['id']}")

# Parse templates
print("\n" + "="*80)
print("TEMPLATE STRUCTURE")
print("="*80)

for template in africom_schema.get('templates', []):
    template_name = template.get('name', 'Unknown')
    display_name = template.get('displayName', template_name)
    
    print(f"\n### TEMPLATE: {template_name} (Display: {display_name})")
    print("-" * 80)
    
    # VRFs
    vrfs = template.get('vrfs', [])
    if vrfs:
        print(f"\n  VRFs ({len(vrfs)}):")
        for vrf in vrfs:
            vrf_name = vrf.get('name', 'Unknown')
            vzany = vrf.get('vzAnyEnabled', False)
            print(f"    - {vrf_name} (vzAny: {vzany})")
    
    # Bridge Domains
    bds = template.get('bds', [])
    if bds:
        print(f"\n  Bridge Domains ({len(bds)}):")
        for bd in bds:
            bd_name = bd.get('name', 'Unknown')
            vrf_ref = bd.get('vrfRef', '')
            vrf_name = vrf_ref.split('/')[-1] if vrf_ref else 'None'
            
            # Get subnets
            subnets = bd.get('subnets', [])
            subnet_ips = [s.get('ip', 'N/A') for s in subnets]
            
            print(f"    - {bd_name}")
            print(f"        VRF: {vrf_name}")
            if subnet_ips:
                print(f"        Subnets: {', '.join(subnet_ips)}")
    
    # Application Profiles and EPGs
    anps = template.get('anps', [])
    if anps:
        print(f"\n  Application Profiles ({len(anps)}):")
        for anp in anps:
            anp_name = anp.get('name', 'Unknown')
            print(f"    - {anp_name}")
            
            epgs = anp.get('epgs', [])
            if epgs:
                print(f"      EPGs ({len(epgs)}):")
                for epg in epgs:
                    epg_name = epg.get('name', 'Unknown')
                    bd_ref = epg.get('bdRef', '')
                    bd_name = bd_ref.split('/')[-1] if bd_ref else 'None'
                    
                    print(f"        - {epg_name} → BD: {bd_name}")
    
    # Contracts
    contracts = template.get('contracts', [])
    if contracts:
        print(f"\n  Contracts ({len(contracts)}):")
        for contract in contracts:
            contract_name = contract.get('name', 'Unknown')
            scope = contract.get('scope', 'N/A')
            print(f"    - {contract_name} (scope: {scope})")

print("\n" + "="*80)
print("EXPORT COMPLETE")
print("="*80)

# Also save full schema to file
with open('africom_schema_full.json', 'w') as f:
    json.dump(africom_schema, f, indent=2)

print(f"\nFull schema saved to: africom_schema_full.json")
print("\nYou can now share this file or copy the output above.")