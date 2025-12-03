#!/bin/bash

# Azure DevOps Template Importer
# This script imports sample data from local template files directly into Azure DevOps
# using Azure CLI for authentication (more secure than PAT)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
ADO_API_VERSION_STABLE="7.1"
ADO_API_VERSION_PREVIEW="7.1-preview.4"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TEMPLATES_DIR="$SCRIPT_DIR/AzureDevOpsDemoGenerator-original/src/VstsDemoBuilder/Templates"

# Print functions
print_info() { echo -e "${BLUE}ℹ ${NC}$1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_header() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
}

# Function to check Azure CLI login
check_az_login() {
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed. Please install it from: https://aka.ms/azure-cli"
        exit 1
    fi
    
    if ! az account show &> /dev/null; then
        print_error "Not logged in to Azure CLI. Please run 'az login' first."
        exit 1
    fi
    
    print_success "Azure CLI authentication verified"
}

# Function to get Azure CLI access token
get_az_token() {
    local token=$(az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv 2>/dev/null)
    if [ -z "$token" ]; then
        print_error "Failed to get Azure DevOps access token. Please run 'az login' first."
        exit 1
    fi
    echo "$token"
}

# Function to call Azure DevOps REST API
call_ado_api() {
    local method=$1
    local url=$2
    local data=$3
    local token=$4
    local content_type=${5:-"application/json"}
    
    # Debug: show the URL being called (only in verbose mode)
    if [ "${DEBUG:-0}" = "1" ]; then
        echo "DEBUG: $method $url" >&2
    fi
    
    local auth_header="Authorization: Bearer $token"
    
    # Create temp files for response
    local temp_response=$(mktemp)
    local temp_status=$(mktemp)
    
    if [ -z "$data" ]; then
        curl -s -w "%{http_code}" -o "$temp_response" -X "$method" \
            -H "$auth_header" \
            -H "Content-Type: $content_type" \
            "$url" > "$temp_status"
    else
        curl -s -w "%{http_code}" -o "$temp_response" -X "$method" \
            -H "$auth_header" \
            -H "Content-Type: $content_type" \
            -d "$data" \
            "$url" > "$temp_status"
    fi
    
    # Get the HTTP status code and response body
    local http_code=$(cat "$temp_status")
    local response_body=$(cat "$temp_response")
    
    # Clean up temp files
    rm -f "$temp_response" "$temp_status"
    
    # Check for HTTP errors
    if [ "$http_code" -ge 400 ]; then
        if [ "${DEBUG:-0}" = "1" ]; then
            echo "DEBUG: Response: $response_body" >&2
        fi
        # Try to extract JSON error message, fallback to showing response body
        local error_msg=$(echo "$response_body" | jq -r '.message // empty' 2>/dev/null)
        if [ ! -z "$error_msg" ]; then
            echo "ERROR: HTTP $http_code - $error_msg" >&2
        else
            echo "ERROR: HTTP $http_code" >&2
        fi
        echo "$response_body"
        return 1
    fi
    
    echo "$response_body"
}

