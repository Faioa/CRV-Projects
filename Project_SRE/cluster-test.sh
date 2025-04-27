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
REQUESTS_PER_PROCESS=1000
WRITE_READ_ITER=10
SERVER_ITER=100
PENDING_COUNT=1000
PENDING_TIME=10000

# Create logs directory
LOGS_DIR=$(mktemp -d)

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
  curl -s --connect-timeout 10 "$URL" > /dev/null
  return $?
}

# Function to run a specific test type
run_test() {
  local test_type=$1
  local process_count=$2
  local pid_list=()
  local log_files=()
  local start_time=$(date +%s)
  local total_requests=0
  
  echo "📊 Starting $test_type test with $process_count processes at $start_time"
  
  # Check if server is up before starting
  if ! check_server; then
    echo "❌ Server at $URL is not responding before test start! Aborting."
    return 1
  fi
  
  case $test_type in
    "server")
      start_time=$(date +%s)
      for (( i=1; i<=$process_count; i++ )); do
        log_file="$LOGS_DIR/${test_type}_${i}_$(date +%s).log"
        node loadTest/fetchData.js server $REQUESTS_PER_PROCESS $SERVER_ITER > "$log_file" 2>&1 &
        pid_list+=($!)
        log_files+=("$log_file")
        echo "  - Started server test process $i with PID ${pid_list[-1]}"
      done
      total_requests=$((process_count * REQUESTS_PER_PROCESS))
      ;;
    "writeRead")
      start_time=$(date +%s)
      for (( i=1; i<=$process_count; i++ )); do
        log_file="$LOGS_DIR/${test_type}_${i}_$(date +%s).log"
        node loadTest/fetchData.js writeRead $REQUESTS_PER_PROCESS $WRITE_READ_ITER > "$log_file" 2>&1 &
        pid_list+=($!)
        log_files+=("$log_file")
        echo "  - Started writeRead test process $i with PID ${pid_list[-1]}"
      done
      # Write/read has roughly 1.1 requests per iteration due to the mix of operations
      total_requests=$((process_count * REQUESTS_PER_PROCESS * 11 / 10))
      ;;
    "pending")
      start_time=$(date +%s)
      for (( i=1; i<=$process_count; i++ )); do
        log_file="$LOGS_DIR/${test_type}_${i}_$(date +%s).log"
        node loadTest/fetchData.js pending $PENDING_COUNT $PENDING_TIME > "$log_file" 2>&1 &
        pid_list+=($!)
        log_files+=("$log_file")
        echo "  - Started pending connections test process $i with PID ${pid_list[-1]}"
      done
      total_requests=$((process_count * PENDING_COUNT))
      ;;
    "combined")
      start_time=$(date +%s)
      for (( i=1; i<=$process_count; i++ )); do
        # Choose a random test type
        test_types=("server" "writeRead" "pending")
        random_index=$((RANDOM % 3))
        random_test=${test_types[$random_index]}
        log_file="$LOGS_DIR/${test_type}_${random_test}_${i}_$(date +%s).log"
        
        case $random_test in
          "server")
            node loadTest/fetchData.js server $REQUESTS_PER_PROCESS $SERVER_ITER > "$log_file" 2>&1 &
            pid_list+=($!)
            log_files+=("$log_file")
            echo "  - Started random test (server) with PID ${pid_list[-1]}"
            total_requests=$((total_requests + REQUESTS_PER_PROCESS))
            ;;
          "writeRead")
            node loadTest/fetchData.js writeRead $REQUESTS_PER_PROCESS $WRITE_READ_ITER > "$log_file" 2>&1 &
            pid_list+=($!)
            log_files+=("$log_file")
            echo "  - Started random test (writeRead) with PID ${pid_list[-1]}"
            total_requests=$((total_requests + REQUESTS_PER_PROCESS * 11 / 10))
            ;;
          "pending")
            node loadTest/fetchData.js pending $PENDING_COUNT $PENDING_TIME > "$log_file" 2>&1 &
            pid_list+=($!)
            log_files+=("$log_file")
            echo "  - Started random test (pending) with PID ${pid_list[-1]}"
            total_requests=$((total_requests + PENDING_COUNT))
            ;;
        esac
        
        # Small delay to stagger starts
        sleep 1
      done
      ;;
  esac
  
  # Monitor server and processes
