#!/bin/bash
# Error diagnostics utilities for Docker container

# Enable error handling
set -e

# Log with timestamp and category using our standardized logger
log() {
  local message="$1"
  /usr/local/bin/logger.sh UTILITIES "${BASH_LINENO[0]}"
}

# Ensure required directories exist
ensure_dirs() {
  log "Ensuring required directories exist"
  
  # Create directories for logs and socket files
  for dir in /tmp/nginx_logs; do
    if [ ! -d "$dir" ]; then
      log "Creating directory: $dir"
      mkdir -p "$dir"
      chmod -R 755 "$dir"
    fi
  done
  
  # Create log files if they don't exist
  touch /tmp/error_502_history.log 2>/dev/null || log "Could not create error history log"
  
  log "Directory check complete"
}

# Monitor and log 502 errors by checking Nginx access logs
monitor_502_errors() {
  log "Starting 502 error monitoring..."
  
  # Ensure directories exist first
  ensure_dirs
  
  # Simple grep for 502 errors in nginx logs
  tail -f /dev/stdout | grep --line-buffered -i '502' | while read -r line; do
    log "502 Bad Gateway detected"
    log "Access log entry: $line"
    
    # Capture current state for diagnostics
    log "Capturing system state..."
    
    # Process state
    log "=== Process Status ==="
    ps aux | grep -E 'nginx|php|swoole|supervis' | grep -v grep | while read -r pline; do
      log "$pline"
    done
    
    # Socket state
    log "=== Socket Status ==="
    netstat -tunlp | grep -E '80|8000' | while read -r sline; do
      log "$sline"
    done
    
    # Supervisor status
    log "=== Supervisor Status ==="
    supervisorctl status all 2>&1 | while read -r sstatus; do
      log "$sstatus"
    done || log "Failed to get supervisor status"
    
    # Recent logs
    log "=== Recent Octane Errors ==="
    supervisorctl tail octane stderr 100 2>/dev/null | grep -i 'error\|exception\|fatal' | tail -20 | while read -r oline; do 
      log "$oline"
    done || log "Could not retrieve octane errors"
    
    # Memory usage
    log "=== Memory Status ==="
    free -m | while read -r mline; do
      log "$mline"
    done
    
    log "Diagnostics captured for 502 error"
    
    # Add to 502 error history for trend analysis
    echo "$(date +'%s') 502" >> /tmp/error_502_history.log
  done
}

# Check if Octane is running and responding
check_octane() {
  log "Checking Octane status..."
  
  # Direct request to Octane
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/ 2>/dev/null || echo "Connection failed")
  
  if [ "$HTTP_CODE" = "200" ]; then
    log "Octane is responding correctly (HTTP 200)"
    return 0
  else
    log "Octane returned HTTP $HTTP_CODE"
    
    # Check process
    if pgrep -f "php.*octane:start" > /dev/null; then
      log "Octane process exists but is not responding correctly"
      ps aux | grep -f "php.*octane:start" | grep -v grep | while read -r line; do
        log "$line"
      done
    else
      log "No Octane process found"
    fi
    
    return 1
  fi
}

# Recover from specific error conditions
recover_from_errors() {
  log "Running error recovery procedures..."
  
  # Ensure directories exist
  ensure_dirs
  
  # Check for common error patterns
  if ! check_octane; then
    log "Attempting to restart Octane..."
    supervisorctl restart octane 2>&1 | while read -r line; do
      log "$line"
    done || {
      log "Failed to restart Octane via supervisorctl"
      return 1
    }
    
    sleep 5
    
    if check_octane; then
      log "Octane successfully restarted"
    else
      log "Octane restart failed, check application logs"
    fi
  fi
  
  # Check Nginx
  if ! pgrep -x "nginx" > /dev/null; then
    log "Nginx not found, attempting restart..."
    supervisorctl restart nginx 2>&1 | while read -r line; do
      log "$line"
    done || log "Failed to restart nginx"
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
      log "Usage: $0 {monitor|check|recover|ensure_dirs}"
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
