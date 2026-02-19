# BD and EPG Settings Comparison Report

## Source Data
- **NDO Backup**: `ScheduledBackup-20260203070000.tar.gz`
- **Terraform Config**: `bds_epgs.tf`
- **Analysis Date**: February 3, 2026

---

## Executive Summary

### Complete BD Settings Comparison

| Setting | IPv4 BDs (NDO Backup) | IPv6 BDs (Terraform) | Status |
|---------|----------------------|---------------------|--------|
| **l2_unknown_unicast** | `flood` | `proxy` | ⚠️ **DIFFERENT** |
| **unicast_routing** | `true` (99.99%) | `true` | ✅ Match |
| **host_route** | `true` (67%) / `false` (33%) | `true` | ✅ Match (majority) |
| arp_flood | `true` | Not set (defaults) | ⚠️ Check default |
| intersite_bum_traffic | `true` | `true` | ✅ Match |
| l2_stretch | `true` | `true` | ✅ Match |
| optimize_wan_bandwidth | `true` | `true` | ✅ Match |
| l3_multicast | `false` | `false` (VRF level) | ✅ Match |
| unk_mcast_act | `flood` | Not set (defaults) | ⚠️ Check default |
| v6_unk_mcast_act | `flood` | Not set (defaults) | ⚠️ Check default |
| multi_dst_pkt_act | `bd-flood` | Not set (defaults) | ⚠️ Check default |
| ep_move_detect_mode | `none` (82%) / `garp` (10%) | Not set | ⚠️ Check default |
| ip_dataplane_learning | `enabled` | Not set (defaults) | ⚠️ Check default |

### Key Statistics from NDO Backup

| Setting | Value | Count | Percentage |
|---------|-------|-------|------------|
| unicastRouting | `true` | 31,684 | 99.99% |
| unicastRouting | `false` | 1 | 0.01% |
| hostBasedRouting | `true` | 25,493 | 67% |
| hostBasedRouting | `false` | 12,138 | 33% |
| epMoveDetectMode | `none` | 28,187 | 82% |
| epMoveDetectMode | `garp` | 3,590 | 10% |
| ipDataPlaneLearning | `enabled` | 1,153 | 100% |

---

## Unicast Routing and Host Route Analysis

### Unicast Routing
- **IPv4 BDs**: `unicastRouting: true` on 31,684 instances (virtually all BDs)
- **IPv6 BDs (Terraform)**: `unicast_routing = true` on all BDs
- **Status**: ✅ **MATCH** - Both use unicast routing enabled

### Host-Based Routing (Host Route Advertisement)
- **IPv4 BDs**: Mixed - 67% have `hostBasedRouting: true`, 33% have `false`
- **IPv6 BDs (Terraform)**: `host_route = true` on all site BD deployments
- **Status**: ✅ **CONSISTENT** - IPv6 follows the majority pattern

**Audit Trail from NDO Backup** shows these IPv6 BDs were configured with host-based routing:
- BD-AD, BD-VVOIP-PROXY, BD-VVOIP-MGMT (L2_Stretched)
- BD-APP-SVR, BD-E911-SVR, BD-DHCP-SVR, BD-WEB-SVR (L2_Stretched)
- BD-DB-SVR, BD-SYSLOG (L2_Non-Stretched)
- BD-GEF-MGMT (G-Specific_Only)
- BD-V0950 (IPv4 BD also updated)

### IP Dataplane Learning
- **IPv4 BDs**: `ipDataPlaneLearning: enabled` (1,153 instances)
- **IPv6 BDs (Terraform)**: Not explicitly set (uses default)
- **Status**: ⚠️ Provider defaults to enabled, should be verified

### Endpoint Move Detection Mode
- **IPv4 BDs**: 
  - `none`: 28,187 (82%)
  - `garp`: 3,590 (10%)
  - Empty/not set: 2,570 (8%)
- **IPv6 BDs (Terraform)**: Not explicitly set
- **Status**: ⚠️ Consider adding `ep_move_detect_mode = "none"` for consistency

---

## Detailed IPv4 BD Settings (From NDO Backup)

### Sample IPv4 BDs (Reference EPGs for bindings)

```
BD-V0140 (APCG_DB_SQL):
  arpFlood: True
  intersiteBumTrafficAllow: True
  l2Stretch: True
  l2UnknownUnicast: flood
  l3MCast: False
  multiDstPktAct: bd-flood
  optimizeWanBandwidth: True
  unkMcastAct: flood
  v6unkMcastAct: flood

BD-V0172 (APCG_AD):
  arpFlood: True
  intersiteBumTrafficAllow: True
  l2Stretch: True
  l2UnknownUnicast: flood
  l3MCast: False
  multiDstPktAct: bd-flood
  optimizeWanBandwidth: True
  unkMcastAct: flood
  v6unkMcastAct: flood

BD-V0174 (APCG_ACAS):
  arpFlood: True
  intersiteBumTrafficAllow: True
  l2Stretch: True
  l2UnknownUnicast: flood
  l3MCast: False
  multiDstPktAct: bd-flood
  optimizeWanBandwidth: True
  unkMcastAct: flood
  v6unkMcastAct: flood
```

