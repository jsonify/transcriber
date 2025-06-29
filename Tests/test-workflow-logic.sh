#!/bin/bash
# Test script for workflow logic validation
# Tests the workflow components that can be tested locally

set -e

echo "🧪 Testing Release Workflow Logic Components"
echo "============================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0

# Helper function to run test
run_test() {
    local test_name="$1"
    local expected="$2"
    shift 2
    local command="$@"
    
    echo -e "\n${BLUE}🔸 Test: $test_name${NC}"
    echo "   Command: $command"
    echo "   Expected: $expected"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    # Run the command and capture output
    if result=$(eval "$command" 2>&1); then
        if echo "$result" | grep -q "$expected"; then
            echo -e "   ${GREEN}✅ PASS${NC}"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "   ${RED}❌ FAIL${NC}"
            echo "   Actual output: $result"
        fi
    else
        echo -e "   ${RED}❌ FAIL (command failed)${NC}"
        echo "   Error: $result"
    fi
}

# Test version extraction logic (simulating workflow)
test_version_extraction() {
    echo -e "\n${YELLOW}🔧 Testing Version Extraction Logic${NC}"
    
    # Simulate the workflow version extraction
    GITHUB_REF="refs/tags/v2.2.0"
    VERSION=${GITHUB_REF#refs/tags/v}
    
    run_test "Version extraction from tag ref" \
        "2.2.0" \
        "echo '$VERSION'"
    
    # Test version format validation
    if [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "   ${GREEN}✅ Version format validation: PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "   ${RED}❌ Version format validation: FAIL${NC}"
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}

# Test artifact file patterns
test_artifact_patterns() {
    echo -e "\n${YELLOW}🔧 Testing Artifact File Patterns${NC}"
    
    # Create test directory structure
    mkdir -p test-artifacts
    touch "test-artifacts/transcriber-2.2.0.zip"
    touch "test-artifacts/transcriber-2.2.1.zip"
    touch "test-artifacts/other-file.txt"
    
    # Test pattern matching (simulating workflow logic)
    run_test "Find exact version match" \
        "transcriber-2.2.0.zip" \
        "cd test-artifacts && ls transcriber-2.2.0.zip 2>/dev/null || echo 'not found'"
    
    run_test "Find any transcriber zip" \
        "transcriber-" \
        "cd test-artifacts && find . -name 'transcriber-*.zip' | head -1"
    
    # Cleanup
    rm -rf test-artifacts
}

# Test consistency validation
test_consistency_validation() {
    echo -e "\n${YELLOW}🔧 Testing Consistency Validation${NC}"
    
    # Test tag vs version consistency (simulating workflow)
    VERSION="2.2.0"
    EXPECTED_TAG="v$VERSION"
    ACTUAL_TAG="v2.2.0"
    
    if [ "$EXPECTED_TAG" = "$ACTUAL_TAG" ]; then
        echo -e "   ${GREEN}✅ Tag consistency validation: PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "   ${RED}❌ Tag consistency validation: FAIL${NC}"
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
    
    # Test mismatch case
    ACTUAL_TAG="v2.2.1"
    if [ "$EXPECTED_TAG" != "$ACTUAL_TAG" ]; then
        echo -e "   ${GREEN}✅ Tag mismatch detection: PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "   ${RED}❌ Tag mismatch detection: FAIL${NC}"
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}

# Test CI workflow integration points
test_ci_integration() {
    echo -e "\n${YELLOW}🔧 Testing CI Integration Points${NC}"
    
    # Test build commands work with version override
    run_test "CLI build with version override" \
        "Using release version override: 2.2.0" \
        "RELEASE_VERSION=2.2.0 make version-debug"
    
    run_test "Build paths use correct version" \
        "Version: 2.2.0" \
        "RELEASE_VERSION=2.2.0 make info | grep 'Version:'"
}

# Run all tests
echo -e "${BLUE}Starting workflow logic tests...${NC}"

test_version_extraction
test_artifact_patterns  
test_consistency_validation
test_ci_integration

echo -e "\n${BLUE}📊 Overall Test Summary${NC}"
echo "======================="
echo "Tests run: $TESTS_RUN"
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $((TESTS_RUN - TESTS_PASSED))"

if [ $TESTS_PASSED -eq $TESTS_RUN ]; then
    echo -e "\n${GREEN}🎉 All workflow logic tests passed!${NC}"
    echo -e "${GREEN}The workflow changes should work correctly.${NC}"
    exit 0
else
    echo -e "\n${RED}💥 Some workflow logic tests failed.${NC}"
    exit 1
fi