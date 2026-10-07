"use client";

import React, { useState, useEffect } from "react";
import { useAuth } from "@/lib/auth/AuthContext";
import { executeGraphQL } from "@/lib/graphql/client";
import { GET_SALES, CLEAR_ORDERS_MUTATION } from "@/lib/graphql/operations";
import { Receipt, RefreshCw, AlertCircle, CheckCircle2, Clock, Trash2 } from "lucide-react";

interface SaleItem {
  id: string;
  productName: string;
  quantity: number;
  unitPrice: number;
  lineTotal: number;
}

interface Sale {
  id: string;
  invoiceNumber: string;
  clientInvoiceRef: string;
  subtotal: number;
  taxAmount: number;
  discountAmount: number;
  grandTotal: number;
  paidAmount: number;
  paymentStatus: string;
  paymentMethod: string;
  createdAt: string;
  customerName: string;
  items: SaleItem[];
}

export default function SalesPage() {
  const { token, activeBusiness } = useAuth();
  const [sales, setSales] = useState<Sale[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [successMsg, setSuccessMsg] = useState<string | null>(null);
  const [showClearConfirm, setShowClearConfirm] = useState(false);
  const [clearing, setClearing] = useState(false);

  const fetchSales = async () => {
    if (!token || !activeBusiness) return;
    setLoading(true);
    setError(null);
    try {
      const res = await executeGraphQL<{ sales: Sale[] }>(
        GET_SALES,
        { limit: 50 },
        token,
        activeBusiness.id
      );
      if (res.data?.sales) {
        setSales(res.data.sales);
      } else if (res.errors) {
        setError(res.errors[0]?.message || "Failed to load sales invoices");
      }
    } catch (err: any) {
      setError(err?.message || "Failed to load sales invoices");
    } finally {
      setLoading(false);
    }
  };

  const handleClearOrders = async () => {
    if (!token || !activeBusiness) return;
    setClearing(true);
    setError(null);
    try {
      const res = await executeGraphQL<{ clearOrders: boolean }>(
        CLEAR_ORDERS_MUTATION,
        { confirm: true },
        token,
        activeBusiness.id
      );
      if (res.data?.clearOrders) {
        setSuccessMsg("All sales orders cleared successfully. Products and customer accounts were preserved.");
        setShowClearConfirm(false);
        fetchSales();
      } else if (res.errors) {
        setError(res.errors[0]?.message || "Failed to clear sales orders");
      }
    } catch (err: any) {
      setError(err?.message || "Failed to clear sales orders");
    } finally {
      setClearing(false);
    }
  };

  useEffect(() => {
    fetchSales();
  }, [token, activeBusiness]);

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: "24px" }}>
      {/* Header */}
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <div>
          <h1 style={{ fontSize: "1.75rem", fontWeight: 700, letterSpacing: "-0.02em" }}>
            Sales & Invoices
          </h1>
          <p style={{ color: "var(--text-secondary)", fontSize: "0.875rem", marginTop: "4px" }}>
            Authoritative legal sequential invoices synchronized across mobile POS terminals and online channels.
          </p>
        </div>

        <div style={{ display: "flex", gap: "12px", alignItems: "center" }}>
          <button
            onClick={() => setShowClearConfirm(true)}
            className="btn btn-secondary"
            style={{
              display: "flex",
              alignItems: "center",
              gap: "8px",
              color: "var(--accent-danger, #ef4444)",
              borderColor: "rgba(239, 68, 68, 0.3)",
            }}
          >
            <Trash2 size={16} />
            Clear Order History
          </button>

          <button
            onClick={fetchSales}
            className="btn btn-secondary"
            style={{ display: "flex", alignItems: "center", gap: "8px" }}
          >
            <RefreshCw size={16} />
            Refresh
          </button>
        </div>
      </div>

      {/* Clear Confirmation Modal */}
      {showClearConfirm && (
        <div
          style={{
            padding: "16px 20px",
            backgroundColor: "rgba(239, 68, 68, 0.1)",
            border: "1px solid var(--accent-danger)",
            borderRadius: "var(--radius-md)",
            display: "flex",
            justifyContent: "space-between",
            alignItems: "center",
            gap: "16px",
          }}
        >
          <div>
            <div style={{ fontWeight: 600, color: "var(--accent-danger)", fontSize: "0.95rem" }}>
              Are you sure you want to clear all order history?
            </div>
            <div style={{ fontSize: "0.85rem", color: "var(--text-secondary)", marginTop: "4px" }}>
              This will permanently delete all sales and reset invoice numbering back to #1. Products and customer accounts will NOT be affected.
            </div>
          </div>
          <div style={{ display: "flex", gap: "8px" }}>
            <button
              onClick={() => setShowClearConfirm(false)}
              className="btn btn-secondary"
              disabled={clearing}
            >
              Cancel
            </button>
            <button
              onClick={handleClearOrders}
              className="btn btn-primary"
              style={{ backgroundColor: "var(--accent-danger)", borderColor: "var(--accent-danger)" }}
              disabled={clearing}
            >
              {clearing ? "Clearing..." : "Yes, Clear Orders"}
            </button>
          </div>
        </div>
      )}

      {/* Success Notification */}
      {successMsg && (
        <div
          style={{
            padding: "12px 16px",
            backgroundColor: "rgba(16, 185, 129, 0.15)",
            border: "1px solid var(--accent-success, #10b981)",
            borderRadius: "var(--radius-sm)",
            color: "var(--accent-success, #10b981)",
            display: "flex",
            alignItems: "center",
            gap: "8px",
          }}
        >
          <CheckCircle2 size={18} />
          <span>{successMsg}</span>
        </div>
      )}

      {/* Error Notification */}
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

      {/* Invoices Table */}
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
              <th style={{ padding: "14px 20px" }}>Invoice Number</th>
              <th style={{ padding: "14px 20px" }}>Client Offline Ref</th>
              <th style={{ padding: "14px 20px" }}>Customer</th>
              <th style={{ padding: "14px 20px" }}>Date & Time</th>
              <th style={{ padding: "14px 20px" }}>Method</th>
              <th style={{ padding: "14px 20px" }}>Status</th>
              <th style={{ padding: "14px 20px", textAlign: "right" }}>Grand Total</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={7} style={{ padding: "40px", textAlign: "center", color: "var(--text-muted)" }}>
                  Loading sales invoices...
                </td>
              </tr>
            ) : sales.length === 0 ? (
              <tr>
                <td colSpan={7} style={{ padding: "40px", textAlign: "center", color: "var(--text-muted)" }}>
                  No sales invoices recorded yet. Invoices billed via the mobile POS or backend will appear here.
                </td>
              </tr>
            ) : (
              sales.map((s) => (
                <tr
                  key={s.id}
                  style={{
                    borderBottom: "1px solid var(--border-color)",
                    transition: "background 0.15s ease",
                  }}
                >
                  <td style={{ padding: "14px 20px", fontWeight: 700 }}>
                    <div style={{ display: "flex", alignItems: "center", gap: "8px" }}>
                      <Receipt size={16} color="var(--accent-primary)" />
                      <span>{s.invoiceNumber}</span>
                    </div>
                  </td>
                  <td style={{ padding: "14px 20px", color: "var(--text-muted)", fontSize: "0.8125rem" }}>
                    {s.clientInvoiceRef || "Direct Server"}
                  </td>
                  <td style={{ padding: "14px 20px", fontWeight: 500 }}>
                    {s.customerName}
                  </td>
                  <td style={{ padding: "14px 20px", color: "var(--text-secondary)", fontSize: "0.875rem" }}>
                    {new Date(s.createdAt).toLocaleString()}
                  </td>
                  <td style={{ padding: "14px 20px", fontSize: "0.8125rem", color: "var(--text-secondary)" }}>
                    {s.paymentMethod}
                  </td>
                  <td style={{ padding: "14px 20px" }}>
                    <span
                      className={`badge ${
                        s.paymentStatus === "PAID"
                          ? "badge-success"
                          : s.paymentStatus === "PARTIAL"
                          ? "badge-warning"
                          : "badge-danger"
                      }`}
                    >
                      {s.paymentStatus}
                    </span>
                  </td>
                  <td
                    style={{
                      padding: "14px 20px",
                      textAlign: "right",
                      fontWeight: 700,
                      fontSize: "1rem",
                      color: "var(--accent-success)",
                    }}
                  >
                    ₹ {s.grandTotal.toFixed(2)}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
