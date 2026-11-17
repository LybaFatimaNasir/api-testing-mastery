"""
Production FastAPI Reference Implementation
Run with: uvicorn main:app --reload --port 5055
Interactive Swagger Docs auto-generated at: http://localhost:5055/docs
"""

from typing import List, Optional
from datetime import datetime
from fastapi import FastAPI, HTTPException, Depends, status, Query
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, Field
import uuid

app = FastAPI(
    title="Product Catalog & Inventory API",
    description="FastAPI reference implementation matching OpenAPI 3.0 specification",
    version="1.0.0"
)

security = HTTPBearer()
VALID_TOKEN = "demo-jwt-token-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.user-admin-12345"

# --- Models ---
class LoginRequest(BaseModel):
    username: str
    password: str

class LoginResponse(BaseModel):
    token: str
    tokenType: str = "Bearer"
    expiresIn: int = 3600
    user: dict

class ProductBase(BaseModel):
    name: str = Field(..., min_length=2, example="Wireless Headphones")
    description: Optional[str] = Field(None, example="Premium audio headphones")
    price: float = Field(..., gt=0, example=99.99)
    category: str = Field(..., example="Audio")
    stockQuantity: int = Field(10, ge=0, example=25)
    inStock: bool = Field(True, example=True)

class ProductCreate(ProductBase):
    pass

class ProductUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=2)
    description: Optional[str] = None
    price: Optional[float] = Field(None, gt=0)
    category: Optional[str] = None
    stockQuantity: Optional[int] = Field(None, ge=0)
    inStock: Optional[bool] = None

class Product(ProductBase):
    id: str
    createdAt: datetime
    updatedAt: datetime

class PaginatedProductsResponse(BaseModel):
    items: List[Product]
    pagination: dict

# In-memory storage
products_db: dict[str, Product] = {
    "prod-101": Product(
        id="prod-101",
        name="Wireless Noise-Canceling Headphones",
        description="Premium over-ear Bluetooth headphones with active noise cancellation.",
        price=199.99,
        category="Audio",
        stockQuantity=45,
        inStock=True,
        createdAt=datetime.utcnow(),
        updatedAt=datetime.utcnow()
    )
}

def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    if credentials.credentials != VALID_TOKEN:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired Bearer token"
        )
    return credentials.credentials

# --- Endpoints ---
@app.get("/", tags=["System"])
def root():
    return {
        "name": "Product Catalog & Inventory API",
        "status": "online",
        "version": "1.0.0",
        "docsUrl": "/docs"
    }

@app.post("/api/v1/auth/login", response_model=LoginResponse, tags=["Authentication"])
def login(payload: LoginRequest):
    if payload.username == "admin" and payload.password == "password123":
        return LoginResponse(
            token=VALID_TOKEN,
            tokenType="Bearer",
            expiresIn=3600,
            user={"username": "admin", "role": "administrator"}
        )
    raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid username or password")

@app.get("/api/v1/products", response_model=PaginatedProductsResponse, tags=["Products"])
def list_products(
    search: Optional[str] = None,
    category: Optional[str] = None,
    minPrice: Optional[float] = None,
    maxPrice: Optional[float] = None,
    page: int = Query(1, ge=1),
    limit: int = Query(10, ge=1, le=50)
):
    items = list(products_db.values())
    if search:
        s = search.lower()
        items = [p for p in items if s in p.name.lower() or (p.description and s in p.description.lower())]
    if category:
        items = [p for p in items if p.category.lower() == category.lower()]
    if minPrice is not None:
        items = [p for p in items if p.price >= minPrice]
    if maxPrice is not None:
        items = [p for p in items if p.price <= maxPrice]

    total = len(items)
    skip = (page - 1) * limit
    paged_items = items[skip : skip + limit]
    
    return PaginatedProductsResponse(
        items=paged_items,
        pagination={"total": total, "page": page, "limit": limit, "totalPages": (total + limit - 1) // limit}
    )

@app.post("/api/v1/products", response_model=Product, status_code=status.HTTP_201_CREATED, tags=["Products"])
def create_product(payload: ProductCreate, token: str = Depends(verify_token)):
    new_id = f"prod-{uuid.uuid4().hex[:6]}"
    now = datetime.utcnow()
    product = Product(id=new_id, createdAt=now, updatedAt=now, **payload.dict())
    products_db[new_id] = product
    return product

@app.get("/api/v1/products/{product_id}", response_model=Product, tags=["Products"])
def get_product(product_id: str):
    if product_id not in products_db:
        raise HTTPException(status_code=404, detail=f"Product with ID '{product_id}' not found")
    return products_db[product_id]

@app.put("/api/v1/products/{product_id}", response_model=Product, tags=["Products"])
def update_product(product_id: str, payload: ProductUpdate, token: str = Depends(verify_token)):
    if product_id not in products_db:
        raise HTTPException(status_code=404, detail=f"Product with ID '{product_id}' not found")
    
    item = products_db[product_id]
    update_data = payload.dict(exclude_unset=True)
    for field, value in update_data.items():
        setattr(item, field, value)
    item.updatedAt = datetime.utcnow()
    return item

@app.delete("/api/v1/products/{product_id}", tags=["Products"])
def delete_product(product_id: str, token: str = Depends(verify_token)):
    if product_id not in products_db:
        raise HTTPException(status_code=404, detail=f"Product with ID '{product_id}' not found")
    del products_db[product_id]
    return {"success": True, "message": f"Product '{product_id}' deleted successfully", "id": product_id}