#   echo "  - Monitoring server health..."
  local server_crashed=false
  local completed_processes=0
  local crash_time=""
  
  while [[ $completed_processes -lt ${#pid_list[@]} ]]; do
    # Check if server is still responsive every 5 seconds
#     if ! $server_crashed && ! check_server; then
#       crash_time=$(date +%s)
#       echo "❌ SERVER CRASHED at $crash_time during $test_type test!"
#       server_crashed=true
#
#       sleep 1
#
#       # Count completed requests before crash
#       local total=0
#       local failed=0
#       for log_file in "${log_files[@]}"; do
#         if [ -f "$log_file" ]; then
#           local log_count=$(grep -c "^fetch$" "$log_file" 2>/dev/null)
#           [[ "$log_count" =~ ^[0-9]+$ ]] || log_count=0
#           total=$((total + log_count))
#           log_count=$(grep -c "fetch failed" "$log_file" 2>/dev/null)
#           [[ "$log_count" =~ ^[0-9]+$ ]] || log_count=0
#           failed=$((failed + log_count))
#         fi
#       done
#       local actual_requests=$((total - failed))
#       echo "  - Approximately $total requests were sent before crash"
#       echo "  - Approximately $actual_requests were successful"
#
#       # Kill remaining processes
#       for pid in "${pid_list[@]}"; do
#         if kill -0 $pid 2>/dev/null; then
#           kill $pid 2>/dev/null
#         fi
#       done
#       break
#     fi
    
    # Check process status
    completed_processes=0
    for i in "${!pid_list[@]}"; do
      if ! kill -0 ${pid_list[$i]} 2>/dev/null; then
        completed_processes=$((completed_processes + 1))
      fi
    done
    
    echo -ne "  - Progress: $completed_processes/${#pid_list[@]} processes completed\r"
    sleep 1
  done
  
  echo ""
  
  # Calculate statistics if no crash occurred
  if ! $server_crashed; then
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Count actual requests from logs
    local total=0
    local failed=0
    for log_file in "${log_files[@]}"; do
      if [ -f "$log_file" ]; then
        local log_count=$(grep -c "^fetch$" "$log_file" 2>/dev/null)
        [[ "$log_count" =~ ^[0-9]+$ ]] || log_count=0
        total=$((total + log_count))
        log_count=$(grep -c "fetch failed" "$log_file" 2>/dev/null)
        [[ "$log_count" =~ ^[0-9]+$ ]] || log_count=0
        failed=$((failed + log_count))
      fi
    done
    local actual_requests=$((total - failed))

    if [ $duration -gt 0 ]; then
      local requests_per_second=$(bc <<< "scale=2; $total / $duration")
      echo "✅ $test_type test completed successfully"
      echo "📈 Statistics:"
      echo "  - Total requests: $total"
      echo "  - Total success: $actual_requests"
      echo "  - Test duration: $duration seconds"
      echo "  - Throughput: $requests_per_second requests/second"
    else
      echo "✅ $test_type test completed too quickly to measure throughput"
    fi
  else
    echo "❌ $test_type test aborted due to server crash"
  fi
}

# Main script execution
echo "🚀 Cluster test script"
echo "URL: $URL"
echo "Concurrent processes: $CONCURRENT_PROCESSES"
echo "Test type: $TEST_TYPE"

# Run the specified test
run_test "$TEST_TYPE" "$CONCURRENT_PROCESSES"

if [ -d "$LOGS_DIR" ]; then
  echo "📝 Test logs available in $LOGS_DIR directory"
fi
