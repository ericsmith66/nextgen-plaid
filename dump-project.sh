#!/bin/bash

# Save as dump-project-full.sh and run from project root
OUTPUT="nextgen-plaid-full-dump-$(date +%Y%m%d-%H%M%S).txt"

echo "=== NEXTGEN-PLAID FULL PROJECT DUMP == $(date) ===" > "$OUTPUT"
echo "Generated from: $(pwd)" >> "$OUTPUT"
echo >> "$OUTPUT"

# Find and dump all relevant files
find . -type f \( \
  -name "*.rb" -o \
  -name "*.erb" -o \
  -name "*.html.erb" -o \
  -name "*.yml" -o \
  -name "*.json" -o \
  -name "Gemfile" -o \
  -name "Rakefile" -o \
  -name ".env" \) | sort | while read file; do
  echo "====================================================================" >> "$OUTPUT"
  echo "=== FILE: $file ===" >> "$OUTPUT"
  echo "====================================================================" >> "$OUTPUT"
  if [[ "$file" == *".env"* ]]; then
    echo "# .env (keys masked for safety)" >> "$OUTPUT"
    sed 's/PLAID_CLIENT_ID=.*/PLAID_CLIENT_ID=***MASKED***/; s/PLAID_SECRET=.*/PLAID_SECRET=***MASKED***/; s/ENCRYPTION_KEY=.*/ENCRYPTION_KEY=***MASKED***/' "$file" 2>/dev/null || cat "$file" >> "$OUTPUT"
  else
    cat "$file" 2>/dev/null || echo "# FILE NOT READABLE OR EMPTY" >> "$OUTPUT"
  fi
  echo -e "\n\n" >> "$OUTPUT"
done

echo "=== DUMP COMPLETE ===" >> "$OUTPUT"
echo "File created: $OUTPUT"
echo "Size: $(du -h "$OUTPUT" | cut -f1)"