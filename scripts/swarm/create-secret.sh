#!/bin/bash
set -e

# Check if we have the right number of arguments
if [ $# -ne 2 ]; then
  echo "Error: Incorrect number of arguments"
  echo "Usage: $0 secret_name \"Secret content\""
  exit 1
fi

SECRET_NAME=$1
SECRET_CONTENT=$2

# Create the secret
printf "%s" "$SECRET_CONTENT" | docker secret create "$SECRET_NAME" -

# Check if the secret was created successfully
if [ $? -eq 0 ]; then
  echo "Secret '$SECRET_NAME' created successfully"
else
  echo "Failed to create secret '$SECRET_NAME'"
  exit 1
fi
