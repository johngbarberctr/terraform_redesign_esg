#!/usr/bin/env python3
"""
Parse NDO backup file and extract BD/EPG configurations for comparison.
This script extracts JSON data embedded in the BSON backup file.
"""

import re
import json
import sys
from collections import defaultdict

def extract_json_objects(data, pattern):
    """Extract JSON objects containing a specific pattern."""
    results = []
    # Find all occurrences of the pattern
    idx = 0
    while True:
        idx = data.find(pattern, idx)
        if idx == -1:
            break
        
        # Find the start of the JSON object (search backward for '{')
        start = idx
        brace_count = 0
        while start > 0:
            if data[start] == '{':
                # Check if this is the start of our object
                test_str = data[start:idx+len(pattern)+100]
                if pattern in test_str:
                    break
            start -= 1
        
        # Find the end of the JSON object
        end = start
        brace_count = 0
        in_string = False
        escape_next = False
        
        while end < len(data):
            char = data[end]
            
            if escape_next:
                escape_next = False
                end += 1
                continue
            
            if char == '\\':
                escape_next = True
                end += 1
                continue
            
            if char == '"' and not escape_next:
                in_string = not in_string
            
            if not in_string:
                if char == '{':
                    brace_count += 1
                elif char == '}':
                    brace_count -= 1
                    if brace_count == 0:
                        end += 1
                        break
            
            end += 1
        
        if start < end:
            json_str = data[start:end]
            try:
                obj = json.loads(json_str)
                results.append(obj)
            except json.JSONDecodeError:
                pass
        
        idx = end
    
    return results

