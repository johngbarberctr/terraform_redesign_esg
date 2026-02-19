#!/usr/bin/env python3
"""
Analyze BD nameAlias values to map IPv4 BDs to IPv6 functional categories.
This script extracts and categorizes the existing BD configurations.
"""

import json
import re
from collections import defaultdict

# The 39 IPv6 functional BD names from bds_epgs.tf
IPV6_FUNCTIONAL_BDS = [
    "BD-NMS",           # Network Management System
    "BD-NAC",           # Network Access Control
    "BD-LB",            # Load Balancer
    "BD-VVOIP-MGMT",    # Voice over IP Management
    "BD-VVOIP-PROXY",   # Voice over IP Proxy
    "BD-DNS-MGMT",      # DNS Management
    "BD-VHOST-MGMT",    # Virtual Host Management
    "BD-CFG-MGMT",      # Configuration Management
    "BD-ADM-DCO",       # Admin DCO
    "BD-AD",            # Active Directory
    "BD-ADFS",          # Active Directory Federation Services
    "BD-RCC-SVR",       # RCC Server
    "BD-RCC-DNS",       # RCC DNS
    "BD-RCC-DCO",       # RCC DCO
    "BD-RCC-UNIX",      # RCC Unix
    "BD-ACAS-SCANNERS", # ACAS Scanners
    "BD-C2C-SCANNERS",  # C2C Scanners
    "BD-SYSMAN",        # System Management
    "BD-OCSP",          # Online Certificate Status Protocol
    "BD-ACAS-MGMT",     # ACAS Management
    "BD-PKI-SRV",       # PKI Server
    "BD-LMR",           # LMR (Land Mobile Radio)
    "BD-PRINT-SVR",     # Print Server
    "BD-FILE-SVR",      # File Server
    "BD-DHCP-SVR",      # DHCP Server
    "BD-SMTP-SVR",      # SMTP Server
    "BD-D64-PROXY",     # D64 Proxy
    "BD-RWEB-PROXY",    # Reverse Web Proxy
    "BD-FWEB-PROXY",    # Forward Web Proxy
    "BD-SYSLOG",        # Syslog
    "BD-DB-SVR",        # Database Server
    "BD-BACKUP-SVR",    # Backup Server
    "BD-APP-SVR",       # Application Server
    "BD-FMWR-SVR",      # Firmware Server
    "BD-WEB-SVR",       # Web Server
    "BD-PATCH",         # Patch Management
    "BD-E911-SVR",      # E911 Server
    "BD-MECM",          # Microsoft Endpoint Configuration Manager
    "BD-GEF-MGMT",      # GEF Management
]

