# Quick Reference - Azure DevOps Template Importer

## Setup (One Time)

```bash
# Install Azure CLI (if needed)
brew install azure-cli

# Login to Azure
az login
```

## Basic Usage

```bash
# Set organization
export ADO_ORG="your-org-name"

# List all templates
./import-ado-template.sh --list

# Import a template (interactive)
./import-ado-template.sh

# Import with auto-confirm
./import-ado-template.sh -n "ProjectName" -t "TemplateName" -y

# Import into a compatible, effectively empty project
./import-ado-template.sh -n "ProjectName" -t "TemplateName" --use-existing -y
```

## Popular Templates

```bash
# General demos
-t "ContosoShuttle2"      # Best for Agile/Scrum demos
-t "Gen-PartsUnlimited"   # Full-featured e-commerce (private repo)

# DevOps Learning
-t "DL-Docker"            # Docker/Container workflows
-t "DL-Python"            # Python application
-t "DL-Terraform"         # Infrastructure as Code

# Public GitHub repos (fully accessible)
-t "Gen-Tailwind Traders" # E-commerce with public code
-t "FA-IAC-migration"     # IaC migration patterns
-t "MSL-Test-bicep"       # Bicep testing
```

## Common Commands

```bash
# Check Azure CLI status
az account show

# Refresh login
az login

# View help
./import-ado-template.sh --help

# Debug mode
DEBUG=1 ./import-ado-template.sh -n "Test" -t "ContosoShuttle2"
```

## What Gets Created

Each import creates:
- ✅ Azure DevOps project
- ✅ 6 sprints with dates configured
- ✅ Work items (Epics, Features, Tasks, Bugs)
- ✅ Git repository
- ✅ Branches and Pull Requests
- ✅ YAML pipelines (auto-created)
- ✅ Dashboard
- ✅ Wiki pages
- ✅ Work item queries

## Troubleshooting

```bash
# Not logged in?
az login

# Wrong organization?
export ADO_ORG="correct-org-name"

# Token expired?
az login  # Re-authenticate

# HTTP 401 / TF400813?
az account show --query user.name -o tsv
az logout
az login --allow-no-subscriptions
# The signed-in identity must also be a member of the Azure DevOps organization.

# Template not found?
./import-ado-template.sh --list  # Check exact name

# Existing project rejected?
# Confirm its process matches the template and that it has no work items,
# committed repository content, extra repositories, builds, or wiki.
```

## Authentication

✅ **Uses Azure CLI** - No PAT needed!
- Tokens auto-refresh
- More secure
- No credentials in code

## File Locations

```
AzureDevOpsDemoGenerator-terminal/
├── import-ado-template.sh     # Main script
├── example-import.sh           # Usage examples
├── README.md                   # Full documentation
├── MIGRATION_GUIDE.md          # PAT to Azure CLI migration
└── AzureDevOpsDemoGenerator-original/
    └── src/VstsDemoBuilder/Templates/  # 71+ templates
```

## Examples

```bash
# Quick import
export ADO_ORG="myorg"
./import-ado-template.sh -n "Demo$(date +%s)" -t "ContosoShuttle2" -y

# With specific org
./import-ado-template.sh -o "myorg" -n "TestProject" -t "DL-Docker" -y

# Reuse an existing compatible, effectively empty project
./import-ado-template.sh -o "myorg" -n "TestProject" -t "DL-Docker" --use-existing -y

# Interactive mode (asks for inputs)
./import-ado-template.sh
```

## Access Your Project

After import completes:
```
https://dev.azure.com/YOUR-ORG/YOUR-PROJECT
```

## Resources

- Templates: 71+ available
- Source: [Azure DevOps Demo Generator](https://azuredevopsdemogenerator.azurewebsites.net/)
- Azure CLI: [https://aka.ms/azure-cli](https://aka.ms/azure-cli)

---

**Pro Tip**: Add timestamp to project names to avoid conflicts:
```bash
./import-ado-template.sh -n "Demo$(date +%s)" -t "ContosoShuttle2" -y
```