def parse_backup_for_schemas(backup_path):
    """Parse the backup file and extract schema data."""
    print(f"Reading backup file: {backup_path}")
    
    with open(backup_path, 'rb') as f:
        raw_data = f.read()
    
    # Convert to string, ignoring errors
    data = raw_data.decode('utf-8', errors='ignore')
    print(f"File size: {len(data):,} characters")
    
    # Find all BD definitions
    bd_pattern = r'"bds"\s*:\s*\['
    epg_pattern = r'"epgs"\s*:\s*\['
    
    # Extract schema sections by looking for displayName patterns
    schemas = {}
    
    # Find EUR-RCC-E schema
    rcc_pattern = '"displayName":"EUR-RCC-E"'
    if rcc_pattern in data:
        print("\nFound EUR-RCC-E schema")
    
    # Extract BD configurations from the backup
    bds = defaultdict(list)
    epgs = defaultdict(list)
    
    # Look for BD patterns with settings
    print("\nSearching for BD configurations...")
    
    # Pattern for IPv6 BDs (BD-NAC, BD-AD, etc.)
    ipv6_bd_names = [
        'BD-NMS', 'BD-NAC', 'BD-MECM', 'BD-VHOST-MGMT', 'BD-ADM-DCO', 'BD-SYSMAN',
        'BD-ACAS-MGMT', 'BD-PATCH', 'BD-LB', 'BD-DNS-MGMT', 'BD-DHCP', 'BD-NTP',
        'BD-RADIUS', 'BD-TACACS', 'BD-SMTP', 'BD-VDI', 'BD-THIN-CLIENT', 
        'BD-ACAS-SCANNERS', 'BD-CRYPTO', 'BD-CERT-OCSP', 'BD-PKI-SRV', 'BD-DB-FE',
        'BD-AD', 'BD-PRINT', 'BD-MGMT-APP', 'BD-VOICE', 'BD-FWEB-PROXY', 
        'BD-ENCLAVE-PROXY', 'BD-WEB-SVR', 'BD-APP-SVR', 'BD-CLD-CON', 'BD-JUMP',
        'BD-ADM-DCO', 'BD-LOG-SVR', 'BD-FILE-SVR', 'BD-BACKUP-SVR', 'BD-DB-SVR',
        'BD-SYSLOG', 'BD-GEF-MGMT', 'BD-LMR'
    ]
    
    # Pattern for IPv4 BDs (BD-Vxxxx)
    ipv4_bd_pattern = re.compile(r'"name"\s*:\s*"(BD-V\d+)"')
    
    # Find all unique BD names
    all_bd_matches = re.findall(r'"name"\s*:\s*"(BD-[^"]+)"', data)
    unique_bds = set(all_bd_matches)
    
    print(f"Found {len(unique_bds)} unique BD names")
    
    # Separate IPv4 and IPv6 BDs
    ipv4_bds = sorted([bd for bd in unique_bds if re.match(r'BD-V\d+', bd)])
    ipv6_bds = sorted([bd for bd in unique_bds if bd in ipv6_bd_names])
    
    print(f"  - IPv4 BDs (BD-Vxxxx pattern): {len(ipv4_bds)}")
    print(f"  - IPv6 BDs (functional names): {len(ipv6_bds)}")
    
    # Extract detailed BD configurations
    bd_configs = {}
    
    # Look for BD config blocks
    # The pattern is: "name":"BD-xxx",...,"unicastRoute":..., etc.
    bd_config_pattern = re.compile(
        r'\{[^}]*"name"\s*:\s*"(BD-[^"]+)"[^}]*?"(?:unicastRoute|arpFlood|l2UnknownUnicast|intersiteBumTrafficAllow|optimizeWanBandwidth|l3MCast|l2Stretch|unkMcastAct|v6unkMcastAct|multiDstPktAct|ipLearning)"[^}]*\}',
        re.DOTALL
    )
    
    # More flexible pattern to capture BD settings
    print("\nExtracting BD settings...")
    
    # Search for BD definitions with their settings
    bd_block_pattern = re.compile(
        r'"name"\s*:\s*"(BD-[^"]+)"[^{]*?'
        r'(?:"unicastRoute"\s*:\s*(true|false))?[^{]*?'
        r'(?:"arpFlood"\s*:\s*(true|false))?[^{]*?'
        r'(?:"l2UnknownUnicast"\s*:\s*"([^"]*)")?[^{]*?'
        r'(?:"intersiteBumTrafficAllow"\s*:\s*(true|false))?[^{]*?'
        r'(?:"l2Stretch"\s*:\s*(true|false))?',
        re.DOTALL
    )
    
    # Alternative: Search for complete BD objects
    # Look for JSON-like structures containing BD settings
    
    # Find sections containing "bds" arrays
    bds_array_starts = [m.start() for m in re.finditer(r'"bds"\s*:\s*\[', data)]
    print(f"Found {len(bds_array_starts)} 'bds' array sections")
    
    # Process each bds array
    for start_idx in bds_array_starts[:50]:  # Limit to first 50 to avoid duplicates
        # Find the array end
        bracket_count = 0
        in_array = False
        end_idx = start_idx
        
        for i in range(start_idx, min(start_idx + 500000, len(data))):
            if data[i] == '[':
                bracket_count += 1
                in_array = True
            elif data[i] == ']':
                bracket_count -= 1
                if bracket_count == 0 and in_array:
                    end_idx = i + 1
                    break
        
        if end_idx > start_idx:
            array_content = data[start_idx:end_idx]
            
            # Try to parse individual BD objects
            bd_obj_pattern = re.compile(r'\{[^{}]*"name"\s*:\s*"(BD-[^"]+)"[^{}]*\}')
            
            for match in bd_obj_pattern.finditer(array_content):
                bd_str = match.group(0)
                bd_name = match.group(1)
                
                # Extract settings from this BD object
                settings = {
                    'name': bd_name,
                    'unicastRoute': None,
                    'arpFlood': None,
                    'l2UnknownUnicast': None,
                    'intersiteBumTrafficAllow': None,
                    'l2Stretch': None,
                    'optimizeWanBandwidth': None,
                    'l3MCast': None,
                    'unkMcastAct': None,
                    'v6unkMcastAct': None,
                    'multiDstPktAct': None,
                    'ipLearning': None
                }
                
                # Extract each setting
                for key in settings.keys():
                    if key == 'name':
                        continue
                    pattern = f'"{key}"\\s*:\\s*(true|false|"[^"]*")'
                    m = re.search(pattern, bd_str)
                    if m:
                        val = m.group(1)
                        if val in ['true', 'false']:
                            settings[key] = val == 'true'
                        else:
                            settings[key] = val.strip('"')
                
                # Only store if we got meaningful settings
                if any(v is not None for k, v in settings.items() if k != 'name'):
                    if bd_name not in bd_configs:
                        bd_configs[bd_name] = settings
    
    print(f"Extracted settings for {len(bd_configs)} BDs")
    
    # Now do the same for EPGs
    print("\nSearching for EPG configurations...")
    
    epg_configs = {}
    
    # Find sections containing "epgs" arrays
    epgs_array_starts = [m.start() for m in re.finditer(r'"epgs"\s*:\s*\[', data)]
    print(f"Found {len(epgs_array_starts)} 'epgs' array sections")
    
    for start_idx in epgs_array_starts[:50]:
        bracket_count = 0
        in_array = False
        end_idx = start_idx
        
        for i in range(start_idx, min(start_idx + 500000, len(data))):
            if data[i] == '[':
                bracket_count += 1
                in_array = True
            elif data[i] == ']':
                bracket_count -= 1
                if bracket_count == 0 and in_array:
                    end_idx = i + 1
                    break
        
        if end_idx > start_idx:
            array_content = data[start_idx:end_idx]
            
            epg_obj_pattern = re.compile(r'\{[^{}]*"name"\s*:\s*"(EPG-[^"]+)"[^{}]*\}')
            
            for match in epg_obj_pattern.finditer(array_content):
                epg_str = match.group(0)
                epg_name = match.group(1)
                
                settings = {
                    'name': epg_name,
                    'proxyArp': None,
                    'preferredGroup': None,
                    'intraEpg': None,
                    'mcastSource': None,
                    'epgType': None,
                    'uSegEpg': None
                }
                
                for key in settings.keys():
                    if key == 'name':
                        continue
                    pattern = f'"{key}"\\s*:\\s*(true|false|"[^"]*")'
                    m = re.search(pattern, epg_str)
                    if m:
                        val = m.group(1)
                        if val in ['true', 'false']:
                            settings[key] = val == 'true'
                        else:
                            settings[key] = val.strip('"')
                
                if any(v is not None for k, v in settings.items() if k != 'name'):
                    if epg_name not in epg_configs:
                        epg_configs[epg_name] = settings
    
    print(f"Extracted settings for {len(epg_configs)} EPGs")
    
    return bd_configs, epg_configs, ipv4_bds, ipv6_bds

