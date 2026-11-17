# ==============================================================================
# Automated API Test Suite Runner
# ==============================================================================
param(
    [string]$BaseUrl = "http://127.0.0.1:5055"
)

$ErrorActionPreference = "Continue"

# Disable proxy lookup for blazing fast local loopback requests
[System.Net.WebRequest]::DefaultWebProxy = $null

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "   API TESTING LAB - AUTOMATED END-TO-END TEST RUNNER" -ForegroundColor Cyan
Write-Host "   Target: $BaseUrl" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# State variables
$token = ""
$createdId = ""
$passedCount = 0
$failedCount = 0
$testResults = [System.Collections.ArrayList]::new()

function Execute-Test {
    param(
        [string]$TestName,
        [scriptblock]$Action
    )
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $status = "FAIL"
    $detail = ""
    
    try {
        $result = & $Action
        $stopwatch.Stop()
        $status = "PASS"
        $script:passedCount++
        Write-Host " [PASS] $TestName ($($stopwatch.ElapsedMilliseconds)ms)" -ForegroundColor Green
        if ($result) {
            Write-Host "        -> $result" -ForegroundColor DarkGray
        }
    } catch {
        $stopwatch.Stop()
        $status = "FAIL"
        $detail = $_.Exception.Message
        $script:failedCount++
        Write-Host " [FAIL] $TestName ($($stopwatch.ElapsedMilliseconds)ms)" -ForegroundColor Red
        Write-Host "        -> Error: $detail" -ForegroundColor DarkYellow
    }
    
    [void]$script:testResults.Add([PSCustomObject]@{
        Name = $TestName
        Status = $status
        DurationMs = $stopwatch.ElapsedMilliseconds
        Detail = $detail
    })
}

# 1. Server Health Check
Execute-Test "01. Server Health & Root Check (GET /)" {
    $res = Invoke-RestMethod -Uri "$BaseUrl/" -Method Get -Headers @{ "Accept" = "application/json" }
    if ($res.status -ne "online") { throw "Expected status 'online', got '$($res.status)'" }
    return "API Online (Version: $($res.version))"
}

# 2. OpenAPI Spec Check
Execute-Test "02. OpenAPI Specification Verification (GET /openapi.json)" {
    $spec = Invoke-RestMethod -Uri "$BaseUrl/openapi.json" -Method Get
    if (-not $spec.openapi.StartsWith("3.")) { throw "Invalid OpenAPI version: $($spec.openapi)" }
    if (-not $spec.paths."/api/v1/products") { throw "Missing /api/v1/products in spec paths" }
    return "OpenAPI $($spec.openapi) validated with $($spec.paths.PSObject.Properties.Count) path items"
}

# 3. Authentication - Valid Credentials
Execute-Test "03. User Authentication - Valid Credentials (POST /api/v1/auth/login)" {
    $body = @{ username = "admin"; password = "password123" } | ConvertTo-Json
    $res = Invoke-RestMethod -Uri "$BaseUrl/api/v1/auth/login" -Method Post -Body $body -ContentType "application/json"
    if (-not $res.token) { throw "No token returned in response" }
    $script:token = $res.token
    return "Bearer token received: $($script:token.Substring(0, 20))..."
}

# 4. Authentication - Invalid Credentials (Negative Test)
Execute-Test "04. User Authentication - Invalid Credentials Negative Test (401 Expected)" {
    $body = @{ username = "admin"; password = "badPassword" } | ConvertTo-Json
    try {
        $res = Invoke-RestMethod -Uri "$BaseUrl/api/v1/auth/login" -Method Post -Body $body -ContentType "application/json"
        throw "Expected HTTP 401, but call succeeded!"
    } catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 401) {
            return "Correctly rejected with 401 Unauthorized"
        } else {
            throw "Expected 401 status, got: $($_.Exception.Message)"
        }
    }
}

# 5. List Products
Execute-Test "05. List Products with Pagination (GET /api/v1/products)" {
    $res = Invoke-RestMethod -Uri "$BaseUrl/api/v1/products?page=1&limit=5" -Method Get
    if ($res.items.Count -eq 0) { throw "Items array is empty" }
    if ($res.pagination.page -ne 1) { throw "Page number mismatch" }
    return "Retrieved $($res.items.Count) products out of total $($res.pagination.total)"
}

# 6. Query Filtering
Execute-Test "06. Filter Products by Category (GET /api/v1/products?category=Audio)" {
    $res = Invoke-RestMethod -Uri "$BaseUrl/api/v1/products?category=Audio" -Method Get
    foreach ($item in $res.items) {
        if ($item.category -ne "Audio") { throw "Product $($item.name) has category $($item.category), expected 'Audio'" }
    }
    return "All $($res.items.Count) items matched category 'Audio'"
}

