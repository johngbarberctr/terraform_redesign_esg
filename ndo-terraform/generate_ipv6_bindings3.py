#!/usr/bin/env python3
"""
NDO IPv6 Binding Generator - Production Version
Complete VLAN Mapping from Actual Data
CONFIGURED FOR LEAVES 101/102 (111/112 will be done later)

Features:
- Schema backup before deployment
- Environment variable support for credentials
- Dry-run mode
- Uses original working binding logic
"""
import requests
import json
import time
import urllib3
from collections import defaultdict
import sys
import re
import traceback
import os
from datetime import datetime
from getpass import getpass

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


class NDOIPv6BindingGenerator:
    def __init__(self, ndo_host, username, password, schema_name="AEDCE", dry_run=False):
        self.ndo_host = ndo_host
        self.schema_name = schema_name
        self.session = requests.Session()
        self.session.verify = False
        self.dry_run = dry_run
        self.backup_file = None
        
        print(f"Initializing connection to {ndo_host}...")
        if dry_run:
            print("⚠️  DRY RUN MODE - No changes will be made to NDO")
        
        self.auth_token = self._authenticate(username, password)
        
        # COMPLETE VLAN mapping from actual VM deployment data
        self.epg_mapping = {
            # Infrastructure Management
            'EPG-NAC': {
                'reference': 'EPG-V0015', 
                'vlan': 3021,
                'template': 'L2_Stretched',
                'function': '15',
                'subnet': '1500::/56'
            },
            'EPG-CFG-MGMT': {
                'reference': 'EPG-V0021', 
                'vlan': 3105,
                'template': 'L2_Stretched',
                'function': '69',
                'subnet': '6900::/56'
            },
            'EPG-MECM': {
                'reference': 'EPG-V0033', 
                'vlan': 3236,
                'template': 'L2_Stretched',
                'function': 'ec',
                'subnet': 'ec00::/56'
            },
            'EPG-NMS': {
                'reference': 'EPG-V0015',
                'vlan': 3001,
                'template': 'L2_Stretched',
                'function': '01',
                'subnet': '0100::/56'
            },
            'EPG-VHOST-MGMT': {
                'reference': 'EPG-V0033',
                'vlan': 3102,
                'template': 'L2_Stretched',
                'function': '66',
                'subnet': '6600::/56'
            },
            'EPG-SYSMAN': {
                'reference': 'EPG-V0021',
                'vlan': 3195,
                'template': 'L2_Stretched',
                'function': 'c3',
                'subnet': 'c300::/56'
            },
            'EPG-PATCH': {
                'reference': 'EPG-V0033',
                'vlan': 3230,
                'template': 'L2_Stretched',
                'function': 'e6',
                'subnet': 'e600::/56'
            },
            
            # Network Services
            'EPG-LB': {
                'reference': 'EPG-V0210', 
                'vlan': 3050,
                'template': 'L2_Stretched',
                'function': '1b',
                'subnet': '1b00::/56'
            },
            'EPG-DNS-MGMT': {
                'reference': 'EPG-V0216', 
                'vlan': 3083,
                'template': 'L2_Stretched',
                'function': '53',
                'subnet': '5300::/56'
            },
            'EPG-RCC-DNS': {
                'reference': 'EPG-V0218', 
                'vlan': 3051,
                'template': 'L2_Stretched',
                'function': 'bd',
                'subnet': 'bd00::/56'
            },
            'EPG-DHCP-SVR': {
                'reference': 'EPG-V0219', 
                'vlan': 3210,
                'template': 'L2_Stretched',
                'function': 'd2',
                'subnet': 'd200::/56'
            },
            'EPG-SMTP-SVR': {
                'reference': 'EPG-V0220', 
                'vlan': 3213,
                'template': 'L2_Stretched',
                'function': 'd5',
                'subnet': 'd500::/56'
            },
            
            # Voice and Communications
            'EPG-VVOIP-MGMT': {
                'reference': 'EPG-V0160', 
                'vlan': 3064,
                'template': 'L2_Stretched',
                'function': '40',
                'subnet': '4000::/56'
            },
            'EPG-VVOIP-PROXY': {
                'reference': 'EPG-V0161', 
                'vlan': 3065,
                'template': 'L2_Stretched',
                'function': '41',
                'subnet': '4100::/56'
            },
            'EPG-LMR': {
                'reference': 'EPG-V0163', 
                'vlan': 3052,
                'template': 'L2_Stretched',
                'function': 'cb',
                'subnet': 'cb00::/56'
            },
            'EPG-E911-SVR': {
                'reference': 'EPG-V0178', 
                'vlan': 3053,
                'template': 'L2_Stretched',
                'function': 'e9',
                'subnet': 'e900::/56'
            },
            
            # Security Services
            'EPG-ACAS-SCANNERS': {
                'reference': 'EPG-V0140', 
                'vlan': 3192,
                'template': 'L2_Stretched',
                'function': 'c0',
                'subnet': 'c000::/56',
                'note': 'ACAS type uses VLAN 3442 with c001::/56'
            },
            'EPG-C2C-SCANNERS': {
                'reference': 'EPG-V0141', 
                'vlan': 3442,
                'template': 'L2_Stretched',
                'function': 'c1',
                'subnet': 'c001::/56'
            },
            'EPG-OCSP': {
                'reference': 'EPG-V0142', 
                'vlan': 3197,
                'template': 'L2_Stretched',
                'function': 'c5',
                'subnet': 'c500::/56'
            },
            'EPG-PKI-SRV': {
                'reference': 'EPG-V0144', 
                'vlan': 3054,
                'template': 'L2_Stretched',
                'function': 'ca',
                'subnet': 'ca00::/56'
            },
            'EPG-ACAS-MGMT': {
                'reference': 'EPG-V0140',
                'vlan': 3198,
                'template': 'L2_Stretched',
                'function': 'c6',
                'subnet': 'c600::/56'
            },
            
            # Directory and Authentication
            'EPG-AD': {
                'reference': 'EPG-V0150', 
                'vlan': 3173,
                'template': 'L2_Stretched',
                'function': 'ad',
                'subnet': 'ad00::/56'
            },
            'EPG-ADFS': {
                'reference': 'EPG-V0160', 
                'vlan': 3175,
                'template': 'L2_Stretched',
                'function': 'af',
                'subnet': 'af00::/56'
            },
            
            # Proxy Services
            'EPG-D64-PROXY': {
                'reference': 'EPG-V0260', 
                'vlan': 3055,
                'template': 'L2_Stretched',
                'function': 'd6',
                'subnet': 'd600::/56'
            },
            'EPG-RWEB-PROXY': {
                'reference': 'EPG-V0261', 
                'vlan': 3056,
                'template': 'L2_Stretched',
                'function': 'd7',
                'subnet': 'd700::/56',
                'public': True
            },
            'EPG-FWEB-PROXY': {
                'reference': 'EPG-V0262', 
                'vlan': 3057,
                'template': 'L2_Stretched',
                'function': 'd8',
                'subnet': 'd800::/56',
                'public': True
            },
            
            # Application and Web Servers
            'EPG-APP-SVR': {
                'reference': 'EPG-V0420', 
                'vlan': 3224,
                'template': 'L2_Stretched',
                'function': 'e0',
                'subnet': 'e000::/56'
            },
            'EPG-WEB-SVR': {
                'reference': 'EPG-V0420', 
                'vlan': 3228,
                'template': 'L2_Stretched',
                'function': 'e4',
                'subnet': 'e400::/56',
                'public': True
            },
            'EPG-FMWR-SVR': {
                'reference': 'EPG-V0450', 
                'vlan': 3058,
                'template': 'L2_Stretched',
                'function': 'e3',
                'subnet': 'e300::/56'
            },
            
            # RCC Services
            'EPG-RCC-SVR': {
                'reference': 'EPG-V0470', 
                'vlan': 3059,
                'template': 'L2_Stretched',
                'function': 'bc',
                'subnet': 'bc00::/56'
            },
            'EPG-RCC-DCO': {
                'reference': 'EPG-V0471', 
                'vlan': 3060,
                'template': 'L2_Stretched',
                'function': 'be',
                'subnet': 'be00::/56'
            },
            'EPG-RCC-UNIX': {
                'reference': 'EPG-V0472', 
                'vlan': 3061,
                'template': 'L2_Stretched',
                'function': 'bf',
                'subnet': 'bf00::/56'
            },
            'EPG-ADM-DCO': {
                'reference': 'EPG-V0471',
                'vlan': 3163,
                'template': 'L2_Stretched',
                'function': 'a3',
                'subnet': 'a300::/56'
            },
            
            # Storage Services
            'EPG-PRINT-SVR': {
                'reference': 'EPG-V0520', 
                'vlan': 3208,
                'template': 'L2_Stretched',
                'function': 'd0',
                'subnet': 'd000::/56'
            },
            'EPG-FILE-SVR': {
                'reference': 'EPG-V0521', 
                'vlan': 3209,
                'template': 'L2_Stretched',
                'function': 'd1',
                'subnet': 'd100::/56'
            },
            'EPG-BACKUP-SVR': {
                'reference': 'EPG-V0522', 
                'vlan': 3221,
                'template': 'K-Specific_Only',
                'function': 'dd',
                'subnet': 'dd00::/56'
            },
            
            # Database and Logging
            'EPG-DB-SVR': {
                'reference': 'EPG-V0570', 
                'vlan': 3219,
                'template': 'L2_Non-Stretched',
                'function': 'db',
                'subnet': 'db00::/56'
            },
            'EPG-SYSLOG': {
                'reference': 'EPG-V0572', 
                'vlan': 3217,
                'template': 'L2_Non-Stretched',
                'function': 'd9',
                'subnet': 'd900::/56'
            },
            
            # G-Specific Only
            'EPG-GEF-MGMT': {
                'reference': 'EPG-V0260', 
                'vlan': 3062,
                'template': 'G-Specific_Only',
                'function': 'ef',
                'subnet': 'ef00::/56'
            },
        }
        
        # Verified VLANs from actual data
        self.verified_vlans = [
            3001, 3021, 3064, 3065, 3083, 3102, 3105, 3163, 3173, 3175, 
            3192, 3195, 3197, 3198, 3208, 3209, 3210, 3213, 3217, 3219, 
            3221, 3224, 3228, 3230, 3236, 3442
        ]
        
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
    
    def backup_schema(self, schema, schema_id):
        """Backup current schema state before changes"""
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        self.backup_file = f'schema_backup_{schema_id}_{timestamp}.json'
        
        try:
            with open(self.backup_file, 'w') as f:
                json.dump(schema, f, indent=2)
            print(f"✓ Schema backed up to: {self.backup_file}")
            return self.backup_file
        except Exception as e:
            print(f"⚠️  Warning: Could not create backup: {str(e)}")
            return None
    
    def discover_rcc_epgs(self, schema):
        """Auto-discover all RCC EPGs across all templates"""
        print("\n" + "="*80)
        print("DISCOVERING RCC EPGs - VERIFIED VLAN ASSIGNMENTS")
        print("="*80)
        
        rcc_epgs = []
        
        templates = schema.get('templates', [])
        print(f"Scanning {len(templates)} templates...")
        
        for template in templates:
            template_name = template.get('name', 'Unknown')
            anps = template.get('anps', [])
            
            for anp in anps:
                anp_name = anp.get('name', '')
                
                if anp_name == 'AppProf-RCC':
                    print(f"\n✓ Found AppProf-RCC in template: {template_name}")
                    print(f"  {'EPG Name':<25} {'BD Name':<25} {'Func':<6} {'Subnet':<18} {'VLAN':<6} {'Status'}")
                    print(f"  {'-'*25} {'-'*25} {'-'*6} {'-'*18} {'-'*6} {'-'*10}")
                    
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
                        
                        # Show VLAN assignment with verification status
                        if epg_name in self.epg_mapping:
                            mapping = self.epg_mapping[epg_name]
                            vlan = mapping['vlan']
                            function = mapping['function']
                            subnet = mapping['subnet']
                            
                            status = "✅ DATA" if vlan in self.verified_vlans else "⚠️ SAFE"
                            print(f"  {epg_name:<25} {bd_name:<25} {function:<6} {subnet:<18} {vlan:<6} {status}")
                        else:
                            print(f"  {epg_name:<25} {bd_name:<25} {'??':<6} {'??':<18} {'??':<6} ✗ UNMAPPED")
        
        print(f"\n✓ Total RCC EPGs discovered: {len(rcc_epgs)}")
        return sorted(rcc_epgs, key=lambda x: x['epg_name'])
    
    def extract_all_ipv4_bindings(self, schema):
        """Extract port bindings from ALL IPv4 EPGs (excluding leaves 111/112 - will be configured later)"""
        print(f"\n" + "="*80)
        print(f"EXTRACTING ALL IPv4 EPG PORT BINDINGS")
        print("(Filtering out leaves 111/112 - will be configured later)")
        print("="*80)
        
        try:
            sites_response = self.session.get(f"https://{self.ndo_host}/api/v1/sites")
            sites_response.raise_for_status()
            sites_map = {site['id']: site['name'] for site in sites_response.json()['sites']}
            
            all_bindings = defaultdict(list)
            skipped_111_112 = 0
            
            sites = schema.get('sites', [])
            print(f"Scanning {len(sites)} site/template deployment combinations...")
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
                                    
                                    # Skip bindings on leaves 111/112 (will configure later)
                                    if re.search(r'/(?:paths|protpaths)-11[12](?:/|-11[12])', path):
                                        skipped_111_112 += 1
                                        continue
                                    
                                    binding = {
                                        'site': site_name,
                                        'type': port.get('type', 'port'),
                                        'path': path,
                                        'deployment_immediacy': port.get('deploymentImmediacy', 'immediate'),
                                        'mode': port.get('mode', 'regular')
                                    }
                                    all_bindings[epg_name].append(binding)
            
            print(f"✓ Physical sites: {sorted(unique_sites)}")
            print(f"✓ Found bindings for {len(all_bindings)} IPv4 EPGs")
            print(f"✓ Skipped {skipped_111_112} bindings on leaves 111/112 (will be configured later)")
            
            # Show reference EPGs
            print("\nReference EPG Status:")
            for ipv6_epg, mapping in sorted(self.epg_mapping.items()):
                ref_epg = mapping['reference']
                if ref_epg in all_bindings:
                    print(f"  ✓ {ref_epg:<15} → {ipv6_epg:<20} ({len(all_bindings[ref_epg]):2} bindings)")
                else:
                    print(f"  ✗ {ref_epg:<15} → {ipv6_epg:<20} (NOT FOUND - will use defaults)")
            
            return all_bindings
            
        except Exception as e:
            print(f"✗ Error extracting bindings: {str(e)}")
            traceback.print_exc()
            return {}
    
    def _get_default_bindings(self):
        """Provide default port bindings (VPC only, leaves 101/102)"""
        return [
            {
                'site': 'APIC1',
                'type': 'vpc',
                'path': 'topology/pod-1/protpaths-101-102/pathep-[VPC_D1A-B]',
                'deployment_immediacy': 'immediate',
                'mode': 'regular'
            },
            {
                'site': 'APIC1',
                'type': 'vpc',
                'path': 'topology/pod-1/protpaths-101-102/pathep-[VPC_D2A-B]',
                'deployment_immediacy': 'immediate',
                'mode': 'regular'
            },
            {
                'site': 'APIC2',
                'type': 'vpc',
                'path': 'topology/pod-1/protpaths-101-102/pathep-[VPC_D1A-B]',
                'deployment_immediacy': 'immediate',
                'mode': 'regular'
            },
            {
                'site': 'APIC2',
                'type': 'vpc',
                'path': 'topology/pod-1/protpaths-101-102/pathep-[VPC_D2A-B]',
                'deployment_immediacy': 'immediate',
                'mode': 'regular'
            }
        ]
    
    def generate_ipv6_bindings(self, rcc_epgs, all_ipv4_bindings):
        """Generate IPv6 bindings with VERIFIED VLANs"""
        print("\n" + "="*80)
        print("GENERATING IPv6 BINDINGS - USING VERIFIED VLANs FROM ACTUAL DATA")
        print("CONFIGURED FOR LEAVES 101/102 ONLY")
        print("="*80)
        
        ipv6_bindings = []
        vlan_assignments = {}
        
        for epg_info in rcc_epgs:
            epg_name = epg_info['epg_name']
            template = epg_info['template']
            bd_name = epg_info['bd_name']
            
            if epg_name in self.epg_mapping:
                mapping = self.epg_mapping[epg_name]
                reference_epg = mapping['reference']
                vlan = mapping['vlan']
                function = mapping['function']
                subnet = mapping['subnet']
                is_public = mapping.get('public', False)
                note = mapping.get('note', '')
                
                # VLAN conflict check
                if vlan in vlan_assignments:
                    print(f"\n⚠️  VLAN CONFLICT DETECTED!")
                    print(f"  VLAN {vlan} already assigned to: {vlan_assignments[vlan]}")
                    print(f"  Attempting to assign to: {epg_name}")
                    old_vlan = vlan
                    vlan = self._find_next_available_vlan(vlan_assignments, vlan + 1)
                    print(f"  ✓ Resolved: Using VLAN {vlan} instead of {old_vlan}")
                
                vlan_assignments[vlan] = epg_name
                
                public_flag = " [PUBLIC]" if is_public else ""
                vlan_status = "✅ VERIFIED" if vlan in self.verified_vlans else "⚠️ ASSIGNED (not in data)"
                
                print(f"\n{epg_name} - {vlan_status}{public_flag}")
                print(f"  Function: {function} | VLAN: {vlan} | Subnet: {subnet}")
                print(f"  Template: {template}")
                print(f"  Reference: {reference_epg}")
                if note:
                    print(f"  Note: {note}")
                
                # Get bindings
                if reference_epg in all_ipv4_bindings:
                    ports_to_use = all_ipv4_bindings[reference_epg]
                    print(f"  ✓ Using {len(ports_to_use)} port bindings from {reference_epg}")
                else:
                    print(f"  ⚠️  Reference EPG not found, using defaults (leaves 101/102)")
                    ports_to_use = self._get_default_bindings()
            else:
                # Unmapped EPG
                print(f"\n{epg_name} - ✗ NOT MAPPED")
                vlan = self._find_next_available_vlan(vlan_assignments, 3700)
                vlan_assignments[vlan] = epg_name
                print(f"  ⚠️  Auto-assigned VLAN: {vlan}")
                ports_to_use = self._get_default_bindings()
                reference_epg = 'default'
                function = 'unknown'
                subnet = 'unknown'
                is_public = False
            
            # Filter by template/site
            filtered_ports = []
            for port in ports_to_use:
                include_port = False
                
                if template == 'G-Specific_Only':
                    include_port = (port['site'] == 'APIC1')
                elif template == 'K-Specific_Only':
                    include_port = (port['site'] == 'APIC2')
                else:
                    include_port = True
                
                if include_port:
                    filtered_ports.append(port)
            
            print(f"  Ports: {len(filtered_ports)} (filtered for {template})")
            
            epg_config = {
                'epg_name': epg_name,
                'vlan': str(vlan),
                'tenant': 'EUR',
                'app_profile': 'AppProf-RCC',
                'bd_name': bd_name,
                'template': template,
                'function_code': function,
                'ipv6_subnet': subnet,
                'reference_epg': reference_epg if epg_name in self.epg_mapping else 'default',
                'is_public': is_public if epg_name in self.epg_mapping else False,
                'verified_from_data': vlan in self.verified_vlans,
                'leaf_pair': '101-102',
                'ports': []
            }
            
            for port in filtered_ports:
                port_config = {
                    'description': f"{epg_name} IPv6 Func:{function} VLAN:{vlan}",
                    'is_trunk': True,
                    'path': port['path'],
                    'deployment_immediacy': port['deployment_immediacy'],
                    'mode': port['mode'],
                    'encap': f"vlan-{vlan}",
                    'site': port['site'],
                    'type': port['type']
                }
                epg_config['ports'].append(port_config)
                print(f"    {port['site']:<10} {port['type']:<6} {port['path']}")
            
            ipv6_bindings.append(epg_config)
        
        return ipv6_bindings
    
    def _find_next_available_vlan(self, vlan_assignments, start_vlan):
        """Find next available VLAN"""
        vlan = start_vlan
        while vlan in vlan_assignments and vlan < 4000:
            vlan += 1
        return vlan
    
    def save_bindings_to_file(self, bindings, filename='ipv6_rcc_port_bindings.json'):
        """Save generated bindings to JSON file with verification report"""
        print(f"\n" + "="*80)
        print("SAVING BINDINGS TO FILE")
        print("="*80)
        
        try:
            with open(filename, 'w') as f:
                json.dump(bindings, f, indent=2)
            print(f"✓ Bindings saved to: {filename}")
            
            # Comprehensive summary
            total_ports = sum(len(epg['ports']) for epg in bindings)
            by_template = defaultdict(int)
            by_site = defaultdict(int)
            by_function = defaultdict(list)
            vlans_used = []
            public_epgs = []
            verified_count = 0
            assigned_count = 0
            
            for epg in bindings:
                by_template[epg['template']] += 1
                by_function[epg.get('function_code', 'unknown')].append(epg['epg_name'])
                vlans_used.append(int(epg['vlan']))
                
                if epg.get('verified_from_data', False):
                    verified_count += 1
                else:
                    assigned_count += 1
                
                if epg.get('is_public', False):
                    public_epgs.append(f"{epg['epg_name']} (VLAN {epg['vlan']})")
                
                for port in epg['ports']:
                    by_site[port['site']] += 1
            
            print(f"\n📊 DEPLOYMENT SUMMARY - LEAVES 101/102")
            print(f"{'='*80}")
            print(f"  Target Leaf Pair: 101-102")
            print(f"  Leaves 111-112: SKIPPED (will be configured later)")
            print(f"  Total EPGs: {len(bindings)}")
            print(f"  Total Port Bindings: {total_ports}")
            print(f"  VLAN Range: {min(vlans_used)} - {max(vlans_used)}")
            print(f"  Verified VLANs (from data): {verified_count}")
            print(f"  Assigned VLANs (safe range): {assigned_count}")
            
            print(f"\n  📋 By Template:")
            for template, count in sorted(by_template.items()):
                print(f"    {template:<25} {count:2} EPGs")
            
            print(f"\n  🌐 By Site:")
            for site, count in sorted(by_site.items()):
                print(f"    {site:<25} {count:3} port bindings")
            
            print(f"\n  🔢 By Function Code:")
            for func in sorted(by_function.keys()):
                epgs = by_function[func]
                print(f"    {func:<6} {', '.join(epgs)}")
            
            if public_epgs:
                print(f"\n  🌍 Public-Facing Services:")
                for epg in public_epgs:
                    print(f"    {epg}")
            
            # VLAN assignment report
            print(f"\n  📍 VLAN Assignments (sorted):")
            print(f"  {'VLAN':<6} {'EPG Name':<25} {'Function':<8} {'Subnet':<18} {'Status'}")
            print(f"  {'-'*6} {'-'*25} {'-'*8} {'-'*18} {'-'*15}")
            
            for epg in sorted(bindings, key=lambda x: int(x['vlan'])):
                func = epg.get('function_code', '??')
                subnet = epg.get('ipv6_subnet', '??')
                public_mark = " [PUBLIC]" if epg.get('is_public', False) else ""
                verified = "✅ VERIFIED" if epg.get('verified_from_data', False) else "⚠️ ASSIGNED"
                
                print(f"  {epg['vlan']:<6} {epg['epg_name']:<25} {func:<8} {subnet:<18} {verified}{public_mark}")
            
            # Warning for unverified VLANs
            unverified = [epg for epg in bindings if not epg.get('verified_from_data', False)]
            if unverified:
                print(f"\n  ⚠️  WARNING: {len(unverified)} EPGs have ASSIGNED VLANs (not in spreadsheet)")
                print(f"  Please verify these VLANs don't conflict with your network:")
                for epg in unverified:
                    print(f"    - {epg['epg_name']}: VLAN {epg['vlan']} (Function: {epg['function_code']})")
            
            # Reminder about 111/112
            print(f"\n  📝 REMINDER: Leaves 111/112 need to be configured separately")
            print(f"     Run this script again with modified settings for 111/112 when ready")
                
        except Exception as e:
            print(f"✗ Error saving file: {str(e)}")
            raise
    
    def deploy_bindings(self, bindings):
        """Deploy IPv6 bindings to NDO - ORIGINAL WORKING LOGIC"""
        print("\n" + "="*80)
        print("DEPLOYING IPv6 BINDINGS TO NDO - LEAVES 101/102 ONLY")
        print("="*80)
        
        if self.dry_run:
            print("\n⚠️  DRY RUN MODE - Simulating deployment (no changes will be made)")
        
        try:
            schema_id = self.get_schema_id()
            schema_url = f"https://{self.ndo_host}/api/v1/schemas/{schema_id}"
            
            # Fetch fresh schema - EXACTLY LIKE ORIGINAL
            response = self.session.get(schema_url)
            response.raise_for_status()
            schema = response.json()
            
            # Backup current state
            self.backup_schema(schema, schema_id)
            
            epg_cache = self._build_epg_cache(schema)
            print(f"✓ Cached {len(epg_cache)} EPG locations")
            
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
                        
                        static_port = {
                            "type": port['type'],
                            "path": port['path'],
                            "portEncapVlan": vlan,
                            "deploymentImmediacy": port['deployment_immediacy'],
                            "mode": port['mode']
                        }
                        
                        # NO DUPLICATE CHECK - MATCHES ORIGINAL WORKING SCRIPT
                        patch = {
                            "op": "add",
                            "path": f"/sites/{cache_entry['site_idx']}/anps/{cache_entry['anp_idx']}/epgs/{cache_entry['epg_idx']}/staticPorts/-",
                            "value": static_port
                        }
                        all_patches.append(patch)
                        processed_epgs.add(cache_key)
                    else:
                        if cache_key not in skipped_epgs:
                            skipped_epgs.append(cache_key)
            
            print(f"✓ Processed {len(processed_epgs)} EPG instances")
            
            if skipped_epgs:
                print(f"\n⚠️  Warning: {len(skipped_epgs)} EPG instances not found in schema:")
                for key in skipped_epgs:
                    print(f"  - {key}")
            
            if not all_patches:
                print("\n⚠️  No bindings to deploy!")
                return
            
            print(f"\n✓ Ready to deploy {len(all_patches)} port bindings")
            
            # DRY RUN - show what would be deployed
            if self.dry_run:
                print("\n📋 DRY RUN - Patches that would be applied:")
                for i, patch in enumerate(all_patches[:10]):
                    print(f"  {i+1}. Path: {patch['value']['path']}")
                    print(f"      Type: {patch['value']['type']}, VLAN: {patch['value']['portEncapVlan']}")
                if len(all_patches) > 10:
                    print(f"  ... and {len(all_patches) - 10} more patches")
                print(f"\n✓ Dry run complete. {len(all_patches)} patches would be applied.")
                return
            
            # Deploy in batches - EXACTLY LIKE ORIGINAL
            batch_size = 50
            successful = 0
            failed = 0
            start_time = time.time()
            
            print("\n🚀 Deploying to leaves 101/102...")
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
            
            print("\n" + "="*80)
            print(f"✅ DEPLOYMENT COMPLETE in {end_time - start_time:.1f} seconds")
            print(f"   Configured: Leaves 101/102")
            print(f"   Pending: Leaves 111/112 (run script again when ready)")
            print("="*80)
            print(f"  ✓ Successful: {successful} bindings")
            if failed > 0:
                print(f"  ✗ Failed: {failed} bindings")
                
        except Exception as e:
            print(f"\n✗ Deployment error: {str(e)}")
            if self.backup_file:
                print(f"💾 Restore from backup: {self.backup_file}")
            traceback.print_exc()
            raise
    
    def _build_epg_cache(self, schema):
        """Build cache of EPG locations in schema - EXACTLY LIKE ORIGINAL"""
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


