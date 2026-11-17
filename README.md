# 🚀 API & API Testing Masterclass
### Comprehensive REST API Testing Laboratory with Swagger UI, Bruno, Postman & CI/CD Automation

[![API Test Automation](https://github.com/LybaFatimaNasir/api-testing-mastery/actions/workflows/api-automation.yml/badge.svg)](https://github.com/LybaFatimaNasir/api-testing-mastery/actions/workflows/api-automation.yml)
![OpenAPI 3.0](https://img.shields.io/badge/OpenAPI-3.0.3-6BA539?logo=openapi-initiative&logoColor=white)
![Swagger UI](https://img.shields.io/badge/Swagger-UI-85EA2D?logo=swagger&logoColor=black)
![Newman](https://img.shields.io/badge/Newman-CLI%20Automated-FF6C37?logo=postman&logoColor=white)
![Bruno CLI](https://img.shields.io/badge/Bruno-CLI%20Automated-F97316)
![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-CI%2FCD-2088FF?logo=github-actions&logoColor=white)
![Tests](https://img.shields.io/badge/Tests-12%2F12%20Passing-brightgreen)
![Zero Dependencies](https://img.shields.io/badge/Dependencies-Zero%20(Native)-blue)

An end-to-end laboratory and reference project for learning, developing, and mastering **RESTful APIs** and comprehensive **API Testing**. Features a zero-dependency local REST API server, an interactive Swagger UI documentation dashboard, complete test suites for both **Bruno** and **Postman**, and a 12-stage automated CLI test runner.

---

## 🌟 Key Features

- **⚡ Zero-Dependency Live API Server (`server.ps1`):** Runs out-of-the-box on Windows using native .NET HTTP services—no Node.js or Python required to start testing immediately.
- **📖 Interactive Swagger UI (`/docs`):** Live exploratory testing workbench powered by OpenAPI 3.0 specification.
- **🔐 Bearer / JWT Token Authentication:** Endpoints protected with bearer token validation and security error handling.
- **📦 Full CRUD Lifecycle:** Product catalog supporting pagination (`page`, `limit`), search queries, and category/price filtering.
- **🐶 Bruno Suite (`bruno/`):** 100% offline, Git-friendly plain-text `.bru` files with declarative `assert` blocks and variable chaining.
- **📮 Postman Collection (`postman/`):** Postman v2.1 collection with JavaScript assertions (`pm.test()`, `pm.expect()`) and dynamic environment persistence.
- **🧪 Automated CLI Runner (`test-runner.ps1`):** 12-test automated verification suite with real-time latency benchmarking and pass/fail reporting.
- **🏭 Production Reference Code:** Full equivalent implementations in **FastAPI** (Python) and **Express** (Node.js).

---

## 📁 Repository Structure

```text
├── .github/workflows/
│   └── api-automation.yml        # GitHub Actions dual-matrix CI/CD pipeline
├── openapi.json                  # Formal OpenAPI 3.0.3 specification
├── server.ps1                    # Native REST API server with embedded Swagger UI
├── test-runner.ps1               # Automated 12-test CLI runner
├── run-automation-suite.ps1      # Orchestrated automation runner (PowerShell + Newman + Bruno)
├── package.json                  # NPM test automation scripts & CLI dependencies
├── publish-to-github.ps1         # Automated GitHub API publisher script
├── postman/
│   ├── Products_API.postman_collection.json      # Postman test collection
│   └── Local_Environment.postman_environment.json # Postman environment variables
├── bruno/
│   ├── bruno.json                # Bruno collection descriptor
│   ├── environments/local.bru    # Bruno environment variables
│   ├── 01 - Health Check.bru
│   ├── 02 - Login Success.bru
│   ├── 03 - Login Invalid Credentials.bru
│   ├── 04 - Get All Products.bru
│   ├── 05 - Filtered Products.bru
│   ├── 06 - Create Product.bru
│   ├── 07 - Get Product By ID.bru
│   ├── 08 - Update Product.bru
│   ├── 09 - Get Stats Authenticated.bru
│   ├── 10 - Delete Product.bru
│   ├── 11 - Verify Deleted Product.bru
│   └── 12 - Create Without Auth Negative Test.bru
├── fastapi_alternative/          # Python FastAPI implementation
│   ├── main.py
│   └── requirements.txt
└── express_alternative/          # Node.js Express implementation
    ├── server.js
    └── package.json
```

---

## 🚀 Quick Start

### 1. Launch the REST API Server
In PowerShell:
```powershell
powershell -ExecutionPolicy Bypass -File .\server.ps1
```
The server will start listening at:
- **Interactive Dashboard:** `http://localhost:5055/`
- **Swagger UI Documentation:** `http://localhost:5055/docs`
- **Raw OpenAPI Spec:** `http://localhost:5055/openapi.json`

### 2. Run the Automated CLI Test Suite
In a separate terminal:
```powershell
.\test-runner.ps1
```
You will see 12 automated tests execute across authentication, CRUD, and security validations:
```text
================================================================
                     TEST EXECUTION SUMMARY
================================================================
 TOTAL TESTS : 12
 PASSED      : 12
 FAILED      : 0
 SUCCESS RATE: 100%
================================================================
```

---

## 🛠️ Testing Workflows

### A. Testing with Swagger UI
1. Navigate to [`http://localhost:5055/docs`](http://localhost:5055/docs).
2. Expand `POST /api/v1/auth/login`, click **Try it out**, and submit credentials:
   ```json
   { "username": "admin", "password": "password123" }
   ```
3. Copy the returned `token`.
4. Click the green **Authorize** lock button at the top and paste the token.
5. All protected endpoints (`POST`, `PUT`, `DELETE /api/v1/products`) will now execute with authorization.

### B. Testing with Bruno
1. Download and open [Bruno](https://www.usebruno.com/).
2. Click **Open Collection** and select the `bruno/` directory in this repo.
3. Select the **local** environment from the top-right dropdown.
4. Execute individual requests or run the entire folder in the Collection Runner.

### C. Testing with Postman
1. Open [Postman](https://www.postman.com/).
2. Click **Import** and select:
   - `postman/Products_API.postman_collection.json`
   - `postman/Local_Environment.postman_environment.json`
3. Select **Local API Testing Environment** in the environment dropdown.
4. Click **Run collection** to run the complete automated test flow.

### D. Headless CI/CD Automation Runner
You can run all three test engines (Native PowerShell, Newman Postman CLI, and Bruno CLI) headlessly with a single command:
```powershell
.\run-automation-suite.ps1
```
Or run each runner individually:
```powershell
# 1. Native zero-dependency suite (12 stages)
.\test-runner.ps1

# 2. Newman Postman CLI with terminal output & HTML report
npx newman run postman/Products_API.postman_collection.json -e postman/Local_Environment.postman_environment.json --reporters cli,htmlextra --reporter-htmlextra-export test-reports/newman-report.html

# 3. Bruno CLI headless runner
npx @usebruno/cli run bruno --env local
```

---

## ⚡ GitHub Actions Continuous Integration

The repository includes a production-grade CI/CD pipeline at [`.github/workflows/api-automation.yml`](.github/workflows/api-automation.yml) configured with:
- **Windows Native Job:** Bootstraps the zero-dependency PowerShell server in background, executes the native 12-stage test runner, runs Newman CLI with HTML extra reporter, and runs the Bruno CLI suite.
- **Linux Express Job:** Tests cross-platform parity by spinning up the Express.js server on Ubuntu and running Newman and Bruno against it.
- **Automated Artifacts & Summaries:** Publishes rich Markdown summaries to the GitHub Action run overview and archives downloadable HTML and JUnit test reports for every push and PR.

---

## 📊 Endpoints Reference

| Method | Endpoint | Description | Auth Required |
| :--- | :--- | :--- | :---: |
| `GET` | `/` | Service health & API dashboard | No |
| `GET` | `/docs` | Interactive Swagger UI | No |
| `GET` | `/openapi.json` | Raw OpenAPI 3.0.3 specification | No |
| `POST` | `/api/v1/auth/login` | Authenticate user & issue Bearer token | No |
| `GET` | `/api/v1/products` | List products with query filtering & pagination | No |
| `POST` | `/api/v1/products` | Create new product | **Bearer** |
| `GET` | `/api/v1/products/:id` | Retrieve single product details | No |
| `PUT` | `/api/v1/products/:id` | Update product attributes | **Bearer** |
| `DELETE` | `/api/v1/products/:id` | Remove product from catalog | **Bearer** |
| `GET` | `/api/v1/stats` | Aggregated catalog & inventory metrics | **Bearer** |

---

## 📜 License
MIT License. Feel free to use this project as a foundation for your API development and testing journeys.
