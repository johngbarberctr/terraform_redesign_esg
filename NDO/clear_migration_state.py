#!/usr/bin/env python3
"""
Clear stuck migration state in NDO
"""

import requests
import json
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# Configuration
NDO_URL = "https://10.196.209.170"
NDO_USER = "admin"
NDO_PASS = "cisco!123"
SCHEMA_ID = "68a72e0b3bffb5d1e2ef0e58"

def login():
    """Login to NDO"""
    url = f"{NDO_URL}/api/v1/auth/login"
    payload = {"username": NDO_USER, "password": NDO_PASS}
    response = requests.post(url, json=payload, verify=False)
    if response.status_code == 200:
        return response.json()['token']
    return None

def clear_migration_and_delete():
    """Clear migration state and delete template"""
    token = login()
    if not token:
        print("Failed to login")
        return
    
    headers = {"Authorization": f"Bearer {token}"}
    
    # Get schema
    print("Getting schema...")
    response = requests.get(f"{NDO_URL}/api/v1/schemas/{SCHEMA_ID}", 
                          headers=headers, verify=False)
    
    if response.status_code != 200:
        print(f"Failed to get schema: {response.text}")
        return
    
    schema = response.json()
    print(f"Current templates: {[t['name'] for t in schema['templates']]}")
    
    # Method 1: Clear migration flags
    print("\nClearing migration flags...")
    for template in schema['templates']:
        # Remove all migration-related fields
        keys_to_remove = ['migration', 'migrations', 'migrationStatus', 
                         'sourceMigration', 'targetMigration']
        for key in keys_to_remove:
            if key in template:
                del template[key]
    
    # Update schema
    response = requests.put(f"{NDO_URL}/api/v1/schemas/{SCHEMA_ID}",
                          headers=headers, json=schema, verify=False)
    
    if response.status_code == 200:
        print("✓ Migration flags cleared")
    else:
        print(f"Failed to clear flags: {response.text}")
    
    # Method 2: Remove VRF_Template from templates array
    print("\nRemoving VRF_Template...")
    schema['templates'] = [t for t in schema['templates'] 
                          if t['name'] != 'VRF_Template']
    
    # Update schema without VRF_Template
    response = requests.put(f"{NDO_URL}/api/v1/schemas/{SCHEMA_ID}",
                          headers=headers, json=schema, verify=False)
    
    if response.status_code == 200:
        print("✓ VRF_Template deleted successfully!")
        print(f"Remaining templates: {[t['name'] for t in schema['templates']]}")
    else:
        print(f"Failed to delete template: {response.text}")
        
        # Try alternative: Set schema with only L2_Stretched
        print("\nTrying alternative: Reset schema with only L2_Stretched...")
        minimal_schema = {
            "id": SCHEMA_ID,
            "displayName": "AEDCE",
            "templates": [
                {
                    "name": "L2_Stretched",
                    "displayName": "L2_Stretched",
                    "tenantId": schema['templates'][0].get('tenantId', ''),
                    "anps": [],
                    "vrfs": [],
                    "bds": [],
                    "contracts": [],
                    "filters": [],
                    "externalEpgs": [],
                    "serviceGraphs": []
                }
            ],
            "sites": schema.get('sites', [])
        }
        
        response = requests.put(f"{NDO_URL}/api/v1/schemas/{SCHEMA_ID}",
                              headers=headers, json=minimal_schema, verify=False)
        
        if response.status_code == 200:
            print("✓ Schema reset with only L2_Stretched template")
        else:
            print(f"Failed: {response.text}")

if __name__ == "__main__":
    clear_migration_and_delete()