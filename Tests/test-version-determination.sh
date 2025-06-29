#!/bin/bash
# Test script for shared version determination logic (get-version.sh)
# Tests the robustness and error handling of the version determination system

set -e

echo "🧪 Testing Shared Version Determination Logic"
echo "============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0

# Get script paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GET_VERSION_SCRIPT="$PROJECT_ROOT/installer/build-scripts/get-version.sh"

# Backup original VERSION file if it exists
VERSION_FILE="$PROJECT_ROOT/VERSION"
VERSION_BACKUP=""
if [ -f "$VERSION_FILE" ]; then
    VERSION_BACKUP=$(cat "$VERSION_FILE")
fi

# Helper function to run test
run_test() {
    local test_name="$1"
    local expected="$2" 
    local should_succeed="$3"  # true/false
    shift 3
    local command="$@"
    
    echo -e "\n${BLUE}🔸 Test: $test_name${NC}"
    echo "   Command: $command"
    echo "   Expected: $expected"
    echo "   Should succeed: $should_succeed"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    # Run the command and capture both stdout and stderr
    if result=$(eval "$command" 2>&1); then
        # Command succeeded
        if [ "$should_succeed" = "true" ]; then
            if echo "$result" | grep -q "$expected"; then
                echo -e "   ${GREEN}✅ PASS${NC}"
                TESTS_PASSED=$((TESTS_PASSED + 1))
            else
                echo -e "   ${RED}❌ FAIL (unexpected output)${NC}"
                echo "   Actual: $result"
            fi
        else
            echo -e "   ${RED}❌ FAIL (should have failed but succeeded)${NC}"
            echo "   Actual: $result"
        fi
    else
        # Command failed
        if [ "$should_succeed" = "false" ]; then
            if echo "$result" | grep -q "$expected"; then
                echo -e "   ${GREEN}✅ PASS${NC}"
                TESTS_PASSED=$((TESTS_PASSED + 1))
            else
                echo -e "   ${RED}❌ FAIL (wrong error message)${NC}"
                echo "   Actual: $result"
            fi
        else
            echo -e "   ${RED}❌ FAIL (should have succeeded but failed)${NC}"
            echo "   Error: $result"
        fi
    fi
}

# Cleanup function
cleanup() {
    # Restore original VERSION file
    if [ -n "$VERSION_BACKUP" ]; then
        echo "$VERSION_BACKUP" > "$VERSION_FILE"
    elif [ -f "$VERSION_FILE" ]; then
        rm -f "$VERSION_FILE"
    fi
    
    # Clean up any test files
    rm -f "$VERSION_FILE.test"
    
    # Unset test environment variables
    unset RELEASE_VERSION
}

# Set up cleanup trap
trap cleanup EXIT

echo -e "\n${YELLOW}🔧 Testing Normal Operation${NC}"

# Test 1: VERSION file exists and contains valid version
echo "2.2.4" > "$VERSION_FILE"
run_test "Valid VERSION file (2.2.4)" \
    "2.2.4" \
    "true" \
    "'$GET_VERSION_SCRIPT'"

# Test 2: RELEASE_VERSION environment variable override
run_test "RELEASE_VERSION override (3.0.0)" \
    "3.0.0" \
    "true" \
    "RELEASE_VERSION=3.0.0 '$GET_VERSION_SCRIPT'"

# Test 3: RELEASE_VERSION takes priority over VERSION file
echo "1.0.0" > "$VERSION_FILE"
run_test "RELEASE_VERSION priority over VERSION file" \
    "5.0.0" \
    "true" \
    "RELEASE_VERSION=5.0.0 '$GET_VERSION_SCRIPT'"

echo -e "\n${YELLOW}🔧 Testing Error Conditions${NC}"

# Test 4: Missing VERSION file (no RELEASE_VERSION)
rm -f "$VERSION_FILE"
unset RELEASE_VERSION
run_test "Missing VERSION file" \
    "Version file not found or is empty" \
    "false" \
    "'$GET_VERSION_SCRIPT'"

# Test 5: Empty VERSION file  
touch "$VERSION_FILE"  # Create empty file
run_test "Empty VERSION file" \
    "Version file not found or is empty" \
    "false" \
    "'$GET_VERSION_SCRIPT'"

# Test 6: VERSION file with only whitespace
echo "   " > "$VERSION_FILE"
run_test "VERSION file with whitespace only" \
    "contains only whitespace" \
    "false" \
    "'$GET_VERSION_SCRIPT'"