def compare_bd_settings(bd_configs, ipv4_bds, ipv6_bds):
    """Compare BD settings between IPv4 and IPv6."""
    print("\n" + "="*80)
    print("BD SETTINGS COMPARISON")
    print("="*80)
    
    # Get sample IPv4 BD settings
    ipv4_settings = {}
    for bd_name in ipv4_bds:
        if bd_name in bd_configs:
            ipv4_settings[bd_name] = bd_configs[bd_name]
    
    # Get IPv6 BD settings
    ipv6_settings = {}
    for bd_name in ipv6_bds:
        if bd_name in bd_configs:
            ipv6_settings[bd_name] = bd_configs[bd_name]
    
    print(f"\nIPv4 BDs with settings: {len(ipv4_settings)}")
    print(f"IPv6 BDs with settings: {len(ipv6_settings)}")
    
    # Analyze IPv4 BD settings to find common patterns
    if ipv4_settings:
        print("\n--- Sample IPv4 BD Settings ---")
        sample_count = 0
        for name, settings in sorted(ipv4_settings.items()):
            if sample_count < 10:
                print(f"\n{name}:")
                for k, v in settings.items():
                    if k != 'name' and v is not None:
                        print(f"  {k}: {v}")
                sample_count += 1
    
    if ipv6_settings:
        print("\n--- IPv6 BD Settings ---")
        for name, settings in sorted(ipv6_settings.items()):
            print(f"\n{name}:")
            for k, v in settings.items():
                if k != 'name' and v is not None:
                    print(f"  {k}: {v}")
    
    # Compare settings
    print("\n" + "="*80)
    print("SETTINGS DIFFERENCE ANALYSIS")
    print("="*80)
    
    # Get common settings from IPv4 BDs
    if ipv4_settings:
        setting_counts = defaultdict(lambda: defaultdict(int))
        for settings in ipv4_settings.values():
            for k, v in settings.items():
                if k != 'name' and v is not None:
                    setting_counts[k][str(v)] += 1
        
        print("\nCommon IPv4 BD settings (most frequent values):")
        for setting, values in sorted(setting_counts.items()):
            most_common = max(values.items(), key=lambda x: x[1])
            print(f"  {setting}: {most_common[0]} ({most_common[1]}/{len(ipv4_settings)} BDs)")
    
    return ipv4_settings, ipv6_settings

