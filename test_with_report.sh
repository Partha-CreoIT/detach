#!/bin/bash

# Create coverage directory if it doesn't exist
mkdir -p coverage

# Run the integration tests with coverage
flutter test integration_test/home_test.dart --coverage

# Install lcov if not installed (macOS specific since we're on darwin)
if ! command -v lcov &> /dev/null; then
    brew install lcov
fi

# Generate HTML report
genhtml coverage/lcov.info -o coverage/html

echo "Test coverage report is available at coverage/html/index.html" 