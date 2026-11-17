# ==============================================================================
# Complete Local API Automation Test Suite Orchestrator
# Executes: Native PowerShell Suite, Newman (Postman CLI), and Bruno CLI
# ==============================================================================
param(
    [string]$BaseUrl = "http://127.0.0.1:5055",
    [switch]$SkipNewman,
    [switch]$SkipBruno,
    [switch]$KeepServerRunning
)

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "     REST API TEST AUTOMATION ORCHESTRATOR (CI / LOCAL)         " -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host " Target Base URL: $BaseUrl" -ForegroundColor Gray
Write-Host ""

$serverProcess = $null
$startedServerLocally = $false

# ------------------------------------------------------------------------------
# 1. Health Probe & Server Auto-Start
# ------------------------------------------------------------------------------
Write-Host "[1/4] Checking REST API Server Availability..." -ForegroundColor Yellow
$isAlive = $false
try {
    $health = Invoke-RestMethod -Uri "$BaseUrl/" -Method Get -Headers @{ "Accept" = "application/json" } -TimeoutSec 2 -ErrorAction Stop
    if ($health.status -eq "online") {
        $isAlive = $true
        Write-Host "      ✓ REST API Server is already online at $BaseUrl" -ForegroundColor Green
    }
} catch {
    $isAlive = $false
}

if (-not $isAlive) {
    Write-Host "      ⚡ API Server not detected. Launching .\server.ps1 in background..." -ForegroundColor Yellow
    $serverScript = Join-Path $PSScriptRoot "server.ps1"
    $serverProcess = Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$serverScript`"" -PassThru
    $startedServerLocally = $true
    
    # Wait for server readiness
    $ready = $false
    for ($i = 1; $i -le 15; $i++) {
        Start-Sleep -Milliseconds 600
        try {
            $h = Invoke-RestMethod -Uri "$BaseUrl/" -Method Get -Headers @{ "Accept" = "application/json" } -TimeoutSec 1 -ErrorAction Stop
            if ($h.status -eq "online") {
                $ready = $true
                break
            }
        } catch {}
    }
    
    if ($ready) {
        Write-Host "      ✓ Background API Server successfully started (PID: $($serverProcess.Id))" -ForegroundColor Green
    } else {
        Write-Host "      ❌ Failed to start background API server. Exiting." -ForegroundColor Red
        exit 1
    }
}

# Ensure test-reports directory exists
$reportsDir = Join-Path $PSScriptRoot "test-reports"
if (-not (Test-Path $reportsDir)) {
    New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
}

$overallSuccess = $true

# ------------------------------------------------------------------------------
# 2. Run Native 12-Stage PowerShell Test Runner
# ------------------------------------------------------------------------------
Write-Host ""
Write-Host "[2/4] Executing Native 12-Stage PowerShell Automation Suite..." -ForegroundColor Yellow
$runnerScript = Join-Path $PSScriptRoot "test-runner.ps1"
& powershell -ExecutionPolicy Bypass -File $runnerScript -BaseUrl $BaseUrl
if ($LASTEXITCODE -ne 0) {
    $overallSuccess = $false
    Write-Host "      ❌ PowerShell Test Runner reported failures." -ForegroundColor Red
} else {
    Write-Host "      ✓ Native PowerShell Suite passed 100%!" -ForegroundColor Green
}

# ------------------------------------------------------------------------------
# 3. Run Postman Collection via Newman CLI
# ------------------------------------------------------------------------------
Write-Host ""
Write-Host "[3/4] Executing Postman Test Collection via Newman CLI..." -ForegroundColor Yellow

if ($SkipNewman) {
    Write-Host "      [SKIPPED] Newman suite skipped by flag." -ForegroundColor DarkGray
} else {
    $newmanCmd = Get-Command newman -ErrorAction SilentlyContinue
    $postmanCollection = Join-Path $PSScriptRoot "postman\Products_API.postman_collection.json"
    $postmanEnv = Join-Path $PSScriptRoot "postman\Local_Environment.postman_environment.json"
    $htmlReport = Join-Path $reportsDir "newman-report.html"
    $junitReport = Join-Path $reportsDir "newman-junit.xml"

    if ($newmanCmd) {
        Write-Host "      Running: newman run ..." -ForegroundColor Cyan
        & newman run $postmanCollection -e $postmanEnv `
            --reporters cli,htmlextra,junit `
            --reporter-htmlextra-export $htmlReport `
            --reporter-junit-export $junitReport `
            --reporter-htmlextra-title "Product Catalog REST API - Automated Report"
        
        if ($LASTEXITCODE -ne 0) {
            $overallSuccess = $false
            Write-Host "      ❌ Newman reported test failures." -ForegroundColor Red
        } else {
            Write-Host "      ✓ Newman Postman Suite completed successfully!" -ForegroundColor Green
            Write-Host "      📄 HTML Report generated: $htmlReport" -ForegroundColor Gray
        }
    } else {
        Write-Host "      ⚠️ Newman is not installed globally." -ForegroundColor DarkYellow
        Write-Host "         To install: npm install -g newman newman-reporter-htmlextra" -ForegroundColor DarkGray
        Write-Host "         Or run via npx: npx newman run postman/Products_API.postman_collection.json -e postman/Local_Environment.postman_environment.json" -ForegroundColor DarkGray
    }
}

# ------------------------------------------------------------------------------
# 4. Run Bruno Collection via Bruno CLI
# ------------------------------------------------------------------------------
Write-Host ""
Write-Host "[4/4] Executing Bruno Test Collection via Bruno CLI (@usebruno/cli)..." -ForegroundColor Yellow

if ($SkipBruno) {
    Write-Host "      [SKIPPED] Bruno suite skipped by flag." -ForegroundColor DarkGray
} else {
    $bruCmd = Get-Command bru -ErrorAction SilentlyContinue
    $brunoDir = Join-Path $PSScriptRoot "bruno"

    if ($bruCmd) {
        Write-Host "      Running: bru run bruno --env local ..." -ForegroundColor Cyan
        & bru run $brunoDir --env local
        if ($LASTEXITCODE -ne 0) {
            $overallSuccess = $false
            Write-Host "      ❌ Bruno CLI reported test failures." -ForegroundColor Red
        } else {
            Write-Host "      ✓ Bruno CLI collection passed 100%!" -ForegroundColor Green
        }
    } else {
        Write-Host "      ⚠️ Bruno CLI (bru) is not installed globally." -ForegroundColor DarkYellow
        Write-Host "         To install: npm install -g @usebruno/cli" -ForegroundColor DarkGray
        Write-Host "         Or run via npx: npx @usebruno/cli run bruno --env local" -ForegroundColor DarkGray
    }
}

# ------------------------------------------------------------------------------
# Cleanup
# ------------------------------------------------------------------------------
if ($startedServerLocally -and -not $KeepServerRunning) {
    Write-Host ""
    Write-Host "Shutting down temporary background API server (PID: $($serverProcess.Id))..." -ForegroundColor DarkGray
    Stop-Process -Id $serverProcess.Id -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
if ($overallSuccess) {
    Write-Host "   🎉 ALL AUTOMATED TEST SUITES COMPLETED WITH SUCCESS!        " -ForegroundColor Green
} else {
    Write-Host "   ⚠️ ONE OR MORE TEST SUITES REPORTED FAILURES                " -ForegroundColor Red
}
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

if ($overallSuccess) { exit 0 } else { exit 1 }