# Function to create Azure DevOps project
create_project() {
    local org=$1
    local project_name=$2
    local description=$3
    local process_template=$4
    local token=$5
    
    print_info "Creating project '$project_name'..."
    
    local payload=$(cat <<EOF
{
    "name": "$project_name",
    "description": "$description",
    "visibility": "private",
    "capabilities": {
        "versioncontrol": {
            "sourceControlType": "Git"
        },
        "processTemplate": {
            "templateTypeId": "$process_template"
        }
    }
}
EOF
)
    
    local url="https://dev.azure.com/$org/_apis/projects?api-version=$ADO_API_VERSION_PREVIEW"
    local response=$(call_ado_api "POST" "$url" "$payload" "$token")
    
    if echo "$response" | grep -q '"id"'; then
        local operation_url=$(echo "$response" | grep -o '"url":"[^"]*"' | head -1 | cut -d'"' -f4)
        print_success "Project creation initiated"
        
        # Wait for project creation to complete
        print_info "Waiting for project creation to complete..."
        local max_wait=120
        local elapsed=0
        
        while [ $elapsed -lt $max_wait ]; do
            local status_response=$(call_ado_api "GET" "$operation_url" "" "$token")
            local status=$(echo "$status_response" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
            
            if [ "$status" = "succeeded" ]; then
                print_success "Project created successfully"
                return 0
            elif [ "$status" = "failed" ]; then
                print_error "Project creation failed"
                echo "$status_response"
                return 1
            fi
            
            echo -n "."
            sleep 5
            elapsed=$((elapsed + 5))
        done
        
        echo ""
        print_warning "Timeout waiting for project creation"
        return 1
    else
        print_error "Failed to create project"
        echo "$response"
        return 1
    fi
}

# Function to create iterations
create_iterations() {
    local org=$1
    local project=$2
    local iterations_file=$3
    local token=$4
    
    if [ ! -f "$iterations_file" ]; then
        print_warning "No iterations file found, skipping..."
        return 0
    fi
    
    print_info "Creating iterations..."
    
    # Read iterations from JSON file
    local iteration_count=$(cat "$iterations_file" | jq -r '.children? | length' 2>/dev/null)
    
    if [ "$iteration_count" = "null" ] || [ "$iteration_count" -eq 0 ]; then
        print_warning "No iterations found in template"
        return 0
    fi
    
    # Calculate sprint dates starting from today
    local current_date=$(date +%Y-%m-%d)
    
    for i in $(seq 0 $((iteration_count - 1))); do
        local iteration=$(cat "$iterations_file" | jq -r ".children[$i].name" 2>/dev/null)
        
        if [ -z "$iteration" ] || [ "$iteration" = "null" ]; then
            continue
        fi
        
        # Calculate start and end dates for 2-week sprints
        local start_date=$(date -v+${i}w -v+${i}w +%Y-%m-%d 2>/dev/null || date -d "+$((i*2)) weeks" +%Y-%m-%d 2>/dev/null || echo "$current_date")
        local end_date=$(date -v+${i}w -v+${i}w -v+13d +%Y-%m-%d 2>/dev/null || date -d "+$((i*2+1)) weeks +6 days" +%Y-%m-%d 2>/dev/null || echo "$current_date")
        
        local payload=$(cat <<EOF
{
    "name": "$iteration",
    "attributes": {
        "startDate": "${start_date}T00:00:00Z",
        "finishDate": "${end_date}T23:59:59Z"
    }
}
EOF
)
        
        local url="https://dev.azure.com/$org/$project/_apis/wit/classificationnodes/iterations?api-version=$ADO_API_VERSION_STABLE"
        local response=$(call_ado_api "POST" "$url" "$payload" "$token")
        
        if echo "$response" | grep -q '"id"'; then
            print_success "Created iteration: $iteration ($start_date to $end_date)"
        else
            print_warning "Failed to create iteration: $iteration (may already exist)"
        fi
    done
}

# Function to set iteration dates for existing sprints
set_iteration_dates() {
    local org=$1
    local project=$2
    local token=$3
    
    print_info "Setting iteration dates..."
    
    # Get existing iterations
    local url="https://dev.azure.com/$org/$project/_apis/wit/classificationnodes/iterations?api-version=$ADO_API_VERSION_STABLE&\$depth=2"
    local iterations_response=$(call_ado_api "GET" "$url" "" "$token")
    
    # Get list of existing iteration names
    local existing_iterations=$(echo "$iterations_response" | jq -r '.children[]?.name // empty' 2>/dev/null | sort)
    
    if [ "${DEBUG:-0}" = "1" ]; then
        echo "DEBUG: Existing iterations:" >&2
        echo "$existing_iterations" >&2
    fi
    
    # Calculate sprint dates starting from today
    local sprint_num=0
    
    # Map template sprint names to actual iteration names
    # Templates use "Sprint 1", "Sprint 2", etc.
    # Scrum template creates: Sprint 1, Sprint 2, Sprint 3, Sprint 4, Sprint 5, Sprint 6
    # Agile template creates: Iteration 1, Iteration 2, Iteration 3
    
    # Update existing sprints/iterations with 2-week intervals
    local sprint_names=()
    if echo "$existing_iterations" | grep -q "^Sprint"; then
        sprint_names=("Sprint 1" "Sprint 2" "Sprint 3" "Sprint 4" "Sprint 5" "Sprint 6")
    elif echo "$existing_iterations" | grep -q "^Iteration"; then
        sprint_names=("Iteration 1" "Iteration 2" "Iteration 3" "Iteration 4" "Iteration 5" "Iteration 6")
    else
        # Create Sprint 1-6 as default
        sprint_names=("Sprint 1" "Sprint 2" "Sprint 3" "Sprint 4" "Sprint 5" "Sprint 6")
    fi
    
    for sprint in "${sprint_names[@]}"; do
        # Calculate start and end dates for 2-week sprints
        local start_date=$(date -v+${sprint_num}w -v+${sprint_num}w +%Y-%m-%d 2>/dev/null || date -d "+$((sprint_num*2)) weeks" +%Y-%m-%d 2>/dev/null)
        local end_date=$(date -v+${sprint_num}w -v+${sprint_num}w -v+13d +%Y-%m-%d 2>/dev/null || date -d "+$((sprint_num*2+1)) weeks +6 days" +%Y-%m-%d 2>/dev/null)
        
        if [ -z "$start_date" ]; then
            print_warning "Could not calculate dates for $sprint"
            sprint_num=$((sprint_num + 1))
            continue
        fi
        
        local update_payload=$(cat <<EOF
{
    "attributes": {
        "startDate": "${start_date}T00:00:00Z",
        "finishDate": "${end_date}T23:59:59Z"
    }
}
EOF
)
        
        local update_url="https://dev.azure.com/$org/$project/_apis/wit/classificationnodes/iterations/${sprint// /%20}?api-version=$ADO_API_VERSION_STABLE"
        local update_response=$(call_ado_api "PATCH" "$update_url" "$update_payload" "$token" 2>/dev/null)
        
        if echo "$update_response" | grep -q '"id"' 2>/dev/null; then
            echo -n "."
        else
            echo -n "x"
        fi
        
        sprint_num=$((sprint_num + 1))
    done
    
    echo ""
    print_success "Iteration dates configured"
}

# Function to create work items
create_work_items() {
    local org=$1
    local project=$2
    local work_items_source=$3
    local token=$4
    
    print_info "Creating work items..."
    
    local work_item_files=()
    
    # Check if it's a directory (ContosoShuttle2 format: WorkItems/Epic.json)
    if [ -d "$work_items_source" ]; then
        # Use a while loop to properly handle filenames with spaces
        while IFS= read -r -d '' file; do
            work_item_files+=("$file")
        done < <(find "$work_items_source" -maxdepth 1 -name "*.json" -type f -print0)
    else
        # It's a template path, look for *fromTemplate.json files in the same directory (PartsUnlimited format)
        local template_dir=$(dirname "$work_items_source")
        while IFS= read -r -d '' file; do
            work_item_files+=("$file")
        done < <(find "$template_dir" -maxdepth 1 -name "*fromTemplate.json" -type f -print0)
    fi
    
    if [ ${#work_item_files[@]} -eq 0 ]; then
        print_warning "No work item files found"
        return 0
    fi
    
    # Process work items in order: Epic -> Feature -> PBI/User Story -> Task -> Bug -> Test Case
    local work_item_types=("Epic" "Feature" "Product Backlog Item" "User Story" "Task" "Bug" "Test Case")
    
    if [ "${DEBUG:-0}" = "1" ]; then
        echo "DEBUG: Found ${#work_item_files[@]} work item files" >&2
        for f in "${work_item_files[@]}"; do
            echo "DEBUG:   File: $(basename "$f")" >&2
        done
    fi
    
    for wi_type in "${work_item_types[@]}"; do
        # Try both formats: WorkItems/Epic.json and EpicfromTemplate.json
        local wi_file=""
        
        if [ "${DEBUG:-0}" = "1" ]; then
            echo "DEBUG: Looking for work item type: $wi_type" >&2
        fi
        
        for file in "${work_item_files[@]}"; do
            local basename=$(basename "$file")
            if [ "${DEBUG:-0}" = "1" ]; then
                echo "DEBUG:   Checking if '$basename' matches '${wi_type}.json'" >&2
            fi
            if [[ "$basename" == "${wi_type}.json" ]] || [[ "$basename" == *"${wi_type}"*"fromTemplate.json" ]]; then
                wi_file="$file"
                if [ "${DEBUG:-0}" = "1" ]; then
                    echo "DEBUG:   MATCH! Using $wi_file" >&2
                fi
                break
            fi
        done
        
        if [ -z "$wi_file" ] || [ ! -f "$wi_file" ]; then
            continue
        fi
        
        if [ "${DEBUG:-0}" = "1" ]; then
            echo "DEBUG: Processing $wi_type from file: $wi_file" >&2
        fi
        
        print_info "Creating ${wi_type}s..."
        
        # Read work items from file
        local count=$(cat "$wi_file" | jq -r '.count // 0')
        
        if [ "${DEBUG:-0}" = "1" ]; then
            echo "DEBUG: Found $count ${wi_type}s in file" >&2
        fi
        
        if [ "$count" -eq 0 ]; then
            continue
        fi
        
        local items=$(cat "$wi_file" | jq -c '.value[]?')
        
        for j in $(seq 0 $((count - 1))); do
            local item=$(cat "$wi_file" | jq -c ".value[$j]" 2>/dev/null)
            
            if [ -z "$item" ] || [ "$item" = "null" ]; then
                continue
            fi
            
            # Extract fields and build patch document  
            local title=$(echo "$item" | jq -r '.fields."System.Title" // "Untitled"' 2>/dev/null)
            local description=$(echo "$item" | jq -r '.fields."System.Description" // ""' 2>/dev/null)
            local state=$(echo "$item" | jq -r '.fields."System.State" // ""' 2>/dev/null)
            local iteration_path=$(echo "$item" | jq -r '.fields."System.IterationPath" // ""' 2>/dev/null)
            
            # Extract iteration name from the path
            local iteration_name=""
            # TEMPORARILY SKIP ITERATION ASSIGNMENT - iterations exist but path format issues
            # Will assign iterations manually or fix in future update
            iteration_path=""
            
            # TODO: Fix iteration path format issues
            # Original code preserved below for reference:
            # if [ ! -z "$iteration_path" ] && [ "$iteration_path" != "null" ] && [ "$iteration_path" != "$project" ]; then
            #     iteration_name=$(echo "$iteration_path" | sed 's/.*\\//')
            #     iteration_path="$project/$iteration_name"
            # fi
            
            # Only use simple, common states that work across process templates
            # Skip state field entirely if it's not a basic value - let Azure DevOps use defaults
            local use_state="false"
            case "$state" in
                "New") use_state="true" ;;
                "Active") 
                    # Map Active to New to avoid issues
                    state="New"
                    use_state="true"
                    ;;
                *) 
                    # For all other states, skip and let Azure DevOps use defaults
                    use_state="false" 
                    ;;
            esac
            
            # Build JSON using jq - include iteration path if available
            local patch_doc=$(jq -n \
                --arg title "$title" \
                --arg state "$state" \
                --arg use_state "$use_state" \
                --arg description "$description" \
                --arg iteration "$iteration_path" \
                '[
                    {"op":"add","path":"/fields/System.Title","value":$title}
                ] + 
                (if $use_state == "true" then 
                    [{"op":"add","path":"/fields/System.State","value":$state}]
                else [] end) +
                (if $description != "" and $description != "null" then 
                    [{"op":"add","path":"/fields/System.Description","value":$description}] 
                else [] end) +
                (if $iteration != "" and $iteration != "null" then
                    [{"op":"add","path":"/fields/System.IterationPath","value":$iteration}]
                else [] end)')
            
            # Debug: show iteration assignment
            if [ "${DEBUG:-0}" = "1" ] && [ ! -z "$iteration_path" ] && [ "$iteration_path" != "null" ]; then
                echo "DEBUG: Assigning '$title' to iteration '$iteration_path'" >&2
            fi
            
            # Create work item - URL encode the work item type
            local wi_type_encoded=$(echo "$wi_type" | sed 's/ /%20/g')
            local url="https://dev.azure.com/$org/$project/_apis/wit/workitems/\$${wi_type_encoded}?api-version=$ADO_API_VERSION_STABLE"
            local response=$(call_ado_api "POST" "$url" "$patch_doc" "$token" "application/json-patch+json")
            
            if echo "$response" | grep -q '"id"'; then
                echo -n "."
            else
                # Silent failure for work items to avoid clutter
                echo -n "x"
            fi
        done
        
        echo ""
    done
    
    print_success "Work items created"
}