def main():
    backup_path = "/Users/johbarbe/Documents/terraform_redesign_esg/NDO/backup_analysis/20260203070000/backup"
    
    bd_configs, epg_configs, ipv4_bds, ipv6_bds = parse_backup_for_schemas(backup_path)
    
    # Compare BD settings
    ipv4_bd_settings, ipv6_bd_settings = compare_bd_settings(bd_configs, ipv4_bds, ipv6_bds)
    
    # Output detailed results
    output_file = "/Users/johbarbe/Documents/terraform_redesign_esg/NDO/bd_epg_comparison.txt"
    with open(output_file, 'w') as f:
        f.write("="*80 + "\n")
        f.write("BD AND EPG SETTINGS COMPARISON - NDO BACKUP ANALYSIS\n")
        f.write("="*80 + "\n\n")
        
        f.write("IPv4 BDs Found:\n")
        for bd in sorted(ipv4_bds)[:50]:
            f.write(f"  {bd}\n")
        if len(ipv4_bds) > 50:
            f.write(f"  ... and {len(ipv4_bds) - 50} more\n")
        
        f.write(f"\nIPv6 BDs Found ({len(ipv6_bds)}):\n")
        for bd in sorted(ipv6_bds):
            f.write(f"  {bd}\n")
        
        f.write("\n" + "="*80 + "\n")
        f.write("IPv4 BD CONFIGURATIONS (Sample)\n")
        f.write("="*80 + "\n")
        
        for name, settings in sorted(ipv4_bd_settings.items())[:20]:
            f.write(f"\n{name}:\n")
            for k, v in settings.items():
                if k != 'name' and v is not None:
                    f.write(f"  {k}: {v}\n")
        
        f.write("\n" + "="*80 + "\n")
        f.write("IPv6 BD CONFIGURATIONS\n")
        f.write("="*80 + "\n")
        
        for name, settings in sorted(ipv6_bd_settings.items()):
            f.write(f"\n{name}:\n")
            for k, v in settings.items():
                if k != 'name' and v is not None:
                    f.write(f"  {k}: {v}\n")
        
        f.write("\n" + "="*80 + "\n")
        f.write("EPG CONFIGURATIONS\n")
        f.write("="*80 + "\n")
        
        for name, settings in sorted(epg_configs.items()):
            f.write(f"\n{name}:\n")
            for k, v in settings.items():
                if k != 'name' and v is not None:
                    f.write(f"  {k}: {v}\n")
    
    print(f"\nDetailed comparison written to: {output_file}")
    
    # Also save raw configs as JSON
    json_output = "/Users/johbarbe/Documents/terraform_redesign_esg/NDO/bd_epg_configs.json"
    with open(json_output, 'w') as f:
        json.dump({
            'bd_configs': bd_configs,
            'epg_configs': epg_configs,
            'ipv4_bds': ipv4_bds,
            'ipv6_bds': ipv6_bds
        }, f, indent=2)
    print(f"Raw configurations saved to: {json_output}")

if __name__ == "__main__":
    main()
