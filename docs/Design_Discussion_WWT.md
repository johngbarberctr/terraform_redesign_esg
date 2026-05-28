RCC-E ACI Design Discussion – 26 August 2025
Summary Document
Purpose
To discuss the redesign of the ACI (Application Centric Infrastructure) strategy for RCC-E, address network integration challenges, upgrade paths, IPv6 transition, firewall strategy, and next steps.
Key Participants
- Eric Helgeson – Engineer, WWT Europe
- Rita Younger – Practice Lead, Data Center Networking, WWT
- John Barber – Network Consulting Engineer (NCE), Clay Concern
- Belete Ageze – Customer Delivery Architect, Cisco Public Sector
Main Discussion Points
1. Current State and Priorities
- Existing infrastructure includes legacy Cisco 5K switches and FEXes, currently being migrated into new ACI leaf switches (9Ks).
- Focus is on replacing legacy equipment before major ACI redesign.
- Ongoing use of Python/Ansible automation for configuration migration.
2. ACI Redesign Approach
- Considering single-tenant model with several VRFs, bridge domains, and EPGs.
- Gradual move from network-centric to more application-centric segmentation as application dependencies are mapped.
- Initial recommendation to migrate all workloads to a single ESG, then segment as needed.
3. Integration and Migration
- Immediate goal: VMM (Virtual Machine Manager) integration to streamline VMware operations.
- Challenges around application dependency mapping; critical for effective segmentation.
4. Firewall and Security Strategy
- Current design hairpins inter-VRF traffic through firewalls for routing and security.
- Consensus: ESGs provide adequate segmentation; introducing additional east-west firewalls may add unnecessary complexity.
- No current need for complex traffic engineering within ACI.
5. IPv6 Transition
- Top priority for the customer is dual-stack IPv4/IPv6 support.
- Current limitations: Underlay IPv6 not yet supported in ACI Multi-site; overlay IPv6 is supported for user/application traffic.
- Underlay IPv6 support anticipated in future ACI releases.
6. Upgrade and Tooling
- Need to upgrade ACI and NDO/NDFC to access new features (e.g., full ESG support).
- Ongoing reliance on Cisco Nexus Dashboard and associated tools.
7. Next Steps & Recommendations
- Complete replacement of 5K infrastructure.
- Accelerate VMM domain integration.
- Start with network-centric mode, transition to application-centric as dependencies are mapped.
- Collaborate on diagrams and documentation for better situational awareness.
- Plan workshops to accelerate design decisions and ensure alignment.
- Monitor ACI/NDO software roadmap for IPv6 and ESG enhancements.

Detailed Document
1. Team Introductions and Roles
- Eric Helgeson: WWT Europe engineer, 10+ years supporting the region, provides ongoing ACI expertise.
- Rita Younger: 30+ years with Cisco networks, leads data center networking practice, experienced consultant and instructor.
- John Barber: Onsite NCE at Clay Concern, specializes in data center and ACI, responsible for on-the-ground migration and design.
- Belete Ageze: Cisco public sector architect, supports migration and ACI best practices.
2. ACI Redesign Goals and Strategy
- Drivers: Equipment refresh (migration from 5Ks to 9Ks), maximize ACI investment, and improve segmentation/security.
- Design Approach:
  - Single Tenant: Considered optimal given multi-site structure and potential future site consolidation.
  - Current Segmentation: 8–9 VRFs, ~192 EPGs/bridge domains.
  - Migration Path: Move existing infrastructure into ACI using network-centric mode; transition to ESGs and application-centric segmentation over time.
  - VMM Integration: Identified as a priority for operational efficiency.
3. Network Integration and Application Mapping
- Challenges:
  - Lack of application dependency mapping makes true application-centric design difficult.
  - Plan to begin with all workloads in a single ESG, gradually segment as critical applications are identified.
  - Use of ServiceNow for potential dependency mapping; Cisco tools considered cost-prohibitive.
