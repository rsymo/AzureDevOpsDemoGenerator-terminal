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
# List templates
./import-ado-template.sh --list

# Import a template
export ADO_ORG="your-org"
export ADO_PAT="your-pat"
./import-ado-template.sh -n "MyProject" -t "Gen-PartsUnlimited" -y
```

## Prerequisites

- macOS
- Git, curl, jq (pre-installed on macOS)
- Azure DevOps organization
- Personal Access Token with Full Access

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

## Credits

Templates sourced from [Azure DevOps Demo Generator](https://azuredevopsdemogenerator.azurewebsites.net/)
