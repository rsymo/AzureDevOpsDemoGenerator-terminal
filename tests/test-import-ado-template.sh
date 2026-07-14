#!/bin/bash

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/import-ado-template.sh"

source "$SCRIPT"
set +e

passed=0
failed=0

pass() {
    echo "PASS: $1"
    passed=$((passed + 1))
}

fail() {
    echo "FAIL: $1"
    failed=$((failed + 1))
}

assert_success() {
    local name=$1
    shift

    if "$@" > /dev/null 2>&1; then
        pass "$name"
    else
        fail "$name"
    fi
}

assert_failure_contains() {
    local name=$1
    local expected=$2
    shift 2
    local output

    output=$("$@" 2>&1)
    local status=$?

    if [ $status -ne 0 ] && echo "$output" | grep -Fq "$expected"; then
        pass "$name"
    else
        fail "$name"
        echo "$output"
    fi
}

assert_failure() {
    local name=$1
    shift

    if "$@" > /dev/null 2>&1; then
        fail "$name"
    else
        pass "$name"
    fi
}

original_validate_existing_project=$(declare -f validate_existing_project)
original_call_ado_api=$(declare -f call_ado_api)
original_create_project=$(declare -f create_project)

create_called=false
validate_called=false

create_project() {
    create_called=true
}

validate_existing_project() {
    validate_called=true
}

prepare_project org project description process-id Scrum token false
if [ "$create_called" = true ] && [ "$validate_called" = false ]; then
    pass "default mode creates a project"
else
    fail "default mode creates a project"
fi

create_called=false
validate_called=false
prepare_project org project description process-id Scrum token true
if [ "$create_called" = false ] && [ "$validate_called" = true ]; then
    pass "existing mode skips project creation"
else
    fail "existing mode skips project creation"
fi

create_project() {
    return 1
}

assert_failure \
    "project creation failure is returned" \
    prepare_project org project description process-id Scrum token false

validate_existing_project() {
    return 1
}

assert_failure \
    "existing project validation failure is returned" \
    prepare_project org project description process-id Scrum token true

eval "$original_create_project"
eval "$original_validate_existing_project"

curl() {
    return 7
}

assert_curl_failure_cleanup() {
    local temp_dir
    local output
    local status

    temp_dir=$(mktemp -d)
    output=$(TMPDIR="$temp_dir" call_ado_api GET https://example.invalid "" token 2>&1)
    status=$?

    if [ "$status" -ne 0 ] \
        && echo "$output" | grep -Fq "Azure DevOps API request failed (curl exit code 7)" \
        && [ -z "$(find "$temp_dir" -mindepth 1 -print -quit)" ]; then
        pass "API transport failure is returned clearly and cleans up temp files"
    else
        fail "API transport failure is returned clearly and cleans up temp files"
        echo "$output"
    fi

    rmdir "$temp_dir"
}

assert_curl_failure_cleanup

eval "$original_call_ado_api"

PROJECT_EXISTS=true
PROJECT_STATE=wellFormed
PROJECT_PROCESS_ID=scrum-process
PROJECT_PROCESS_NAME=Scrum
PROJECT_SOURCE_CONTROL=Git
WORK_ITEM_COUNT=0
REPOSITORY_COUNT=1
REPOSITORY_NAME=ExistingProject
REPOSITORY_SIZE=0
REPOSITORY_DEFAULT_BRANCH=""
BUILD_COUNT=0
WIKI_COUNT=0

reset_fixtures() {
    PROJECT_EXISTS=true
    PROJECT_STATE=wellFormed
    PROJECT_PROCESS_ID=scrum-process
    PROJECT_PROCESS_NAME=Scrum
    PROJECT_SOURCE_CONTROL=Git
    WORK_ITEM_COUNT=0
    REPOSITORY_COUNT=1
    REPOSITORY_NAME=ExistingProject
    REPOSITORY_SIZE=0
    REPOSITORY_DEFAULT_BRANCH=""
    BUILD_COUNT=0
    WIKI_COUNT=0
}

call_ado_api() {
    local url=$2

    case "$url" in
        *"includeCapabilities=true"*)
            if [ "$PROJECT_EXISTS" != true ]; then
                return 1
            fi
            jq -n \
                --arg state "$PROJECT_STATE" \
                --arg process_id "$PROJECT_PROCESS_ID" \
                --arg process_name "$PROJECT_PROCESS_NAME" \
                --arg source_control "$PROJECT_SOURCE_CONTROL" \
                '{
                    state: $state,
                    capabilities: {
                        processTemplate: {
                            templateTypeId: $process_id,
                            templateName: $process_name
                        },
                        versioncontrol: {
                            sourceControlType: $source_control
                        }
                    }
                }'
            ;;
        *"/_apis/wit/wiql?"*)
            if [ "$WORK_ITEM_COUNT" -gt 0 ]; then
                echo '{"workItems":[{"id":1}]}'
            else
                echo '{"workItems":[]}'
            fi
            ;;
        *"/_apis/git/repositories?"*)
            jq -n \
                --argjson count "$REPOSITORY_COUNT" \
                --arg name "$REPOSITORY_NAME" \
                --argjson size "$REPOSITORY_SIZE" \
                --arg branch "$REPOSITORY_DEFAULT_BRANCH" \
                '{
                    count: $count,
                    value: [
                        {
                            name: $name,
                            size: $size,
                            defaultBranch: (if $branch == "" then null else $branch end)
                        }
                    ]
                }'
            ;;
        *"/_apis/build/definitions?"*)
            jq -n --argjson count "$BUILD_COUNT" '{count: $count, value: []}'
            ;;
        *"/_apis/wiki/wikis?"*)
            jq -n --argjson count "$WIKI_COUNT" '{count: $count, value: []}'
            ;;
        *)
            return 1
            ;;
    esac
}

