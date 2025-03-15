#!/bin/bash
# Error diagnostics utilities for Docker container

# Enable error handling and exit on error
set -e

# Log with timestamp and category
log() {
  local level="$1"
  local message="$2"
  echo "$(date +'%Y-%m-%d %H:%M:%S') [$level] $message"
}

# Monitor and log 502 errors by checking Nginx access logs
monitor_502_errors() {
  log "INFO" "Starting 502 error monitoring..."
  
  # Create fifo for log streaming
  FIFO_PATH="/tmp/nginx_log_fifo"
  if [ ! -p "$FIFO_PATH" ]; then
    mkfifo "$FIFO_PATH"
  fi
  
  # Redirect nginx access log to fifo
  tail -f /dev/stdout | grep -i '502' > "$FIFO_PATH" &
  TAIL_PID=$!
  
  # Read from fifo and process 502 errors
  while read -r line; do
    log "ERROR" "502 Bad Gateway detected"
    log "DEBUG" "Access log entry: $line"
    
    # Capture current state for diagnostics
    log "DEBUG" "Capturing system state..."
    
    # Process state
    log "DEBUG" "=== Process Status ==="
    ps aux | grep -E 'nginx|php|swoole|supervis' | grep -v grep
    
    # Socket state
    log "DEBUG" "=== Socket Status ==="
    netstat -tunlp | grep -E '80|8000'
    
    # Supervisor status
    log "DEBUG" "=== Supervisor Status ==="
    supervisorctl status all
    
    # Recent logs
    log "DEBUG" "=== Recent Octane Errors ==="
    supervisorctl tail octane stderr 100 | grep -i 'error\|exception\|fatal' | tail -20
    
    # Memory usage
    log "DEBUG" "=== Memory Status ==="
    free -m
    
    log "INFO" "Diagnostics captured for 502 error"
    
    # Add to 502 error history for trend analysis
    echo "$(date +'%s') 502" >> /tmp/error_502_history.log
  done < "$FIFO_PATH"
  
  # Cleanup
  kill $TAIL_PID
}

# Check if Octane is running and responding
check_octane() {
  log "INFO" "Checking Octane status..."
  
  # Direct request to Octane
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/)
  
  if [ "$HTTP_CODE" = "200" ]; then
    log "INFO" "Octane is responding correctly (HTTP 200)"
    return 0
  else
    log "ERROR" "Octane returned HTTP $HTTP_CODE"
    
    # Check process
    if pgrep -f "php.*octane:start" > /dev/null; then
      log "DEBUG" "Octane process exists but is not responding correctly"
      ps aux | grep -f "php.*octane:start" | grep -v grep
    else
      log "ERROR" "No Octane process found"
    fi
    
    return 1
  fi
}

# Recover from specific error conditions
recover_from_errors() {
  log "INFO" "Running error recovery procedures..."
  
  # Check for common error patterns
  if ! check_octane; then
    log "WARN" "Attempting to restart Octane..."
    supervisorctl restart octane
    sleep 5
    
    if check_octane; then
      log "INFO" "Octane successfully restarted"
    else
      log "ERROR" "Octane restart failed, check application logs"
    fi
  fi
  
  # Check Nginx
  if ! pgrep -x "nginx" > /dev/null; then
    log "WARN" "Nginx not found, attempting restart..."
    supervisorctl restart nginx
    sleep 2
  fi
}

# Main function
main() {
  case "$1" in
    monitor)
      monitor_502_errors
      ;;
    check)
      check_octane
      ;;
    recover)
      recover_from_errors
      ;;
    *)
      log "INFO" "Usage: $0 {monitor|check|recover}"
      exit 1
      ;;
  esac
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi

tinker() {
  if [ -z "$1" ]; then
    php artisan tinker
  else
    php artisan tinker --execute="\"dd($1);\""
  fi
}

# Commonly used aliases
alias ..="cd .."
alias ...="cd ../.."
alias art="php artisan"
