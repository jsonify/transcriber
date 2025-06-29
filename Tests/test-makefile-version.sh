#!/bin/bash
# Test script for Makefile version resolution logic
# Tests the RELEASE_VERSION override functionality

set -e

echo "🧪 Testing Makefile Version Resolution Logic"
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

# Test 1: Default behavior (should use latest git tag)
run_test "Default version resolution (git tag)" \
    "Using GIT_VERSION" \
    "make version-debug | head -20"

# Test 2: RELEASE_VERSION override
run_test "RELEASE_VERSION override (2.2.0)" \
    "Using RELEASE_VERSION override" \
    "RELEASE_VERSION=2.2.0 make version-debug | head -20"

# Test 3: RELEASE_VERSION override with different version
run_test "RELEASE_VERSION override (1.5.0)" \
    "Final VERSION: '1.5.0'" \
    "RELEASE_VERSION=1.5.0 make version-debug | head -20"

# Test 4: Verify version is used correctly
run_test "Version used correctly in build info" \
    "Version: 2.2.0" \
    "RELEASE_VERSION=2.2.0 make info | grep 'Version:'"

# Test 5: Empty RELEASE_VERSION should fall back to normal logic
run_test "Empty RELEASE_VERSION fallback" \
    "Using GIT_VERSION" \
    "RELEASE_VERSION= make version-debug | head -20"

# Test 6: Test version command with override
run_test "Version command with override" \
    "Release override: 3.0.0" \
    "RELEASE_VERSION=3.0.0 make version"

echo -e "\n${BLUE}📊 Test Summary${NC}"
echo "==============="
echo "Tests run: $TESTS_RUN"
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $((TESTS_RUN - TESTS_PASSED))"

if [ $TESTS_PASSED -eq $TESTS_RUN ]; then
    echo -e "\n${GREEN}🎉 All tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}💥 Some tests failed.${NC}"
    exit 1
fi