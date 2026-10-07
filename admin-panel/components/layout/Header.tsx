"use client";

import React from "react";
import { useAuth } from "@/lib/auth/AuthContext";
import { Building2 } from "lucide-react";

export function Header() {
  const { user, activeBusiness, availableBusinesses, switchBusiness } = useAuth();

  return (
    <header
      style={{
        height: "64px",
        backgroundColor: "var(--bg-secondary)",
        borderBottom: "1px solid var(--border-color)",
        display: "flex",
        alignItems: "center",
        justifyContent: "space-between",
        padding: "0 28px",
        marginLeft: "260px",
      }}
    >
      {/* Tenant Selector Dropdown */}
      <div style={{ display: "flex", alignItems: "center", gap: "12px" }}>
        <Building2 size={18} color="var(--accent-primary)" />
        <select
          value={activeBusiness?.id || ""}
          onChange={(e) => {
            const selected = availableBusinesses.find((b) => b.id === e.target.value);
            if (selected) switchBusiness(selected);
          }}
          style={{
            backgroundColor: "var(--bg-tertiary)",
            color: "var(--text-primary)",
            border: "1px solid var(--border-color)",
            padding: "6px 12px",
            borderRadius: "var(--radius-sm)",
            fontSize: "0.875rem",
            outline: "none",
            cursor: "pointer",
          }}
        >
          {availableBusinesses.map((b) => (
            <option key={b.id} value={b.id}>
              {b.name} ({b.roleName})
            </option>
          ))}
        </select>
      </div>

      {/* User Info */}
      <div style={{ display: "flex", alignItems: "center", gap: "16px" }}>
        <div style={{ textAlign: "right" }}>
          <p style={{ fontSize: "0.875rem", fontWeight: 600 }}>
            {user ? `${user.firstName} ${user.lastName}`.trim() || user.email : "Admin"}
          </p>
          <p style={{ fontSize: "0.75rem", color: "var(--text-secondary)" }}>
            {user?.email}
          </p>
        </div>
        <div
          style={{
            width: "36px",
            height: "36px",
            borderRadius: "var(--radius-full)",
            backgroundColor: "var(--bg-tertiary)",
            border: "1px solid var(--border-color)",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            fontWeight: 700,
            fontSize: "0.875rem",
            color: "var(--accent-primary)",
          }}
        >
          {user?.firstName ? user.firstName[0].toUpperCase() : "U"}
        </div>
      </div>
    </header>
  );
}
