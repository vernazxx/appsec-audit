# OWASP Cheat Sheet Series: what to pull, by what you find

Base URL: `https://cheatsheetseries.owasp.org/cheatsheets/<Name>_Cheat_Sheet.html`.
Cite the specific cheat sheet in each finding's remediation. Always start with
**Secure_Code_Review** and **Threat_Modeling** for method.

## By language / framework

| Stack | Cheat sheets |
|---|---|
| Go | Input_Validation, Error_Handling, Transport_Layer_Security (no Go-specific sheet; also https://go.dev/doc/security/best-practices) |
| Node.js / TypeScript | Nodejs_Security, JavaScript_and_TypeScript_Security, NPM_Security, Prototype_Pollution_Prevention, NodeJS_Docker |
| Next.js | Nextjs_Security |
| Python / Django / DRF / FastAPI | Django_Security, Django_REST_Framework, FastAPI_Security, Deserialization |
| Java | Java_Security, Injection_Prevention_in_Java, Bean_Validation, JAAS |
| .NET | DotNet_Security |
| PHP / Laravel / Symfony | PHP_Configuration, Laravel, Symfony |
| Ruby on Rails | Ruby_on_Rails |
| C / C++ toolchain | C-Based_Toolchain_Hardening |
| Mobile | Mobile_Application_Security, Pinning |

## By feature

| Feature in the code | Cheat sheets |
|---|---|
| HTTP server / responses | HTTP_Headers, Content_Security_Policy, HTTP_Strict_Transport_Security, Clickjacking_Defense, Web_Cache_Security |
| HTTP client fetching user URLs | Server_Side_Request_Forgery_Prevention, Denial_of_Service |
| REST / GraphQL / gRPC / WebSocket | REST_Security, REST_Assessment, GraphQL, gRPC_Security, WebSocket_Security, Web_Service_Security |
| Login / sessions / MFA / reset | Authentication, Session_Management, Multifactor_Authentication, Forgot_Password, Credential_Stuffing_Prevention, Passkey_Security |
| Authorization | Authorization, Access_Control, Authorization_Patterns, Insecure_Direct_Object_Reference_Prevention, Multi_Tenant_Security |
| OAuth / OIDC / SAML / JWT | OAuth2, SAML_Security, JSON_Web_Token, Workload_Identity_Federation |
| Database | SQL_Injection_Prevention, Query_Parameterization, Database_Security, NoSQL_Security |
| Templates / HTML output | Cross_Site_Scripting_Prevention, DOM_based_XSS_Prevention, Server_Side_Template_Injection_Prevention, HTML5_Security |
| File upload / paths | File_Upload, Input_Validation |
| Shell / subprocess | OS_Command_Injection_Defense |
| XML | XML_External_Entity_Prevention, XML_Security |
| Crypto / secrets / keys | Cryptographic_Storage, Password_Storage, Key_Management, Secrets_Management, Post_Quantum_Cryptography |
| Logging | Logging, Logging_Vocabulary |
| Errors | Error_Handling |
| Webhooks | Webhook_Security |
| Payments | Third_Party_Payment_Gateway_Integration, Transaction_Authorization |
| LLM / agents / MCP / RAG | LLM_Prompt_Injection_Prevention, AI_Agent_Security, MCP_Security, RAG_Security, Secure_Coding_with_AI |
| Containers / K8s / IaC / cloud | Docker_Security, Kubernetes_Security, Infrastructure_as_Code_Security, Secure_Cloud_Architecture, Serverless_FaaS_Security |
| CI/CD / dependencies | CI_CD_Security, GitHub_Actions_Security, Software_Supply_Chain_Security, Vulnerable_Dependency_Management, Dependency_Graph_SBOM |
| Microservices | Microservices_Security, Network_Segmentation, Zero_Trust_Architecture |
| Privacy | User_Privacy_Protection |
