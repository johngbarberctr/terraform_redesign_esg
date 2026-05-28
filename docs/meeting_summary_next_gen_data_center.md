# Meeting Summary

Topic: Next-Generation Data Center Design and ACI Expansion
Date: [Insert Date]
Participants: John Barber, Conrad (Data Center Manager), Samantha (Engineer), Belete Ageze

## 1. Current Environment

ACI Fabric: Two-site deployment using Cisco NDO to stretch bridge domains and EPGs.
Routing and Security:  - Firewalls at the edge currently handle both north–south and inter-VRF traffic.  - Routing managed through legacy Cisco 5580 firewalls with OSPF southbound and BGP northbound.
Hardware:  - Border leafs, service leafs, and legacy Nexus 5Ks with FEXes (to be replaced by ~30 new leaf switches).  - Plan to migrate to Cisco 4210 next-generation firewalls.

## 2. Key Challenges

Suboptimal Security Architecture:  - Current inter-VRF communication forces traffic to exit and re-enter ACI through firewalls.  - Unclear whether firewalls are strictly required for east–west segmentation versus using ACI contracts.
Routing and Failover Issue:  - Loss of a default route (quad zero) in one DC causes ACI to reroute via the other DC through ISN.  - Results in asymmetric traffic flows, breaking firewall state.  - Metrics in intersite L3Out are not properly influencing path selection.
Complex VRF Layout:  - Five separate VRFs increase operational complexity and force unnecessary firewall hops.  - Current design is network-centric (1 VLAN : 1 Bridge Domain : 1 EPG), not application-centric.

## 3. Recommendations and Next Steps

Hardware Transition (Immediate Priority):  - Remove Nexus 5Ks, deploy new leaf switches (target arrival: June 9).  - Minimize disruptive design changes during physical migration due to resource constraints.
Logical Design Improvements (Post-Migration):  - VRF Rationalization: Combine VRFs where possible; use ACI contracts for segmentation if firewall-level policy is not required.  - Evaluate ESG (Endpoint Security Groups):    - Move toward application-centric design.    - Simplify security policy definition and reduce need for inter-VRF routing through firewalls.  - Routing Protocol Review:    - Consider moving from OSPF southbound to end-to-end BGP for consistency and simpler failover control.    - Develop fixes for quad-zero route issue using both OSPF and BGP options.
Planning and Testing:  - Create a detailed blueprint for “next-gen” data center design with input from Cisco best practices.  - Schedule maintenance windows post–June 4 to test default route failover behavior safely.  - Build new logical design in parallel with production environment, then migrate services incrementally.

## 4. Action Items

Belete: Prepare design recommendations addressing quad-zero failover and VRF rationalization (OSPF vs BGP options).
John/Conrad: Plan physical migration of Nexus 5Ks → leaf switches and prepare cabling diagrams.
All: Align on future application-centric model leveraging ESG and contracts rather than firewall sandwiching where possible.
Timeline:  - No production changes until June 4.  - Hardware delivery expected June 9; migration to begin immediately after.

Prepared by: [Your Name]
For: Internal review and next-step planning