# Keyword patterns for mapping nameAlias to functional categories
# Each pattern: (regex_pattern, target_bd_name, confidence_level)
MAPPING_PATTERNS = [
    # Active Directory patterns
    (r'\bAD\b|ACTIVE_?DIR', 'BD-AD', 'high'),
    (r'\bADFS\b|AD_?FS|FEDERATION', 'BD-ADFS', 'high'),
    
    # DNS patterns
    (r'\bDNS\b', 'BD-DNS-MGMT', 'high'),
    
    # DHCP patterns
    (r'\bDHCP\b', 'BD-DHCP-SVR', 'high'),
    
    # Voice/VoIP patterns
    (r'\bVOIP\b|\bVOICE\b|\bUC\b|UNIFIED_?COMM', 'BD-VVOIP-MGMT', 'medium'),
    
    # Print patterns
    (r'\bPRINT\b', 'BD-PRINT-SVR', 'high'),
    
    # File server patterns
    (r'\bFILE\b|\bNAS\b|\bSTORAGE\b|FILE_?SVR', 'BD-FILE-SVR', 'medium'),
    
    # Database patterns
    (r'\bDB\b|\bDATABASE\b|\bSQL\b|\bORACLE\b|\bMYSQL\b', 'BD-DB-SVR', 'high'),
    
    # Web server patterns
    (r'\bWEB\b|\bHTTP\b|\bIIS\b', 'BD-WEB-SVR', 'medium'),
    
    # Application server patterns
    (r'\bAPP\b|\bAPPLICATION\b|_APP_', 'BD-APP-SVR', 'medium'),
    
    # Backup patterns
    (r'\bBACKUP\b|\bNETBACKUP\b|\bVEEAM\b|\bARCHIVE\b', 'BD-BACKUP-SVR', 'high'),
    
    # Syslog patterns
    (r'\bSYSLOG\b|\bLOG\b', 'BD-SYSLOG', 'medium'),
    
    # SMTP/Email patterns
    (r'\bSMTP\b|\bEMAIL\b|\bMAIL\b', 'BD-SMTP-SVR', 'high'),
    
    # Load Balancer patterns
    (r'\bLB\b|\bLOAD_?BAL|\bF5\b|\bNETSCALER\b', 'BD-LB', 'high'),
    
    # NAC patterns
    (r'\bNAC\b|\bISE\b|NETWORK_?ACCESS', 'BD-NAC', 'high'),
    
    # PKI/Certificate patterns
    (r'\bPKI\b|\bCERT\b|\bCA\b', 'BD-PKI-SRV', 'medium'),
    (r'\bOCSP\b', 'BD-OCSP', 'high'),
    
    # Scanner patterns
    (r'\bACAS\b|\bNESSUS\b|\bSCAN\b', 'BD-ACAS-SCANNERS', 'medium'),
    (r'\bC2C\b', 'BD-C2C-SCANNERS', 'high'),
    
    # Management patterns
    (r'\bMGMT\b|\bMANAGE\b|\bMON\b|_MGMT|MGMT_', 'BD-CFG-MGMT', 'low'),
    (r'\bSRVR_?MGMT\b|\bSERVER_?MGMT\b|\bVHOST\b', 'BD-VHOST-MGMT', 'medium'),
    (r'\bGEF\b', 'BD-GEF-MGMT', 'high'),
    (r'\bSYS_?MAN\b|\bSYSTEM_?MAN', 'BD-SYSMAN', 'high'),
    
    # MECM/SCCM patterns
    (r'\bMECM\b|\bSCCM\b|\bCONFIG_?MGR\b', 'BD-MECM', 'high'),
    
    # Patch patterns
    (r'\bPATCH\b|\bWSUS\b|\bUPDATE\b', 'BD-PATCH', 'medium'),
    
    # Firmware patterns
    (r'\bFIRMWARE\b|\bFMWR\b', 'BD-FMWR-SVR', 'high'),
    
    # E911 patterns
    (r'\bE911\b|\b911\b|\bEMERGENCY\b', 'BD-E911-SVR', 'high'),
    
    # LMR patterns
    (r'\bLMR\b|\bRADIO\b', 'BD-LMR', 'high'),
    
    # Proxy patterns
    (r'\bPROXY\b|\bSQUID\b', 'BD-FWEB-PROXY', 'low'),
    
    # NMS patterns
    (r'\bNMS\b|\bNETWORK_?MGMT\b|\bSNMP\b', 'BD-NMS', 'high'),
    
    # DCO patterns
    (r'\bDCO\b', 'BD-ADM-DCO', 'medium'),
    
    # RCC patterns
    (r'\bRCC\b', 'BD-RCC-SVR', 'medium'),
]


def parse_bd_json(json_file_path):
    """Parse the BD JSON file and extract relevant information."""
    with open(json_file_path, 'r') as f:
        data = json.load(f)
    
    bds = []
    for item in data.get('imdata', []):
        if 'fvBD' in item:
            attrs = item['fvBD']['attributes']
            bd_info = {
                'name': attrs.get('name', ''),
                'nameAlias': attrs.get('nameAlias', ''),
                'dn': attrs.get('dn', ''),
            }
            
            # Extract VRF from children
            for child in item['fvBD'].get('children', []):
                if 'fvRsCtx' in child:
                    bd_info['vrf'] = child['fvRsCtx']['attributes'].get('tnFvCtxName', '')
                elif 'fvSubnet' in child:
                    if 'subnets' not in bd_info:
                        bd_info['subnets'] = []
                    bd_info['subnets'].append(child['fvSubnet']['attributes'].get('ip', ''))
            
            bds.append(bd_info)
    
    return bds


def map_alias_to_category(name_alias, bd_name):
    """Map a nameAlias to a functional BD category."""
    if not name_alias:
        return None, 'none', []
    
    matches = []
    for pattern, target_bd, confidence in MAPPING_PATTERNS:
        if re.search(pattern, name_alias, re.IGNORECASE):
            matches.append((target_bd, confidence, pattern))
    
    # Return best match (highest confidence)
    if matches:
        # Sort by confidence: high > medium > low
        confidence_order = {'high': 0, 'medium': 1, 'low': 2}
        matches.sort(key=lambda x: confidence_order.get(x[1], 3))
        return matches[0][0], matches[0][1], matches
    
    return None, 'none', []


