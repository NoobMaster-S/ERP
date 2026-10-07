"use client";

import React, { useState } from "react";
import { useAuth } from "@/lib/auth/AuthContext";
import { Users, UserPlus, Mail, Shield } from "lucide-react";

export default function UsersTeamPage() {
  const { activeBusiness, user } = useAuth();
  const [showInviteModal, setShowInviteModal] = useState(false);

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
          <h1 style={{ fontSize: "1.75rem", fontWeight: 700 }}>Team & User Management</h1>
          <p style={{ color: "var(--text-secondary)", marginTop: "4px" }}>
            Manage staff memberships and role allocations for {activeBusiness?.name || "active organization"}.
          </p>
        </div>
        <button
          onClick={() => setShowInviteModal(true)}
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
          <UserPlus size={16} />
          Invite Team Member
        </button>
      </div>

      <div className="table-container">
        <table>
          <thead>
            <tr>
              <th>Member Name</th>
              <th>Email</th>
              <th>Assigned Role</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>
                <div style={{ display: "flex", alignItems: "center", gap: "10px" }}>
                  <div
                    style={{
                      width: "32px",
                      height: "32px",
                      borderRadius: "var(--radius-full)",
                      backgroundColor: "var(--bg-tertiary)",
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "center",
                      fontWeight: 600,
                      color: "var(--accent-primary)",
                    }}
                  >
                    {user?.firstName ? user.firstName[0].toUpperCase() : "U"}
                  </div>
                  <span style={{ fontWeight: 600 }}>
                    {user ? `${user.firstName} ${user.lastName}`.trim() : "Current User"}
                  </span>
                </div>
              </td>
              <td style={{ color: "var(--text-secondary)" }}>{user?.email}</td>
              <td>
                <span className="badge badge-info">{activeBusiness?.roleName || "Owner"}</span>
              </td>
              <td>
                <span className="badge badge-success">Active</span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      {showInviteModal && (
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
              maxWidth: "440px",
              padding: "32px",
              backgroundColor: "var(--bg-secondary)",
            }}
          >
            <h2 style={{ fontSize: "1.25rem", fontWeight: 700, marginBottom: "8px" }}>
              Invite Team Member
            </h2>
            <p style={{ color: "var(--text-secondary)", fontSize: "0.875rem", marginBottom: "20px" }}>
              An invitation email will be dispatched to join {activeBusiness?.name}.
            </p>

            <form
              onSubmit={(e) => {
                e.preventDefault();
                setShowInviteModal(false);
              }}
              style={{ display: "flex", flexDirection: "column", gap: "16px" }}
            >
              <div>
                <label style={{ display: "block", fontSize: "0.8125rem", marginBottom: "6px", color: "var(--text-secondary)" }}>
                  Email Address
                </label>
                <input
                  type="email"
                  required
                  placeholder="colleague@business.com"
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
                  Select Role
                </label>
                <select
                  style={{
                    width: "100%",
                    padding: "10px",
                    backgroundColor: "var(--bg-tertiary)",
                    border: "1px solid var(--border-color)",
                    borderRadius: "var(--radius-sm)",
                    color: "var(--text-primary)",
                  }}
                >
                  <option value="Manager">Manager</option>
                  <option value="Sales Staff">Sales Staff</option>
                  <option value="Cashier">Cashier</option>
                  <option value="Inventory Staff">Inventory Staff</option>
                  <option value="Accountant">Accountant</option>
                </select>
              </div>

              <div style={{ display: "flex", gap: "12px", marginTop: "12px" }}>
                <button
                  type="button"
                  onClick={() => setShowInviteModal(false)}
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
                  style={{
                    flex: 1,
                    padding: "10px",
                    backgroundColor: "var(--accent-primary)",
                    border: "none",
                    borderRadius: "var(--radius-sm)",
                    color: "#ffffff",
                    fontWeight: 600,
                    cursor: "pointer",
                  }}
                >
                  Send Invite
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
