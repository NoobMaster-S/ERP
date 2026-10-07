"use client";

import React, { useState, useEffect } from "react";
import { useAuth } from "@/lib/auth/AuthContext";
import { executeGraphQL } from "@/lib/graphql/client";
import { GET_ROLES, GET_PERMISSIONS } from "@/lib/graphql/operations";
import { Shield, Check, Lock } from "lucide-react";

interface Role {
  id: string;
  name: string;
  description: string;
  isSystem: boolean;
  permissions: string[];
}

interface Permission {
  id: string;
  module: string;
  description: string;
}

export default function RolesMatrixPage() {
  const { token, activeBusiness } = useAuth();
  const [roles, setRoles] = useState<Role[]>([]);
  const [permissions, setPermissions] = useState<Permission[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function fetchData() {
      if (!token || !activeBusiness) return;
      const [resRoles, resPerms] = await Promise.all([
        executeGraphQL(GET_ROLES, {}, token, activeBusiness.id),
        executeGraphQL(GET_PERMISSIONS, {}, token, activeBusiness.id),
      ]);

      if (resRoles.data?.roles) setRoles(resRoles.data.roles);
      if (resPerms.data?.permissions) setPermissions(resPerms.data.permissions);
      setLoading(false);
    }
    fetchData();
  }, [token, activeBusiness]);

  // Group permissions by module
  const modules = Array.from(new Set(permissions.map((p) => p.module)));

  return (
    <div>
      <div style={{ marginBottom: "28px" }}>
        <h1 style={{ fontSize: "1.75rem", fontWeight: 700 }}>Roles & Permission Matrix</h1>
        <p style={{ color: "var(--text-secondary)", marginTop: "4px" }}>
          Role-Based Access Control matrix for {activeBusiness?.name || "active organization"}.
        </p>
      </div>

      {loading ? (
        <p style={{ color: "var(--text-secondary)" }}>Loading permission matrix...</p>
      ) : (
        <div style={{ display: "flex", flexDirection: "column", gap: "32px" }}>
          {/* Roles Summary Cards */}
          <div
            style={{
              display: "grid",
              gridTemplateColumns: "repeat(auto-fill, minmax(280px, 1fr))",
              gap: "20px",
            }}
          >
            {roles.map((r) => (
              <div key={r.id} className="glass-panel" style={{ padding: "20px" }}>
                <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: "8px" }}>
                  <div style={{ display: "flex", alignItems: "center", gap: "8px" }}>
                    <Shield size={18} color="var(--accent-primary)" />
                    <h3 style={{ fontSize: "1.0625rem", fontWeight: 700 }}>{r.name}</h3>
                  </div>
                  {r.isSystem && (
                    <span className="badge badge-warning" style={{ gap: "4px" }}>
                      <Lock size={10} /> System
                    </span>
                  )}
                </div>
                <p style={{ fontSize: "0.8125rem", color: "var(--text-secondary)", marginBottom: "12px" }}>
                  {r.description || "Custom business role"}
                </p>
                <span className="badge badge-info">
                  {r.permissions.length} Permissions
                </span>
              </div>
            ))}
          </div>

          {/* Matrix Table */}
          <div className="table-container">
            <table>
              <thead>
                <tr>
                  <th style={{ minWidth: "220px" }}>Permission / Action</th>
                  <th style={{ minWidth: "120px" }}>Module</th>
                  {roles.map((r) => (
                    <th key={r.id} style={{ textAlign: "center", minWidth: "110px" }}>
                      {r.name}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {modules.map((mod) => {
                  const modPerms = permissions.filter((p) => p.module === mod);
                  return (
                    <React.Fragment key={mod}>
                      <tr style={{ backgroundColor: "rgba(31, 41, 55, 0.4)" }}>
                        <td colSpan={2 + roles.length} style={{ fontWeight: 700, color: "var(--accent-primary)", padding: "8px 16px" }}>
                          {mod.toUpperCase()}
                        </td>
                      </tr>
                      {modPerms.map((p) => (
                        <tr key={p.id}>
                          <td>
                            <p style={{ fontWeight: 600 }}>{p.id}</p>
                            <p style={{ fontSize: "0.75rem", color: "var(--text-muted)" }}>{p.description}</p>
                          </td>
                          <td style={{ color: "var(--text-secondary)" }}>{p.module}</td>
                          {roles.map((r) => {
                            const hasIt = r.permissions.includes(p.id);
                            return (
                              <td key={r.id} style={{ textAlign: "center" }}>
                                {hasIt ? (
                                  <div
                                    style={{
                                      display: "inline-flex",
                                      alignItems: "center",
                                      justifyContent: "center",
                                      width: "22px",
                                      height: "22px",
                                      borderRadius: "var(--radius-full)",
                                      backgroundColor: "rgba(16, 185, 129, 0.15)",
                                      color: "#34d399",
                                    }}
                                  >
                                    <Check size={14} />
                                  </div>
                                ) : (
                                  <span style={{ color: "var(--text-muted)" }}>—</span>
                                )}
                              </td>
                            );
                          })}
                        </tr>
                      ))}
                    </React.Fragment>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}