- Tools: Python/Ansible automation for migration; NDI for limited dependency insights.
4. Firewall and Routing Design
- Current State: All inter-VRF routing is via external firewalls (“hairpinning”).
- Discussion: No current requirement for complex in-fabric firewalling; ESGs suffice for most segmentation and security needs.
- Future Considerations: Avoid overcomplicating network with unnecessary east-west firewalls.
5. IPv6 Transition and Dual Stack Support
- Customer Priority: Move to dual-stack IPv4/IPv6 throughout the data center.
- ACI Support:
  - Overlay IPv6: Supported for endpoints and bridge domains.
  - Underlay IPv6: Not yet supported in ACI multi-site; expected in future releases (potentially 6.2.x).
  - Workarounds: IPv4 underlay with IPv6 overlay is currently functional for most user/application traffic.
  - Limitations: VXLAN tunnels over ISN currently require IPv4; full native IPv6 underlay support pending.
6. Upgrade and Platform Considerations
- ACI/NDO/NDFC Upgrades: Required for latest ESG and IPv6 features. Current versions may limit some multi-site capabilities.
- Alternative Solutions: Some customers are evaluating NDFC over ACI for simplicity; Arista considered but found more complex.
7. Collaboration and Next Steps
- Action Items:
  - Share updated network diagrams for design alignment.
  - Schedule workshops (potentially involving broader teams) to finalize migration and design plans.
  - Monitor software release notes for critical features (IPv6 underlay, enhanced ESG).
  - Engage in peer reviews and external validation to support internal alignment.
- Workshop Structure: Led by on-site NCE, supported by WWT/Cisco experts, focus on actionable design decisions.
- Customer Environment: Typical of DoD and enterprise clients; balancing legacy constraints with modern ACI features.
8. Additional Observations
- Industry Trends: Most customers remain in network-centric mode due to lack of application mapping; complexity has led some to consider alternatives.
- Support Considerations: Cisco support and ecosystem remain a differentiator versus competitors like Arista.

Attachments
(Please attach your diagrams or supporting documents as referenced.)

Example: Action Item Table

| (table — text only follows) |
|---|
| Action Item | Owner | Due Date | Status |
| Replace legacy 5Ks/ FEXes | John Barber | Q4 2025 | In Progress |
| Integrate VMM domains | John Barber | Q4 2025 | Pending |
| Share latest network diagrams | John Barber | Q3 2025 | Pending |
| Plan and schedule workshop | Eric Helgeson | Q3 2025 | Pending |
| Monitor ACI upgrade roadmap | Rita Younger | Ongoing | In Progress |

Action Item
Owner
Due Date
Status
Replace legacy 5Ks/FEXes
John Barber
Q4 2025
In Progress
Integrate VMM domains
John Barber
Q4 2025
Pending
Share latest network diagrams
John Barber
Q3 2025
Pending
Plan and schedule workshop
Eric Helgeson
Q3 2025
Pending
Monitor ACI upgrade roadmap
Rita Younger
Ongoing
In Progress

Notes & Considerations
- Edge Cases: If IPv6 underlay is required before support is available, project timelines may need adjustment.
- Dependencies: Migration sequencing is dependent on completion of hardware upgrades and VMM integration.
- Customer Prioritization: Shifts in DOD requirements or site consolidation may affect design direction.

RCC-E ACI Design Discussion – Detailed Meeting Record
Date: 26 August 2025Session: RCC-E ACI Design Discussion-20250826 1347-1Generated: AI-assisted, based on provided transcript

Table of Contents
- Participants & Roles
- Meeting Overview
- Current State of Environment
- Project Priorities & Drivers
- ACI Redesign Discussion
- Technical Migration Details
- Firewall & Security Architecture
- IPv6 Transition & Multi-Site Considerations
- ACI/Nexus Dashboard Tooling & Upgrade Path
- Challenges and Risks
- Next Steps & Action Items
- Appendices: Key Quotes and Insights

1. Participants & Roles

| (table — text only follows) |
|---|
| Name | Role/Org | Responsibilities/Context |
| Eric Helgeson | Engineer, WWT (Europe) | Regional ACI lead, customer advisor, Europe experience |
| Rita Younger | Practice Lead, DC Networking, WWT | 30+ yrs Cisco, design lead, consultant, instructor |
| John Barber | NCE, Clay Concern | Onsite engineer, ACI migration, config, project advocate |
| Belete  Ageze | Customer Delivery Architect, Cisco | US Public Sector, Cisco ACI expert, design guidance |
| Mike Woody | (Not present, referenced) | ACI technical SME/lab developer, resource |

