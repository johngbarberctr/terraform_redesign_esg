#!/usr/bin/env python3
"""
Parse NDO backup file v2 - Comprehensive extraction of BD/EPG settings.
This searches for all BD/EPG configurations including IPv6 ones.
"""

import re
import json
from collections import defaultdict

def main():
    backup_path = "/Users/johbarbe/Documents/terraform_redesign_esg/NDO/backup_analysis/20260203070000/backup"
    
    print(f"Reading backup file: {backup_path}")
    
    with open(backup_path, 'rb') as f:
        raw_data = f.read()
    
    data = raw_data.decode('utf-8', errors='ignore')
    print(f"File size: {len(data):,} characters")
    
    # IPv6 BD names we're looking for
    ipv6_bd_names = [
        'BD-NMS', 'BD-NAC', 'BD-MECM', 'BD-VHOST-MGMT', 'BD-ADM-DCO', 'BD-SYSMAN',
        'BD-ACAS-MGMT', 'BD-PATCH', 'BD-LB', 'BD-DNS-MGMT', 'BD-DHCP', 'BD-NTP',
        'BD-RADIUS', 'BD-TACACS', 'BD-SMTP', 'BD-VDI', 'BD-THIN-CLIENT', 
        'BD-ACAS-SCANNERS', 'BD-CRYPTO', 'BD-CERT-OCSP', 'BD-PKI-SRV', 'BD-DB-FE',
        'BD-AD', 'BD-PRINT', 'BD-MGMT-APP', 'BD-VOICE', 'BD-FWEB-PROXY', 
        'BD-ENCLAVE-PROXY', 'BD-WEB-SVR', 'BD-APP-SVR', 'BD-CLD-CON', 'BD-JUMP',
        'BD-LOG-SVR', 'BD-FILE-SVR', 'BD-BACKUP-SVR', 'BD-DB-SVR',
        'BD-SYSLOG', 'BD-GEF-MGMT', 'BD-LMR', 'BD-ADFS'
    ]
    
    # Find all occurrences of IPv6 BD names with their context
    print("\n" + "="*80)
    print("SEARCHING FOR IPv6 BD CONFIGURATIONS IN NDO BACKUP")
    print("="*80)
    
    ipv6_bd_configs = {}
    
    for bd_name in ipv6_bd_names:
        # Search for this BD name in the backup
        pattern = f'"name"\\s*:\\s*"{bd_name}"'
        matches = list(re.finditer(pattern, data))
        
        if matches:
            print(f"\n{bd_name}: Found {len(matches)} occurrences")
            
            # Get the context around each match to find settings
            for i, match in enumerate(matches[:5]):  # First 5 occurrences
                start = max(0, match.start() - 200)
                end = min(len(data), match.end() + 2000)
                context = data[start:end]
                
                # Extract settings from context
                settings = {}
                
                # BD Settings
                setting_patterns = {
                    'unicastRoute': r'"unicastRoute"\s*:\s*(true|false)',
                    'arpFlood': r'"arpFlood"\s*:\s*(true|false)',
                    'l2UnknownUnicast': r'"l2UnknownUnicast"\s*:\s*"([^"]*)"',
                    'intersiteBumTrafficAllow': r'"intersiteBumTrafficAllow"\s*:\s*(true|false)',
                    'l2Stretch': r'"l2Stretch"\s*:\s*(true|false)',
                    'optimizeWanBandwidth': r'"optimizeWanBandwidth"\s*:\s*(true|false)',
                    'l3MCast': r'"l3MCast"\s*:\s*(true|false)',
                    'unkMcastAct': r'"unkMcastAct"\s*:\s*"([^"]*)"',
                    'v6unkMcastAct': r'"v6unkMcastAct"\s*:\s*"([^"]*)"',
                    'multiDstPktAct': r'"multiDstPktAct"\s*:\s*"([^"]*)"',
                    'ipLearning': r'"ipLearning"\s*:\s*(true|false)',
                    'limitIpLearnToSubnets': r'"limitIpLearnToSubnets"\s*:\s*(true|false)',
                    'vmac': r'"vmac"\s*:\s*"([^"]*)"',
                    'epMoveDetectMode': r'"epMoveDetectMode"\s*:\s*"([^"]*)"',
                }
                
                for key, regex in setting_patterns.items():
                    m = re.search(regex, context)
                    if m:
                        val = m.group(1)
                        if val in ['true', 'false']:
                            settings[key] = val == 'true'
                        else:
                            settings[key] = val
                
                # Extract subnets
                subnet_match = re.search(r'"subnets"\s*:\s*\[([^\]]*)\]', context)
                if subnet_match:
                    settings['_subnets'] = subnet_match.group(1)[:200] + "..."
                
                # Extract VRF reference
                vrf_match = re.search(r'"vrfRef"\s*:\s*"([^"]*)"', context)
                if vrf_match:
                    settings['_vrfRef'] = vrf_match.group(1)
                
                if settings and len(settings) > 1:
                    if bd_name not in ipv6_bd_configs or len(settings) > len(ipv6_bd_configs.get(bd_name, {})):
                        ipv6_bd_configs[bd_name] = settings
                        print(f"  Occurrence {i+1}: Found {len(settings)} settings")
    
    # Now search for IPv4 BD configurations (sample)
    print("\n" + "="*80)
    print("SEARCHING FOR IPv4 BD CONFIGURATIONS (Sample)")
    print("="*80)
    
    ipv4_bd_configs = {}
    ipv4_sample_bds = ['BD-V0140', 'BD-V0150', 'BD-V0172', 'BD-V0174', 'BD-V0191', 'BD-V0192', 
                       'BD-V0316', 'BD-V0471', 'BD-V0481', 'BD-V0522', 'BD-V0540', 'BD-V0950', 'BD-V0976']
    
    for bd_name in ipv4_sample_bds:
        pattern = f'"name"\\s*:\\s*"{bd_name}"'
        matches = list(re.finditer(pattern, data))
        
        if matches:
            print(f"\n{bd_name}: Found {len(matches)} occurrences")
            
            for i, match in enumerate(matches[:3]):
                start = max(0, match.start() - 200)
                end = min(len(data), match.end() + 2000)
                context = data[start:end]
                
                settings = {}
                
                setting_patterns = {
                    'unicastRoute': r'"unicastRoute"\s*:\s*(true|false)',
                    'arpFlood': r'"arpFlood"\s*:\s*(true|false)',
                    'l2UnknownUnicast': r'"l2UnknownUnicast"\s*:\s*"([^"]*)"',
                    'intersiteBumTrafficAllow': r'"intersiteBumTrafficAllow"\s*:\s*(true|false)',
                    'l2Stretch': r'"l2Stretch"\s*:\s*(true|false)',
                    'optimizeWanBandwidth': r'"optimizeWanBandwidth"\s*:\s*(true|false)',
                    'l3MCast': r'"l3MCast"\s*:\s*(true|false)',
                    'unkMcastAct': r'"unkMcastAct"\s*:\s*"([^"]*)"',
                    'v6unkMcastAct': r'"v6unkMcastAct"\s*:\s*"([^"]*)"',
                    'multiDstPktAct': r'"multiDstPktAct"\s*:\s*"([^"]*)"',
                    'ipLearning': r'"ipLearning"\s*:\s*(true|false)',
                    'limitIpLearnToSubnets': r'"limitIpLearnToSubnets"\s*:\s*(true|false)',
                    'vmac': r'"vmac"\s*:\s*"([^"]*)"',
                    'epMoveDetectMode': r'"epMoveDetectMode"\s*:\s*"([^"]*)"',
                }
                
                for key, regex in setting_patterns.items():
                    m = re.search(regex, context)
                    if m:
                        val = m.group(1)
                        if val in ['true', 'false']:
                            settings[key] = val == 'true'
                        else:
                            settings[key] = val
                
                vrf_match = re.search(r'"vrfRef"\s*:\s*"([^"]*)"', context)
                if vrf_match:
                    settings['_vrfRef'] = vrf_match.group(1)
                
                if settings and len(settings) > 1:
                    if bd_name not in ipv4_bd_configs or len(settings) > len(ipv4_bd_configs.get(bd_name, {})):
                        ipv4_bd_configs[bd_name] = settings
                        print(f"  Occurrence {i+1}: Found {len(settings)} settings")
    
    # Search for EPG configurations
    print("\n" + "="*80)
    print("SEARCHING FOR IPv6 EPG CONFIGURATIONS")
    print("="*80)
    
    ipv6_epg_names = [name.replace('BD-', 'EPG-') for name in ipv6_bd_names]
    ipv6_epg_configs = {}
    
    for epg_name in ipv6_epg_names:
        pattern = f'"name"\\s*:\\s*"{epg_name}"'
        matches = list(re.finditer(pattern, data))
        
        if matches:
            print(f"\n{epg_name}: Found {len(matches)} occurrences")
            
            for i, match in enumerate(matches[:3]):
                start = max(0, match.start() - 200)
                end = min(len(data), match.end() + 2000)
                context = data[start:end]
                
                settings = {}
                
                epg_setting_patterns = {
                    'proxyArp': r'"proxyArp"\s*:\s*(true|false)',
                    'preferredGroup': r'"preferredGroup"\s*:\s*(true|false)',
                    'intraEpg': r'"intraEpg"\s*:\s*"([^"]*)"',
                    'mcastSource': r'"mcastSource"\s*:\s*(true|false)',
                    'epgType': r'"epgType"\s*:\s*"([^"]*)"',
                    'uSegEpg': r'"uSegEpg"\s*:\s*(true|false)',
                    'floodInEncap': r'"floodInEncap"\s*:\s*(true|false)',
                }
                
                for key, regex in epg_setting_patterns.items():
                    m = re.search(regex, context)
                    if m:
                        val = m.group(1)
                        if val in ['true', 'false']:
                            settings[key] = val == 'true'
                        else:
                            settings[key] = val
                
                # Extract BD reference
                bd_match = re.search(r'"bdRef"\s*:\s*"([^"]*)"', context)
                if bd_match:
                    settings['_bdRef'] = bd_match.group(1)
                
                if settings:
                    if epg_name not in ipv6_epg_configs or len(settings) > len(ipv6_epg_configs.get(epg_name, {})):
                        ipv6_epg_configs[epg_name] = settings
                        print(f"  Occurrence {i+1}: Found {len(settings)} settings")
    
    # Generate comparison report
    print("\n" + "="*80)
    print("GENERATING DETAILED COMPARISON REPORT")
    print("="*80)
    
    report = []
    report.append("="*100)
    report.append("BD AND EPG SETTINGS COMPARISON - NDO BACKUP vs TERRAFORM CONFIGURATION")
    report.append("Backup: ScheduledBackup-20260203070000.tar.gz")
    report.append("="*100)
    
    # IPv6 BD Settings from backup
    report.append("\n" + "="*80)
    report.append("IPv6 BD CONFIGURATIONS (FROM NDO BACKUP)")
    report.append("="*80)
    
    bd_settings_summary = defaultdict(lambda: defaultdict(int))
    
    for bd_name in sorted(ipv6_bd_configs.keys()):
        settings = ipv6_bd_configs[bd_name]
        report.append(f"\n{bd_name}:")
        for k, v in sorted(settings.items()):
            if not k.startswith('_'):
                report.append(f"  {k}: {v}")
                bd_settings_summary[k][str(v)] += 1
        for k, v in sorted(settings.items()):
            if k.startswith('_'):
                report.append(f"  {k}: {v[:100]}..." if len(str(v)) > 100 else f"  {k}: {v}")
    
    # IPv4 BD Settings from backup (sample)
    report.append("\n" + "="*80)
    report.append("IPv4 BD CONFIGURATIONS (SAMPLE FROM NDO BACKUP)")
    report.append("="*80)
    
    ipv4_bd_settings_summary = defaultdict(lambda: defaultdict(int))
    
    for bd_name in sorted(ipv4_bd_configs.keys()):
        settings = ipv4_bd_configs[bd_name]
        report.append(f"\n{bd_name}:")
        for k, v in sorted(settings.items()):
            if not k.startswith('_'):
                report.append(f"  {k}: {v}")
                ipv4_bd_settings_summary[k][str(v)] += 1
        for k, v in sorted(settings.items()):
            if k.startswith('_'):
                report.append(f"  {k}: {v[:100]}..." if len(str(v)) > 100 else f"  {k}: {v}")
    
    # IPv6 EPG Settings
    report.append("\n" + "="*80)
    report.append("IPv6 EPG CONFIGURATIONS (FROM NDO BACKUP)")
    report.append("="*80)
    
    for epg_name in sorted(ipv6_epg_configs.keys()):
        settings = ipv6_epg_configs[epg_name]
        report.append(f"\n{epg_name}:")
        for k, v in sorted(settings.items()):
            if not k.startswith('_'):
                report.append(f"  {k}: {v}")
        for k, v in sorted(settings.items()):
            if k.startswith('_'):
                report.append(f"  {k}: {v[:100]}..." if len(str(v)) > 100 else f"  {k}: {v}")
    
    # Summary and Comparison
    report.append("\n" + "="*80)
    report.append("SETTINGS COMPARISON SUMMARY")
    report.append("="*80)
    
    report.append("\nIPv6 BD Common Settings:")
    for setting, values in sorted(bd_settings_summary.items()):
        if values:
            most_common = max(values.items(), key=lambda x: x[1])
            report.append(f"  {setting}: {most_common[0]} ({most_common[1]}/{len(ipv6_bd_configs)} BDs)")
    
    report.append("\nIPv4 BD Common Settings (Sample):")
    for setting, values in sorted(ipv4_bd_settings_summary.items()):
        if values:
            most_common = max(values.items(), key=lambda x: x[1])
            report.append(f"  {setting}: {most_common[0]} ({most_common[1]}/{len(ipv4_bd_configs)} BDs)")
    
    # Differences
    report.append("\n" + "="*80)
    report.append("POTENTIAL CONFIGURATION DIFFERENCES")
    report.append("="*80)
    
    all_settings = set(list(bd_settings_summary.keys()) + list(ipv4_bd_settings_summary.keys()))
    
    for setting in sorted(all_settings):
        ipv6_vals = bd_settings_summary.get(setting, {})
        ipv4_vals = ipv4_bd_settings_summary.get(setting, {})
        
        ipv6_common = max(ipv6_vals.items(), key=lambda x: x[1])[0] if ipv6_vals else "NOT SET"
        ipv4_common = max(ipv4_vals.items(), key=lambda x: x[1])[0] if ipv4_vals else "NOT SET"
        
        if ipv6_common != ipv4_common:
            report.append(f"\n  {setting}:")
            report.append(f"    IPv6: {ipv6_common}")
            report.append(f"    IPv4: {ipv4_common}")
            report.append(f"    STATUS: ⚠️ DIFFERENT")
        else:
            report.append(f"\n  {setting}: ✅ SAME ({ipv6_common})")
    
    # Write report
    output_file = "/Users/johbarbe/Documents/terraform_redesign_esg/NDO/bd_epg_full_comparison.txt"
    with open(output_file, 'w') as f:
        f.write('\n'.join(report))
    
    print(f"\nFull comparison report written to: {output_file}")
    
    # Save raw data as JSON
    json_output = "/Users/johbarbe/Documents/terraform_redesign_esg/NDO/bd_epg_configs_v2.json"
    with open(json_output, 'w') as f:
        json.dump({
            'ipv6_bd_configs': ipv6_bd_configs,
            'ipv4_bd_configs': ipv4_bd_configs,
            'ipv6_epg_configs': ipv6_epg_configs,
        }, f, indent=2, default=str)
    
    print(f"Raw configurations saved to: {json_output}")
    
    # Print summary
    print("\n" + "="*80)
    print("QUICK SUMMARY")
    print("="*80)
    print(f"IPv6 BDs found in backup: {len(ipv6_bd_configs)}")
    print(f"IPv4 BDs found in backup: {len(ipv4_bd_configs)}")
    print(f"IPv6 EPGs found in backup: {len(ipv6_epg_configs)}")

if __name__ == "__main__":
    main()
