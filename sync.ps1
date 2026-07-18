# Git Synchronization Script for namn20.github.io
# Enable UTF-8 encoding for Output
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " namn20.github.io Git Sync Started" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. Pull latest changes
Write-Host "`n[1/3] Pulling latest changes from remote..." -ForegroundColor Yellow
git pull origin main

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error pulling changes from remote. Please resolve any conflicts manually." -ForegroundColor Red
    Read-Host "Press Enter to exit..."
    exit $LASTEXITCODE
}

# 2. Check for local changes
$status = git status --porcelain
if ([string]::IsNullOrEmpty($status)) {
    Write-Host "`nNo local changes detected. Workspace is up-to-date." -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Cyan
    Read-Host "Press Enter to exit..."
    exit 0
}

Write-Host "`nLocal changes detected:" -ForegroundColor Yellow
git status -s

# Ask user if they want to commit and push
$choice = Read-Host "`nDo you want to commit and push these changes? (Y/N)"
if ($choice -match '^[Yy]$' -or [string]::IsNullOrEmpty($choice)) {
    $msg = Read-Host "Enter commit message (default: 'Update blog content')"
    if ([string]::IsNullOrEmpty($msg)) {
        $msg = "Update blog content"
    }
    
    # 3. Add, Commit, Push
    Write-Host "`n[2/3] Adding and committing changes..." -ForegroundColor Yellow
    git add -A
    git commit -m "$msg"
    
    Write-Host "`n[3/3] Pushing changes to remote..." -ForegroundColor Yellow
    git push origin main
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`nSuccessfully synchronized with GitHub!" -ForegroundColor Green
    } else {
        Write-Host "`nFailed to push changes. Please check your GitHub credentials/permissions." -ForegroundColor Red
    }
} else {
    Write-Host "`nSync cancelled by user." -ForegroundColor Gray
}

Write-Host "==========================================" -ForegroundColor Cyan
Read-Host "Press Enter to exit..."