def analyze_mapping(bds):
    """Analyze BD data and create mapping report."""
    
    # Group by suggested mapping
    mapping_results = defaultdict(list)
    unmatched = []
    
    for bd in bds:
        name = bd.get('name', '')
        alias = bd.get('nameAlias', '')
        vrf = bd.get('vrf', '')
        subnets = bd.get('subnets', [])
        
        target_bd, confidence, all_matches = map_alias_to_category(alias, name)
        
        if target_bd:
            mapping_results[target_bd].append({
                'source_bd': name,
                'alias': alias,
                'vrf': vrf,
                'subnets': subnets,
                'confidence': confidence,
                'all_matches': all_matches
            })
        else:
            unmatched.append({
                'source_bd': name,
                'alias': alias,
                'vrf': vrf,
                'subnets': subnets
            })
    
    return mapping_results, unmatched


def print_report(mapping_results, unmatched, bds):
    """Print the mapping analysis report."""
    
    print("=" * 80)
    print("BD MAPPING ANALYSIS REPORT")
    print("=" * 80)
    print(f"\nTotal BDs analyzed: {len(bds)}")
    print(f"BDs with suggested mappings: {sum(len(v) for v in mapping_results.values())}")
    print(f"BDs without mappings (need manual review): {len(unmatched)}")
    
    # Print each category
    print("\n" + "=" * 80)
    print("PROPOSED MAPPINGS (by IPv6 Functional BD)")
    print("=" * 80)
    
    for ipv6_bd in sorted(IPV6_FUNCTIONAL_BDS):
        matches = mapping_results.get(ipv6_bd, [])
        if matches:
            print(f"\n### {ipv6_bd} ({len(matches)} BDs)")
            print("-" * 60)
            for m in sorted(matches, key=lambda x: x['confidence']):
                conf_marker = "✅" if m['confidence'] == 'high' else "⚠️" if m['confidence'] == 'medium' else "❓"
                subnets_str = ', '.join(m['subnets'][:3])
                if len(m['subnets']) > 3:
                    subnets_str += f" (+{len(m['subnets'])-3} more)"
                print(f"  {conf_marker} {m['source_bd']} | Alias: {m['alias']}")
                print(f"      VRF: {m['vrf']} | Subnets: {subnets_str}")
    
    # Print unmatched BDs
    if unmatched:
        print("\n" + "=" * 80)
        print("UNMATCHED BDs (Need Manual Review)")
        print("=" * 80)
        
        # Group unmatched by VRF
        by_vrf = defaultdict(list)
        for bd in unmatched:
            by_vrf[bd['vrf']].append(bd)
        
        for vrf in sorted(by_vrf.keys()):
            print(f"\n### VRF: {vrf}")
            print("-" * 60)
            for bd in sorted(by_vrf[vrf], key=lambda x: x['source_bd']):
                alias = bd['alias'] if bd['alias'] else "(no alias)"
                subnets_str = ', '.join(bd['subnets'][:2])
                if len(bd['subnets']) > 2:
                    subnets_str += f" (+{len(bd['subnets'])-2} more)"
                print(f"  • {bd['source_bd']} | Alias: {alias}")
                print(f"      Subnets: {subnets_str}")


def generate_csv_output(mapping_results, unmatched):
    """Generate CSV-friendly output for the mapping."""
    
    print("\n" + "=" * 80)
    print("CSV OUTPUT FOR MAPPING VERIFICATION")
    print("=" * 80)
    print("source_bd,nameAlias,vrf,suggested_ipv6_bd,confidence,subnets")
    
    # Mapped entries
    for ipv6_bd in sorted(mapping_results.keys()):
        for m in mapping_results[ipv6_bd]:
            subnets = ';'.join(m['subnets'])
            print(f"{m['source_bd']},{m['alias']},{m['vrf']},{ipv6_bd},{m['confidence']},{subnets}")
    
    # Unmatched entries
    for bd in unmatched:
        alias = bd['alias'] if bd['alias'] else ""
        subnets = ';'.join(bd['subnets'])
        print(f"{bd['source_bd']},{alias},{bd['vrf']},UNMATCHED,none,{subnets}")


if __name__ == '__main__':
    import sys
    
    if len(sys.argv) < 2:
        print("Usage: python analyze_bd_mapping.py <bd_json_file>")
        print("\nTo extract the BD data, save the JSON starting with '{\"totalCount\":\"215\"...' to a file.")
        sys.exit(1)
    
    json_file = sys.argv[1]
    
    print(f"Loading BD data from: {json_file}")
    bds = parse_bd_json(json_file)
    
    print(f"Parsed {len(bds)} BDs")
    
    mapping_results, unmatched = analyze_mapping(bds)
    print_report(mapping_results, unmatched, bds)
    
    print("\n")
    generate_csv_output(mapping_results, unmatched)
