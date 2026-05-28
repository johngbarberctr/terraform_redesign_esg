ACI Network Design and Migration Strategy
Technical Discussion Meeting Notes
Date: [Meeting Date]Participants: John Barber, Belete AgezeSubject: ACI Architecture Design and Migration Planning

Executive Summary
This document summarizes the technical discussion regarding the redesign and migration strategy for the Application Centric Infrastructure (ACI) environment. The discussion focused on optimizing the tenant structure, implementing Endpoint Security Groups (ESGs), and establishing best practices for application-centric deployment.

Key Discussion Topics
1. Tenant and VRF Architecture
Current Consideration
- Initial proposal to create separate tenants for each VRF (potentially 10 tenants)
- Migration of Bridge Domains (BDs) and EPGs to respective tenants
Expert Recommendation
- Single tenant with multiple VRFs is preferred over multiple tenants
- From the switch perspective, there is no forwarding difference between:
  - One tenant with multiple VRFs
  - Multiple tenants with single VRFs
Key Considerations
- Access Control: Tenant-level privilege assignment is the only advantage of multiple tenants
- Management Overhead: Multiple tenants require switching between tenant contexts for configuration
- NDO Complexity: Multiple tenants require multiple templates (1:1 minimum ratio)
- Recommendation: Use multiple tenants only when there is clear business unit separation or distinct administrative boundaries
2. Endpoint Security Groups (ESGs) Implementation
Migration Strategy
- Phase 1: Create a single ESG and migrate all endpoints
- Phase 2: Gradually break out applications into specific ESGs based on selectors
- Phase 3: Implement granular policies per ESG
ESG Support Timeline
- Single-site ESG in NDO: Expected June/July 2025 (version 6.1 or 6.2)
- Multi-site stretched ESG: Later release (timeline TBD)
- Current Status: ESG available in APIC but not yet in NDO
Benefits of ESG
- Purely policy construct (no networking component)
- Simplifies application-centric deployment
- Enables cross-bridge domain extension within VRF
- Reduces complexity compared to EPG-based policy
3. Application-Centric Deployment
Bridge Domain Strategy
Option 1: Service-Based Bridge Domains
- One large subnet for database tier (/22)
- One large subnet for web tier
- One large subnet for application tier
- All similar services share the same bridge domain
Option 2: Application-Based Bridge Domains
- Dedicated bridge domain per application (e.g., HR, Engineering)
- Each contains all tiers (web, app, database) for that application
- Multiple EPGs can map to single bridge domain
EPG Structure Best Practices
- Create EPG structure based on application components
- Implement clear naming conventions
- Start with permissive policies (vzAny) and tighten over time
- Consider using CSW or similar tools for application dependency mapping
4. VMM Integration
Current State
- Not currently implemented
- Static port mapping in use
Recommendation
- Strongly recommended for operational efficiency
- Simplifies configuration through port group integration
- Eliminates need for static mapping
- Requires stakeholder buy-in and education
5. Policy and Security Architecture
Service Graph (PBR) Considerations
- Use Case: Only required if firewall inspection needed between EPGs
- Current Design: Firewall inspection only between VRFs (via L3Out)
- Recommendation: Avoid PBR unless specific security requirements exist
- Complexity Warning: PBR adds significant troubleshooting overhead
Route Leaking vs. Firewall
- Current State: All inter-VRF traffic traverses firewall
- Challenge: Route leaking with multi-site and application-centric design is complex
- Recommendation: Continue using firewall for inter-VRF communication until ESG support is available
6. L3Out Optimization
Current Configuration
- Multiple L3Outs per VRF
- All connecting to different firewall contexts
Optimization Opportunity
- Consolidate L3Outs where possible
- Simplify firewall context design
- Reduce configuration overhead

Recommendations Summary
Immediate Actions
- Maintain single tenant architecture unless clear administrative separation is required
- Document application dependencies and create EPG mapping
- Evaluate VMM integration benefits with stakeholders
- Defer ESG implementation until NDO support is available (June/July 2025)
Design Decisions
- Tenant Structure: Single tenant with multiple VRFs
- Bridge Domain Strategy: Choose between service-based or application-based approach
- Security Policy: Start with vzAny, implement contracts based on requirements
- Inter-VRF Communication: Continue using firewall (no route leaking)
- Service Graph/PBR: Do not implement unless specific EPG-to-EPG firewall requirement exists
Future Considerations
- ESG Migration: Plan for ESG implementation once NDO support is available
- Application Dependency Mapping: Consider CSW or alternative tools
- Automation: Evaluate Terraform or Ansible for configuration management
- L3Out Consolidation: Review and optimize firewall connectivity

Technical Resources
API and Automation
- NDO Developer Guide: Available through Help Center → Programming and Developer Guide
- Automation Tools Available:
  - Ansible collections for Nexus Dashboard
  - Terraform collections for NDO
  - REST API documentation and examples
  - Postman collections for common operations
Key Technical Constraints
- ESG not currently supported in multi-site deployments
- Route leaking complexity increases with:
  - Application-centric design
  - Multi-site deployment
  - EPG-based policies
- CSW or similar tool recommended for application dependency discovery

Next Steps
- Review tenant structure decision with stakeholders
- Create application inventory and EPG mapping
- Schedule VMM integration discussion with virtualization team
- Monitor ESG feature release schedule
- Develop migration timeline based on equipment delivery
- Consider engaging Cisco CX services for implementation support

Meeting Notes
Additional Context:
- Organization is receiving new equipment, making this an optimal time for redesign
- DoD zero-trust architecture considerations are relevant but don't necessitate EPG-to-EPG firewalling
- Most VRFs are extended between sites in the multi-site deployment
- Current pain point: Difficulty mapping EPGs to applications without proper discovery tools
Follow-up Items:
- Share Postman collection for NDO automation
- Discuss potential for CX services engagement
- Review application-centric deployment examples from similar deployments

Document prepared from technical discussion between ACI architecture team members