Name
Role/Org
Responsibilities/Context
Eric Helgeson
Engineer, WWT (Europe)
Regional ACI lead, customer advisor, Europe experience
Rita Younger
Practice Lead, DC Networking, WWT
30+ yrs Cisco, design lead, consultant, instructor
John Barber
NCE, Clay Concern
Onsite engineer, ACI migration, config, project advocate
Belete Ageze
Customer Delivery Architect, Cisco
US Public Sector, Cisco ACI expert, design guidance
Mike Woody
(Not present, referenced)
ACI technical SME/lab developer, resource

2. Meeting Overview
- Purpose: Align stakeholders on ACI redesign, network integration, migration priorities, IPv6 support, and next steps for RCC-E.
- Format: Open technical discussion with design brainstorming, operational review, and Q&A.
- Chapters: Introductions, ACI redesign, integration challenges, firewall/IPv6 strategy, upgrade path, networking challenges, wrap-up.

3. Current State of Environment
- Data Center Fabric:
  - Legacy: Cisco 5Ks, FEXes (acting as Layer 2 access below 9Ks).
  - Target: New ACI leaf switches (9Ks) to replace 5Ks/FEXes.
- ACI Deployment:
  - Tenancy: Single tenant, multi-site (two main, one remote leaf).
  - Segmentation: 8–9 VRFs, ~192 EPGs and bridge domains.
  - External Connections: L3Outs to firewalls per site; ISN (Inter-Site Network) used for site-to-site.
- Tools/Automation: Python and Ansible for extracting configs and deploying to ACI; intention to leverage automation for port bindings, minimize VLAN sprawl.

4. Project Priorities & Drivers
- Immediate: Remove 5Ks/FEXes, migrate workloads to ACI 9Ks.
- Mid-term: Redesign ACI for greater efficiency, security, and application alignment.
- Other: Transition to dual-stack IPv4/IPv6, improve VMware (VMM) integration, simplify segmentation/security, maximize investment in ACI.

5. ACI Redesign Discussion
5.1. Design Philosophy
- Current Mode: Network-centric, mapping VLANs/EPGs/VRFs directly.
- Target Mode: Gradual shift to application-centric segmentation (using ESGs), as application dependencies are mapped.
- Single vs. Multi-Tenant: Consensus to remain single-tenant for current and near-future, pending site consolidation.
5.2. Segmentation Approach
- Initial Step: Migrate all workloads into one ESG for simplicity and control; break out into multiple ESGs/contracts as more is learned about application dependencies.
- Mapping: VRFs aligned with bridge domains/EPGs; VLANs mapped to ESGs.
- Application Discovery: No comprehensive mapping currently; plan to use ServiceNow and limited NDI capabilities.
5.3. Application Dependency Mapping
- Challenge: No current deep visibility into application flows; risk of “breaking” critical apps during segmentation.
- Best Practice: Start with low-risk apps for segmentation experiments; maintain broad connectivity until dependencies are mapped.
5.4. VMM Integration
- Critical Priority: VMM domains (for VMware) not yet integrated; viewed as a first technical milestone for improved operational efficiency.

6. Technical Migration Details
- Current Tasks:
  - Extract configs from 5Ks using Ansible/Python.
  - Rebind ports and migrate VLANs to ACI fabric.
- Bindings: Focus on proper EPG/port bindings, avoiding unnecessary VLAN carryover.
- Legacy Complexity: 5Ks currently act as access, pass all VLANs through, many endpoints (especially VMware and UCS) hang off FEXes.
- Clean-Up Goal: Migrate all access to 9Ks, simplify fabric, and remove “ugly” legacy L2 topology.

7. Firewall & Security Architecture
7.1. Current Model
- Inter-VRF Routing: All routed via external firewall (hairpin).
- East-West Security: ESGs used for segmentation; no in-fabric firewalls.
7.2. Design Discussion
- Consensus: ESGs sufficient for most segmentation/security; avoid adding in-fabric firewalls unless specific compliance/engineering needs arise.
- Complexity Warning: Inserting firewalls for east-west traffic in ACI increases complexity, especially in a multi-site context; consensus to avoid unless strictly required.
- Efficiency: Some minor concerns about hairpin routing efficiency, but not identified as a bottleneck.