# 7. Create Product without Token (Negative Test)
Execute-Test "07. Create Product without Token Negative Test (401 Expected)" {
    $body = @{ name = "Unauthenticated Product"; price = 50; category = "Misc" } | ConvertTo-Json
    try {
        $res = Invoke-RestMethod -Uri "$BaseUrl/api/v1/products" -Method Post -Body $body -ContentType "application/json"
        throw "Expected 401 Unauthorized, but request succeeded"
    } catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 401) {
            return "Security guard active: 401 Unauthorized returned"
        } else {
            throw "Expected 401 status, got: $($_.Exception.Message)"
        }
    }
}

# 8. Create Product with Invalid Payload (Negative Test)
Execute-Test "08. Create Product with Bad Payload Negative Test (400 Expected)" {
    $body = @{ name = ""; price = -10; category = "" } | ConvertTo-Json
    $headers = @{ "Authorization" = "Bearer $script:token" }
    try {
        $res = Invoke-RestMethod -Uri "$BaseUrl/api/v1/products" -Method Post -Body $body -ContentType "application/json" -Headers $headers
        throw "Expected 400 Bad Request, but request succeeded"
    } catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 400) {
            return "Validation guard active: 400 Bad Request returned"
        } else {
            throw "Expected 400 status, got: $($_.Exception.Message)"
        }
    }
}

# 9. Create Product (Authorized)
Execute-Test "09. Create New Product (POST /api/v1/products)" {
    $newProd = @{
        name = "Automated Test RGB Mechanical Keyboard"
        description = "High-precision optical switches with custom keycaps."
        price = 149.95
        category = "Accessories"
        stockQuantity = 50
        inStock = $true
    } | ConvertTo-Json
    $headers = @{ "Authorization" = "Bearer $script:token" }
    $res = Invoke-RestMethod -Uri "$BaseUrl/api/v1/products" -Method Post -Body $newProd -ContentType "application/json" -Headers $headers
    if (-not $res.id) { throw "Created product does not have an ID" }
    $script:createdId = $res.id
    return "Product created successfully with ID: $($script:createdId)"
}

# 10. Get Product By ID
Execute-Test "10. Retrieve Created Product (GET /api/v1/products/{id})" {
    $res = Invoke-RestMethod -Uri "$BaseUrl/api/v1/products/$($script:createdId)" -Method Get
    if ($res.id -ne $script:createdId) { throw "ID mismatch: $($res.id) != $($script:createdId)" }
    if ($res.name -ne "Automated Test RGB Mechanical Keyboard") { throw "Name mismatch" }
    return "Product retrieved: $($res.name) (\$ $($res.price))"
}

# 11. Update Product
Execute-Test "11. Update Product (PUT /api/v1/products/{id})" {
    $updateData = @{
        name = "Automated Test RGB Mechanical Keyboard (Updated Pro)"
        price = 179.95
        stockQuantity = 65
    } | ConvertTo-Json
    $headers = @{ "Authorization" = "Bearer $script:token" }
    $res = Invoke-RestMethod -Uri "$BaseUrl/api/v1/products/$($script:createdId)" -Method Put -Body $updateData -ContentType "application/json" -Headers $headers
    if ($res.price -ne 179.95) { throw "Price not updated: $($res.price)" }
    if ($res.name -ne "Automated Test RGB Mechanical Keyboard (Updated Pro)") { throw "Name not updated" }
    return "Product updated: Name='$($res.name)', Price=\$ $($res.price)"
}

# 12. Delete Product & Verify 404
Execute-Test "12. Delete Product & Verify Deletion (DELETE then GET 404)" {
    $headers = @{ "Authorization" = "Bearer $script:token" }
    $delRes = Invoke-RestMethod -Uri "$BaseUrl/api/v1/products/$($script:createdId)" -Method Delete -Headers $headers
    if (-not $delRes.success) { throw "Delete operation failed" }
    
    # Verify 404
    try {
        $getRes = Invoke-RestMethod -Uri "$BaseUrl/api/v1/products/$($script:createdId)" -Method Get
        throw "Product still exists after deletion!"
    } catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 404) {
            return "Product successfully deleted and subsequent GET verified 404 Not Found"
        } else {
            throw "Expected 404, got: $($_.Exception.Message)"
        }
    }
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "                     TEST EXECUTION SUMMARY" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host " TOTAL TESTS : $($passedCount + $failedCount)"
Write-Host " PASSED      : $passedCount" -ForegroundColor Green
Write-Host " FAILED      : $failedCount" -ForegroundColor $(if ($failedCount -eq 0) { "Green" } else { "Red" })
Write-Host " SUCCESS RATE: $([Math]::Round(($passedCount / ($passedCount + $failedCount) * 100), 1))%"
Write-Host "================================================================" -ForegroundColor Cyan
