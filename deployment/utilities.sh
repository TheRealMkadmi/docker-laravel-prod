#!/bin/bash
# Error diagnostics utilities for Docker container

# Enable error handling
set -e

# Log with timestamp and category
log() {
  local level="$1"
  local message="$2"
  echo "$(date +'%Y-%m-%d %H:%M:%S') [$level] $message"
}

# Ensure required directories exist
ensure_dirs() {
  log "INFO" "Ensuring required directories exist"
  
  # Create directories for logs and socket files
  for dir in /var/log/supervisor /var/run/supervisor /tmp/nginx_logs; do
    if [ ! -d "$dir" ]; then
      log "INFO" "Creating directory: $dir"
      mkdir -p "$dir"
      chmod -R 755 "$dir"
    fi
  done
  
  # Create log files if they don't exist
  touch /tmp/error_502_history.log 2>/dev/null || log "WARN" "Could not create error history log"
  
  log "INFO" "Directory check complete"
}

# Monitor and log 502 errors by checking Nginx access logs
monitor_502_errors() {
  log "INFO" "Starting 502 error monitoring..."
  
  # Ensure directories exist first
  ensure_dirs
  
  # Simple grep for 502 errors in nginx logs
  tail -f /dev/stdout | grep --line-buffered -i '502' | while read -r line; do
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
    supervisorctl status all || log "ERROR" "Failed to get supervisor status"
    
    # Recent logs
    log "DEBUG" "=== Recent Octane Errors ==="
    supervisorctl tail octane stderr 100 | grep -i 'error\|exception\|fatal' | tail -20 || log "WARN" "Could not retrieve octane errors"
    
    # Memory usage
    log "DEBUG" "=== Memory Status ==="
    free -m
    
    log "INFO" "Diagnostics captured for 502 error"
    
    # Add to 502 error history for trend analysis
    echo "$(date +'%s') 502" >> /tmp/error_502_history.log
  done
}

# Check if Octane is running and responding
check_octane() {
  log "INFO" "Checking Octane status..."
  
  # Direct request to Octane
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/ 2>/dev/null || echo "Connection failed")
  
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
  
  # Ensure directories exist
  ensure_dirs
  
  # Check for common error patterns
  if ! check_octane; then
    log "WARN" "Attempting to restart Octane..."
    supervisorctl restart octane || {
      log "ERROR" "Failed to restart Octane via supervisorctl"
      return 1
    }
    
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
    supervisorctl restart nginx || log "ERROR" "Failed to restart nginx"
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
    ensure_dirs)
      ensure_dirs
      ;;
    *)
      log "INFO" "Usage: $0 {monitor|check|recover|ensure_dirs}"
      exit 1
      ;;
  esac
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi

# Commonly used aliases
alias ..="cd .."
alias ...="cd ../.."
alias art="php artisan"
