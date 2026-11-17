# ==============================================================================
# Product Catalog REST API Server (Zero Dependencies, Built on .NET HttpListener)
# ==============================================================================
param(
    [int]$Port = 5055
)

$ErrorActionPreference = "Continue"

# In-memory Product Database
$script:products = [System.Collections.ArrayList]::new()

function Reset-Database {
    $script:products.Clear()
    $sampleData = @(
        [ordered]@{
            id = "prod-101"
            name = "Wireless Noise-Canceling Headphones"
            description = "Premium over-ear Bluetooth headphones with active noise cancellation."
            price = 199.99
            category = "Audio"
            inStock = $true
            stockQuantity = 45
            createdAt = "2026-11-17T10:00:00Z"
            updatedAt = "2026-11-17T10:00:00Z"
        },
        [ordered]@{
            id = "prod-102"
            name = "Ergonomic Mechanical Keyboard"
            description = "Custom hot-swappable tactile switches with RGB per-key backlighting."
            price = 129.50
            category = "Accessories"
            inStock = $true
            stockQuantity = 28
            createdAt = "2026-11-17T10:05:00Z"
            updatedAt = "2026-11-17T10:05:00Z"
        },
        [ordered]@{
            id = "prod-103"
            name = "Ultra-Wide Gaming Monitor 34-inch"
            description = "144Hz 1ms curved IPS gaming monitor with HDR400 support."
            price = 449.00
            category = "Electronics"
            inStock = $true
            stockQuantity = 12
            createdAt = "2026-11-17T10:10:00Z"
            updatedAt = "2026-11-17T10:10:00Z"
        },
        [ordered]@{
            id = "prod-104"
            name = "USB-C Multi-Port Docking Station"
            description = "10-in-1 hub with dual HDMI 4K, Gigabit Ethernet, 100W Power Delivery."
            price = 69.95
            category = "Accessories"
            inStock = $true
            stockQuantity = 80
            createdAt = "2026-11-17T10:15:00Z"
            updatedAt = "2026-11-17T10:15:00Z"
        },
        [ordered]@{
            id = "prod-105"
            name = "Studio Condenser USB Microphone"
            description = "Cardioid pickup pattern with built-in pop filter and zero-latency monitoring."
            price = 119.00
            category = "Audio"
            inStock = $false
            stockQuantity = 0
            createdAt = "2026-11-17T10:20:00Z"
            updatedAt = "2026-11-17T10:20:00Z"
        }
    )
    foreach ($item in $sampleData) {
        [void]$script:products.Add([hashtable]$item)
    }
}

Reset-Database

# Valid auth tokens
$script:validToken = "demo-jwt-token-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.user-admin-12345"

# OpenAPI Spec Path
$script:openApiPath = Join-Path $PSScriptRoot "openapi.json"