8. IPv6 Transition & Multi-Site Considerations
8.1. Customer Priority
- Dual-Stack: Strong DOD-driven push to enable IPv6 everywhere; dual-stack (not IPv6-only) is the immediate goal.
- Bridge Domains/L3Outs: Need to support IPv6 addressing and routing throughout.
8.2. ACI Support
- Overlay IPv6: Supported—endpoints and bridge domains can use IPv6.
- Underlay IPv6: Not currently supported in ACI Multi-site; VXLAN tunnels over ISN must use IPv4 underlay. IPv6 underlay targeted for future (possibly version 6.2+).
- Routing: BGP underlay remains IPv4; overlay (user/app traffic) can be dual-stack.
8.3. Implications
- User Traffic: Can achieve dual-stack endpoint-to-endpoint communication, even across sites, as long as underlay stays IPv4.
- Limitations: No native IPv6-only underlay or VXLAN tunnel establishment; may not matter for current workloads/applications.

9. ACI/Nexus Dashboard Tooling & Upgrade Path
- Current Tools: NDI (Nexus Dashboard Insights), NDO (Orchestrator), limited NDFC (Fabric Controller).
- Upgrade Need: ESG multi-site, enhanced IPv6 features require upgrade (current ACI ~6.0.7, NDO ~4.1).

10. Challenges and Risks
- Application Dependency Mapping: Lack thereof increases risk in segmentation efforts.
- Legacy Infrastructure: Prolonged use of 5Ks/FEXes complicates migration and increases operational risk.
- Customer Readiness: Internal delays, shifting priorities (e.g., IPv6, firewall refresh) could impact timelines.
- Tooling Gaps: Full benefit of Cisco’s advanced mapping/discovery tools not available due to cost constraints.

11. Next Steps & Action Items

| (table — text only follows) |
|---|
| Action/Decision | Owner(s) | Target Date | Notes |
| Complete 5K/FEX migration to 9Ks | John Barber | Q4 2025 | Use automation for config/port migration |
| Integrate VMM domains for VMware | John Barber | Q4 2025 | First technical milestone |
| Share updated network diagrams | John Barber | Q3 2025 | For design review by Rita/Eric |
| Plan/schedule ACI redesign workshop | Eric Helgeson, Rita | Q3–Q4 2025 | Include all relevant stakeholders |
| Map initial application dependencies | John Barber | Q4 2025 | Use ServiceNow, NDI, interviews |
| Monitor ACI/NDO software roadmap | Rita Younger, Belete | Ongoing | IPv6 underlay, ESG improvements |
| Prepare documentation for firewall/F5 flows | John Barber | Q4 2025 | For future migration design |

Action/Decision
Owner(s)
Target Date
Notes
Complete 5K/FEX migration to 9Ks
John Barber
Q4 2025
Use automation for config/port migration
Integrate VMM domains for VMware
John Barber
Q4 2025
First technical milestone
Share updated network diagrams
John Barber
Q3 2025
For design review by Rita/Eric
Plan/schedule ACI redesign workshop
Eric Helgeson, Rita
Q3–Q4 2025
Include all relevant stakeholders
Map initial application dependencies
John Barber
Q4 2025
Use ServiceNow, NDI, interviews
Monitor ACI/NDO software roadmap
Rita Younger, Belete
Ongoing
IPv6 underlay, ESG improvements
Prepare documentation for firewall/F5 flows
John Barber
Q4 2025
For future migration design

12. Appendices: Key Quotes and Insights
- “The biggest struggle really is mapping everything, right? All the applications… it's not even smart, right? You can't maintain that.”
- “Right now, all inter-VRF routing goes through the firewall—no route leaking in ACI. Avoiding that keeps things cleaner.”
- “VMN integration should be first. That will make things so much easier from a virtual VMware standpoint.”
- “IPv6 overlay is supported, but underlay is not yet—shouldn’t be a blocker for most user traffic. Underlay support is on the roadmap.”
- “Many customers stay network-centric due to lack of application mapping. Even Cisco has moved away from pure ‘application-centric’ language.”
- “If hairpinning traffic through the firewall isn’t causing issues, don’t add complexity.”
- “NDFC is being adopted by some for simplicity, but ACI remains common for DOD/Enterprise due to support.”

Notes and Special Considerations
- Edge Cases: If IPv6 underlay becomes urgent, project may require architecture shift or timeline adjustment.
- Dependencies: Complete removal of 5Ks is prerequisite for major ACI design changes.
- External Input: Workshop should include stakeholders managing F5, firewalls, and other critical integrations for holistic design.
