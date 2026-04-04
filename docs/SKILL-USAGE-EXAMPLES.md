# Skill Usage Examples

> **Purpose**: Real-world usage scenarios and examples for all Skills in Skill-Hub
>
> **Note**: Skills are designed for AI Agents to read and execute. These examples help users understand what Skills can do.

---

## Table of Contents

- [Environment Configuration Skills](#environment-configuration-skills)
- [ServiceNow Skills](#servicenow-skills)
- [Software Center Skills](#software-center-skills)
- [Complete Workflows](#complete-workflows)

---

## Environment Configuration Skills

### env-configure-java

**Scenario**: New employee needs to set up Java development environment

**Before**:
```
User: "I just installed Java JDK but my IDE can't find it"
Problem: JAVA_HOME not configured, Java not in PATH
```

**After**:
```
User: "Help me configure Java environment"
AI: [Uses env-configure-java skill]
      1. Detects Java installation path
      2. Sets JAVA_HOME environment variable
      3. Adds Java to PATH
      4. Verifies configuration
Result: "Java environment configured successfully. JAVA_HOME set to C:\Program Files\Java\jdk-17"
```

**Related Skills**: `env-configure-maven`, `env-configure-gradle`

---

### env-configure-maven

**Scenario**: Developer needs Maven for Java project builds

**Before**:
```
User: "I installed Maven but 'mvn' command not found"
Problem: MAVEN_HOME not set, Maven bin not in PATH
```

**After**:
```
User: "Configure Maven for me"
AI: [Uses env-configure-maven skill]
      1. Checks JAVA_HOME prerequisite
      2. Detects Maven installation
      3. Sets MAVEN_HOME environment variable
      4. Adds Maven bin to PATH
      5. Verifies with mvn --version
Result: "Maven configured successfully. You can now run 'mvn --version'"
```

**Prerequisites**: `env-configure-java` must be configured first

**Related Skills**: `env-configure-java`, `env-configure-nexus`

---

### env-configure-nodejs

**Scenario**: Frontend developer needs Node.js environment

**Before**:
```
User: "I installed Node.js but npm command doesn't work"
Problem: Node.js not in PATH
```

**After**:
```
User: "Set up Node.js environment"
AI: [Uses env-configure-nodejs skill]
      1. Detects Node.js installation
      2. Adds Node.js and npm to PATH
      3. Verifies node --version and npm --version
Result: "Node.js environment configured. Node v18.17.0 and npm 9.6.7 are now available"
```

**Related Skills**: `env-configure-npm`, `env-configure-pnpm`

---

### env-configure-python

**Scenario**: Data scientist needs Python for machine learning projects

**Before**:
```
User: "Python installed but 'python' is not recognized"
Problem: Python not in PATH
```

**After**:
```
User: "Configure Python environment"
AI: [Uses env-configure-python skill]
      1. Detects Python installation
      2. Adds Python and pip to PATH
      3. Verifies python --version and pip --version
Result: "Python environment configured. Python 3.11.4 is now available"
```

**Related Skills**: `env-configure-pip`

---

### env-configure-git

**Scenario**: New developer needs Git configured for version control

**Before**:
```
User: "Every time I commit, Git asks for username and email"
Problem: Git user.name and user.email not configured
```

**After**:
```
User: "Set up Git configuration"
AI: [Uses env-configure-git skill]
      1. Sets global user.name
      2. Sets global user.email
      3. Verifies configuration
Result: "Git configured with your name and email. You can now commit without specifying credentials"
```

**Related Skills**: `env-configure-gh`

---

### env-configure-npm

**Scenario**: Developer needs to use internal npm registry

**Before**:
```
User: "npm install is very slow"
Problem: Using public npm registry instead of internal Nexus
```

**After**:
```
User: "Configure npm to use internal registry"
AI: [Uses env-configure-npm skill]
      1. Sets npm registry to internal Nexus URL
      2. Verifies configuration
Result: "npm registry configured to use internal Nexus mirror. Installation speed improved"
```

**Related Skills**: `env-configure-nodejs`, `env-configure-pnpm`

---

### env-configure-pnpm

**Scenario**: Project requires pnpm package manager

**Before**:
```
User: "I need to use pnpm but it's not configured"
Problem: pnpm registry not set
```

**After**:
```
User: "Configure pnpm for me"
AI: [Uses env-configure-pnpm skill]
      1. Sets pnpm registry to internal Nexus URL
      2. Verifies configuration
Result: "pnpm registry configured to use internal Nexus mirror"
```

**Related Skills**: `env-configure-nodejs`, `env-configure-npm`

---

### env-configure-gradle

**Scenario**: Java developer needs Gradle build tool

**Before**:
```
User: "Gradle command not found after installation"
Problem: GRADLE_HOME not set, Gradle not in PATH
```

**After**:
```
User: "Set up Gradle environment"
AI: [Uses env-configure-gradle skill]
      1. Checks JAVA_HOME prerequisite
      2. Detects Gradle installation
      3. Sets GRADLE_HOME environment variable
      4. Adds Gradle bin to PATH
      5. Verifies with gradle --version
Result: "Gradle environment configured successfully"
```

**Prerequisites**: `env-configure-java` must be configured first

**Related Skills**: `env-configure-java`, `env-configure-maven`

---

### env-configure-gh

**Scenario**: Developer needs GitHub CLI for Git operations

**Before**:
```
User: "I want to use GitHub CLI but it's not configured"
Problem: GitHub CLI needs authentication and host configuration
```

**After**:
```
User: "Configure GitHub CLI"
AI: [Uses env-configure-gh skill]
      1. Checks Git configuration prerequisite
      2. Authenticates with GitHub
      3. Configures GitHub host
      4. Verifies with gh --version
Result: "GitHub CLI configured. You can now use 'gh' commands"
```

**Prerequisites**: `env-configure-git` should be configured first

**Related Skills**: `env-configure-git`

---

### env-configure-path

**Scenario**: User needs to add custom tool to PATH

**Before**:
```
User: "I installed a CLI tool but can't run it from anywhere"
Problem: Tool's bin directory not in PATH
```

**After**:
```
User: "Add this tool to my PATH: C:\Tools\MyCLI\bin"
AI: [Uses env-configure-path skill]
      1. Validates the provided path exists
      2. Adds path to user PATH environment variable
      3. Verifies configuration
Result: "Path configured. You can now run MyCLI commands from any directory"
```

**Related Skills**: Any `env-configure-*` skill for specific tools

---

## ServiceNow Skills

### sn-request-software

**Scenario**: Employee needs to install software that requires approval

**Before**:
```
User: "I need to install Java on my machine"
Process: Find ServiceNow portal → Find software request form → Fill form → Wait for approval
Time: 15-30 minutes to submit request
```

**After**:
```
User: "I need Java installed"
AI: [Uses sn-request-software skill]
      1. Gathers required information (software name, applicant, reason)
      2. Checks for existing requests
      3. Navigates to ServiceNow portal
      4. Submits software request
      5. Provides ticket number and timeline
Result: "Software request submitted. Ticket #REQ0012345. Approval takes 1-2 business days. You'll receive email notification"
```

**Next Step**: After approval, use `swc-install-package` to install

**Related Skills**: `swc-install-package`, `sn-request-ad-group`

---

### sn-request-ad-group

**Scenario**: Employee needs access to internal systems

**Before**:
```
User: "I need access to the production deployment system"
Process: Find AD group request form → Fill justification → Submit → Wait for approval
```

**After**:
```
User: "I need access to production deployment"
AI: [Uses sn-request-ad-group skill]
      1. Identifies required AD group
      2. Gathers applicant information and justification
      3. Checks for existing requests
      4. Submits AD group request via ServiceNow
      5. Provides ticket number
Result: "AD group request submitted. Ticket #REQ0012346. Approval takes 2-3 business days"
```

**Related Skills**: `sn-request-software`

---

## Software Center Skills

### swc-install-package

**Scenario**: Employee needs to install approved software

**Before**:
```
User: "My Java request was approved, now I need to install it"
Process: Open Software Center → Search for Java → Click Install → Wait
Time: 5-10 minutes
```

**After**:
```
User: "Install Java (my request was approved)"
AI: [Uses swc-install-package skill]
      1. Verifies request approval status
      2. Opens Software Center
      3. Locates Java package
      4. Initiates installation
      5. Monitors installation progress
      6. Verifies installation
      7. Suggests env-configure-java if needed
Result: "Java installed successfully. Would you like me to configure the environment variables next?"
```

**Prerequisites**: Software request must be approved via `sn-request-software`

**Related Skills**: `sn-request-software`, `env-configure-java`

---

## Complete Workflows

### Workflow 1: Complete Java Installation

**User Request**: "Help me install Java"

**AI Orchestration**:
```
Step 1: Check if Java is already installed
        → No, Java not found

Step 2: Check if software request exists
        → No approved request found

Step 3: [sn-request-software] Submit ServiceNow request
        → Ticket #REQ0012345 submitted
        → Inform user: "Request submitted, waiting for approval (1-2 business days)"

[Wait for approval - user returns after 2 days]

Step 4: Check request status
        → Approved! Software available in Software Center

Step 5: [swc-install-package] Install Java via Software Center
        → Java installed successfully

Step 6: [env-configure-java] Configure Java environment variables
        → JAVA_HOME set, PATH updated

Step 7: Verify installation
        → Run java -version → Java 17.0.8

Final Result: "Java 17.0.8 has been installed and configured. You can now use Java development tools"
```

**Skills Used**: `sn-request-software` → `swc-install-package` → `env-configure-java`

---

### Workflow 2: Complete Maven Setup

**User Request**: "I need Maven for my Java project"

**AI Orchestration**:
```
Step 1: Check prerequisites
        → JAVA_HOME configured? Yes
        → Maven installed? No

Step 2: Check if Maven request exists
        → No approved request found

Step 3: [sn-request-software] Submit Maven request
        → Ticket #REQ0012347 submitted
        → Wait for approval

[After approval]

Step 4: [swc-install-package] Install Maven
        → Maven installed successfully

Step 5: [env-configure-maven] Configure Maven environment
        → MAVEN_HOME set, PATH updated
        → Verified with mvn --version

Final Result: "Apache Maven 3.9.4 configured. You can now build your Java projects with 'mvn clean install'"
```

**Skills Used**: `sn-request-software` → `swc-install-package` → `env-configure-maven`

**Prerequisites**: `env-configure-java` must be completed first

---

### Workflow 3: Frontend Development Setup

**User Request**: "Set up my frontend development environment"

**AI Orchestration**:
```
Step 1: Check Node.js installation
        → Node.js not installed

Step 2: [sn-request-software] Request Node.js
        → Ticket submitted, wait for approval

[After approval]

Step 3: [swc-install-package] Install Node.js
        → Node.js and npm installed

Step 4: [env-configure-nodejs] Configure Node.js environment
        → PATH configured, verified node and npm versions

Step 5: [env-configure-npm] Configure internal npm registry
        → Registry set to internal Nexus mirror

Step 6: [env-configure-git] Configure Git (if not already configured)
        → Git user.name and user.email set

Step 7: [env-configure-gh] Configure GitHub CLI (optional)
        → GitHub authentication configured

Final Result: "Frontend development environment ready:
- Node.js v18.17.0 with npm 9.6.7
- Internal npm registry configured for faster installs
- Git configured with your credentials
- GitHub CLI ready for use"
```

**Skills Used**: `sn-request-software` → `swc-install-package` → `env-configure-nodejs` → `env-configure-npm` → `env-configure-git` → `env-configure-gh`

---

### Workflow 4: New Employee Onboarding

**User Request**: "I'm a new developer, set up everything I need"

**AI Orchestration**:
```
Phase 1: Access Requests (Day 1)
- [sn-request-software] Request development tools (Java, Node.js, IDE)
- [sn-request-ad-group] Request access to Git repositories, CI/CD, deployment systems
- Inform user of approval timelines

Phase 2: Software Installation (After approvals, Day 2-3)
- [swc-install-package] Install all approved software
- Track installation progress for each tool

Phase 3: Environment Configuration (Day 3)
- [env-configure-java] Configure Java
- [env-configure-maven] Configure Maven
- [env-configure-nodejs] Configure Node.js
- [env-configure-npm] Configure npm registry
- [env-configure-git] Configure Git
- [env-configure-gh] Configure GitHub CLI
- [env-configure-path] Add any additional tools to PATH

Phase 4: Verification (Day 3)
- Verify all tools are installed and configured
- Run version checks for each tool
- Provide summary report

Final Result: "Development environment setup complete:
✓ Java 17.0.8 with Maven 3.9.4
✓ Node.js 18.17.0 with npm 9.6.7
✓ Git configured with your credentials
✓ GitHub CLI authenticated
✓ All internal registries configured
You're ready to start development!"
```

**Skills Used**: Multiple skills across multiple days, orchestrated by AI based on approval status and dependencies

---

## Key Benefits

### Before Skill-Hub
- **Time**: 2-4 hours to set up development environment
- **Effort**: Manual searching, form filling, configuration
- **Errors**: Misconfiguration common, especially for new employees
- **Knowledge**: Tribal knowledge, repeated questions

### After Skill-Hub
- **Time**: 15-30 minutes of user time (AI does the work)
- **Effort**: One natural language request
- **Errors**: AI follows Skills precisely, idempotent configuration
- **Knowledge**: Encoded in Skills, reusable by all employees

---

## For AI Agents

**How to Use These Examples**:

1. **Understand Intent**: These examples show common user requests and which Skills to use
2. **Learn Orchestration**: See how multiple Skills combine to complete complex tasks
3. **Handle Dependencies**: Understand prerequisite relationships between Skills
4. **Communicate Clearly**: Examples show how to inform users at each step

**Remember**: 
- Skills are atomic capabilities
- AI handles orchestration based on context
- Always check prerequisites before using a Skill
- Be idempotent - check first, configure only if needed
- Inform users clearly at every step

---

**Document Version**: 1.0.0  
**Last Updated**: 2026-04-04  
**Maintained By**: Skill-Hub Team
