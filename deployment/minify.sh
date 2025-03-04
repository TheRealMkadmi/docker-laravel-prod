#!/bin/bash

# Create temporary directory for processed files
mkdir -p /tmp/public_minified

# Copy all files to temp directory first
cp -r ${ROOT}/public/* /tmp/public_minified/

# Find and minify JS files
find /tmp/public_minified -type f -name "*.js" ! -name "*.min.js" -exec echo "Minifying JS: {}" \; -exec terser {} -o {} \;

# Find and minify CSS files
find /tmp/public_minified -type f -name "*.css" ! -name "*.min.css" -exec echo "Minifying CSS: {}" \; -exec cleancss -o {} {} \;

# Copy back to public directory
cp -r /tmp/public_minified/* ${ROOT}/public/

# Clean up
rm -rf /tmp/public_minified
