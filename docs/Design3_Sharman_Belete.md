RECOMMENDED ACI DESIGN - FINAL ARCHITECTURE
1. Tenant Strategy Decision
Recommendation: MAINTAIN SINGLE TENANT with Multiple VRFs
Rationale:
- You currently have 199 BDs across 7 VRFs in the EUR tenant
- Belete correctly points out that multiple tenants add complexity without technical benefit
- NDO requires separate templates per tenant (7 VRFs = potentially 7+ templates)
- Your team manages the entire infrastructure (no separate business unit admins)
- Simpler automation and day-2 operations
Exception: Only consider Shared Services tenant if you need strict separation for external routing
2. Bridge Domain Consolidation Strategy
Recommendation: Hybrid Approach Based on VRF Size
For EUR-E and EUR-AIS (168 BDs combined):
Option A: Service-Based Consolidation
├── BD-EUR-E-Web (consolidate all web tier BDs)
├── BD-EUR-E-App (consolidate all app tier BDs)
├── BD-EUR-E-DB (consolidate all database BDs)
└── BD-EUR-E-Infra (infrastructure services)

Option B: Application-Based Consolidation
├── BD-EUR-E-HR (all HR-related subnets)
├── BD-EUR-E-Finance (all finance subnets)
├── BD-EUR-E-Engineering (all engineering subnets)
└── [Continue per major application group]
For smaller VRFs (EUR-AIM, EUR-AIV, EUR-AIZ, EUR-AIP):
- Keep existing structure initially
- Consolidate only if applications span multiple BDs
3. Migration Path - Phased Approach
Phase 1: Foundation (Do Now)
yaml
1. Enable microsegmentation on all EPGs:
- Configure intra-EPG isolation
- Set up private VLANs (primary/isolated)
- Keep vzAny contracts in place

2. Create "All-EPGs" ESG per VRF:
- EUR-AIS-ALL-ESG (maps all 82 EPGs)
- EUR-E-ALL-ESG (maps all 86 EPGs)
- [Continue for each VRF]
Phase 2: Wait for ESG Multi-Site Support (June/July 2025)
yaml
3. Begin application discovery:
- Map which BDs/EPGs belong to which applications
- Document inter-application dependencies

4. Create application-specific ESGs:
- Use IP-based selectors initially
- Migrate from "ALL-ESG" to app-specific ESGs
- Keep vzAny as safety net
Phase 3: Security Tightening (Post-ESG)
yaml
5. Replace vzAny with explicit contracts
6. Implement service graphs for inspection
7. Consider PBR only if needed
4. Technical Implementation Details
ESG Configuration Approach:
python
# Steve's Easier Method - Recommended
1. Keep existing BD/EPG structure (no disruption)
2. Enable microseg on EPGs:
- Intra-EPG isolation = enforced
- Use private VLANs for VMware
3. Create ESGs with IP selectors:
- Start with one ESG containing all EPGs
- Progressively create app-specific ESGs
- Use MAC tags for higher priority (switch traffic)
Contract Strategy:
Phase 1: vzAny → permit all
Phase 2: vzAny → ESG contracts (open)
Phase 3: ESG → ESG contracts (specific ports)
Phase 4: Add firewall service graphs for unknowns
5. Multi-Site Considerations
Current Constraints:
- ESGs not supported in NDO until v4.1/6.1 (June 2025)
- Route leaking complex with multi-site EPGs
- Most VRFs are stretched between sites
Recommendations:
- DON'T attempt route leaking with current multi-site setup
- KEEP firewall-based inter-VRF routing for now
- WAIT for ESG support before major changes
- Consider VMM integration to simplify operations
6. Simplified Architecture Diagram
Current State:                Target State (Post-ESG):
┌─────────────┐              ┌─────────────┐
│  EUR Tenant │              │  EUR Tenant │
├─────────────┤              ├─────────────┤
│ 7 VRFs      │              │ 7 VRFs      │
│ 199 BDs     │   ────►      │ ~20-30 BDs  │
│ 199 EPGs    │              │ 199 EPGs    │
│ vzAny       │              │ 20-50 ESGs  │
└─────────────┘              └─────────────┘
↓                            ↓
Firewall                    Firewall
(all inter-VRF)            (inter-VRF + inspection)
7. Automation Requirements
Essential Tools:
- Terraform CLI with NAC (start immediately)
- Postman collections for NDO
- Python scripts for IP-to-MAC mapping
Templates Structure:
hcl
terraform/
├── modules/
│   ├── microseg-enablement/
│   ├── esg-creation/
│   └── contract-management/
├── environments/
│   ├── eur-ais/
│   ├── eur-e/
│   └── [other-vrfs]/
8. Decision Matrix

| (table — text only follows) |
|---|
| Decision Point | Recommendation | Rationale |
| Tenant Structure | Single tenant | Simpler NDO templates, same admin team |
| BD Consolidation | Yes, but gradual | Reduce from 199 to ~30 over time |
| ESG Adoption | Wait until June 2025 | Multi-site support required |
| VMM Integration | Implement | Simplifies ESG management |
| Route Leaking | No | Too complex with multi-site |
| PBR/Service Graphs | Limited use | Only for specific inspection needs |
| Migration Approach | Parallel build | Non-disruptive |

Decision Point
Recommendation
Rationale
Tenant Structure
Single tenant
Simpler NDO templates, same admin team
BD Consolidation
Yes, but gradual
Reduce from 199 to ~30 over time
ESG Adoption
Wait until June 2025
Multi-site support required
VMM Integration
Implement
Simplifies ESG management
Route Leaking
No
Too complex with multi-site
PBR/Service Graphs
Limited use
Only for specific inspection needs
Migration Approach
Parallel build
Non-disruptive
9. What NOT to Do
❌ Don't create 7 separate tenants - unnecessary complexity ❌ Don't implement route leaking before ESG support ❌ Don't remove vzAny until fully confident in ESG setup ❌ Don't use PBR unless specifically needed for EPG-to-EPG firewall ❌ Don't rush BD consolidation - wait for ESG support
10. Immediate Next Steps
- Week 1: Enable microsegmentation on test EPGs
- Week 2: Set up Terraform/NAC framework
- Week 3: Create first "ALL-EPG" ESG in test VRF
- Week 4: Document application-to-BD/EPG mapping
- Ongoing: Prepare for June ESG multi-site release
This design balances the desire for application-centric networking with the practical constraints of your multi-site deployment and the upcoming ESG support timeline. It provides a clear migration path that minimizes disruption while achieving your security and visibility goals.
