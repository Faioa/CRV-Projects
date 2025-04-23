#!/bin/bash

# Help function
show_help() {
  echo "Usage: ./cluster-test.sh <url> <concurrent_processes> <test_type>"
  echo ""
  echo "Arguments:"
  echo "  url                  - Server URL to test (e.g., http://localhost:8080/node-redis)"
  echo "  concurrent_processes - Number of parallel processes to run"
  echo "  test_type            - Type of test to run:"
  echo "                         - writeRead : Test write and read operations"
  echo "                         - pending   : Test pending connections"
  echo "                         - server    : Test server ping operations"
  echo "                         - combined  : Run a random mix of all tests"
  echo ""
  echo "Example: ./cluster-test.sh http://localhost:8080/node-redis 5 writeRead"
}

# Check if all required arguments are provided
if [ $# -ne 3 ]; then
  show_help
  exit 1
fi

URL=$1
CONCURRENT_PROCESSES=$2
TEST_TYPE=$3

# Set default values for tests
REQUESTS_PER_PROCESS=10000
WRITE_READ_ITER=10
SERVER_ITER=100
PENDING_COUNT=200
PENDING_TIME=10000

# Validate test type
valid_tests=("writeRead" "pending" "server" "combined")
valid=false
for test in "${valid_tests[@]}"; do
  if [ "$TEST_TYPE" == "$test" ]; then
    valid=true
    break
  fi
done

if ! $valid; then
  echo "❌ Error: Invalid test type '$TEST_TYPE'"
  show_help
  exit 1
fi

# Export URL for the Node script
export URL

# Check if URL is valid
if ! [[ "$URL" =~ ^https?:// ]]; then
  echo "⚠️  Warning: URL doesn't start with http:// or https://"
  echo "    Using URL as provided: $URL"
fi

# Function to check if server is responsive
check_server() {
  curl -s --connect-timeout 5 "$URL" > /dev/null
  return $?
}

# Function to run a specific test type
run_test() {
  local test_type=$1
  local process_count=$2
  local pid_list=()
  local start_time=$(date +%s)
  
  echo "📊 Starting $test_type test with $process_count processes"
  
  # Check if server is up before starting
  if ! check_server; then
    echo "❌ Server at $URL is not responding before test start! Aborting."
    return 1
  fi
  
  case $test_type in
    "server")
      for (( i=1; i<=$process_count; i++ )); do
        node loadTest/fetchData.js server $REQUESTS_PER_PROCESS $SERVER_ITER >/dev/null 2>&1 &
        pid_list+=($!)
        echo "  - Started server test process $i with PID ${pid_list[-1]}"
      done
      ;;
    "writeRead")
      for (( i=1; i<=$process_count; i++ )); do
        node loadTest/fetchData.js writeRead $REQUESTS_PER_PROCESS $WRITE_READ_ITER >/dev/null 2>&1 &
        pid_list+=($!)
        echo "  - Started writeRead test process $i with PID ${pid_list[-1]}"
      done
      ;;
    "pending")
      for (( i=1; i<=$process_count; i++ )); do
        node loadTest/fetchData.js pending $PENDING_COUNT $PENDING_TIME >/dev/null 2>&1 &
        pid_list+=($!)
        echo "  - Started pending connections test process $i with PID ${pid_list[-1]}"
      done
      ;;
    "combined")
      for (( i=1; i<=$process_count; i++ )); do
        # Choose a random test type
        test_types=("server" "writeRead" "pending")
        random_index=$((RANDOM % 3))
        random_test=${test_types[$random_index]}
        
        case $random_test in
          "server")
            node loadTest/fetchData.js server $REQUESTS_PER_PROCESS $SERVER_ITER >/dev/null 2>&1 &
            pid_list+=($!)
            echo "  - Started random test (server) with PID ${pid_list[-1]}"
            ;;
          "writeRead")
            node loadTest/fetchData.js writeRead $REQUESTS_PER_PROCESS $WRITE_READ_ITER >/dev/null 2>&1 &
            pid_list+=($!)
            echo "  - Started random test (writeRead) with PID ${pid_list[-1]}"
            ;;
          "pending")
            node loadTest/fetchData.js pending $PENDING_COUNT $PENDING_TIME >/dev/null 2>&1 &
            pid_list+=($!)
            echo "  - Started random test (pending) with PID ${pid_list[-1]}"
            ;;
        esac
        
        # Small delay to stagger starts
        sleep 0.5
      done
      ;;
  esac
  
  # Wait for all processes to complete with progress update
  echo "  - Waiting for processes to complete..."
  local completed=0
  while [ ${#pid_list[@]} -gt 0 ]; do
    for i in "${!pid_list[@]}"; do
      if ! kill -0 ${pid_list[$i]} 2>/dev/null; then
        completed=$((completed + 1))
        echo "  - Process ${pid_list[$i]} completed ($completed/$process_count)"
        unset pid_list[$i]
      fi
    done
    # Update array after modification
    pid_list=("${pid_list[@]}")
    sleep 1
  done
  
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  
  echo "✅ $test_type test completed in $duration seconds"
}

# Main script execution
echo "🚀 Cluster test script"
echo "URL: $URL"
echo "Concurrent processes: $CONCURRENT_PROCESSES"
echo "Test type: $TEST_TYPE"

# Check if server is responsive before starting
if ! check_server; then
  echo "❌ Server at $URL is not responding! Aborting tests."
  exit 1
fi

# Run the specified test
run_test "$TEST_TYPE" "$CONCURRENT_PROCESSES"

echo "✅ Test completed successfully"
