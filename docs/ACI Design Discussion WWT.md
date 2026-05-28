ACI Design Discussion - Detailed Technical Document
Meeting Date: August 26, 2025Duration: 44 minutesDocument Version: 1.0Classification: Technical Implementation Guide
Table of Contents
- Meeting Context and Participants
- Current Infrastructure Analysis
- Technical Requirements and Constraints
- Proposed Architecture Design
- Implementation Strategy
- IPv6 Migration Planning
- Security Architecture
- Technical Challenges and Solutions
- Industry Best Practices
- Action Items and Timeline

1. Meeting Context and Participants
Participant Profiles
John Barber - Network Compute Engineer (NCE)
- Role: On-site lead engineer at Clay Concern
- Tenure: 2.5 years at current position
- Background: Former Army, stationed in Germany
- Responsibilities: Primary ACI and data center networking
- Current Focus: Legacy equipment migration and ACI redesign
Eric Helgeson - WWT Engineer
- Coverage: European theater support
- Experience: 10 years supporting European customers, 20 years in Germany
- Collaboration: Working with Rita Younger and Mike Woody on ACI solutions
- Historical Context: Familiar with customer's fragmented procurement history
Rita Younger - WWT Practice Lead
- Expertise: 30+ years Cisco networking experience
- Position: Data Center Networking Practice Lead at WWT
- Background: Former Cisco Advanced Services instructor and CSAT program participant
- Location: St. Louis, Missouri
- Notable: Daughter works as Fed SEM at Cisco
Belete Ageze - Cisco Architect
- Role: Customer Delivery Architect
- Sector: US Public Sector
- Relationship: Long-standing relationship with John Barber
- Focus: ACI design and implementation guidance
Meeting Objectives
- Establish consensus on ACI redesign approach
- Address IPv6 requirements and limitations
- Determine firewall integration strategy
- Define migration phases and priorities
- Align on technical implementation details

2. Current Infrastructure Analysis
Network Architecture Overview
Physical Infrastructure
- Current Legacy Equipment:
  - Nexus 5K switches (acting as Layer 2 access switches)
  - Multiple FEX units for port expansion
  - VPC connections from 5Ks to ACI fabric
  - All VLANs trunked through 5K switches
- ACI Deployment:
  - Version: ACI 6.0.7
  - NDO Version: 4.1.x (requiring upgrade for ESG support)
  - Controllers: 3 per site configuration
  - Multi-site: 2 primary sites + 1 remote leaf location
Logical Configuration
- Tenant Structure: Multiple tenants (considering single tenant migration)
- VRFs: 8-9 Virtual Routing and Forwarding instances
- Bridge Domains: 192 configured
- EPGs: 192 End Point Groups (1:1 with Bridge Domains)
- Current Mode: Network-centric (VLAN-based segmentation)
- Inter-VRF Communication: VZANY per VRF
- External Routing: L3Outs to firewalls at each site
Infrastructure Dependencies
Compute Infrastructure
- VMware Environment: Currently connected via legacy 5K switches
- UCS Platform: Hanging off 5K infrastructure
- Storage: Connected through legacy switching
- VMM Integration: Not currently implemented
Network Services
- Firewalls: Upgrading to new FirePower appliances
- Load Balancers: F5 devices (routing strategy TBD)
- Inter-Site Connectivity: ISN (Inter-Site Network) established
- Remote Sites: Connected via remote leaf architecture
Historical Context
The ACI implementation was originally deployed 4-5 years ago as an emergency replacement for failing Nexus 7K switches. The deployment was:
- Rushed due to network outages
- Implemented without proper planning
- Procured in fragments over time
- Met with internal resistance ("fought" by staff)
- Never fully utilized for intended capabilities

3. Technical Requirements and Constraints
Organizational Mandates
IPv6 Requirements (High Priority)
- Mandate: Full IPv6 implementation across infrastructure
- Approach: Dual-stack configuration (IPv4 + IPv6)
- Timeline: Elevated to top priority, possibly superseding redesign
- Scope: All L3Outs, bridge domains, and external routing
Modernization Goals
- Replace all legacy 5K/FEX infrastructure
- Implement true application-centric networking
- Improve security through micro-segmentation
- Reduce operational complexity
- Enable automation capabilities
Technical Constraints
Version Dependencies
- ESG Multi-site Support: Requires latest versions
  - ACI: 6.2+ recommended
  - NDO: 4.2+ required
- IPv6 Limitations:
  - Underlay: IPv4 only (IPv6 planned for 6.2.1)
  - Overlay: Full IPv6 support available
  - VXLAN tunnels over ISN: Not supported for IPv6