# Function to import source code from external repository
import_source_code() {
    local org=$1
    local project=$2
    local source_config_dir=$3
    local token=$4
    
    if [ ! -d "$source_config_dir" ]; then
        return 0
    fi
    
    print_info "Importing source code..."
    
    # Find source code configuration file
    local config_file=$(find "$source_config_dir" -name "*.json" -type f | head -1)
    
    if [ ! -f "$config_file" ]; then
        print_warning "No source code configuration found"
        return 0
    fi
    
    # Read source repository URL
    local source_url=$(cat "$config_file" | jq -r '.parameters.gitSource.url // empty')
    
    if [ -z "$source_url" ]; then
        print_warning "No source repository URL found"
        return 0
    fi
    
    print_info "Source repository: $source_url"
    
    # Create a temporary directory for cloning
    local temp_dir=$(mktemp -d)
    
    # Try to clone the source repository (with timeout)
    print_info "Cloning source repository..."
    
    # Try cloning with timeout to avoid hanging
    if timeout 30 git clone --depth 1 --quiet "$source_url" "$temp_dir/source" 2>/dev/null; then
        # Successfully cloned
        print_success "Source repository cloned"
        
        # Get the default repository name for the project
        local repo_name="$project"
        
        # Remove git history to start fresh
        cd "$temp_dir/source"
        rm -rf .git
        git init --quiet
        git add .
        git commit -m "Initial commit from template" --quiet
        
        # Configure git credentials for Azure DevOps using token
        # Use a custom credential helper script
        local cred_helper="$temp_dir/git-credential-helper.sh"
        cat > "$cred_helper" << CREDHELPER
#!/bin/bash
echo "username="
echo "password=$token"
CREDHELPER
        chmod +x "$cred_helper"
        
        git config credential.helper "!$cred_helper"
        git remote add origin "https://dev.azure.com/$org/$project/_git/$repo_name"
        
        # Push to Azure DevOps
        print_info "Pushing code to Azure DevOps repository..."
        if git push -u origin --all --force --quiet 2>&1; then
            print_success "Source code imported successfully"
        else
            # Try one more time with main/master specifically
            if git push -u origin main --quiet 2>/dev/null || git push -u origin master --quiet 2>/dev/null; then
                print_success "Source code imported successfully"
            else
                print_warning "Could not push to Azure DevOps repository - you may need to initialize it manually"
            fi
        fi
        
        # Clean up
        cd - > /dev/null
    else
        print_warning "Source repository not accessible (may be private or offline)"
        print_info "You can manually clone code from: $source_url"
        print_info "Or push your own code to: https://dev.azure.com/$org/$project/_git/$project"
    fi
    
    # Clean up
    rm -rf "$temp_dir"
}