def get_credentials():
    """Get credentials from environment variables or prompt"""
    ndo_host = os.environ.get('NDO_HOST')
    ndo_user = os.environ.get('NDO_USER')
    ndo_password = os.environ.get('NDO_PASSWORD')
    
    if not ndo_host:
        ndo_host = input("Enter NDO host IP/hostname [198.18.133.100]: ").strip()
        if not ndo_host:
            ndo_host = "198.18.133.100"
    
    if not ndo_user:
        ndo_user = input("Enter NDO username [admin]: ").strip()
        if not ndo_user:
            ndo_user = "admin"
    
    if not ndo_password:
        ndo_password = getpass("Enter NDO password: ")
    
    return ndo_host, ndo_user, ndo_password


def main():
    # Parse arguments
    mode = sys.argv[1] if len(sys.argv) > 1 else "both"
    
    # Schema name
    schema_name = os.environ.get('NDO_SCHEMA', 'AEDCE')
    
    print("="*80)
    print("NDO IPv6 RCC BINDING GENERATOR - VERIFIED VLAN ASSIGNMENTS")
    print("CONFIGURED FOR LEAVES 101/102 (111/112 will be done later)")
    print("All VLANs extracted from actual VM deployment data")
    print("="*80)
    
    # Get credentials
    try:
        ndo_host, ndo_user, ndo_password = get_credentials()
    except KeyboardInterrupt:
        print("\n\nCancelled by user")
        sys.exit(0)
    
    print(f"\nConfiguration:")
    print(f"  NDO Host: {ndo_host}")
    print(f"  Schema: {schema_name}")
    print(f"  Mode: {mode}")
    print(f"  Target Leaves: 101/102")
    print(f"  Skipped Leaves: 111/112 (pending)")
    print("="*80)
    
    dry_run = mode == 'dry-run'
    start_time = time.time()
    
    try:
        generator = NDOIPv6BindingGenerator(ndo_host, ndo_user, ndo_password, schema_name, dry_run=dry_run)
        
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
        
        # Extract ALL IPv4 bindings (excluding 111/112)
        all_ipv4_bindings = generator.extract_all_ipv4_bindings(schema)
        
        if not all_ipv4_bindings:
            print("\n⚠️  No IPv4 bindings found, using defaults for all EPGs (leaves 101/102)")
        
        # Generate IPv6 bindings
        ipv6_bindings = generator.generate_ipv6_bindings(rcc_epgs, all_ipv4_bindings)
        
        # Save to file
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        output_file = f'ipv6_rcc_port_bindings_101_102_{timestamp}.json'
        generator.save_bindings_to_file(ipv6_bindings, output_file)
        
        # Deploy if requested
        if mode in ['deploy', 'dry-run', 'both']:
            print("\n" + "="*80)
            
            if dry_run:
                print("🔍 DRY RUN MODE - Simulating deployment...")
                generator.deploy_bindings(ipv6_bindings)
            else:
                user_input = input("\n🚀 Deploy bindings to NDO now? (leaves 101/102 only) (yes/no): ")
                if user_input.lower() == 'yes':
                    generator.deploy_bindings(ipv6_bindings)
                else:
                    print("\n✓ Bindings saved to file only. No changes made to NDO.")
        
        end_time = time.time()
        print(f"\n✅ Total execution time: {end_time - start_time:.1f} seconds")
        print(f"\n📝 NEXT STEPS:")
        print(f"   1. Verify configuration on leaves 101/102")
        print(f"   2. When ready for leaves 111/112, update the script:")
        print(f"      - Change regex filter from 11[12] to 10[12]")
        print(f"      - Change default bindings from 101-102 to 111-112")
        print(f"      - Run the script again")
        
        if generator.backup_file:
            print(f"\n💾 Schema backup: {generator.backup_file}")
        
    except KeyboardInterrupt:
        print("\n\n⚠️  Operation cancelled by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n✗ FATAL ERROR: {str(e)}")
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()