Resource Limitations
- Tools:
  - No Tetration or similar application dependency mapping
  - Limited to NDI for visibility
  - ServiceNow potentially available
- Budget:
  - No funding for advanced analytics tools
  - Professional services limited
- Staffing:
  - Single on-site engineer (John)
  - Remote support from WWT and Cisco
Compliance Requirements
- DoD Standards: Must maintain security compliance
- Change Management: Extensive "rock drill" exercises required
- Documentation: Comprehensive design documentation needed
- Testing: Thorough validation before production changes

4. Proposed Architecture Design
Target State Architecture
Tenant Design
- Structure: Single tenant model
- Rationale:
  - Simplified management
  - Easier troubleshooting
  - Reduced complexity for small team
  - Sufficient for current requirements
VRF Strategy
- Approach: Maintain existing VRF structure initially
- Mapping: Align new Bridge Domains and EPGs with current VRFs
- Evolution: Gradual consolidation based on application requirements
Endpoint Group Strategy
Phase 1: Foundation
Current State (192 EPGs) → Single ESG Migration
- Create one ESG per VRF initially
- Maintain VZANY for universal communication
- Map existing EPGs to single ESG
Phase 2: Selective Segmentation
Single ESG → Application-Based ESGs
- Identify critical applications
- Create dedicated ESGs per application
- Implement contracts between ESGs
- Maintain backward compatibility
Phase 3: Full Segmentation
Application ESGs → Micro-segmentation
- Complete application dependency mapping
- Granular security policies
- Full contract implementation
- Remove VZANY dependencies
VMM Integration Architecture
VMware Integration Design
- Domain Type: VMM Domain for vCenter
- Scope: All VMware clusters
- Benefits:
  - Dynamic EPG assignment
  - Automated VLAN provisioning
  - Improved visibility
  - Simplified operations
Implementation Approach
- Create VMM domain in ACI
- Establish vCenter connectivity
- Associate with physical infrastructure
- Migrate VMs gradually
- Validate and optimize
Bridge Domain Design
Consolidation Strategy
- Current: 192 Bridge Domains (1:1 with VLANs)
- Target: Consolidated based on routing requirements
- Approach:
- Per VRF: Create logical Bridge Domains- Production_Web_BD- Production_App_BD- Production_DB_BD- DMZ_Services_BD- Management_BD
Subnet Management
- Maintain existing IP schemes initially
- Plan for IPv6 dual-stack per BD
- Optimize subnet sizes based on actual usage
- Document all changes thoroughly

5. Implementation Strategy
Phase 1: Infrastructure Modernization (0-3 months)
Week 1-2: Preparation
- [ ] Complete network documentation
- [ ] Inventory all connections on 5K/FEX
- [ ] Develop migration runbooks
- [ ] Create rollback procedures
Week 3-4: VMM Integration
- [ ] Configure VMM domain
- [ ] Test with non-production cluster
- [ ] Document procedures
- [ ] Train operations team
Week 5-12: Legacy Migration
- [ ] Install new leaf switches
- [ ] Migrate connections from 5K/FEX
- [ ] Validate connectivity
- [ ] Decommission legacy equipment
Phase 2: ACI Optimization (3-6 months)
Platform Upgrades
Current State:
- ACI: 6.0.7
- NDO: 4.1.x

Target State:
- ACI: 6.2.x (recommended release)
- NDO: 4.2.x (ESG multi-site support)
ESG Implementation
- Single ESG Creation
  - One ESG per VRF
  - Include all EPGs
  - Maintain VZANY
- Testing and Validation
  - Verify all communication paths
  - Document any issues
  - Performance benchmarking
- Gradual Migration
  - Start with test/dev environments
  - Move to production systematically
  - Maintain rollback capability
Phase 3: Application-Centric Transformation (6-12 months)
Application Discovery Process
Automated Discovery
Tools and Methods:
1. NDI Analytics
- Flow analysis
- Endpoint tracking
- Protocol identification

2. ServiceNow Integration
- CMDB correlation
- Application mapping
- Dependency tracking

3. Python Scripts
- Parse existing configs
- Generate topology maps
- Identify communication patterns
Manual Discovery
- Interview application owners
- Review documentation
- Analyze firewall rules
- Examine load balancer configs
ESG Segmentation Strategy
Critical Applications First
- Identify top 5 critical applications
- Map all dependencies
- Create dedicated ESGs
- Implement specific contracts
- Test thoroughly
- Monitor and optimize
Iterative Refinement
- Weekly review cycles
- Continuous optimization
- Performance monitoring
- Security validation

