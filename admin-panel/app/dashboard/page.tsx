"use client";

import React from "react";
import { useAuth } from "@/lib/auth/AuthContext";
import {
  Building2,
  Users,
  ShieldCheck,
  Activity,
  ArrowUpRight,
} from "lucide-react";
import Link from "next/link";

export default function DashboardHomePage() {
  const { activeBusiness, availableBusinesses } = useAuth();

  const stats = [
    {
      label: "Active Organization",
      value: activeBusiness?.name || "N/A",
      sub: `Type: ${activeBusiness?.businessType || "General"}`,
      icon: Building2,
      color: "var(--accent-primary)",
    },
    {
      label: "User Role",
      value: activeBusiness?.roleName || "Owner",
      sub: `${activeBusiness?.permissions.length || 0} permissions granted`,
      icon: ShieldCheck,
      color: "var(--accent-success)",
    },
    {
      label: "Accessible Tenants",
      value: `${availableBusinesses.length}`,
      sub: "Multi-tenant workspaces",
      icon: Users,
      color: "var(--accent-warning)",
    },
    {
      label: "System Status",
      value: "Operational",
      sub: "GraphQL & Postgres online",
      icon: Activity,
      color: "var(--accent-primary)",
    },
  ];

  return (
    <div>
      {/* Page Title */}
      <div style={{ marginBottom: "28px" }}>
        <h1 style={{ fontSize: "1.75rem", fontWeight: 700 }}>Administration Overview</h1>
        <p style={{ color: "var(--text-secondary)", marginTop: "4px" }}>
          Platform metrics and tenant workspace management.
        </p>
      </div>

      {/* Metrics Grid */}
      <div
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fit, minmax(240px, 1fr))",
          gap: "20px",
          marginBottom: "36px",
        }}
      >
        {stats.map((s, idx) => {
          const Icon = s.icon;
          return (
            <div
              key={idx}
              className="glass-panel"
              style={{ padding: "24px" }}
            >
              <div
                style={{
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "space-between",
                  marginBottom: "16px",
                }}
              >
                <span style={{ fontSize: "0.8125rem", color: "var(--text-secondary)" }}>
                  {s.label}
                </span>
                <div
                  style={{
                    padding: "8px",
                    borderRadius: "var(--radius-sm)",
                    backgroundColor: "rgba(255, 255, 255, 0.04)",
                  }}
                >
                  <Icon size={18} color={s.color} />
                </div>
              </div>
              <h2
                style={{
                  fontSize: "1.5rem",
                  fontWeight: 700,
                  overflow: "hidden",
                  textOverflow: "ellipsis",
                  whiteSpace: "nowrap",
                }}
              >
                {s.value}
              </h2>
              <p style={{ fontSize: "0.75rem", color: "var(--text-muted)", marginTop: "4px" }}>
                {s.sub}
              </p>
            </div>
          );
        })}
      </div>

      {/* Quick Navigation Cards */}
      <div
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fit, minmax(320px, 1fr))",
          gap: "24px",
        }}
      >
        <div className="glass-panel" style={{ padding: "28px" }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
            <div>
              <h3 style={{ fontSize: "1.125rem", fontWeight: 600 }}>Manage Businesses</h3>
              <p style={{ color: "var(--text-secondary)", fontSize: "0.875rem", marginTop: "4px" }}>
                Create new business workspaces, configure currencies, and branch settings.
              </p>
            </div>
            <Link
              href="/dashboard/businesses"
              style={{
                display: "inline-flex",
                alignItems: "center",
                gap: "4px",
                color: "var(--accent-primary)",
                fontSize: "0.875rem",
                fontWeight: 600,
              }}
            >
              <span>View</span>
              <ArrowUpRight size={16} />
            </Link>
          </div>
        </div>

        <div className="glass-panel" style={{ padding: "28px" }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
            <div>
              <h3 style={{ fontSize: "1.125rem", fontWeight: 600 }}>Roles & Permission Matrix</h3>
              <p style={{ color: "var(--text-secondary)", fontSize: "0.875rem", marginTop: "4px" }}>
                Inspect granular permission codes and custom role policies.
              </p>
            </div>
            <Link
              href="/dashboard/roles"
              style={{
                display: "inline-flex",
                alignItems: "center",
                gap: "4px",
                color: "var(--accent-primary)",
                fontSize: "0.875rem",
                fontWeight: 600,
              }}
            >
              <span>View</span>
              <ArrowUpRight size={16} />
            </Link>
          </div>
        </div>
      </div>
    </div>
  );
}
