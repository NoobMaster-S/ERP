"use client";

import React, { useState, useEffect } from "react";
import { useAuth } from "@/lib/auth/AuthContext";
import { executeGraphQL } from "@/lib/graphql/client";
import { GET_PRODUCTS, CREATE_PRODUCT_MUTATION } from "@/lib/graphql/operations";
import { Package, Plus, Search, RefreshCw, CheckCircle2, AlertCircle } from "lucide-react";

interface Product {
  id: string;
  name: string;
  sku: string;
  barcode: string;
  costPrice: number;
  sellingPrice: number;
  taxRate: number;
  minStockThreshold: number;
  categoryName: string | null;
  unitCode: string;
  isActive: boolean;
}

export default function InventoryPage() {
  const { token, activeBusiness } = useAuth();
  const [products, setProducts] = useState<Product[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [showAddModal, setShowAddModal] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Form State
  const [formData, setFormData] = useState({
    name: "",
    sku: "",
    barcode: "",
    costPrice: 0,
    sellingPrice: 0,
    taxRate: 18.0,
    minStockThreshold: 5,
  });

  const fetchProducts = async () => {
    if (!token || !activeBusiness) return;
    setLoading(true);
    setError(null);
    try {
      const res = await executeGraphQL<{ products: Product[] }>(
        GET_PRODUCTS,
        { search: search || null },
        token,
        activeBusiness.id
      );
      if (res.data?.products) {
        setProducts(res.data.products);
      } else if (res.errors) {
        setError(res.errors[0]?.message || "Failed to load products");
      }
    } catch (err: any) {
      setError(err?.message || "Failed to load products");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchProducts();
  }, [token, activeBusiness]);

  const handleCreateProduct = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!token || !activeBusiness) return;
    try {
      const res = await executeGraphQL(
        CREATE_PRODUCT_MUTATION,
        {
          input: {
            name: formData.name,
            sku: formData.sku || null,
            barcode: formData.barcode || null,
            costPrice: Number(formData.costPrice),
            sellingPrice: Number(formData.sellingPrice),
            taxRate: Number(formData.taxRate),
            minStockThreshold: Number(formData.minStockThreshold),
          },
        },
        token,
        activeBusiness.id
      );
      if (res.errors) {
        alert("Failed to create product: " + res.errors[0]?.message);
        return;
      }
      setShowAddModal(false);
      setFormData({
        name: "",
        sku: "",
        barcode: "",
        costPrice: 0,
        sellingPrice: 0,
        taxRate: 18.0,
        minStockThreshold: 5,
      });
      fetchProducts();
    } catch (err: any) {
      alert("Failed to create product: " + err.message);
    }
  };

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: "24px" }}>
      {/* Header */}
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <div>
          <h1 style={{ fontSize: "1.75rem", fontWeight: 700, letterSpacing: "-0.02em" }}>
            Inventory & Catalog
          </h1>
          <p style={{ color: "var(--text-secondary)", fontSize: "0.875rem", marginTop: "4px" }}>
            Manage master products, SKU barcodes, margins, and warehouse inventory.
          </p>
        </div>

        <div style={{ display: "flex", gap: "12px" }}>
          <button
            onClick={fetchProducts}
            className="btn btn-secondary"
            style={{ display: "flex", alignItems: "center", gap: "8px" }}
          >
            <RefreshCw size={16} />
            Refresh
          </button>
          <button
            onClick={() => setShowAddModal(true)}
            className="btn btn-primary"
            style={{ display: "flex", alignItems: "center", gap: "8px" }}
          >
            <Plus size={16} />
            Add Product
          </button>
        </div>
      </div>

      {/* Filter / Search Bar */}
      <div className="card" style={{ padding: "16px" }}>
        <div style={{ display: "flex", gap: "12px", alignItems: "center" }}>
          <div style={{ position: "relative", flex: 1 }}>
            <Search
              size={18}
              style={{
                position: "absolute",
                left: "12px",
                top: "50%",
                transform: "translateY(-50%)",
                color: "var(--text-muted)",
              }}
            />
            <input
              type="text"
              placeholder="Search by product name, SKU, or barcode..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && fetchProducts()}
              style={{
                width: "100%",
                padding: "10px 14px 10px 40px",
                backgroundColor: "var(--bg-tertiary)",
                border: "1px solid var(--border-color)",
                borderRadius: "var(--radius-sm)",
                color: "#fff",
                fontSize: "0.875rem",
              }}
            />
          </div>
          <button onClick={fetchProducts} className="btn btn-secondary">
            Filter
          </button>
        </div>
      </div>

      {/* Error notification */}
      {error && (
        <div
          style={{
            padding: "12px 16px",
            backgroundColor: "rgba(239, 68, 68, 0.15)",
            border: "1px solid var(--accent-danger)",
            borderRadius: "var(--radius-sm)",
            color: "var(--accent-danger)",
            display: "flex",
            alignItems: "center",
            gap: "8px",
          }}
        >
          <AlertCircle size={18} />
          <span>{error}</span>
        </div>
      )}

      {/* Products Table */}
      <div className="card" style={{ overflow: "hidden" }}>
        <table style={{ width: "100%", borderCollapse: "collapse", textAlign: "left" }}>
          <thead>
            <tr
              style={{
                borderBottom: "1px solid var(--border-color)",
                backgroundColor: "rgba(255, 255, 255, 0.02)",
                fontSize: "0.8125rem",
                color: "var(--text-muted)",
                textTransform: "uppercase",
              }}
            >
              <th style={{ padding: "14px 20px" }}>Product Name</th>
              <th style={{ padding: "14px 20px" }}>SKU / Barcode</th>
              <th style={{ padding: "14px 20px" }}>Category</th>
              <th style={{ padding: "14px 20px" }}>Cost Price</th>
              <th style={{ padding: "14px 20px" }}>Selling Price</th>
              <th style={{ padding: "14px 20px" }}>Tax</th>
              <th style={{ padding: "14px 20px" }}>Status</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={7} style={{ padding: "40px", textAlign: "center", color: "var(--text-muted)" }}>
                  Loading catalog products...
                </td>
              </tr>
            ) : products.length === 0 ? (
              <tr>
                <td colSpan={7} style={{ padding: "40px", textAlign: "center", color: "var(--text-muted)" }}>
                  No products found. Click "Add Product" to create your first item.
                </td>
              </tr>
            ) : (
              products.map((p) => (
                <tr
                  key={p.id}
                  style={{
                    borderBottom: "1px solid var(--border-color)",
                    transition: "background 0.15s ease",
                  }}
                >
                  <td style={{ padding: "14px 20px", fontWeight: 600 }}>
                    <div style={{ display: "flex", alignItems: "center", gap: "10px" }}>
                      <Package size={18} color="var(--accent-primary)" />
                      <span>{p.name}</span>
                    </div>
                  </td>
                  <td style={{ padding: "14px 20px", color: "var(--text-secondary)", fontSize: "0.875rem" }}>
                    <div>{p.sku || "—"}</div>
                    {p.barcode && <div style={{ fontSize: "0.75rem", color: "var(--text-muted)" }}>{p.barcode}</div>}
                  </td>
                  <td style={{ padding: "14px 20px", color: "var(--text-secondary)", fontSize: "0.875rem" }}>
                    {p.categoryName || "General"}
                  </td>
                  <td style={{ padding: "14px 20px", color: "var(--text-secondary)", fontSize: "0.875rem" }}>
                    ₹ {p.costPrice.toFixed(2)}
                  </td>
                  <td style={{ padding: "14px 20px", fontWeight: 700, color: "var(--accent-success)" }}>
                    ₹ {p.sellingPrice.toFixed(2)}
                  </td>
                  <td style={{ padding: "14px 20px", color: "var(--text-secondary)", fontSize: "0.875rem" }}>
                    {p.taxRate}%
                  </td>
                  <td style={{ padding: "14px 20px" }}>
                    <span className={`badge ${p.isActive ? "badge-success" : "badge-danger"}`}>
                      {p.isActive ? "Active" : "Archived"}
                    </span>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {/* Add Product Modal */}
      {showAddModal && (
        <div
          style={{
            position: "fixed",
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            backgroundColor: "rgba(0, 0, 0, 0.7)",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            zIndex: 100,
          }}
        >
          <div
            className="card"
            style={{
              width: "100%",
              maxWidth: "500px",
              padding: "24px",
              backgroundColor: "var(--bg-secondary)",
            }}
          >
            <h2 style={{ fontSize: "1.25rem", fontWeight: 700, marginBottom: "16px" }}>
              Add New Catalog Product
            </h2>
            <form onSubmit={handleCreateProduct} style={{ display: "flex", flexDirection: "column", gap: "14px" }}>
              <div>
                <label style={{ fontSize: "0.8125rem", color: "var(--text-secondary)", display: "block", marginBottom: "6px" }}>
                  Product Name *
                </label>
                <input
                  type="text"
                  required
                  value={formData.name}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                  placeholder="e.g. Wireless Mouse"
                  style={{
                    width: "100%",
                    padding: "10px",
                    backgroundColor: "var(--bg-tertiary)",
                    border: "1px solid var(--border-color)",
                    borderRadius: "var(--radius-sm)",
                    color: "#fff",
                  }}
                />
              </div>

              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "12px" }}>
                <div>
                  <label style={{ fontSize: "0.8125rem", color: "var(--text-secondary)", display: "block", marginBottom: "6px" }}>
                    SKU Code
                  </label>
                  <input
                    type="text"
                    value={formData.sku}
                    onChange={(e) => setFormData({ ...formData, sku: e.target.value })}
                    placeholder="e.g. ELEC-MOU-01"
                    style={{
                      width: "100%",
                      padding: "10px",
                      backgroundColor: "var(--bg-tertiary)",
                      border: "1px solid var(--border-color)",
                      borderRadius: "var(--radius-sm)",
                      color: "#fff",
                    }}
                  />
                </div>
                <div>
                  <label style={{ fontSize: "0.8125rem", color: "var(--text-secondary)", display: "block", marginBottom: "6px" }}>
                    Barcode
                  </label>
                  <input
                    type="text"
                    value={formData.barcode}
                    onChange={(e) => setFormData({ ...formData, barcode: e.target.value })}
                    placeholder="e.g. 8901234567890"
                    style={{
                      width: "100%",
                      padding: "10px",
                      backgroundColor: "var(--bg-tertiary)",
                      border: "1px solid var(--border-color)",
                      borderRadius: "var(--radius-sm)",
                      color: "#fff",
                    }}
                  />
                </div>
              </div>

              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "12px" }}>
                <div>
                  <label style={{ fontSize: "0.8125rem", color: "var(--text-secondary)", display: "block", marginBottom: "6px" }}>
                    Cost Price (₹)
                  </label>
                  <input
                    type="number"
                    step="0.01"
                    value={formData.costPrice}
                    onChange={(e) => setFormData({ ...formData, costPrice: parseFloat(e.target.value) || 0 })}
                    style={{
                      width: "100%",
                      padding: "10px",
                      backgroundColor: "var(--bg-tertiary)",
                      border: "1px solid var(--border-color)",
                      borderRadius: "var(--radius-sm)",
                      color: "#fff",
                    }}
                  />
                </div>
                <div>
                  <label style={{ fontSize: "0.8125rem", color: "var(--text-secondary)", display: "block", marginBottom: "6px" }}>
                    Selling Price (₹) *
                  </label>
                  <input
                    type="number"
                    step="0.01"
                    required
                    value={formData.sellingPrice}
                    onChange={(e) => setFormData({ ...formData, sellingPrice: parseFloat(e.target.value) || 0 })}
                    style={{
                      width: "100%",
                      padding: "10px",
                      backgroundColor: "var(--bg-tertiary)",
                      border: "1px solid var(--border-color)",
                      borderRadius: "var(--radius-sm)",
                      color: "#fff",
                    }}
                  />
                </div>
              </div>

              <div style={{ display: "flex", justifyContent: "flex-end", gap: "12px", marginTop: "12px" }}>
                <button
                  type="button"
                  onClick={() => setShowAddModal(false)}
                  className="btn btn-secondary"
                >
                  Cancel
                </button>
                <button type="submit" className="btn btn-primary">
                  Save Product
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
