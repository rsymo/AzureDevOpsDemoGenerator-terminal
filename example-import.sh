#!/bin/bash

# Example: Import Azure DevOps templates using the local import script
# This script shows different ways to use the import-ado-template.sh script

echo "=========================================="
echo "Azure DevOps Template Import Examples"
echo "=========================================="
echo ""

# Set your credentials (DO NOT commit these to version control!)
export ADO_ORG="your-org-name"
export ADO_PAT="your-personal-access-token-here"

# Method 1: List available templates
echo "Method 1: List all available templates"
echo "======================================"
./import-ado-template.sh --list
echo ""

# Method 2: Import with full features (recommended)
echo "Method 2: Complete import with all features"
echo "============================================"
echo "This will import:"
echo "  ✅ Project and iterations"
echo "  ✅ Work items (assigned to sprints)"
echo "  ✅ Source code (if accessible)"
echo "  ✅ Dashboards"
echo "  ✅ Queries"
echo "  ℹ️  Pipeline/Test Plan info (manual setup)"
echo ""

# Uncomment to run:
# ./import-ado-template.sh \
#   --name "ContosoShuttle" \
#   --template "ContosoShuttle2" \
#   --yes

# Method 3: Import PartsUnlimited (has accessible source code)
echo "Method 3: Import PartsUnlimited"
echo "==============================="
echo "PartsUnlimited includes working source code!"
echo ""

# Uncomment to run:
# ./import-ado-template.sh \
#   -n "PartsUnlimited" \
#   -t "Gen-PartsUnlimited" \
#   -y

# Method 4: Interactive mode
echo "Method 4: Interactive mode"
echo "=========================="
echo "Just run the script without arguments:"
echo "./import-ado-template.sh"
echo ""
echo "It will prompt you for all required information."

# Method 5: Using environment variables (Recommended for automation)
echo ""
echo "Method 5: Environment variables"
echo "==============================="
cat << 'EOF'
export ADO_ORG="your-org"
export ADO_PAT="your-pat"

./import-ado-template.sh \
  --name "MyProject" \
  --template "ContosoShuttle2" \
  --yes
EOF

echo ""
echo "=========================================="
echo "Popular Templates to Try:"
echo "=========================================="
echo "  • ContosoShuttle2    - Shuttle booking app"
echo "  • Gen-PartsUnlimited - E-commerce demo (has source code!)"
echo "  • DL-Docker          - Docker demos"
echo "  • DL-Python          - Python app demos"
echo ""
echo "Run './import-ado-template.sh --list' to see all 71+ templates!"
