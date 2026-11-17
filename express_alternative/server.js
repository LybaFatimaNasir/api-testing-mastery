/**
 * Production Express.js Reference Implementation
 * Run with: npm install && node server.js
 * Swagger docs at: http://localhost:5055/docs
 */

const express = require('express');
const cors = require('cors');
const swaggerUi = require('swagger-ui-express');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 5055;
const VALID_TOKEN = "demo-jwt-token-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.user-admin-12345";

app.use(cors());
app.use(express.json());

// Load OpenAPI specification
const openApiSpec = JSON.parse(fs.readFileSync(path.join(__dirname, '../openapi.json'), 'utf8'));
app.use('/docs', swaggerUi.serve, swaggerUi.setup(openApiSpec));
app.get('/openapi.json', (req, res) => res.json(openApiSpec));

// In-memory catalog
let products = [
  {
    id: "prod-101",
    name: "Wireless Noise-Canceling Headphones",
    description: "Premium over-ear Bluetooth headphones with active noise cancellation.",
    price: 199.99,
    category: "Audio",
    inStock: true,
    stockQuantity: 45,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString()
  }
];

// Auth middleware
const requireAuth = (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ status: 401, error: "Unauthorized", message: "Missing or invalid Bearer token" });
  }
  const token = authHeader.split(' ')[1];
  if (token !== VALID_TOKEN) {
    return res.status(401).json({ status: 401, error: "Unauthorized", message: "Token validation failed" });
  }
  next();
};

app.get('/', (req, res) => {
  res.json({ name: "Product Catalog API", status: "online", version: "1.0.0", docsUrl: "/docs" });
});

app.post('/api/v1/auth/login', (req, res) => {
  const { username, password } = req.body;
  if (username === 'admin' && password === 'password123') {
    return res.json({
      token: VALID_TOKEN,
      tokenType: "Bearer",
      expiresIn: 3600,
      user: { username: "admin", role: "administrator" }
    });
  }
  return res.status(401).json({ status: 401, error: "Unauthorized", message: "Invalid credentials" });
});

app.get('/api/v1/products', (req, res) => {
  let { search, category, minPrice, maxPrice, page = 1, limit = 10 } = req.query;
  page = parseInt(page);
  limit = parseInt(limit);

  let filtered = products.filter(p => {
    if (search && !p.name.toLowerCase().includes(search.toLowerCase())) return false;
    if (category && p.category.toLowerCase() !== category.toLowerCase()) return false;
    if (minPrice && p.price < parseFloat(minPrice)) return false;
    if (maxPrice && p.price > parseFloat(maxPrice)) return false;
    return true;
  });

  const total = filtered.length;
  const skip = (page - 1) * limit;
  const items = filtered.slice(skip, skip + limit);

  res.json({
    items,
    pagination: { total, page, limit, totalPages: Math.ceil(total / limit) }
  });
});

app.post('/api/v1/products', requireAuth, (req, res) => {
  const { name, price, category, description, stockQuantity = 10, inStock = true } = req.body;
  if (!name || name.length < 2 || !price || price <= 0 || !category) {
    return res.status(400).json({ status: 400, error: "Bad Request", message: "Validation error: invalid name, price, or category" });
  }

  const id = `prod-${Date.now().toString().slice(-6)}`;
  const now = new Date().toISOString();
  const newProduct = { id, name, price, category, description, stockQuantity, inStock, createdAt: now, updatedAt: now };
  products.push(newProduct);

  res.status(201).header('Location', `/api/v1/products/${id}`).json(newProduct);
});

app.get('/api/v1/products/:id', (req, res) => {
  const item = products.find(p => p.id === req.params.id);
  if (!item) return res.status(404).json({ status: 404, error: "Not Found", message: `Product ${req.params.id} not found` });
  res.json(item);
});

app.put('/api/v1/products/:id', requireAuth, (req, res) => {
  const item = products.find(p => p.id === req.params.id);
  if (!item) return res.status(404).json({ status: 404, error: "Not Found", message: `Product ${req.params.id} not found` });

  Object.assign(item, req.body, { updatedAt: new Date().toISOString() });
  res.json(item);
});

app.delete('/api/v1/products/:id', requireAuth, (req, res) => {
  const index = products.findIndex(p => p.id === req.params.id);
  if (index === -1) return res.status(404).json({ status: 404, error: "Not Found", message: `Product ${req.params.id} not found` });

  products.splice(index, 1);
  res.json({ success: true, message: `Product ${req.params.id} deleted successfully`, id: req.params.id });
});

app.listen(PORT, () => {
  console.log(`Server listening on port ${PORT}`);
});
