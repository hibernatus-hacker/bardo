#!/bin/bash

# Run all tests for the Bardo project
echo "Running tests for Bardo project..."
echo ""

# Run the tests using mix
MIX_ENV=test mix test

# Check if tests passed
if [ $? -eq 0 ]; then
  echo ""
  echo "✅ All tests passed!"
else
  echo ""
  echo "❌ Some tests failed."
fi