# Function to create branches
import_branches() {
    local org=$1
    local project=$2
    local repo_name=$3
    local pull_requests_dir=$4
    local token=$5
    
    if [ ! -d "$pull_requests_dir" ]; then
        return 0
    fi
    
    print_info "Creating branches..."
    
    # Get the latest commit on main/master
    local repo_url="https://dev.azure.com/$org/$project/_apis/git/repositories/$repo_name/refs?filter=heads/main&api-version=7.1"
    local main_ref=$(call_ado_api "GET" "$repo_url" "" "$token")
    local main_commit=$(echo "$main_ref" | jq -r '.value[0].objectId // empty' 2>/dev/null)
    
    if [ -z "$main_commit" ]; then
        # Try master instead
        repo_url="https://dev.azure.com/$org/$project/_apis/git/repositories/$repo_name/refs?filter=heads/master&api-version=7.1"
        main_ref=$(call_ado_api "GET" "$repo_url" "" "$token")
        main_commit=$(echo "$main_ref" | jq -r '.value[0].objectId // empty' 2>/dev/null)
    fi
    
    if [ -z "$main_commit" ]; then
        print_warning "Could not get main branch commit - skipping branch creation"
        return 0
    fi
    
    # Extract branch names from PR files
    local branches=()
    for pr_file in "$pull_requests_dir"/*.json; do
        if [ ! -f "$pr_file" ]; then
            continue
        fi
        
        local source_branch=$(cat "$pr_file" | jq -r '.sourceRefName // empty' 2>/dev/null | sed 's|refs/heads/||')
        if [ ! -z "$source_branch" ] && [ "$source_branch" != "master" ] && [ "$source_branch" != "main" ]; then
            branches+=("$source_branch")
        fi
    done
    
    # Create each branch
    local count=0
    for branch in "${branches[@]}"; do
        local create_payload=$(cat <<EOF
[
    {
        "name": "refs/heads/$branch",
        "oldObjectId": "0000000000000000000000000000000000000000",
        "newObjectId": "$main_commit"
    }
]
EOF
)
        
        local create_url="https://dev.azure.com/$org/$project/_apis/git/repositories/$repo_name/refs?api-version=7.1"
        local response=$(call_ado_api "POST" "$create_url" "$create_payload" "$token" 2>/dev/null)
        
        if echo "$response" | grep -q '"name"' 2>/dev/null; then
            echo -n "."
            count=$((count + 1))
        else
            echo -n "x"
        fi
    done
    
    echo ""
    if [ $count -gt 0 ]; then
        print_success "Created $count branch(es)"
    fi
}

# Function to create pull requests
import_pull_requests() {
    local org=$1
    local project=$2
    local repo_name=$3
    local pull_requests_dir=$4
    local token=$5
    
    if [ ! -d "$pull_requests_dir" ]; then
        return 0
    fi
    
    print_info "Creating pull requests..."
    
    local count=0
    for pr_file in "$pull_requests_dir"/*.json; do
        if [ ! -f "$pr_file" ]; then
            continue
        fi
        
        local title=$(cat "$pr_file" | jq -r '.title // "Pull Request"' 2>/dev/null)
        local description=$(cat "$pr_file" | jq -r '.description // ""' 2>/dev/null)
        local source_ref=$(cat "$pr_file" | jq -r '.sourceRefName // ""' 2>/dev/null)
        local target_ref=$(cat "$pr_file" | jq -r '.targetRefName // "refs/heads/main"' 2>/dev/null)
        
        # Update target ref from master to main if needed
        if [ "$target_ref" = "refs/heads/master" ]; then
            target_ref="refs/heads/main"
        fi
        
        if [ -z "$source_ref" ]; then
            continue
        fi
        
        local pr_payload=$(cat <<EOF
{
    "sourceRefName": "$source_ref",
    "targetRefName": "$target_ref",
    "title": "$title",
    "description": "$description"
}
EOF
)
        
        local pr_url="https://dev.azure.com/$org/$project/_apis/git/repositories/$repo_name/pullrequests?api-version=7.1"
        local response=$(call_ado_api "POST" "$pr_url" "$pr_payload" "$token" 2>/dev/null)
        
        if echo "$response" | grep -q '"pullRequestId"' 2>/dev/null; then
            local pr_id=$(echo "$response" | jq -r '.pullRequestId // empty' 2>/dev/null)
            echo -n "."
            count=$((count + 1))
            
            # Add comments if available
            local comments_dir="$pull_requests_dir/Comments"
            if [ -d "$comments_dir" ]; then
                local pr_num=$(basename "$pr_file" .json | sed 's/PullRequest//')
                local comment_file="$comments_dir/PRComment$pr_num.json"
                
                if [ -f "$comment_file" ]; then
                    local comments=$(cat "$comment_file" | jq -c '.[]?' 2>/dev/null)
                    echo "$comments" | while IFS= read -r comment; do
                        if [ ! -z "$comment" ]; then
                            local comment_text=$(echo "$comment" | jq -r '.content // empty' 2>/dev/null)
                            if [ ! -z "$comment_text" ]; then
                                local thread_payload=$(cat <<EOF
{
    "comments": [
        {
            "content": "$comment_text",
            "commentType": 1
        }
    ],
    "status": 1
}
EOF
)
                                local thread_url="https://dev.azure.com/$org/$project/_apis/git/repositories/$repo_name/pullRequests/$pr_id/threads?api-version=7.1"
                                call_ado_api "POST" "$thread_url" "$thread_payload" "$token" > /dev/null 2>&1
                            fi
                        fi
                    done
                fi
            fi
        else
            echo -n "x"
        fi
    done
    
    echo ""
    if [ $count -gt 0 ]; then
        print_success "Created $count pull request(s)"
    fi
}

# Function to import build pipelines
import_build_pipelines() {
    local org=$1
    local project=$2
    local builds_dir=$3
    local token=$4
    local repo_name=$5
    
    if [ ! -d "$builds_dir" ]; then
        return 0
    fi
    
    print_info "Importing build pipelines..."
    
    # Check if azure-pipelines.yml exists in the repo
    local repo_url="https://dev.azure.com/$org/$project/_apis/git/repositories/$repo_name/items?path=/azure-pipelines.yml&api-version=7.1"
    local yaml_check=$(call_ado_api "GET" "$repo_url" "" "$token" 2>/dev/null)
    
    # Check if file exists (API returns raw YAML content if found, error if not)
    if [ ! -z "$yaml_check" ] && echo "$yaml_check" | grep -q "trigger:" 2>/dev/null; then
        print_success "Found azure-pipelines.yml in repository!"
        
        # Get repository ID
        local repo_id_url="https://dev.azure.com/$org/$project/_apis/git/repositories/$repo_name?api-version=7.1"
        local repo_info=$(call_ado_api "GET" "$repo_id_url" "" "$token" 2>/dev/null)
        local repo_id=$(echo "$repo_info" | jq -r '.id // empty' 2>/dev/null)
        
        if [ ! -z "$repo_id" ]; then
            # Attempt to create YAML pipeline automatically
            local pipeline_payload=$(cat <<EOF
{
    "name": "$repo_name-CI",
    "folder": "\\\\",
    "configuration": {
        "type": "yaml",
        "path": "/azure-pipelines.yml",
        "repository": {
            "id": "$repo_id",
            "name": "$repo_name",
            "type": "azureReposGit"
        }
    }
}
EOF
)
            
            local pipeline_url="https://dev.azure.com/$org/$project/_apis/pipelines?api-version=7.1"
            local pipeline_response=$(call_ado_api "POST" "$pipeline_url" "$pipeline_payload" "$token" 2>/dev/null)
            
            if echo "$pipeline_response" | grep -q '"id"' 2>/dev/null; then
                local pipeline_id=$(echo "$pipeline_response" | jq -r '.id // empty' 2>/dev/null)
                print_success "YAML pipeline created automatically! (ID: $pipeline_id)"
                
                # Queue a build run to initialize the pipeline
                local run_payload='{"resources":{"repositories":{"self":{"refName":"refs/heads/main"}}}}'
                local run_url="https://dev.azure.com/$org/$project/_apis/pipelines/$pipeline_id/runs?api-version=7.1"
                call_ado_api "POST" "$run_url" "$run_payload" "$token" > /dev/null 2>&1
            else
                print_info "YAML pipeline found but not auto-created"
                print_info "You can create it via: Pipelines > New Pipeline > Azure Repos Git > Existing YAML"
            fi
        fi
    fi
    
    # Try to import classic build pipelines
    local count=0
    for build_file in "$builds_dir"/*.json; do
        if [ ! -f "$build_file" ]; then
            continue
        fi
        
        local build_name=$(basename "$build_file" .json)
        local build_def=$(cat "$build_file" | jq --arg project "$project" --arg repo "$repo_name" '
            .repository.name = $repo |
            .repository.id = null |
            .project.name = $project
        ' 2>/dev/null)
        
        local build_url="https://dev.azure.com/$org/$project/_apis/build/definitions?api-version=7.1"
        local response=$(call_ado_api "POST" "$build_url" "$build_def" "$token" 2>/dev/null)
        
        if echo "$response" | grep -q '"id"' 2>/dev/null; then
            echo -n "."
            count=$((count + 1))
        fi
    done
    
    if [ $count -gt 0 ]; then
        echo ""
        print_success "Created $count classic build pipeline(s)"
    fi
}

# Function to import release pipelines
import_release_pipelines() {
    local org=$1
    local project=$2
    local releases_dir=$3
    local token=$4
    
    if [ ! -d "$releases_dir" ]; then
        return 0
    fi
    
    print_info "Importing release pipelines..."
    print_warning "Classic release pipelines require manual configuration"
    print_info "Release definitions available in: $releases_dir"
    print_info "You can manually import these through Azure DevOps UI"
    
    # Note: Release pipelines have complex dependencies (service connections, etc.)
    # that require manual setup
}

# Function to import test plans
import_test_plans() {
    local org=$1
    local project=$2
    local testplans_dir=$3
    local token=$4
    
    if [ ! -d "$testplans_dir" ]; then
        return 0
    fi
    
    print_info "Importing test plans..."
    print_warning "Test plans require Azure DevOps Test Plans license"
    print_info "Test plan definitions available in: $testplans_dir"
    print_info "You can manually create test plans in Azure DevOps Test Plans"
    
    # Note: Test Plans API requires specific licensing and permissions
}

# Function to import queries
import_queries() {
    local org=$1
    local project=$2
    local query_file=$3
    local token=$4
    
    if [ ! -f "$query_file" ]; then
        return 0
    fi
    
    print_info "Importing queries..."
    
    # Check if file contains array or single object
    local queries=$(cat "$query_file" | jq -c 'if type == "array" then .[] else . end' 2>/dev/null)
    
    if [ -z "$queries" ]; then
        print_warning "No valid queries found"
        return 0
    fi
    
    local count=0
    echo "$queries" | while IFS= read -r query; do
        if [ -z "$query" ] || [ "$query" = "null" ]; then
            continue
        fi
        
        local query_name=$(echo "$query" | jq -r '.name // "Query"' 2>/dev/null)
        
        # Skip placeholder queries
        if [ "$query_name" = "Query" ] || [ "$query_name" = "\$name\$" ] || [ -z "$query_name" ]; then
            continue
        fi
        
        # Skip if wiql contains placeholders
        local wiql=$(echo "$query" | jq -r '.wiql // ""' 2>/dev/null)
        if echo "$wiql" | grep -q '\$' 2>/dev/null; then
            continue
        fi
        
        local url="https://dev.azure.com/$org/$project/_apis/wit/queries/Shared%20Queries?api-version=7.1"
        local response=$(call_ado_api "POST" "$url" "$query" "$token" 2>/dev/null)
        
        if echo "$response" | grep -q '"id"' 2>/dev/null; then
            echo -n "."
            count=$((count + 1))
        else
            echo -n "x"
        fi
    done
    
    echo ""
    if [ $count -gt 0 ]; then
        print_success "Imported $count quer(ies)"
    else
        print_info "No queries to import (template may use placeholders)"
    fi
}

# Function to import dashboards
import_dashboards() {
    local org=$1
    local project=$2
    local dashboard_dir=$3
    local token=$4
    
    if [ ! -d "$dashboard_dir" ]; then
        return 0
    fi
    
    print_info "Importing dashboards..."
    
    local count=0
    for dashboard_file in "$dashboard_dir"/*.json; do
        if [ ! -f "$dashboard_file" ]; then
            continue
        fi
        
        local dashboard_name=$(cat "$dashboard_file" | jq -r '.name // "Dashboard"')
        
        # Skip placeholder dashboards
        if [ "$dashboard_name" = "\$name\$" ] || echo "$dashboard_name" | grep -q '\$' 2>/dev/null; then
            continue
        fi
        
        local url="https://dev.azure.com/$org/$project/_apis/dashboard/dashboards?api-version=7.1-preview.3"
        local response=$(call_ado_api "POST" "$url" "$(cat "$dashboard_file")" "$token" 2>/dev/null)
        
        if echo "$response" | grep -q '"id"' 2>/dev/null; then
            print_success "Created dashboard: $dashboard_name"
            count=$((count + 1))
        else
            print_warning "Failed to create dashboard: $dashboard_name"
        fi
    done
    
    if [ $count -gt 0 ]; then
        print_success "Imported $count dashboard(s)"
    fi
}

# Function to import wiki
import_wiki() {
    local org=$1
    local project=$2
    local wiki_dir=$3
    local token=$4
    
    if [ ! -d "$wiki_dir" ]; then
        return 0
    fi
    
    print_info "Importing wiki..."
    
    # Check for ProjectWiki directory
    local project_wiki_dir="$wiki_dir/ProjectWiki"
    if [ ! -d "$project_wiki_dir" ]; then
        print_info "No project wiki found in template"
        return 0
    fi
    
    # Get project ID
    local project_url="https://dev.azure.com/$org/_apis/projects/$project?api-version=7.1"
    local project_info=$(call_ado_api "GET" "$project_url" "" "$token" 2>/dev/null)
    local project_id=$(echo "$project_info" | jq -r '.id // empty' 2>/dev/null)
    
    if [ -z "$project_id" ]; then
        print_warning "Could not get project ID for wiki creation"
        return 0
    fi
    
    # Create wiki
    local create_wiki_file="$project_wiki_dir/CreateWiki.json"
    if [ -f "$create_wiki_file" ]; then
        local wiki_name=$(cat "$create_wiki_file" | jq -r '.name // "Wiki"' 2>/dev/null)
        
        local wiki_payload=$(cat <<EOF
{
    "type": "projectWiki",
    "name": "$wiki_name",
    "projectId": "$project_id"
}
EOF
)
        
        local wiki_url="https://dev.azure.com/$org/$project/_apis/wiki/wikis?api-version=7.1"
        local wiki_response=$(call_ado_api "POST" "$wiki_url" "$wiki_payload" "$token" 2>/dev/null)
        
        if echo "$wiki_response" | grep -q '"id"' 2>/dev/null; then
            local wiki_id=$(echo "$wiki_response" | jq -r '.id // empty' 2>/dev/null)
            print_success "Created wiki: $wiki_name"
            
            # Import wiki pages
            local wiki_pages_dir="$project_wiki_dir/$wiki_name"
            if [ -d "$wiki_pages_dir" ]; then
                local page_count=0
                for page_file in "$wiki_pages_dir"/*.json; do
                    if [ ! -f "$page_file" ]; then
                        continue
                    fi
                    
                    local page_name=$(basename "$page_file" .json)
                    local page_content=$(cat "$page_file" | jq -r '.content // ""' 2>/dev/null)
                    
                    if [ -z "$page_content" ]; then
                        continue
                    fi
                    
                    # Create wiki page
                    local page_payload=$(cat <<EOF
{
    "content": "$page_content"
}
EOF
)
                    
                    local page_path=$(echo "$page_name" | sed 's/ /%20/g')
                    local page_url="https://dev.azure.com/$org/$project/_apis/wiki/wikis/$wiki_id/pages?path=/$page_path&api-version=7.1"
                    local page_response=$(call_ado_api "PUT" "$page_url" "$page_payload" "$token" 2>/dev/null)
                    
                    if echo "$page_response" | grep -q '"path"' 2>/dev/null; then
                        echo -n "."
                        page_count=$((page_count + 1))
                    else
                        echo -n "x"
                    fi
                done
                
                echo ""
                if [ $page_count -gt 0 ]; then
                    print_success "Imported $page_count wiki page(s)"
                fi
            fi
        else
            print_warning "Could not create wiki"
        fi
    fi
}

# Function to import service endpoints
import_service_endpoints() {
    local org=$1
    local project=$2
    local endpoints_dir=$3
    local token=$4
    
    if [ ! -d "$endpoints_dir" ]; then
        return 0
    fi
    
    print_info "Importing service endpoints..."
    print_warning "Service endpoints require credentials - skipping automatic import"
    print_info "You can manually create service connections in Azure DevOps"
}

# Function to get process template ID
get_process_template_id() {
    local org=$1
    local process_name=$2
    local token=$3
    
    # Use the correct API version for process templates
    local url="https://dev.azure.com/$org/_apis/process/processes?api-version=7.1-preview.1"
    local response=$(call_ado_api "GET" "$url" "" "$token")
    
    # Debug: Check if response is empty or has errors
    if [ -z "$response" ]; then
        echo "ERROR: Empty response from process templates API" >&2
        return 1
    fi
    
    # Check for error in response
    local error_msg=$(echo "$response" | jq -r '.message // empty' 2>/dev/null)
    if [ ! -z "$error_msg" ]; then
        echo "ERROR: $error_msg" >&2
        return 1
    fi
    
    # Default to Scrum if not specified
    if [ -z "$process_name" ]; then
        process_name="Scrum"
    fi
    
    # Try to find the requested process template
    local template_id=$(echo "$response" | jq -r ".value[]? | select(.name==\"$process_name\") | .id" 2>/dev/null | head -1)
    
    if [ -z "$template_id" ] || [ "$template_id" = "null" ]; then
        # Fallback to Scrum
        template_id=$(echo "$response" | jq -r ".value[]? | select(.name==\"Scrum\") | .id" 2>/dev/null | head -1)
    fi
    
    if [ -z "$template_id" ] || [ "$template_id" = "null" ]; then
        # Last resort: use first available template
        template_id=$(echo "$response" | jq -r ".value[0]? | .id" 2>/dev/null)
    fi
    
    if [ -z "$template_id" ] || [ "$template_id" = "null" ]; then
        echo "ERROR: Could not find any process templates" >&2
        return 1
    fi
    
    echo "$template_id"
}

# Function to list available templates
list_templates() {
    print_header "Available Templates"
    echo ""
    
    if [ ! -d "$TEMPLATES_DIR" ]; then
        print_error "Templates directory not found: $TEMPLATES_DIR"
        return 1
    fi
    
    local count=0
    for template_dir in "$TEMPLATES_DIR"/*; do
        if [ -d "$template_dir" ] && [ -f "$template_dir/ProjectTemplate.json" ]; then
            local template_name=$(basename "$template_dir")
            local description=""
            
            if [ -f "$template_dir/ProjectTemplate.json" ]; then
                description=$(cat "$template_dir/ProjectTemplate.json" | jq -r '.Description // ""')
            fi
            
            echo "  📦 $template_name"
            if [ -n "$description" ]; then
                echo "     $description"
            fi
            echo ""
            count=$((count + 1))
        fi
    done
    
    if [ $count -eq 0 ]; then
        print_warning "No templates found in $TEMPLATES_DIR"
    else
        print_info "Found $count templates"
    fi
}

# Function to validate template
validate_template() {
    local template_name=$1
    local template_path="$TEMPLATES_DIR/$template_name"
    
    if [ ! -d "$template_path" ]; then
        print_error "Template not found: $template_name"
        print_info "Run '$0 --list' to see available templates"
        return 1
    fi
    
    if [ ! -f "$template_path/ProjectTemplate.json" ]; then
        print_error "Invalid template: missing ProjectTemplate.json"
        return 1
    fi
    
    return 0
}

# Function to import template
import_template() {
    local org=$1
    local project_name=$2
    local template_name=$3
    local token=$4
    
    local template_path="$TEMPLATES_DIR/$template_name"
    
    print_header "Importing Template: $template_name"
    echo ""
    
    # Validate template
    if ! validate_template "$template_name"; then
        return 1
    fi
    
    # Read template configuration
    local template_config="$template_path/ProjectTemplate.json"
    local project_settings="$template_path/ProjectSettings.json"
    
    # Get process template
    local process_type="Scrum"
    if [ -f "$project_settings" ]; then
        process_type=$(cat "$project_settings" | jq -r '.type // "Scrum"')
    fi
    
    print_info "Process template: $process_type"
    
    # Get process template ID
    local template_id=$(get_process_template_id "$org" "$process_type" "$token")
    
    if [ -z "$template_id" ]; then
        print_error "Failed to get process template ID"
        return 1
    fi
    
    # Create project
    local description=$(cat "$template_config" | jq -r '.Description // "Demo project created from template"')
    
    if ! create_project "$org" "$project_name" "$description" "$template_id" "$token"; then
        return 1
    fi
    
    echo ""
    
    # Create iterations
    if [ -f "$template_path/Iterations.json" ]; then
        create_iterations "$org" "$project_name" "$template_path/Iterations.json" "$token"
        echo ""
    else
        # If no Iterations.json, set dates for default sprints created by Scrum template
        set_iteration_dates "$org" "$project_name" "$token"
        echo ""
    fi
    
    # Create work items (supports both WorkItems/ folder and *fromTemplate.json formats)
    if [ -d "$template_path/WorkItems" ]; then
        create_work_items "$org" "$project_name" "$template_path/WorkItems" "$token"
        echo ""
    elif ls "$template_path"/*fromTemplate.json 1> /dev/null 2>&1; then
        create_work_items "$org" "$project_name" "$template_path" "$token"
        echo ""
    fi
    
    # Import source code
    if [ -d "$template_path/ImportSourceCode" ]; then
        import_source_code "$org" "$project_name" "$template_path/ImportSourceCode" "$token"
        echo ""
    fi
    
    # Create branches and pull requests (only if source code was imported)
    if [ -d "$template_path/PullRequests" ]; then
        import_branches "$org" "$project_name" "$project_name" "$template_path/PullRequests" "$token"
        echo ""
        import_pull_requests "$org" "$project_name" "$project_name" "$template_path/PullRequests" "$token"
        echo ""
    fi
    
    # Import queries
    if [ -f "$template_path/Query.json" ]; then
        import_queries "$org" "$project_name" "$template_path/Query.json" "$token"
        echo ""
    fi
    
    # Import build pipelines
    if [ -d "$template_path/BuildDefinitions" ]; then
        import_build_pipelines "$org" "$project_name" "$template_path/BuildDefinitions" "$token" "$project_name"
        echo ""
    fi
    
    # Import release pipelines
    if [ -d "$template_path/ReleaseDefinitions" ]; then
        import_release_pipelines "$org" "$project_name" "$template_path/ReleaseDefinitions" "$token"
        echo ""
    fi
    
    # Import test plans
    if [ -d "$template_path/TestPlans" ]; then
        import_test_plans "$org" "$project_name" "$template_path/TestPlans" "$token"
        echo ""
    fi
    
    # Import dashboards
    if [ -d "$template_path/Dashboard" ]; then
        import_dashboards "$org" "$project_name" "$template_path/Dashboard" "$token"
        echo ""
    fi
    
    # Import wiki
    if [ -d "$template_path/Wiki" ]; then
        import_wiki "$org" "$project_name" "$template_path/Wiki" "$token"
        echo ""
    fi
    
    # Import service endpoints (informational only)
    if [ -d "$template_path/ServiceEndpoints" ]; then
        import_service_endpoints "$org" "$project_name" "$template_path/ServiceEndpoints" "$token"
        echo ""
    fi
    
    print_success "Template import completed!"
    echo ""
    echo "Access your project at:"
    echo "https://dev.azure.com/$org/$project_name"
    echo ""
}

# Show usage
show_usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Import Azure DevOps templates from local files using Azure CLI authentication.

Options:
    -h, --help              Show this help message
    -l, --list              List available templates
    -o, --org ORG           Azure DevOps organization name
    -n, --name PROJECT      Project name to create
    -t, --template TEMPLATE Template folder name to import
    -y, --yes               Auto-confirm prompts

Environment Variables:
    ADO_ORG                 Azure DevOps Organization name

Prerequisites:
    - Azure CLI installed (https://aka.ms/azure-cli)
    - Logged in with 'az login'

Examples:
    # Login first
    az login

    # List available templates
    $0 --list

    # Import a template interactively
    $0

    # Import with command line arguments
    $0 -o myorg -n "MyProject" -t "ContosoShuttle2" -y

    # Using environment variable
    export ADO_ORG="your-org"
    $0 -n "MyProject" -t "ContosoShuttle2" -y

Note: This script uses Azure CLI for authentication (more secure than PAT).
      Run 'az login' before using this script.

EOF
}

# Main function
main() {
    print_header "Azure DevOps Template Importer"
    echo ""
    
    # Parse arguments
    local AUTO_CONFIRM=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -l|--list)
                list_templates
                exit 0
                ;;
            -o|--org)
                ADO_ORG="$2"
                shift 2
                ;;
            -n|--name)
                PROJECT_NAME="$2"
                shift 2
                ;;
            -t|--template)
                TEMPLATE_NAME="$2"
                shift 2
                ;;
            -y|--yes)
                AUTO_CONFIRM=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Check for jq
    if ! command -v jq &> /dev/null; then
        print_error "jq is required but not installed"
        echo "Install with: brew install jq"
        exit 1
    fi
    
    # Check Azure CLI login
    check_az_login
    
    # Interactive prompts
    if [ -z "$ADO_ORG" ]; then
        read -p "Enter Azure DevOps Organization name: " ADO_ORG
    fi
    
    if [ -z "$PROJECT_NAME" ]; then
        read -p "Enter Project name: " PROJECT_NAME
    fi
    
    if [ -z "$TEMPLATE_NAME" ]; then
        echo ""
        print_info "Run '$0 --list' to see available templates"
        read -p "Enter Template folder name: " TEMPLATE_NAME
    fi
    
    # Validate inputs
    if [ -z "$ADO_ORG" ] || [ -z "$PROJECT_NAME" ] || [ -z "$TEMPLATE_NAME" ]; then
        print_error "Missing required parameters"
        show_usage
        exit 1
    fi
    
    # Get Azure DevOps access token
    print_info "Getting Azure DevOps access token..."
    local ADO_TOKEN=$(get_az_token)
    
    # Display configuration
    echo ""
    print_header "Configuration"
    echo "Organization: $ADO_ORG"
    echo "Project Name: $PROJECT_NAME"
    echo "Template:     $TEMPLATE_NAME"
    echo "Templates Dir: $TEMPLATES_DIR"
    echo ""
    
    # Confirm
    if [ "$AUTO_CONFIRM" = false ]; then
        read -p "Proceed with template import? (y/n): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Operation cancelled"
            exit 0
        fi
    fi
    
    echo ""
    
    # Import template
    if import_template "$ADO_ORG" "$PROJECT_NAME" "$TEMPLATE_NAME" "$ADO_TOKEN"; then
        exit 0
    else
        exit 1
    fi
}

# Run main
main "$@"
