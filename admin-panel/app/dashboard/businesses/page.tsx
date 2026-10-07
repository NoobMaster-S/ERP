"use client";

import React, { useState } from "react";
import { useAuth } from "@/lib/auth/AuthContext";
import { executeGraphQL } from "@/lib/graphql/client";
import { CREATE_BUSINESS_MUTATION } from "@/lib/graphql/operations";
import { Building2, Plus, Check } from "lucide-react";

export default function BusinessesPage() {
  const { availableBusinesses, activeBusiness, switchBusiness, token } = useAuth();
  const [showModal, setShowModal] = useState(false);
  const [name, setName] = useState("");
  const [slug, setSlug] = useState("");
  const [businessType, setBusinessType] = useState("RETAIL");
  const [currencyCode, setCurrencyCode] = useState("INR");
  const [currencySymbol, setCurrencySymbol] = useState("₹");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleCreate = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmitting(true);
    setError(null);

    const res = await executeGraphQL(
      CREATE_BUSINESS_MUTATION,
      {
        input: {
          name,
          slug,
          businessType,
          currencyCode,
          currencySymbol,
          decimalPlaces: 2,
        },
      },
      token
    );

    if (res.data?.createBusiness) {
      setShowModal(false);
      setName("");
      setSlug("");
      window.location.reload();
    } else {
      setError(res.errors?.[0]?.message || "Failed to create business.");
    }
    setIsSubmitting(false);
  };

  return (
    <div>
      <div
        style={{
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
          marginBottom: "28px",
        }}
      >
        <div>
          <h1 style={{ fontSize: "1.75rem", fontWeight: 700 }}>Business Workspaces</h1>
          <p style={{ color: "var(--text-secondary)", marginTop: "4px" }}>
            Multi-tenant businesses associated with your user account.
          </p>
        </div>
        <button
          onClick={() => setShowModal(true)}
          style={{
            display: "inline-flex",
            alignItems: "center",
            gap: "8px",
            padding: "10px 18px",
            backgroundColor: "var(--accent-primary)",
            color: "#ffffff",
            border: "none",
            borderRadius: "var(--radius-sm)",
            fontWeight: 600,
            fontSize: "0.875rem",
            cursor: "pointer",
          }}
        >
          <Plus size={16} />
          Create New Business
        </button>
      </div>

      {/* Businesses Table */}
      <div className="table-container">
        <table>
          <thead>
            <tr>
              <th>Business Name</th>
              <th>Slug / Identifier</th>
              <th>Business Type</th>
              <th>Your Role</th>
              <th>Status</th>
              <th>Action</th>
            </tr>
          </thead>
          <tbody>
            {availableBusinesses.map((b) => {
              const isActive = b.id === activeBusiness?.id;
              return (
                <tr key={b.id}>
                  <td>
                    <div style={{ display: "flex", alignItems: "center", gap: "10px" }}>
                      <Building2 size={16} color="var(--accent-primary)" />
                      <span style={{ fontWeight: 600 }}>{b.name}</span>
                    </div>
                  </td>
                  <td style={{ fontFamily: "var(--font-mono)", color: "var(--text-secondary)" }}>
                    {b.slug}
                  </td>
                  <td>
                    <span className="badge badge-info">{b.businessType}</span>
                  </td>
                  <td>{b.roleName}</td>
                  <td>
                    <span className="badge badge-success">Active</span>
                  </td>
                  <td>
                    {isActive ? (
                      <span
                        style={{
                          display: "inline-flex",
                          alignItems: "center",
                          gap: "4px",
                          color: "var(--accent-success)",
                          fontSize: "0.8125rem",
                          fontWeight: 600,
                        }}
                      >
                        <Check size={14} /> Active
                      </span>
                    ) : (
                      <button
                        onClick={() => switchBusiness(b)}
                        style={{
                          padding: "6px 12px",
                          backgroundColor: "var(--bg-tertiary)",
                          border: "1px solid var(--border-color)",
                          borderRadius: "var(--radius-sm)",
                          color: "var(--text-primary)",
                          fontSize: "0.8125rem",
                          cursor: "pointer",
                        }}
                      >
                        Switch
                      </button>
                    )}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      {/* Create Business Modal */}
      {showModal && (
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
            backdropFilter: "blur(4px)",
          }}
        >
          <div
            className="glass-panel"
            style={{
              width: "100%",
              maxWidth: "480px",
              padding: "32px",
              backgroundColor: "var(--bg-secondary)",
            }}
          >
            <h2 style={{ fontSize: "1.25rem", fontWeight: 700, marginBottom: "8px" }}>
              Register Business Tenant
            </h2>
            <p style={{ color: "var(--text-secondary)", fontSize: "0.875rem", marginBottom: "20px" }}>
              Initializes an independent multi-tenant ERP partition with default roles.
            </p>

            {error && (
              <p style={{ color: "var(--accent-danger)", fontSize: "0.875rem", marginBottom: "16px" }}>
                {error}
              </p>
            )}

            <form onSubmit={handleCreate} style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
              <div>
                <label style={{ display: "block", fontSize: "0.8125rem", marginBottom: "6px", color: "var(--text-secondary)" }}>
                  Business Name
                </label>
                <input
                  type="text"
                  required
                  value={name}
                  onChange={(e) => {
                    setName(e.target.value);
                    if (!slug) setSlug(e.target.value.toLowerCase().replace(/[^a-z0-9]/g, "-"));
                  }}
                  placeholder="e.g. Apex Electronics"
                  style={{
                    width: "100%",
                    padding: "10px",
                    backgroundColor: "var(--bg-tertiary)",
                    border: "1px solid var(--border-color)",
                    borderRadius: "var(--radius-sm)",
                    color: "var(--text-primary)",
                  }}
                />
              </div>

              <div>
                <label style={{ display: "block", fontSize: "0.8125rem", marginBottom: "6px", color: "var(--text-secondary)" }}>
                  Identifier Slug
                </label>
                <input
                  type="text"
                  required
                  value={slug}
                  onChange={(e) => setSlug(e.target.value)}
                  placeholder="apex-electronics"
                  style={{
                    width: "100%",
                    padding: "10px",
                    backgroundColor: "var(--bg-tertiary)",
                    border: "1px solid var(--border-color)",
                    borderRadius: "var(--radius-sm)",
                    color: "var(--text-primary)",
                  }}
                />
              </div>

              <div>
                <label style={{ display: "block", fontSize: "0.8125rem", marginBottom: "6px", color: "var(--text-secondary)" }}>
                  Business Vertical / Type
                </label>
                <select
                  value={businessType}
                  onChange={(e) => setBusinessType(e.target.value)}
                  style={{
                    width: "100%",
                    padding: "10px",
                    backgroundColor: "var(--bg-tertiary)",
                    border: "1px solid var(--border-color)",
                    borderRadius: "var(--radius-sm)",
                    color: "var(--text-primary)",
                  }}
                >
                  <option value="RETAIL">Retail Shop / POS</option>
                  <option value="JEWELLERY">Jewellery & Gold Business</option>
                  <option value="ELECTRONICS">Electronics & Appliances</option>
                  <option value="GROCERY">Grocery & Supermarket</option>
                  <option value="WHOLESALE">Wholesale Trader</option>
                  <option value="DISTRIBUTOR">Distributor</option>
                  <option value="SERVICE">Service Business</option>
                  <option value="MANUFACTURING">Small Manufacturing</option>
                  <option value="RESTAURANT">Restaurant / Cafe</option>
                  <option value="GENERAL">General Trading</option>
                </select>
              </div>

              <div style={{ display: "flex", gap: "12px", marginTop: "12px" }}>
                <button
                  type="button"
                  onClick={() => setShowModal(false)}
                  style={{
                    flex: 1,
                    padding: "10px",
                    backgroundColor: "transparent",
                    border: "1px solid var(--border-color)",
                    borderRadius: "var(--radius-sm)",
                    color: "var(--text-secondary)",
                    cursor: "pointer",
                  }}
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isSubmitting}
                  style={{
                    flex: 1,
                    padding: "10px",
                    backgroundColor: "var(--accent-primary)",
                    border: "none",
                    borderRadius: "var(--radius-sm)",
                    color: "#ffffff",
                    fontWeight: 600,
                    cursor: isSubmitting ? "not-allowed" : "pointer",
                  }}
                >
                  {isSubmitting ? "Creating..." : "Save Business"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