6. IPv6 Migration Planning
Current IPv6 Support Matrix

| (table — text only follows) |
|---|
| Component | IPv4 Support | IPv6 Support | Notes |
| Underlay | ✅  Full | ❌  Not Available | Planned for 6.2.1 |
| Overlay | ✅  Full | ✅  Full | Available now |
| Bridge Domains | ✅  Full | ✅  Dual-stack | Supported |
| L3Outs | ✅  Full | ✅  Dual-stack | Supported |
| EPGs | ✅  Full | ✅  Full | Supported |
| Contracts | ✅  Full | ✅  Full | Supported |
| Multi-site ISN | ✅  Full | ⚠️  Limited | No VXLAN over IPv6 |

Component
IPv4 Support
IPv6 Support
Notes
Underlay
✅ Full
❌ Not Available
Planned for 6.2.1
Overlay
✅ Full
✅ Full
Available now
Bridge Domains
✅ Full
✅ Dual-stack
Supported
L3Outs
✅ Full
✅ Dual-stack
Supported
EPGs
✅ Full
✅ Full
Supported
Contracts
✅ Full
✅ Full
Supported
Multi-site ISN
✅ Full
⚠️ Limited
No VXLAN over IPv6
Implementation Approach
Dual-Stack Configuration
Bridge Domain Level
Configuration Steps:
1. Enable IPv6 on Bridge Domain
2. Configure IPv6 gateway
3. Set IPv6 specific parameters:
- ND Policy
- RA Policy
- DAD (Duplicate Address Detection)
L3Out Configuration
External Routing:
1. Configure IPv6 on L3Out interfaces
2. Establish BGP IPv6 address family
3. Configure route maps for IPv6
4. Implement prefix lists
Multi-Site Considerations
Current Limitations
- VXLAN tunnels require IPv4 underlay
- ISN connectivity IPv4-based
- BGP EVPN uses IPv4 transport
Workaround Strategy
- Maintain IPv4 for infrastructure
- Implement IPv6 for user traffic
- Use dual-stack at all layers
- Plan for future full IPv6
Testing and Validation
Test Plan Components
- Connectivity Testing
  - Intra-subnet IPv6
  - Inter-subnet routing
  - External connectivity
  - Multi-site communication
- Application Testing
  - IPv6-only applications
  - Dual-stack applications
  - Legacy IPv4 compatibility
  - Performance comparison
- Security Validation
  - Contract enforcement
  - Firewall policies
  - ACL implementation
  - Traffic inspection

7. Security Architecture
Firewall Integration Strategy
Current State
- Traffic Flow: Hair-pinning through firewalls for inter-VRF
- Placement: External to ACI fabric
- Management: Separate from ACI policy
Recommended Approach
North-South Security (Maintain)
Internet → Firewall → ACI Border Leaf → Internal Resources
- Traditional perimeter security
- Centralized threat management
- Simplified troubleshooting
East-West Security (ESG-Based)
ESG1 ← Contract → ESG2
- Micro-segmentation via ESGs
- Distributed security policy
- No firewall hair-pinning
- Better performance
Decision Rationale
Against Service Graph/PBR:
- Adds complexity in multi-site
- Difficult troubleshooting
- Performance implications
- Limited value with ESGs
For ESG-Based Security:
- Native ACI capability
- Simplified operations
- Better performance
- Sufficient security
Contract Design Strategy
Hierarchical Contract Model
Tier 1: Infrastructure Contracts
Common Services:
- DNS_Contract
- NTP_Contract
- AD_Contract
- Management_Contract
Tier 2: Application Contracts
Application-Specific:
- Web_to_App_Contract
- App_to_DB_Contract
- External_Access_Contract
Tier 3: Security Zones
Zone-Based:
- DMZ_to_Internal_Contract
- Production_to_Development_Contract
- User_to_Services_Contract
Compliance Considerations
DoD Security Requirements
- Mandatory access controls
- Audit logging
- Encryption requirements
- Separation of duties
Implementation Approach
- Map requirements to ACI capabilities
- Implement RBAC in ACI
- Enable comprehensive logging
- Regular security audits

8. Technical Challenges and Solutions
Challenge 1: Application Dependency Mapping
Problem
- No automated discovery tools
- Complex application interactions
- Undocumented dependencies
- Risk of breaking communications
Solution Approach
# Phased Discovery Process
Phase 1: Baseline Current Flows
- Use NDI for flow analysis
- Capture during peak periods
- Document all communications

