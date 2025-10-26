#!/bin/bash

# Wait for Firestore index to be ready, then run tests

echo "======================================================================"
echo "🔍 Monitoring Firestore Index Build Status"
echo "======================================================================"
echo ""
echo "Checking index status every 30 seconds..."
echo "Press Ctrl+C to cancel"
echo ""

while true; do
  # Check index status
  STATUS=$(gcloud firestore indexes composite list --project=wickett-13423 2>&1 | grep "transactions" | awk '{print $10}')

  echo "[$(date '+%H:%M:%S')] Index status: $STATUS"

  if [ "$STATUS" = "READY" ]; then
    echo ""
    echo "======================================================================"
    echo "✅ INDEX IS READY!"
    echo "======================================================================"
    echo ""
    echo "🚀 Starting mainnet transaction tests..."
    echo ""

    # Run the tests
    node /Users/syndicatemike/Wickett/test-mainnet-cli.js

    exit 0
  fi

  # Wait 30 seconds before checking again
  sleep 30
done