assert_success \
    "matching empty project is accepted" \
    validate_existing_project org ExistingProject scrum-process Scrum token

reset_fixtures
PROJECT_EXISTS=false
assert_failure_contains \
    "missing project is rejected" \
    "Could not find or access existing project" \
    validate_existing_project org ExistingProject scrum-process Scrum token

reset_fixtures
PROJECT_STATE=createPending
assert_failure_contains \
    "malformed project state is rejected" \
    "project state is 'createPending'" \
    validate_existing_project org ExistingProject scrum-process Scrum token

reset_fixtures
PROJECT_PROCESS_ID=basic-process
PROJECT_PROCESS_NAME=Basic
assert_failure_contains \
    "process mismatch is rejected" \
    "process is 'Basic', but template requires 'Scrum'" \
    validate_existing_project org ExistingProject scrum-process Scrum token

reset_fixtures
WORK_ITEM_COUNT=1
assert_failure_contains \
    "existing work items are rejected" \
    "project contains work items" \
    validate_existing_project org ExistingProject scrum-process Scrum token

reset_fixtures
REPOSITORY_SIZE=100
REPOSITORY_DEFAULT_BRANCH=refs/heads/main
assert_failure_contains \
    "committed repository content is rejected" \
    "contains committed content" \
    validate_existing_project org ExistingProject scrum-process Scrum token

reset_fixtures
REPOSITORY_COUNT=2
assert_failure_contains \
    "extra repositories are rejected" \
    "project has 2 repositories" \
    validate_existing_project org ExistingProject scrum-process Scrum token

reset_fixtures
BUILD_COUNT=1
assert_failure_contains \
    "existing builds are rejected" \
    "project contains build pipelines" \
    validate_existing_project org ExistingProject scrum-process Scrum token

reset_fixtures
WIKI_COUNT=1
assert_failure_contains \
    "existing wiki is rejected" \
    "project contains a wiki" \
    validate_existing_project org ExistingProject scrum-process Scrum token

call_ado_api() {
    echo '{"value":[{"id":"scrum-process","name":"Scrum"}]}'
}

assert_failure_contains \
    "existing mode requires an exact process lookup" \
    "Required process template 'Agile' is not available" \
    get_process_template_id org Agile token true

assert_success \
    "help includes existing project option" \
    bash -c "'$SCRIPT' --help | grep -q -- '--use-existing'"

echo ""
echo "$passed passed, $failed failed"

if [ $failed -ne 0 ]; then
    exit 1
fi