### IPv4 BD Settings Summary (All 93 Analyzed)
- **arpFlood**: `True` (93/93 BDs - 100%)
- **l2UnknownUnicast**: `flood` (92/93 BDs - 99%)
- **intersiteBumTrafficAllow**: `True` (74/93 BDs - 80%) - Some non-stretched BDs have `False`
- **l2Stretch**: `True` (74/93 BDs - 80%)
- **optimizeWanBandwidth**: `True` (74/93 BDs - 80%)
- **l3MCast**: `False` (93/93 BDs - 100%)
- **multiDstPktAct**: `bd-flood` (93/93 BDs - 100%)
- **unkMcastAct**: `flood` (93/93 BDs - 100%)
- **v6unkMcastAct**: `flood` (93/93 BDs - 100%)

---

## Current IPv6 BD Settings (From Terraform)

```hcl
resource "mso_schema_template_bd" "bd_nac" {
  schema_id               = data.mso_schema.existing.id
  template_name           = "L2_Stretched"
  name                    = "BD-NAC"
  display_name            = "BD-NAC"
  vrf_name                = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id           = data.mso_schema.existing.id
  vrf_template_name       = "VRF_Template"
  layer2_unknown_unicast  = "proxy"      # ⚠️ IPv4 uses "flood"
  layer2_stretch          = true
  unicast_routing         = true
  intersite_bum_traffic   = true
  optimize_wan_bandwidth  = true
  # Missing settings that IPv4 BDs have:
  # - arp_flood (defaults to true in provider?)
  # - unknown_multicast_flooding
  # - ipv6_unknown_multicast_flooding  
  # - multi_destination_flooding
}
```

---

## Deployed IPv6 BD (BD-VHOST-MGMT from NDO Backup)

The only IPv6 BD currently deployed shows these settings:

```
BD-VHOST-MGMT:
  arpFlood: True
  epMoveDetectMode: none
  intersiteBumTrafficAllow: True
  l2Stretch: True
  l2UnknownUnicast: proxy          # ⚠️ Different from IPv4!
  l3MCast: False
  multiDstPktAct: bd-flood
  optimizeWanBandwidth: True
  unkMcastAct: flood
  v6unkMcastAct: flood
```

---

## Recommendations

### 1. L2 Unknown Unicast Setting (Critical)

**Current State**: IPv6 BDs use `proxy`, IPv4 BDs use `flood`

**Impact**:
- `proxy`: Unknown unicast traffic is sent to the spine proxy for lookup. More efficient for stretched BDs across sites. ACI performs hardware proxy lookups.
- `flood`: Unknown unicast traffic is flooded to all ports in the BD. Traditional Layer 2 behavior.

**Recommendation**: 
The `proxy` setting is actually **preferred for stretched L2 BDs** in multi-site ACI deployments because:
1. Reduces bandwidth between sites (no flooding)
2. Spine proxy handles unknown unicast lookups efficiently
3. Works well with ACI's Anycast VTEP architecture

**Decision**: The current `proxy` setting for IPv6 BDs is **acceptable and potentially better** for a new deployment. The IPv4 BDs may be using `flood` due to legacy configuration.

### 2. Missing Explicit Settings

Add these to ensure consistency:

```hcl
resource "mso_schema_template_bd" "bd_example" {
  # ... existing settings ...
  
  # Add these for explicit configuration matching IPv4:
  arp_flood                      = true    # Match IPv4
  unknown_multicast_flooding     = "flood" # Match IPv4
  ipv6_unknown_multicast_flooding = "flood" # Match IPv4
  multi_destination_flooding     = "bd-flood" # Match IPv4
}
```

### 3. EPG Settings Comparison

From the backup, the deployed EPG-VHOST-MGMT shows:
```
EPG-VHOST-MGMT:
  epgType: application
  intraEpg: unenforced
  preferredGroup: False
  proxyArp: False
  uSegEpg: False
```

Current Terraform EPG configuration:
```hcl
resource "mso_schema_template_anp_epg" "epg_nac" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-NAC"
  display_name  = "EPG-NAC"
  bd_name       = mso_schema_template_bd.bd_nac.name
  # Missing settings:
  # - intra_epg = "unenforced"
  # - preferred_group = false
  # - proxy_arp = false
}
```

---

## Summary of Changes Needed

### Option A: Match IPv4 Exactly (Conservative)

Change `layer2_unknown_unicast` from `proxy` to `flood`:

```hcl
layer2_unknown_unicast  = "flood"  # Changed to match IPv4
```

### Option B: Keep Proxy (Recommended for New IPv6 Deployment)

Keep `layer2_unknown_unicast = "proxy"` as it's the preferred setting for:
- Multi-site stretched BDs
- Better WAN bandwidth efficiency
- Modern ACI best practices

Add explicit settings for clarity:

```hcl
layer2_unknown_unicast         = "proxy"  # Keep - better for stretched BDs
arp_flood                      = true
unknown_multicast_flooding     = "flood"
ipv6_unknown_multicast_flooding = "flood"
multi_destination_flooding     = "bd-flood"
```

---

## Verification Checklist

- [ ] Confirm `l2_unknown_unicast` behavior is acceptable for your use case
- [ ] Add explicit ARP flood setting if needed
- [ ] Add explicit multicast flooding settings if needed
- [ ] Test traffic flow between sites after deployment
- [ ] Verify unknown unicast handling meets requirements

---

## Files Analyzed

1. `/Users/johbarbe/Documents/terraform_redesign_esg/NDO/ScheduledBackup-20260203070000.tar.gz` - NDO backup
2. `/Users/johbarbe/Documents/terraform_redesign_esg/NDO/bds_epgs.tf` - Terraform configuration
3. `/Users/johbarbe/Documents/terraform_redesign_esg/NDO/bd_epg_configs_v2.json` - Extracted configurations