Phase 2: Categorize Traffic
- Sort by application
- Identify critical paths
- Map dependencies

Phase 3: Incremental Testing
- Start with non-critical apps
- Test in maintenance windows
- Build confidence gradually
Challenge 2: Limited Resources
Problem
- Single engineer on-site
- No dedicated application team
- Limited budget for tools
- Time constraints
Solution Approach
- Leverage automation (Python/Ansible)
- Utilize WWT/Cisco support
- Implement in phases
- Focus on high-impact changes
Challenge 3: Organizational Resistance
Problem
- Historical negative experience with ACI
- Preference for traditional networking
- Fear of complexity
- Change resistance
Solution Approach
- Education and Training
  - On-site workshops
  - Hands-on demonstrations
  - Success story sharing
  - Gradual adoption
- Quick Wins
  - VMM integration benefits
  - Simplified operations
  - Improved visibility
  - Automation examples
- Stakeholder Engagement
  - Regular updates
  - Clear communication
  - Demonstrated value
  - Risk mitigation
Challenge 4: Multi-Site Complexity
Problem
- ISN configuration
- Site synchronization
- Stretched VLANs
- Disaster recovery
Solution Approach
- Keep design simple initially
- Avoid complex service graphs
- Maintain site autonomy
- Plan for site isolation

9. Industry Best Practices
Comparison with Other Deployments
EUCOM and AFRICOM Approach
- Strategy: Network-centric, one-for-one migration
- Rationale: Simplicity and speed
- Results: Successful migration with minimal disruption
- Lesson: Don't overcomplicate initial migration
Enterprise Trends
Movement to NDFC
- Drivers:
  - Reduced complexity
  - Familiar CLI
  - Easier operations
  - Group Policy Objects for segmentation
- Considerations:
  - Still provides segmentation
  - Simpler than ACI
  - Better for network-centric teams
Arista Competition
- Warning: Cloud Vision more complex than ACI
- Recommendation: Stay with Cisco ecosystem
- Alternative: Consider NDFC if ACI too complex
WWT Recommendations
Based on extensive customer experience:
- Start Simple
  - Network-centric initially
  - Single tenant design
  - Minimal contracts
  - Focus on stability
- VMM Integration Priority
  - Immediate operational benefits
  - Simplified provisioning
  - Better visibility
  - Foundation for automation
- Incremental Migration
  - Avoid "big bang" approaches
  - Test thoroughly
  - Maintain rollback options
  - Document everything
- Application-Centric Evolution
  - Only for critical applications
  - Requires dependency mapping
  - Start with low-risk apps
  - Build expertise gradually

10. Action Items and Timeline
Immediate Actions (Week 1-2)

| (table — text only follows) |
|---|
| Action Item | Owner | Due Date | Status |
| Send network diagrams to WWT | John Barber | Week 1 | Pending |
| Review current documentation | Rita Younger | Week 1 | Pending |
| Schedule on-site workshop | Eric Helgeson | Week 2 | Pending |
| Brief Conrad on approach | John Barber | Upon return | Pending |

Action Item
Owner
Due Date
Status
Send network diagrams to WWT
John Barber
Week 1
Pending
Review current documentation
Rita Younger
Week 1
Pending
Schedule on-site workshop
Eric Helgeson
Week 2
Pending
Brief Conrad on approach
John Barber
Upon return
Pending
Short-term Actions (Month 1-2)

| (table — text only follows) |
|---|
| Action Item | Owner | Target | Priority |
| Complete 5K migration planning | John | Month 1 | High |
| Deploy VMM integration | John | Month 1 | High |
| Test IPv6 in lab | John/Belete | Month 2 | Medium |
| Create automation scripts | John | Month 2 | Medium |

Action Item
Owner
Target
Priority
Complete 5K migration planning
John
Month 1
High
Deploy VMM integration
John
Month 1
High
Test IPv6 in lab
John/Belete
Month 2
Medium
Create automation scripts
John
Month 2
Medium
Medium-term Actions (Month 3-6)

| (table — text only follows) |
|---|
| Action Item | Owner | Target | Priority |
| Upgrade ACI/NDO versions | John | Month 3 | High |
| Implement single ESG | John | Month 4 | High |
| Begin application mapping | Team | Month 5 | Medium |
| Deploy IPv6 dual-stack | John | Month 6 | High |