function Send-JsonResponse {
    param(
        $Response,
        [int]$StatusCode,
        $Data,
        [hashtable]$ExtraHeaders = @{}
    )
    $json = if ($Data -is [string]) { $Data } else { $Data | ConvertTo-Json -Depth 10 -Compress }
    $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
    
    $Response.StatusCode = $StatusCode
    $Response.ContentType = "application/json; charset=utf-8"
    $Response.ContentLength64 = $buffer.Length
    $Response.Headers.Add("Access-Control-Allow-Origin", "*")
    $Response.Headers.Add("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
    $Response.Headers.Add("Access-Control-Allow-Headers", "Content-Type, Authorization, Accept")
    
    foreach ($key in $ExtraHeaders.Keys) {
        $Response.Headers.Add($key, $ExtraHeaders[$key])
    }
    
    $Response.OutputStream.Write($buffer, 0, $buffer.Length)
    $Response.OutputStream.Close()
}

function Send-HtmlResponse {
    param(
        $Response,
        [int]$StatusCode,
        [string]$Html
    )
    $buffer = [System.Text.Encoding]::UTF8.GetBytes($Html)
    $Response.StatusCode = $StatusCode
    $Response.ContentType = "text/html; charset=utf-8"
    $Response.ContentLength64 = $buffer.Length
    $Response.Headers.Add("Access-Control-Allow-Origin", "*")
    $Response.OutputStream.Write($buffer, 0, $buffer.Length)
    $Response.OutputStream.Close()
}

function Read-RequestBody {
    param($Request)
    if (-not $Request.HasEntityBody) { return $null }
    $reader = New-Object System.IO.StreamReader($Request.InputStream, [System.Text.Encoding]::UTF8)
    $body = $reader.ReadToEnd()
    $reader.Close()
    return $body
}

function Validate-Auth {
    param($Request)
    $authHeader = $Request.Headers["Authorization"]
    if ([string]::IsNullOrWhiteSpace($authHeader)) {
        return $false
    }
    if ($authHeader.StartsWith("Bearer ", [System.StringComparison]::OrdinalIgnoreCase)) {
        $token = $authHeader.Substring(7).Trim()
        return ($token -eq $script:validToken -or $token.StartsWith("demo-jwt-token"))
    }
    return $false
}

# Swagger UI HTML Template
$swaggerHtml = @"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>API Documentation - Swagger UI</title>
  <link rel="stylesheet" type="text/css" href="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5/swagger-ui.css" />
  <link rel="icon" type="image/png" href="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5/favicon-32x32.png" />
  <style>
    html { box-sizing: border-box; overflow: -moz-scrollbars-vertical; overflow-y: scroll; }
    *, *:before, *:after { box-sizing: inherit; }
    body { margin: 0; background: #fafafa; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; }
    .topbar { background-color: #1e293b; padding: 12px 24px; color: white; display: flex; align-items: center; justify-content: space-between; }
    .topbar h1 { margin: 0; font-size: 1.15rem; font-weight: 600; }
    .topbar a { color: #38bdf8; text-decoration: none; font-size: 0.9rem; margin-left: 15px; }
  </style>
</head>
<body>
  <div class="topbar">
    <h1>Product Catalog REST API &bull; Interactive Swagger Documentation</h1>
    <div>
      <a href="/" target="_blank">&larr; Back to Dashboard</a>
      <a href="/openapi.json" target="_blank">View Raw OpenAPI Spec</a>
    </div>
  </div>
  <div id="swagger-ui"></div>
  <script src="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5/swagger-ui-bundle.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5/swagger-ui-standalone-preset.js"></script>
  <script>
    window.onload = function() {
      window.ui = SwaggerUIBundle({
        url: "/openapi.json",
        dom_id: '#swagger-ui',
        deepLinking: true,
        presets: [
          SwaggerUIBundle.presets.apis,
          SwaggerUIStandalonePreset
        ],
        plugins: [
          SwaggerUIBundle.plugins.DownloadUrl
        ],
        layout: "StandaloneLayout"
      });
    };
  </script>
</body>
</html>
"@

# Dashboard Landing Page
$dashboardHtml = @"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>REST API & Testing Laboratory</title>
  <style>
    :root { --primary: #2563eb; --primary-hover: #1d4ed8; --bg: #0f172a; --card: #1e293b; --text: #f8fafc; --muted: #94a3b8; --border: #334155; --success: #10b981; --warning: #f59e0b; }
    body { margin: 0; padding: 0; background: var(--bg); color: var(--text); font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen, Ubuntu, Cantarell, sans-serif; line-height: 1.6; }
    .container { max-width: 1000px; margin: 0 auto; padding: 40px 20px; }
    .header { text-align: center; margin-bottom: 40px; }
    .header h1 { font-size: 2.5rem; margin-bottom: 10px; color: #38bdf8; }
    .badge { display: inline-block; padding: 4px 12px; border-radius: 9999px; font-size: 0.85rem; font-weight: 600; background: #065f46; color: #6ee7b7; margin-bottom: 15px; }
    .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; margin-bottom: 30px; }
    .card { background: var(--card); border: 1px solid var(--border); border-radius: 12px; padding: 24px; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.3); }
    .card h2 { margin-top: 0; font-size: 1.35rem; color: #f1f5f9; display: flex; align-items: center; gap: 8px; }
    .btn { display: inline-block; padding: 10px 20px; border-radius: 8px; font-weight: 600; text-decoration: none; text-align: center; cursor: pointer; transition: 0.2s; }
    .btn-primary { background: var(--primary); color: white; border: none; }
    .btn-primary:hover { background: var(--primary-hover); }
    .btn-secondary { background: #334155; color: #f8fafc; border: 1px solid #475569; margin-left: 10px; }
    .code-box { background: #090d16; border: 1px solid #1e293b; border-radius: 8px; padding: 12px; font-family: monospace; font-size: 0.9rem; overflow-x: auto; color: #a5f3fc; }
    table { width: 100%; border-collapse: collapse; margin-top: 15px; font-size: 0.95rem; }
    th, td { text-align: left; padding: 10px 12px; border-bottom: 1px solid var(--border); }
    th { color: var(--muted); font-weight: 500; font-size: 0.85rem; text-transform: uppercase; }
    .method-get { color: #60a5fa; font-weight: bold; }
    .method-post { color: #4ade80; font-weight: bold; }
    .method-put { color: #fbbf24; font-weight: bold; }
    .method-delete { color: #f87171; font-weight: bold; }
    .auth-tag { font-size: 0.75rem; background: #374151; padding: 2px 6px; border-radius: 4px; color: #d1d5db; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <span class="badge">&bull; SERVER ONLINE (Port 5055)</span>
      <h1>REST API Testing Workbench</h1>
      <p style="color: var(--muted); font-size: 1.1rem; max-width: 700px; margin: 0 auto;">
        Interactive test environment for mastering <strong>Swagger UI</strong>, <strong>Bruno</strong>, and <strong>Postman</strong> with real HTTP responses, authentication, and validation.
      </p>
      <div style="margin-top: 25px;">
        <a href="/docs" class="btn btn-primary" target="_blank">&#128214; Open Interactive Swagger UI</a>
        <a href="/openapi.json" class="btn btn-secondary" target="_blank">&#123; &#125; Raw OpenAPI JSON</a>
      </div>
    </div>

    <div class="grid">
      <div class="card">
        <h2>&#128273; Authentication Credentials</h2>
        <p style="color: var(--muted); font-size: 0.9rem;">Send a POST request to <code>/api/v1/auth/login</code> to receive your Bearer access token:</p>
        <div class="code-box">
{<br>
&nbsp;&nbsp;"username": "admin",<br>
&nbsp;&nbsp;"password": "password123"<br>
}
        </div>
        <p style="font-size: 0.85rem; color: #cbd5e1; margin-top: 12px;">
          Pass the returned token in the <code>Authorization</code> header:<br>
          <code style="color: #fbbf24;">Authorization: Bearer &lt;token&gt;</code>
        </p>
      </div>

      <div class="card">
        <h2>&#128736; Testing Tools Setup</h2>
        <ul style="color: var(--muted); font-size: 0.9rem; padding-left: 20px;">
          <li><strong>Swagger UI:</strong> Click the button above to test directly in browser.</li>
          <li><strong>Bruno:</strong> Open Bruno &rarr; "Open Collection" &rarr; select the <code>bruno/</code> directory in this workspace.</li>
          <li><strong>Postman:</strong> Import <code>postman/Products_API.postman_collection.json</code> and select the local environment.</li>
          <li><strong>CLI Runner:</strong> Run <code>.\test-runner.ps1</code> in PowerShell for full automated test execution.</li>
        </ul>
      </div>
    </div>

    <div class="card">
      <h2>&#128640; Available Endpoints</h2>
      <table>
        <thead>
          <tr>
            <th>Method</th>
            <th>Endpoint</th>
            <th>Description</th>
            <th>Auth</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td><span class="method-post">POST</span></td>
            <td><code>/api/v1/auth/login</code></td>
            <td>Authenticates and returns JWT token</td>
            <td>None</td>
          </tr>
          <tr>
            <td><span class="method-get">GET</span></td>
            <td><code>/api/v1/products</code></td>
            <td>List products (filter, search, pagination)</td>
            <td>None</td>
          </tr>
          <tr>
            <td><span class="method-post">POST</span></td>
            <td><code>/api/v1/products</code></td>
            <td>Create new product</td>
            <td><span class="auth-tag">Bearer</span></td>
          </tr>
          <tr>
            <td><span class="method-get">GET</span></td>
            <td><code>/api/v1/products/:id</code></td>
            <td>Get single product details</td>
            <td>None</td>
          </tr>
          <tr>
            <td><span class="method-put">PUT</span></td>
            <td><code>/api/v1/products/:id</code></td>
            <td>Update product fields</td>
            <td><span class="auth-tag">Bearer</span></td>
          </tr>
          <tr>
            <td><span class="method-delete">DELETE</span></td>
            <td><code>/api/v1/products/:id</code></td>
            <td>Remove product from catalog</td>
            <td><span class="auth-tag">Bearer</span></td>
          </tr>
          <tr>
            <td><span class="method-get">GET</span></td>
            <td><code>/api/v1/stats</code></td>
            <td>Inventory & catalog metrics</td>
            <td><span class="auth-tag">Bearer</span></td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</body>
</html>
"@

# Initialize HttpListener
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Prefixes.Add("http://127.0.0.1:$Port/")

try {
    $listener.Start()
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host " [API Server] Running at: http://localhost:$Port/ and http://127.0.0.1:$Port/" -ForegroundColor Green
    Write-Host " [Swagger UI] View docs at: http://localhost:$Port/docs" -ForegroundColor Green
    Write-Host " [Dashboard]  Open in browser: http://localhost:$Port/" -ForegroundColor Green
    Write-Host " Press Ctrl+C in this terminal to stop the server." -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Cyan
} catch {
    Write-Host "Failed to start listener on port $Port : $_" -ForegroundColor Red
    exit 1
}

# Main request dispatch loop
try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response
        
        $urlPath = $request.Url.AbsolutePath
        $method = $request.HttpMethod.ToUpper()
        
        Write-Host "[$([DateTime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss'))] $method $urlPath" -ForegroundColor DarkGray
        
        # Handle CORS Preflight
        if ($method -eq "OPTIONS") {
            $response.StatusCode = 204
            $response.Headers.Add("Access-Control-Allow-Origin", "*")
            $response.Headers.Add("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
            $response.Headers.Add("Access-Control-Allow-Headers", "Content-Type, Authorization, Accept")
            $response.OutputStream.Close()
            continue
        }
        
        # Route: GET /
        if ($urlPath -eq "/" -and $method -eq "GET") {
            # Check Accept header: if client requests JSON, send JSON; else send Dashboard HTML
            $acceptHeader = $request.Headers["Accept"]
            if ($acceptHeader -and $acceptHeader.Contains("application/json") -and -not $acceptHeader.Contains("text/html")) {
                $info = [ordered]@{
                    name = "Product Catalog & Inventory API"
                    status = "online"
                    version = "1.0.0"
                    docsUrl = "/docs"
                    specUrl = "/openapi.json"
                    timestamp = [DateTime]::UtcNow.ToString("o")
                }
                Send-JsonResponse -Response $response -StatusCode 200 -Data $info
            } else {
                Send-HtmlResponse -Response $response -StatusCode 200 -Html $dashboardHtml
            }
            continue
        }
        
        # Route: GET /docs (Swagger UI)
        if ($urlPath -eq "/docs" -and $method -eq "GET") {
            Send-HtmlResponse -Response $response -StatusCode 200 -Html $swaggerHtml
            continue
        }
        
        # Route: GET /openapi.json
        if ($urlPath -eq "/openapi.json" -and $method -eq "GET") {
            if (Test-Path $script:openApiPath) {
                $specContent = [System.IO.File]::ReadAllText($script:openApiPath, [System.Text.Encoding]::UTF8)
                Send-JsonResponse -Response $response -StatusCode 200 -Data $specContent
            } else {
                $err = [ordered]@{ status = 404; error = "Not Found"; message = "OpenAPI specification file not found." }
                Send-JsonResponse -Response $response -StatusCode 404 -Data $err
            }
            continue
        }
        
        # Route: POST /api/v1/auth/login
        if ($urlPath -eq "/api/v1/auth/login" -and $method -eq "POST") {
            $rawBody = Read-RequestBody -Request $request
            if ([string]::IsNullOrWhiteSpace($rawBody)) {
                $err = [ordered]@{ status = 400; error = "Bad Request"; message = "Request body cannot be empty." }
                Send-JsonResponse -Response $response -StatusCode 400 -Data $err
                continue
            }
            
            try {
                $credentials = $rawBody | ConvertFrom-Json
            } catch {
                $err = [ordered]@{ status = 400; error = "Bad Request"; message = "Invalid JSON in request body." }
                Send-JsonResponse -Response $response -StatusCode 400 -Data $err
                continue
            }
            
            if ($credentials.username -eq "admin" -and $credentials.password -eq "password123") {
                $loginResult = [ordered]@{
                    token = $script:validToken
                    tokenType = "Bearer"
                    expiresIn = 3600
                    user = [ordered]@{
                        username = "admin"
                        role = "administrator"
                    }
                }
                Send-JsonResponse -Response $response -StatusCode 200 -Data $loginResult
            } else {
                $err = [ordered]@{
                    status = 401
                    error = "Unauthorized"
                    message = "Invalid username or password. Default test credentials: admin / password123"
                    timestamp = [DateTime]::UtcNow.ToString("o")
                }
                Send-JsonResponse -Response $response -StatusCode 401 -Data $err
            }
            continue
        }
        
        # Route: GET /api/v1/products
        if ($urlPath -eq "/api/v1/products" -and $method -eq "GET") {
            $query = $request.Url.Query
            $parsedQuery = [System.Web.HttpUtility]::ParseQueryString($query)
            
            $search = $parsedQuery["search"]
            $category = $parsedQuery["category"]
            $minPrice = $parsedQuery["minPrice"]
            $maxPrice = $parsedQuery["maxPrice"]
            $page = if ($parsedQuery["page"]) { [int]$parsedQuery["page"] } else { 1 }
            $limit = if ($parsedQuery["limit"]) { [int]$parsedQuery["limit"] } else { 10 }
            if ($page -lt 1) { $page = 1 }
            if ($limit -lt 1) { $limit = 10 }
            if ($limit -gt 50) { $limit = 50 }
            
            $filtered = @($script:products | Where-Object {
                $item = $_
                $match = $true
                if (-not [string]::IsNullOrWhiteSpace($search)) {
                    $s = $search.ToLower()
                    $matchName = $item.name.ToLower().Contains($s)
                    $matchDesc = ($item.description -and $item.description.ToLower().Contains($s))
                    if (-not ($matchName -or $matchDesc)) { $match = $false }
                }
                if ($match -and -not [string]::IsNullOrWhiteSpace($category)) {
                    if ($item.category.ToLower() -ne $category.ToLower()) { $match = $false }
                }
                if ($match -and -not [string]::IsNullOrWhiteSpace($minPrice)) {
                    if ([double]$item.price -lt [double]$minPrice) { $match = $false }
                }
                if ($match -and -not [string]::IsNullOrWhiteSpace($maxPrice)) {
                    if ([double]$item.price -gt [double]$maxPrice) { $match = $false }
                }
                $match
            })
            
            $total = $filtered.Count
            $totalPages = [Math]::Ceiling($total / $limit)
            $skip = ($page - 1) * $limit
            
            $items = if ($skip -ge $total) {
                @()
            } else {
                $take = [Math]::Min($limit, $total - $skip)
                $filtered[$skip..($skip + $take - 1)]
            }
            
            $res = [ordered]@{
                items = $items
                pagination = [ordered]@{
                    total = $total
                    page = $page
                    limit = $limit
                    totalPages = [int]$totalPages
                }
            }
            Send-JsonResponse -Response $response -StatusCode 200 -Data $res
            continue
        }
        
        # Route: POST /api/v1/products (Create)
        if ($urlPath -eq "/api/v1/products" -and $method -eq "POST") {
            if (-not (Validate-Auth -Request $request)) {
                $err = [ordered]@{
                    status = 401
                    error = "Unauthorized"
                    message = "Missing or invalid Bearer authentication token in Authorization header."
                    timestamp = [DateTime]::UtcNow.ToString("o")
                }
                Send-JsonResponse -Response $response -StatusCode 401 -Data $err
                continue
            }
            
            $rawBody = Read-RequestBody -Request $request
            if ([string]::IsNullOrWhiteSpace($rawBody)) {
                $err = [ordered]@{ status = 400; error = "Bad Request"; message = "Request body cannot be empty." }
                Send-JsonResponse -Response $response -StatusCode 400 -Data $err
                continue
            }
            
            try {
                $newProd = $rawBody | ConvertFrom-Json
            } catch {
                $err = [ordered]@{ status = 400; error = "Bad Request"; message = "Invalid JSON syntax." }
                Send-JsonResponse -Response $response -StatusCode 400 -Data $err
                continue
            }
            
            # Validation
            if ([string]::IsNullOrWhiteSpace($newProd.name) -or $newProd.name.Length -lt 2) {
                $err = [ordered]@{ status = 400; error = "Bad Request"; message = "Field 'name' is required (minimum 2 characters)." }
                Send-JsonResponse -Response $response -StatusCode 400 -Data $err
                continue
            }
            if ($null -eq $newProd.price -or [double]$newProd.price -le 0) {
                $err = [ordered]@{ status = 400; error = "Bad Request"; message = "Field 'price' is required and must be greater than 0." }
                Send-JsonResponse -Response $response -StatusCode 400 -Data $err
                continue
            }
            if ([string]::IsNullOrWhiteSpace($newProd.category)) {
                $err = [ordered]@{ status = 400; error = "Bad Request"; message = "Field 'category' is required." }
                Send-JsonResponse -Response $response -StatusCode 400 -Data $err
                continue
            }
            
            $newId = "prod-" + ([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds().ToString().Substring(7))
            $nowIso = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
            $qty = if ($null -ne $newProd.stockQuantity) { [int]$newProd.stockQuantity } else { 10 }
            $inStock = if ($null -ne $newProd.inStock) { [bool]$newProd.inStock } else { ($qty -gt 0) }
            
            $createdItem = [ordered]@{
                id = $newId
                name = [string]$newProd.name
                description = [string]$newProd.description
                price = [double]$newProd.price
                category = [string]$newProd.category
                inStock = $inStock
                stockQuantity = $qty
                createdAt = $nowIso
                updatedAt = $nowIso
            }
            
            [void]$script:products.Add([hashtable]$createdItem)
            
            $headers = @{ "Location" = "/api/v1/products/$newId" }
            Send-JsonResponse -Response $response -StatusCode 201 -Data $createdItem -ExtraHeaders $headers
            continue
        }
        
        # Route: GET /api/v1/stats
        if ($urlPath -eq "/api/v1/stats" -and $method -eq "GET") {
            if (-not (Validate-Auth -Request $request)) {
                $err = [ordered]@{ status = 401; error = "Unauthorized"; message = "Authentication token required." }
                Send-JsonResponse -Response $response -StatusCode 401 -Data $err
                continue
            }
            
            $totalCount = $script:products.Count
            $totalValue = 0.0
            $categories = [System.Collections.Generic.HashSet[string]]::new()
            foreach ($p in $script:products) {
                $totalValue += ($p.price * $p.stockQuantity)
                if ($p.category) { [void]$categories.Add($p.category) }
            }
            $avgPrice = if ($totalCount -gt 0) { [Math]::Round(($totalValue / $totalCount), 2) } else { 0.0 }
            
            $stats = [ordered]@{
                totalProducts = $totalCount
                totalInventoryValue = [Math]::Round($totalValue, 2)
                categories = @($categories)
                averagePrice = $avgPrice
            }
            Send-JsonResponse -Response $response -StatusCode 200 -Data $stats
            continue
        }
        
        # Route matching /api/v1/products/{id}
        if ($urlPath -match "^/api/v1/products/([^/]+)$") {
            $prodId = $Matches[1]
            $item = $script:products | Where-Object { $_.id -eq $prodId } | Select-Object -First 1
            
            # GET /api/v1/products/{id}
            if ($method -eq "GET") {
                if ($null -eq $item) {
                    $err = [ordered]@{
                        status = 404
                        error = "Not Found"
                        message = "Product with ID '$prodId' was not found."
                        timestamp = [DateTime]::UtcNow.ToString("o")
                    }
                    Send-JsonResponse -Response $response -StatusCode 404 -Data $err
                } else {
                    Send-JsonResponse -Response $response -StatusCode 200 -Data $item
                }
                continue
            }
            
            # PUT /api/v1/products/{id}
            if ($method -eq "PUT") {
                if (-not (Validate-Auth -Request $request)) {
                    $err = [ordered]@{ status = 401; error = "Unauthorized"; message = "Authentication token required to update products." }
                    Send-JsonResponse -Response $response -StatusCode 401 -Data $err
                    continue
                }
                if ($null -eq $item) {
                    $err = [ordered]@{ status = 404; error = "Not Found"; message = "Cannot update: product '$prodId' not found." }
                    Send-JsonResponse -Response $response -StatusCode 404 -Data $err
                    continue
                }
                
                $rawBody = Read-RequestBody -Request $request
                $updateData = $rawBody | ConvertFrom-Json
                
                if ($null -ne $updateData.name) { $item.name = [string]$updateData.name }
                if ($null -ne $updateData.description) { $item.description = [string]$updateData.description }
                if ($null -ne $updateData.price) { $item.price = [double]$updateData.price }
                if ($null -ne $updateData.category) { $item.category = [string]$updateData.category }
                if ($null -ne $updateData.stockQuantity) { $item.stockQuantity = [int]$updateData.stockQuantity }
                if ($null -ne $updateData.inStock) { $item.inStock = [bool]$updateData.inStock }
                $item.updatedAt = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
                
                Send-JsonResponse -Response $response -StatusCode 200 -Data $item
                continue
            }
            
            # DELETE /api/v1/products/{id}
            if ($method -eq "DELETE") {
                if (-not (Validate-Auth -Request $request)) {
                    $err = [ordered]@{ status = 401; error = "Unauthorized"; message = "Authentication token required to delete products." }
                    Send-JsonResponse -Response $response -StatusCode 401 -Data $err
                    continue
                }
                if ($null -eq $item) {
                    $err = [ordered]@{ status = 404; error = "Not Found"; message = "Cannot delete: product '$prodId' does not exist." }
                    Send-JsonResponse -Response $response -StatusCode 404 -Data $err
                    continue
                }
                
                [void]$script:products.Remove($item)
                $delRes = [ordered]@{
                    success = $true
                    message = "Product '$prodId' deleted successfully."
                    id = $prodId
                }
                Send-JsonResponse -Response $response -StatusCode 200 -Data $delRes
                continue
            }
        }
        
        # 404 Catch-All
        $notFound = [ordered]@{
            status = 404
            error = "Not Found"
            message = "Endpoint '$method $urlPath' is not recognized. Visit /docs for available routes."
            timestamp = [DateTime]::UtcNow.ToString("o")
        }
        Send-JsonResponse -Response $response -StatusCode 404 -Data $notFound
    }
} finally {
    if ($listener.IsListening) {
        $listener.Stop()
    }
    $listener.Close()
    Write-Host "[API Server] Stopped." -ForegroundColor Yellow
}
