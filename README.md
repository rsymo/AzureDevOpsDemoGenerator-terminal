# Azure DevOps Template Importer

A powerful command-line tool that imports complete Azure DevOps demo projects from 71+ pre-built templates. Perfect for demos, training, testing, and exploring Azure DevOps features.

## ✨ Features

**Fully Automated Import:**
- ✅ Projects & sprints with dates
- ✅ Work items (Epics, Features, Tasks, Bugs)
- ✅ Source code with Git history
- ✅ Branches & pull requests
- ✅ YAML pipelines (auto-created)
- ✅ Dashboards
- ✅ Wiki pages
- ✅ Work item queries

**71+ Templates Including:**
- ContosoShuttle2, Gen-PartsUnlimited
- Docker, Python, Node.js demos
- Cloud Adoption Framework templates
- And many more!

## Quick Start

```bash
# 1. Login to Azure CLI (one-time setup)
az login

# 2. List templates
./import-ado-template.sh --list

# 3. Import a template
export ADO_ORG="your-org"
./import-ado-template.sh -n "MyProject" -t "Gen-PartsUnlimited" -y
```

## Prerequisites

- **macOS** (tested on modern versions)
- **Azure CLI** - Install from [https://aka.ms/azure-cli](https://aka.ms/azure-cli)
- **Git, curl, jq** - Pre-installed on macOS
- **Azure DevOps organization**
- **Azure CLI logged in** - Run `az login`

See [example-import.sh](example-import.sh) for more usage examples.

## What Gets Created

Each import creates a complete Azure DevOps project with:
- Work items assigned to 6 sprints (with dates for velocity tracking)
- Source code repository
- Feature branches and open pull requests
- YAML pipelines (automatically created and run)
- Project dashboard
- Wiki with documentation
- Work item queries

## Documentation

For full documentation, see the example script and run `--help`:

```bash
./import-ado-template.sh --help
```

## 📦 Recommended Templates (verified working)

These templates were verified with an anonymous `git ls-remote` and their source
repositories still clone without credentials. `--list` shows only templates in
this verified set.

The richest ones for generating a lot of data:

| Template | Work Items | Source | Builds | Releases | Wiki | Dashboard | Queries | Test Plans | PRs |
|----------|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| **Gen-PartsUnlimited** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Gen-eShopOnWeb** | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ | ✅ | ❌ |
| **Gen-MyShuttle** | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ |
| **Gen-PartsUnlimited-YAML** | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **DL-AKS** | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ |
| **DL-Docker** | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ |
| **DL-ReleaseGates** | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ |
| **DL-SonarQube** | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ |

Also verified and available: `DL-Ansible`, `DL-AzureFunctions`,
`DL-DeploymentGroups`, `DL-Keyvault`, `DL-LaunchDarkly`, `DL-MachineLearning`,
`DL-Octopus`, `DL-PHP`, `DL-Python`, `DL-Selenium`, `DL-Terraform`,
`DL-WhiteSource-Bolt`.

Public GitHub-backed templates:

| Template | Repository | Description |
|----------|-----------|-------------|
| **FA-IAC-migration** | [GitHub](https://github.com/amillerb/fta-live-devops-iac-migration-src) | Infrastructure as Code migration patterns |
| **Gen-Tailwind Traders** | [Backend](https://github.com/Microsoft/TailwindTraders-Backend) / [Website](https://github.com/Microsoft/TailwindTraders-Website) | E-commerce demo application (the third, ADO-hosted repo is gone) |
| **MSL-Test-bicep** | [GitHub](https://github.com/MicrosoftDocs/mslearn-test-bicep-code-using-azure-pipelines) | Testing Bicep code with pipelines |
| **MSL-Toy-reusable** | [GitHub](https://github.com/MicrosoftDocs/mslearn-publish-reusable-bicep-code-using-azure-pipelines) | Publishing reusable Bicep modules |
| **MSL-manage-end-end-deployment-scenarios** | [GitHub](https://github.com/MicrosoftDocs/mslearn-manage-end-end-deployment-scenarios-using-bicep-azure-pipelines) | End-to-end Bicep deployments |
| **Manage-multiple-environments-azure-pipelines** | [GitHub](https://github.com/MicrosoftDocs/mslearn-manage-multiple-environments-using-bicep-azure-pipelines) | Multi-environment Bicep workflows |

## 🗄️ Archived Templates

45 of the original 71 templates point at source repositories that are no longer
publicly reachable. The hosting organization was deleted, made private, or now
requires a login. Importing one of these produces a project with work items but
no source code, branches, pull requests, or pipelines.

These are listed in [`templates-archive.txt`](templates-archive.txt) and are
hidden from `--list`. They remain importable if you name one explicitly with
`-t`, and the script prints a warning first.

```bash
# Show archived templates too
./import-ado-template.sh --list-all
```

## 📋 Complete Template Feature Matrix

<details>
<summary><b>Click to expand - All 71 Templates with Feature Comparison</b></summary>

> Note: the "Repo Access" column below is inherited from the original project
> and reflects where a repo is hosted, not whether it is still reachable. See
> `templates-archive.txt` for the current verified status.

| Template | Work Items | Source Code | Builds | Releases | Wiki | Dashboard | Queries | Test Plans | PRs | Repo Access |
|----------|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| **AC-AzureSentinel** | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | 🔒 Private |
| **AC-NIST800171Rev2** | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | 🔒 Private |
| **AC-SapOnAzure** | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | 🔒 Private |
| **AC-WVDGuidance** | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | 🔒 Private |
| **CAF-ADO-Strategy-Plan-Ready-Governance** | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | 🔒 Private |
| **CAF-AKS_CAF** | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | 🔒 Private |
| **CAF-AzureGovernance** | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | 🔒 Private |
| **CAF-CloudAdoptionPlan** | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | 🔒 Private |
| **CAF-KnowledgeMining** | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | 🔒 Private |
| **CAF-ModernDataAnalytics** | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | 🔒 Private |
| **CAF-ModernDataWarehouse** | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | 🔒 Private |
| **CAF-ModernIOT** | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | 🔒 Private |
| **CAF-RetailRecommender-SolutionAccelerator** | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | 🔒 Private |
| **CAF-SQL_Migration** | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | 🔒 Private |
| **CAF-SecureResearch** | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | 🔒 Private |
| **CAF-ServerMigration** | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | 🔒 Private |
| **CAF-UnifiedDataGovernance** | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | 🔒 Private |
| **CAF-WindowsVirtualDesktop** | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | 🔒 Private |
| **ContosoShuttle / ContosoShuttle2** | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | 🔒 Private |
| **DL-AKS** | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ | 🔒 Private |
| **DL-Ansible** | ❌ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | 🔒 Private |
| **DL-AzureFunctions** | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | 🔒 Private |
| **DL-DeploymentGroups** | ❌ | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ | 🔒 Private |
| **DL-Docker** | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ | 🔒 Private |
| **DL-GitHub** | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ | 🔒 Private |
| **DL-Keyvault** | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | 🔒 Private |
| **DL-LaunchDarkly** | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | 🔒 Private |
| **DL-MachineLearning** | ❌ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | 🔒 Private |
| **DL-Octopus** | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | 🔒 Private |
| **DL-PHP** | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ | 🔒 Private |
| **DL-Python** | ❌ | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ | 🔒 Private |
| **DL-ReleaseGates** | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ | 🔒 Private |
| **DL-Selenium** | ❌ | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ | 🔒 Private |
| **DL-SonarQube** | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | 🔒 Private |
| **DL-Terraform** | ❌ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | 🔒 Private |
| **DL-WhiteSource-Bolt** | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | 🔒 Private |
| **DoJoWhiteBeltGold** | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | 🔒 Private |
| **FA-IAC-migration** | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ **Public** |
| **Gen-ContosoAir** | ✅ | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | N/A |
| **Gen-MyHealthClinic** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ | 🔒 Private |
| **Gen-MyShuttle** | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ | 🔒 Private |
| **Gen-PartsUnlimited** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | 🔒 Private |
| **Gen-PartsUnlimited-YAML** | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | 🔒 Private |
| **Gen-SmartHotel360** | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ | ✅ | ✅ | 🔒 Private |
| **Gen-Tailwind Traders** | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ **Public** |
| **Gen-eShopOnWeb** | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ | ✅ | ❌ | 🔒 Private |
| **MSL-Create-Build-Pipeline** | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | 🔒 Private |
| **MSL-Deploy-Docker-Template** | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | 🔒 Private |
| **MSL-Deploy-Kubernetes-Template** | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | 🔒 Private |
| **MSL-Host-Build-Agent** | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | 🔒 Private |
| **MSL-Implement-Code-Workflow** | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | 🔒 Private |
| **MSL-Manage-Build-Dependencies** | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | 🔒 Private |
| **MSL-Review-azure-infrastructure-changes** | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ **Public** |
| **MSL-Run-Quality-Tests** | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | 🔒 Private |
| **MSL-Scan-Open-Source** | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | 🔒 Private |
| **MSL-Scan-for-Vulnerabilities** | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | 🔒 Private |
| **MSL-SpaceGame-*** (12 templates) | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | 🔒 Private |
| **MSL-Test-bicep** | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ **Public** |
| **MSL-Toy-reusable** | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ **Public** |
| **MSL-manage-end-end-deployment-scenarios** | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ **Public** |
| **Manage-multiple-environments-azure-pipelines** | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ **Public** |

</details>

### Legend:
- ✅ = Feature included in template
- ❌ = Feature not included
- 🔒 Private = Requires access to private Azure DevOps org
- ✅ **Public** = Public GitHub repository (fully accessible)
- N/A = No source code repository defined

### Repository Access Notes:

**Work without source code:**
All templates work fine without source code access. The script creates full project structure (work items, sprints, dashboards, wiki). You can push your own code to the created repositories.

## Credits

Templates sourced from [Azure DevOps Demo Generator](https://azuredevopsdemogenerator.azurewebsites.net/)
