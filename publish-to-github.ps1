# ==============================================================================
# Automated GitHub Repository Creator & Committer (Zero Dependencies / REST API)
# ==============================================================================
param(
    [string]$Token = $env:GITHUB_TOKEN,
    [string]$RepoName = "api-testing-mastery",
    [string]$Description = "API & API Testing Masterclass: Swagger UI, Bruno & Postman with full REST API",
    [switch]$IsPrivate = $false
)

$ErrorActionPreference = "Stop"

# Force TLS 1.2 and bypass proxy discovery for GitHub API
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
[System.Net.WebRequest]::DefaultWebProxy = $null

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "   GITHUB REPOSITORY CREATOR & COMMITTER (VIA GITHUB REST API)   " -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

if ([string]::IsNullOrWhiteSpace($Token)) {
    Write-Host "[!] GitHub Personal Access Token (PAT) not found." -ForegroundColor Yellow
    Write-Host "    You need a GitHub token with 'repo' scope." -ForegroundColor Yellow
    Write-Host "    Generate one in 30 seconds at: https://github.com/settings/tokens" -ForegroundColor Yellow
    Write-Host ""
    $Token = Read-Host -Prompt "Enter your GitHub Personal Access Token"
}

if ([string]::IsNullOrWhiteSpace($Token)) {
    Write-Host "Error: A valid GitHub token is required to create a repository." -ForegroundColor Red
    exit 1
}

$headers = @{
    "Authorization" = "token $Token"
    "Accept" = "application/vnd.github.v3+json"
    "User-Agent" = "Antigravity-API-Masterclass-Publisher"
}

# 1. Verify User Credentials
Write-Host "[-] Verifying GitHub authentication..." -ForegroundColor DarkGray
try {
    $user = Invoke-RestMethod -Uri "https://api.github.com/user" -Method Get -Headers $headers
    $username = $user.login
    Write-Host "[+] Authenticated as: $username" -ForegroundColor Green
} catch {
    Write-Host "[X] Authentication failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "    Please ensure your Personal Access Token is valid and has 'repo' permissions." -ForegroundColor Yellow
    exit 1
}

# 2. Create or Locate Repository
$repoUrl = "https://api.github.com/repos/$username/$RepoName"
$repoExists = $false

try {
    $existingRepo = Invoke-RestMethod -Uri $repoUrl -Method Get -Headers $headers
    $repoExists = $true
    Write-Host "[+] Repository '$username/$RepoName' already exists. Committing updates..." -ForegroundColor Green
} catch {
    # If 404, we create it
    Write-Host "[-] Creating new repository '$RepoName' on GitHub..." -ForegroundColor Cyan
    $createPayload = @{
        name = $RepoName
        description = $Description
        private = [bool]$IsPrivate
        has_issues = $true
        has_wiki = $false
        auto_init = $true # creates initial commit with README so main branch exists
    } | ConvertTo-Json
    
    try {
        $newRepo = Invoke-RestMethod -Uri "https://api.github.com/user/repos" -Method Post -Headers $headers -Body $createPayload
        Write-Host "[+] Repository created successfully at: $($newRepo.html_url)" -ForegroundColor Green
        Start-Sleep -Seconds 2 # wait for git tree initialization
    } catch {
        Write-Host "[X] Failed to create repository: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# 3. Collect Files to Upload
$rootDir = $PSScriptRoot
$excludedExtensions = @(".log", ".tmp")
$excludedFolders = @(".git", ".gemini", "node_modules", ".venv", "venv")

$allFiles = Get-ChildItem -Path $rootDir -Recurse -File | Where-Object {
    $file = $_
    $rel = $file.FullName.Substring($rootDir.Length).TrimStart("\", "/")
    
    # Check folder exclusion
    $inExcludedFolder = $false
    foreach ($ef in $excludedFolders) {
        if ($rel.StartsWith("$ef\") -or $rel.StartsWith("$ef/") -or $rel -eq $ef) {
            $inExcludedFolder = $true
            break
        }
    }
    if ($inExcludedFolder) { return $false }
    
    # Check extension exclusion
    if ($excludedExtensions -contains $file.Extension) { return $false }
    
    # Do not upload the publisher script itself unless desired
    return $true
}

Write-Host "[-] Found $($allFiles.Count) files to commit and upload..." -ForegroundColor Cyan

# 4. Commit Files via GitHub Contents API
$successCount = 0
$failCount = 0

foreach ($file in $allFiles) {
    $relPath = $file.FullName.Substring($rootDir.Length).TrimStart("\", "/").Replace("\", "/")
    $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
    $b64Content = [Convert]::ToBase64String($bytes)
    
    # Check if file exists in target repo to retrieve its current SHA
    $fileUrl = "https://api.github.com/repos/$username/$RepoName/contents/$relPath"
    $sha = $null
    try {
        $existingFile = Invoke-RestMethod -Uri $fileUrl -Method Get -Headers $headers
        $sha = $existingFile.sha
    } catch {
        # File doesn't exist yet, which is normal for initial push
    }
    
    $bodyObj = [ordered]@{
        message = "Add/Update $relPath"
        content = $b64Content
    }
    if ($sha) {
        $bodyObj["sha"] = $sha
    }
    $putBody = $bodyObj | ConvertTo-Json
    
    try {
        $uploadRes = Invoke-RestMethod -Uri $fileUrl -Method Put -Headers $headers -Body $putBody
        Write-Host " [PASS] Commited: $relPath" -ForegroundColor Green
        $successCount++
    } catch {
        Write-Host " [FAIL] Failed: $relPath - $($_.Exception.Message)" -ForegroundColor Red
        $failCount++
    }
    
    # Slight pause to avoid GitHub API rate limit burst
    Start-Sleep -Milliseconds 250
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "                     DEPLOYMENT SUMMARY" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host " REPOSITORY: https://github.com/$username/$RepoName" -ForegroundColor Cyan
Write-Host " COMMITTED : $successCount files" -ForegroundColor Green
if ($failCount -gt 0) {
    Write-Host " FAILED    : $failCount files" -ForegroundColor Red
}
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Your complete API & API Testing project is now live on GitHub!" -ForegroundColor Green
