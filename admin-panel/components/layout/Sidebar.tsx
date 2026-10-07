"use client";

import React from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useAuth } from "@/lib/auth/AuthContext";
import {
  LayoutDashboard,
  Building2,
  Users,
  Shield,
  GitBranch,
  Warehouse,
  Package,
  Receipt,
  History,
  LogOut,
} from "lucide-react";

export function Sidebar() {
  const pathname = usePathname();
  const { logout, activeBusiness, hasPermission } = useAuth();

  const navItems = [
    {
      label: "Dashboard",
      href: "/dashboard",
      icon: LayoutDashboard,
      show: true,
    },
    {
      label: "Inventory & Catalog",
      href: "/dashboard/inventory",
      icon: Package,
      show: true,
    },
    {
      label: "Sales & Invoices",
      href: "/dashboard/sales",
      icon: Receipt,
      show: true,
    },
    {
      label: "Businesses",
      href: "/dashboard/businesses",
      icon: Building2,
      show: true,
    },
    {
      label: "Team & Users",
      href: "/dashboard/users",
      icon: Users,
      show: hasPermission("users.view"),
    },
    {
      label: "Roles & Permissions",
      href: "/dashboard/roles",
      icon: Shield,
      show: hasPermission("roles.view"),
    },
    {
      label: "Audit Logs",
      href: "/dashboard/audit",
      icon: History,
      show: hasPermission("audit.view"),
    },
  ];

  return (
    <aside
      style={{
        width: "260px",
        height: "100vh",
        backgroundColor: "var(--bg-secondary)",
        borderRight: "1px solid var(--border-color)",
        display: "flex",
        flexDirection: "column",
        position: "fixed",
        top: 0,
        left: 0,
        zIndex: 50,
      }}
    >
      {/* Brand Header */}
      <div
        style={{
          padding: "24px 20px",
          borderBottom: "1px solid var(--border-color)",
        }}
      >
        <div style={{ display: "flex", alignItems: "center", gap: "10px" }}>
          <div
            style={{
              width: "36px",
              height: "36px",
              borderRadius: "var(--radius-sm)",
              backgroundColor: "var(--accent-primary)",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              fontWeight: 800,
              fontSize: "1.1rem",
              color: "#fff",
            }}
          >
            E
          </div>
          <div>
            <h1 style={{ fontSize: "1rem", fontWeight: 700, letterSpacing: "-0.02em" }}>
              ERP SaaS
            </h1>
            <p style={{ fontSize: "0.75rem", color: "var(--text-secondary)" }}>
              Admin Console
            </p>
          </div>
        </div>
      </div>

      {/* Navigation Links */}
      <nav style={{ padding: "16px 12px", flex: 1, display: "flex", flexDirection: "column", gap: "4px" }}>
        {navItems
          .filter((item) => item.show)
          .map((item) => {
            const Icon = item.icon;
            const isActive = pathname === item.href;
            return (
              <Link
                key={item.href}
                href={item.href}
                style={{
                  display: "flex",
                  alignItems: "center",
                  gap: "12px",
                  padding: "10px 14px",
                  borderRadius: "var(--radius-sm)",
                  fontSize: "0.875rem",
                  fontWeight: 500,
                  color: isActive ? "#ffffff" : "var(--text-secondary)",
                  backgroundColor: isActive ? "var(--bg-tertiary)" : "transparent",
                  transition: "all 0.15s ease",
                }}
              >
                <Icon size={18} color={isActive ? "var(--accent-primary)" : "var(--text-muted)"} />
                <span>{item.label}</span>
              </Link>
            );
          })}
      </nav>

      {/* Tenant Context Footer */}
      <div
        style={{
          padding: "16px",
          borderTop: "1px solid var(--border-color)",
          backgroundColor: "rgba(0, 0, 0, 0.2)",
        }}
      >
        <div style={{ marginBottom: "12px" }}>
          <p style={{ fontSize: "0.75rem", color: "var(--text-muted)" }}>Active Tenant</p>
          <p
            style={{
              fontSize: "0.875rem",
              fontWeight: 600,
              color: "var(--text-primary)",
              overflow: "hidden",
              textOverflow: "ellipsis",
              whiteSpace: "nowrap",
            }}
          >
            {activeBusiness?.name || "No Business Selected"}
          </p>
          <span className="badge badge-info" style={{ marginTop: "4px" }}>
            {activeBusiness?.roleName || "Guest"}
          </span>
        </div>

        <button
          onClick={logout}
          style={{
            width: "100%",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            gap: "8px",
            padding: "8px",
            background: "transparent",
            border: "1px solid var(--border-color)",
            borderRadius: "var(--radius-sm)",
            color: "var(--accent-danger)",
            fontSize: "0.8125rem",
            cursor: "pointer",
          }}
        >
          <LogOut size={14} />
          Sign Out
        </button>
      </div>
    </aside>
  );
}
