# Hugo static blog deployment script
# Author https://owu.github.io
# Version 2025-12-26 20:00:00

$SRC_DIR = "D:\develop\owu.github.com"
$DST_DIR = "D:\develop\owu.github.io"

# Step 1: Update SOURCE repository to latest main branch version
Write-Host "Updating $SRC_DIR repository to latest version..."
Set-Location -Path $SRC_DIR
git checkout main
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to switch to main branch" -ForegroundColor Red
    exit 1
}

# Reset local changes to ensure consistency with remote repository
git reset --hard
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to reset local changes" -ForegroundColor Red
    exit 1
}

git pull
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to pull latest code" -ForegroundColor Red
    exit 1
}

# Step 2: Navigate to blog directory and execute hugo to generate static blog
Write-Host "Generating Hugo static blog..."
hugo build
if ($LASTEXITCODE -ne 0) {
    Write-Host "Hugo generation failed" -ForegroundColor Red
    exit 1
}

# Step 3: Use git to export clean public directory code
Write-Host "Exporting public directory code..."
$TEMP_DIR = New-TemporaryFile | ForEach-Object { $_.FullName -replace '\.tmp$', '' }
New-Item -ItemType Directory -Path $TEMP_DIR | Out-Null


# Export public directory
git archive --format=zip main public --output="$TEMP_DIR\public.zip"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to export public directory" -ForegroundColor Red
    Remove-Item -Path $TEMP_DIR -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

# Extract the exported zip file
Expand-Archive -Path "$TEMP_DIR\public.zip" -DestinationPath $TEMP_DIR -Force
$EXTRACTED_PUBLIC = Join-Path -Path $TEMP_DIR -ChildPath "public"

# Debug: Check if EXTRACTED_PUBLIC directory exists and its contents
Write-Host "Debug: EXTRACTED_PUBLIC path: $EXTRACTED_PUBLIC"
if (Test-Path -Path $EXTRACTED_PUBLIC) {
    Write-Host "Debug: EXTRACTED_PUBLIC directory exists"
    Write-Host "Debug: EXTRACTED_PUBLIC directory contents:"
    Get-ChildItem -Path $EXTRACTED_PUBLIC -Force
} else {
    Write-Host "Debug: EXTRACTED_PUBLIC directory does not exist" -ForegroundColor Red
    exit 1
}

# Step 4: Navigate to DST_DIR directory and pull latest code
Write-Host "Updating $DST_DIR repository to latest version..."
Set-Location -Path $DST_DIR
git checkout main
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to switch to main branch" -ForegroundColor Red
    Remove-Item -Path $TEMP_DIR -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

git pull
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to pull latest code" -ForegroundColor Red
    Remove-Item -Path $TEMP_DIR -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

# Step 5: Delete all files and directories in DST_DIR except .git
Write-Host "Cleaning $DST_DIR directory..."
Get-ChildItem -Path $DST_DIR -Exclude ".git" -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

# Step 6: Copy exported public directory contents to DST_DIR
Write-Host "Copying public directory contents to $DST_DIR ..."
# Use * to copy all contents of public directory (including subdirectories and hidden files)
Copy-Item -Path "$EXTRACTED_PUBLIC\*" -Destination $DST_DIR -Recurse -Force
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to copy public directory contents" -ForegroundColor Red
    Remove-Item -Path $TEMP_DIR -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

# Verify if target directory contains copied files
if ((Get-ChildItem -Path $DST_DIR -Exclude ".git" -Force | Measure-Object).Count -eq 0) {
    Write-Host "Error: Target directory is still empty, copy may have failed" -ForegroundColor Red
    Remove-Item -Path $TEMP_DIR -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

# Step 7: Clean up temporary directory
Remove-Item -Path $TEMP_DIR -Recurse -Force -ErrorAction SilentlyContinue

# Step 8: Commit and push to remote repository
Write-Host "Committing changes to remote repository..."
git add .
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to add files to staging area" -ForegroundColor Red
    exit 1
}

git commit -m "Update blog content"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to commit code" -ForegroundColor Red
    exit 1
}

git push
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to push code to remote repository" -ForegroundColor Red
    exit 1
}

# Step 9: Return to original directory
Set-Location -Path $SRC_DIR

Write-Host "Deployment completed!" -ForegroundColor Green