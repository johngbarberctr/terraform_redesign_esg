#!/usr/bin/env python3
"""
APIC Endpoint Query Script
--------------------------
Queries APIC for learned endpoints on each EPG to verify functional mappings.

Usage:
    python3 get_epg_endpoints.py --apic <APIC_IP> --username <USER> --password <PASS>
    
Example:
    python3 get_epg_endpoints.py --apic 10.1.1.1 --username admin --password C1sco123
"""

import requests
import json
import argparse
import urllib3
from collections import defaultdict

# Disable SSL warnings for self-signed certs
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

class APICEndpointQuery:
    def __init__(self, apic_ip, username, password):
        self.apic_ip = apic_ip
        self.base_url = f"https://{apic_ip}"
        self.username = username
        self.password = password
        self.session = requests.Session()
        self.token = None
        
    def login(self):
        """Authenticate to APIC"""
        url = f"{self.base_url}/api/aaaLogin.json"
        payload = {
            "aaaUser": {
                "attributes": {
                    "name": self.username,
                    "pwd": self.password
                }
            }
        }
        
        try:
            response = self.session.post(url, json=payload, verify=False, timeout=30)
            response.raise_for_status()
            data = response.json()
            self.token = data['imdata'][0]['aaaLogin']['attributes']['token']
            print(f"✅ Successfully authenticated to APIC {self.apic_ip}")
            return True
        except Exception as e:
            print(f"❌ Failed to authenticate: {e}")
            return False
    
    def get_tenant_epgs(self, tenant="EUR"):
        """Get all EPGs in a tenant"""
        url = f"{self.base_url}/api/node/class/fvAEPg.json"
        params = {
            "query-target-filter": f'wcard(fvAEPg.dn,"tn-{tenant}")',
            "order-by": "fvAEPg.name"
        }
        
        try:
            response = self.session.get(url, params=params, verify=False, timeout=30)
            response.raise_for_status()
            data = response.json()
            
            epgs = []
            for item in data.get('imdata', []):
                attrs = item['fvAEPg']['attributes']
                epgs.append({
                    'name': attrs['name'],
                    'dn': attrs['dn'],
                    'descr': attrs.get('descr', '')
                })
            return epgs
        except Exception as e:
            print(f"❌ Failed to get EPGs: {e}")
            return []
    
    def get_epg_endpoints(self, epg_dn):
        """Get learned endpoints for a specific EPG"""
        # Query fvCEp (Client Endpoints) under this EPG
        url = f"{self.base_url}/api/node/class/fvCEp.json"
        params = {
            "query-target-filter": f'wcard(fvCEp.dn,"{epg_dn}")',
            "rsp-subtree": "children",
            "rsp-subtree-class": "fvIp"
        }
        
        try:
            response = self.session.get(url, params=params, verify=False, timeout=60)
            response.raise_for_status()
            data = response.json()
            
            endpoints = []
            for item in data.get('imdata', []):
                ep_attrs = item['fvCEp']['attributes']
                
                # Get IP addresses from children
                ips = []
                for child in item['fvCEp'].get('children', []):
                    if 'fvIp' in child:
                        ips.append(child['fvIp']['attributes']['addr'])
                
                endpoints.append({
                    'mac': ep_attrs.get('mac', ''),
                    'name': ep_attrs.get('name', ''),
                    'encap': ep_attrs.get('encap', ''),
                    'ips': ips,
                    'learning_source': ep_attrs.get('lcC', '')
                })
            return endpoints
        except Exception as e:
            print(f"❌ Failed to get endpoints: {e}")
            return []
    
    def get_epg_static_ports(self, epg_dn):
        """Get static port bindings for an EPG"""
        url = f"{self.base_url}/api/mo/{epg_dn}.json"
        params = {
            "query-target": "children",
            "target-subtree-class": "fvRsPathAtt"
        }
        
        try:
            response = self.session.get(url, params=params, verify=False, timeout=30)
            response.raise_for_status()
            data = response.json()
            
            ports = []
            for item in data.get('imdata', []):
                attrs = item['fvRsPathAtt']['attributes']
                ports.append({
                    'path': attrs.get('tDn', ''),
                    'encap': attrs.get('encap', ''),
                    'mode': attrs.get('mode', '')
                })
            return ports
        except Exception as e:
            return []
    
    def run_full_report(self, tenant="EUR", target_epgs=None):
        """Generate full endpoint report"""
        if not self.login():
            return
        
        print(f"\n{'='*120}")
        print(f"APIC ENDPOINT REPORT - Tenant: {tenant}")
        print(f"{'='*120}\n")
        
        epgs = self.get_tenant_epgs(tenant)
        print(f"Found {len(epgs)} EPGs in tenant {tenant}\n")
        
        # Filter to target EPGs if specified
        if target_epgs:
            epgs = [e for e in epgs if any(t in e['name'] for t in target_epgs)]
            print(f"Filtered to {len(epgs)} target EPGs\n")
        
        results = []
        
        for epg in epgs:
            endpoints = self.get_epg_endpoints(epg['dn'])
            ports = self.get_epg_static_ports(epg['dn'])
            
            # Extract VLAN from encap
            vlan = ""
            if endpoints and endpoints[0].get('encap'):
                vlan = endpoints[0]['encap'].replace('vlan-', '')
            elif ports and ports[0].get('encap'):
                vlan = ports[0]['encap'].replace('vlan-', '')
            
            results.append({
                'epg': epg['name'],
                'vlan': vlan,
                'endpoint_count': len(endpoints),
                'port_count': len(ports),
                'endpoints': endpoints[:10],  # First 10 for display
                'descr': epg['descr']
            })
        
        # Sort by EPG name
        results.sort(key=lambda x: x['epg'])
        
        # Print summary table
        print(f"{'EPG Name':<30} {'VLAN':<8} {'Endpoints':<12} {'Ports':<8} {'Description'}")
        print(f"{'-'*30} {'-'*8} {'-'*12} {'-'*8} {'-'*40}")
        
        for r in results:
            print(f"{r['epg']:<30} {r['vlan']:<8} {r['endpoint_count']:<12} {r['port_count']:<8} {r['descr'][:40]}")
        
        # Print detailed endpoint info for EPGs with endpoints
        print(f"\n{'='*120}")
        print("DETAILED ENDPOINT DATA (EPGs with learned endpoints)")
        print(f"{'='*120}")
        
        for r in results:
            if r['endpoint_count'] > 0:
                print(f"\n{'-'*80}")
                print(f"EPG: {r['epg']} | VLAN: {r['vlan']} | Endpoints: {r['endpoint_count']}")
                print(f"{'-'*80}")
                print(f"{'MAC Address':<20} {'IP Addresses':<40} {'Learning Source'}")
                print(f"{'-'*20} {'-'*40} {'-'*20}")
                
                for ep in r['endpoints']:
                    ips = ', '.join(ep['ips']) if ep['ips'] else '(no IP)'
                    print(f"{ep['mac']:<20} {ips:<40} {ep['learning_source']}")
                
                if r['endpoint_count'] > 10:
                    print(f"... and {r['endpoint_count'] - 10} more endpoints")
        
        # Save to JSON for further analysis
        output_file = f"apic_endpoints_{self.apic_ip.replace('.','_')}.json"
        with open(output_file, 'w') as f:
            json.dump(results, f, indent=2)
        print(f"\n✅ Full results saved to: {output_file}")
        
        return results


def main():
    parser = argparse.ArgumentParser(description='Query APIC for EPG endpoints')
    parser.add_argument('--apic', required=True, help='APIC IP address')
    parser.add_argument('--username', default='admin', help='APIC username')
    parser.add_argument('--password', required=True, help='APIC password')
    parser.add_argument('--tenant', default='EUR', help='Tenant name (default: EUR)')
    parser.add_argument('--epg-filter', nargs='*', help='Filter to specific EPGs (partial match)')
    
    args = parser.parse_args()
    
    query = APICEndpointQuery(args.apic, args.username, args.password)
    query.run_full_report(args.tenant, args.epg_filter)


if __name__ == "__main__":
    main()