echo -e "\n${YELLOW}🔧 Testing Version Format Validation${NC}"

# Test 7: Valid semantic version
echo "1.2.3" > "$VERSION_FILE"
run_test "Valid semantic version (1.2.3)" \
    "1.2.3" \
    "true" \
    "'$GET_VERSION_SCRIPT'"

# Test 8: Valid semantic version with pre-release
echo "2.0.0-beta.1" > "$VERSION_FILE"
run_test "Valid semantic version with pre-release" \
    "2.0.0-beta.1" \
    "true" \
    "'$GET_VERSION_SCRIPT'"

# Test 9: Invalid version format (should warn but not fail)
echo "invalid-version" > "$VERSION_FILE"
run_test "Invalid version format (should warn)" \
    "does not follow semantic versioning" \
    "true" \
    "'$GET_VERSION_SCRIPT'"

# Test 10: VERSION file with trailing newlines and spaces (should be cleaned)
printf "  2.3.0  \n\n  " > "$VERSION_FILE"
run_test "VERSION with whitespace cleanup" \
    "2.3.0" \
    "true" \
    "'$GET_VERSION_SCRIPT'"

echo -e "\n${YELLOW}🔧 Testing Build Script Integration${NC}"

# Test 11: DMG script integration
echo "2.4.0" > "$VERSION_FILE"
run_test "DMG script can get version" \
    "Using VERSION from file: 2.4.0" \
    "true" \
    "cd '$PROJECT_ROOT' && head -20 installer/build-scripts/create-dmg.sh | grep 'VERSION=.*get-version' && '$GET_VERSION_SCRIPT'"

# Test 12: Installer script integration  
run_test "Installer script can get version" \
    "Using VERSION from file: 2.4.0" \
    "true" \
    "cd '$PROJECT_ROOT' && head -20 installer/build-scripts/create-installer.sh | grep 'VERSION=.*get-version' && '$GET_VERSION_SCRIPT'"

# Test 13: App bundle script integration
run_test "App bundle script can get version" \
    "Using VERSION from file: 2.4.0" \
    "true" \
    "cd '$PROJECT_ROOT' && head -20 installer/build-scripts/build-app-bundle.sh | grep 'VERSION=.*get-version' && '$GET_VERSION_SCRIPT'"

echo -e "\n${YELLOW}🔧 Testing Robustness Improvements${NC}"

# Test 14: Verify no hardcoded fallback exists in any script
run_test "No hardcoded 1.0.1 fallback in DMG script" \
    "" \
    "false" \
    "grep -q '1\\.0\\.1' '$PROJECT_ROOT/installer/build-scripts/create-dmg.sh'"

run_test "No hardcoded 1.0.1 fallback in installer script" \
    "" \
    "false" \
    "grep -q '1\\.0\\.1' '$PROJECT_ROOT/installer/build-scripts/create-installer.sh'"

run_test "No hardcoded 1.0.1 fallback in app bundle script" \
    "" \
    "false" \
    "grep -q '1\\.0\\.1' '$PROJECT_ROOT/installer/build-scripts/build-app-bundle.sh'"

# Test 15: Verify shared script is being used
run_test "DMG script uses shared get-version.sh" \
    "get-version.sh" \
    "true" \
    "grep 'get-version.sh' '$PROJECT_ROOT/installer/build-scripts/create-dmg.sh'"

run_test "Installer script uses shared get-version.sh" \
    "get-version.sh" \
    "true" \
    "grep 'get-version.sh' '$PROJECT_ROOT/installer/build-scripts/create-installer.sh'"

run_test "App bundle script uses shared get-version.sh" \
    "get-version.sh" \
    "true" \
    "grep 'get-version.sh' '$PROJECT_ROOT/installer/build-scripts/build-app-bundle.sh'"

echo -e "\n${BLUE}📊 Test Summary${NC}"
echo "==============="
echo "Tests run: $TESTS_RUN"
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $((TESTS_RUN - TESTS_PASSED))"

if [ $TESTS_PASSED -eq $TESTS_RUN ]; then
    echo -e "\n${GREEN}🎉 All version determination tests passed!${NC}"
    echo -e "${GREEN}The shared version logic is working correctly and robustly.${NC}"
    exit 0
else
    echo -e "\n${RED}💥 Some tests failed.${NC}"
    echo -e "${RED}Please review the failing tests and fix the issues.${NC}"
    exit 1
fi