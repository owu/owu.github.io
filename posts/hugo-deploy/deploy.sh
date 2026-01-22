#!/bin/bash

# Hugo static blog deployment script
# Author https://owu.github.io
# Version 2025-12-26 20:00:00

SRC_DIR="/home/develop/owu.github.com"
DST_DIR="/home/develop/owu.github.io"

# Step 1: Update SOURCE repository to latest main branch version
echo "Updating $SRC_DIR repository to latest version..."
cd "$SRC_DIR"
git checkout main
if [ $? -ne 0 ]; then
    echo "Failed to switch to main branch"
    exit 1
fi

# Reset local changes to ensure consistency with remote repository
git reset --hard
if [ $? -ne 0 ]; then
    echo "Failed to reset local changes"
    exit 1
fi

git pull
if [ $? -ne 0 ]; then
    echo "Failed to pull latest code"
    exit 1
fi

# Step 2: Navigate to blog directory and execute hugo to generate static blog
echo "Generating Hugo static blog..."

hugo build
if [ $? -ne 0 ]; then
    echo "Hugo generation failed"
    exit 1
fi

# Step 3: Use git to export clean public directory code
echo "Exporting public directory code..."
TEMP_DIR=$(mktemp -d)

# Ensure temporary directory is cleaned up on exit
function cleanup {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Export public directory
git archive --format=zip main public --output="$TEMP_DIR/public.zip"
if [ $? -ne 0 ]; then
    echo "Failed to export public directory"
    exit 1
fi

# Extract the exported zip file
unzip -q "$TEMP_DIR/public.zip" -d "$TEMP_DIR"
if [ $? -ne 0 ]; then
    echo "Failed to extract public.zip"
    exit 1
fi

# Get the extracted public directory
EXTRACTED_PUBLIC="$TEMP_DIR/public"

# Verify if extracted public directory exists and contains files
if [ ! -d "$EXTRACTED_PUBLIC" ]; then
    echo "Error: Public directory not found after extraction"
    exit 1
fi

if [ -z "$(ls -A \"$EXTRACTED_PUBLIC\")" ]; then
    echo "Error: Public directory is empty, nothing to copy"
    exit 1
fi

# Step 4: Navigate to DST_DIR directory and pull latest code
echo "Updating $DST_DIR repository to latest version..."
cd "$DST_DIR"
git checkout main
if [ $? -ne 0 ]; then
    echo "Failed to switch to main branch"
    exit 1
fi

git pull
if [ $? -ne 0 ]; then
    echo "Failed to pull latest code"
    exit 1
fi

# Step 5: Delete all files and directories in DST_DIR except .git
echo "Cleaning $DST_DIR directory..."
find "$DST_DIR" -mindepth 1 -maxdepth 1 ! -name ".git" -exec rm -rf {} \;

# Step 6: Copy exported public directory contents to DST_DIR
echo "Copying public directory contents to $DST_DIR ..."
# Use cp command with --preserve option to retain file attributes and ensure all content is copied
cp -r --preserve=all "$EXTRACTED_PUBLIC"/. "$DST_DIR/"
if [ $? -ne 0 ]; then
    echo "Failed to copy public directory contents"
    exit 1
fi

# Verify if target directory contains copied files
if [ -z "$(ls -A \"$DST_DIR\" 2>/dev/null)" ]; then
    echo "Error: Target directory is still empty, copy may have failed"
    exit 1
fi

# Step 7: Clean up temporary directory
echo "Cleaning temporary directory..."
rm -rf "$TEMP_DIR"

# Step 8: Commit and push to remote repository
echo "Committing changes to remote repository..."
git add .
if [ $? -ne 0 ]; then
    echo "Failed to add files to staging area"
    exit 1
fi

git commit -m "Update blog content"
if [ $? -ne 0 ]; then
    echo "Failed to commit code"
    exit 1
fi

git push
if [ $? -ne 0 ]; then
    echo "Failed to push code to remote repository"
    exit 1
fi

# Step 9: Return to original directory
cd "$SRC_DIR"

echo "Deployment completed!"