Action Item
Owner
Target
Priority
Upgrade ACI/NDO versions
John
Month 3
High
Implement single ESG
John
Month 4
High
Begin application mapping
Team
Month 5
Medium
Deploy IPv6 dual-stack
John
Month 6
High
Long-term Actions (Month 6-12)

| (table — text only follows) |
|---|
| Action Item | Owner | Target | Priority |
| Create application ESGs | John | Month 8 | Medium |
| Implement contracts | John | Month 10 | Medium |
| Complete documentation | Team | Month 12 | High |
| Conduct security audit | Team | Month 12 | High |

Action Item
Owner
Target
Priority
Create application ESGs
John
Month 8
Medium
Implement contracts
John
Month 10
Medium
Complete documentation
Team
Month 12
High
Conduct security audit
Team
Month 12
High
Success Criteria
Phase 1 Success Metrics
- ✅ All 5K/FEX equipment replaced
- ✅ VMM integration operational
- ✅ No service disruptions
- ✅ Team trained on new processes
Phase 2 Success Metrics
- ✅ IPv6 dual-stack deployed
- ✅ Single ESG implemented
- ✅ Platform versions current
- ✅ Automation tools deployed
Phase 3 Success Metrics
- ✅ 25% applications in dedicated ESGs
- ✅ Contract policies implemented
- ✅ Full documentation complete
- ✅ Operational efficiency improved

Appendices
A. Technical Resources
Cisco Documentation
- ACI Configuration Guide
- ESG Implementation Guide
- IPv6 Deployment Guide
- Multi-Site Configuration
WWT Resources
- Mike Woody's Lab Environments
- Learning Paths
- Best Practice Guides
- Customer Case Studies
B. Contact Information

| (table — text only follows) |
|---|
| Name | Role | Email | Availability |
| John Barber | NCE Lead | [TBD] | On-site |
| Eric Helgeson | WWT Engineer | [TBD] | Europe TZ |
| Rita Younger | WWT Practice Lead | [TBD] | US Central |
| Belete Ageze | Cisco CDA | [TBD] | US Eastern |
| Mike Woody | WWT SME | [TBD] | US Central |

Name
Role
Email
Availability
John Barber
NCE Lead
[TBD]
On-site
Eric Helgeson
WWT Engineer
[TBD]
Europe TZ
Rita Younger
WWT Practice Lead
[TBD]
US Central
Belete Ageze
Cisco CDA
[TBD]
US Eastern
Mike Woody
WWT SME
[TBD]
US Central
C. Glossary of Terms

| (table — text only follows) |
|---|
| Term | Definition |
| ACI | Application Centric Infrastructure |
| ESG | Endpoint Security Group |
| EPG | Endpoint Group |
| NDO | Nexus Dashboard Orchestrator |
| NDI | Nexus Dashboard Insights |
| NDFC | Nexus Dashboard Fabric Controller |
| VMM | Virtual Machine Manager |
| VRF | Virtual Routing and Forwarding |
| ISN | Inter-Site Network |
| VZANY | Contract permitting any-to-any communication within VRF |
| PBR | Policy-Based Redirect |

Term
Definition
ACI
Application Centric Infrastructure
ESG
Endpoint Security Group
EPG
Endpoint Group
NDO
Nexus Dashboard Orchestrator
NDI
Nexus Dashboard Insights
NDFC
Nexus Dashboard Fabric Controller
VMM
Virtual Machine Manager
VRF
Virtual Routing and Forwarding
ISN
Inter-Site Network
VZANY
Contract permitting any-to-any communication within VRF
PBR
Policy-Based Redirect
D. Risk Register

| (table — text only follows) |
|---|
| Risk | Probability | Impact | Mitigation |
| Application breakage during ESG migration | Medium | High | Thorough testing, gradual migration |
| IPv6 compatibility issues | Low | Medium | Dual-stack approach, extensive testing |
| Resource constraints delay project | High | Medium | Automation, external support |
| Organizational resistance | Medium | Medium | Education, quick wins, communication |

Risk
Probability
Impact
Mitigation
Application breakage during ESG migration
Medium
High
Thorough testing, gradual migration
IPv6 compatibility issues
Low
Medium
Dual-stack approach, extensive testing
Resource constraints delay project
High
Medium
Automation, external support
Organizational resistance
Medium
Medium
Education, quick wins, communication

Document Version Control:
- Version 1.0 - Initial Release - September 2025
- Review Cycle: Monthly
- Next Review: October 2025
- Distribution: Internal Technical Team
Classification: Technical Implementation DocumentRestrictions: Internal Use OnlyOwner: Network Engineering Team
