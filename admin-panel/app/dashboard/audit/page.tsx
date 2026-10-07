"use client";

import React, { useState, useEffect } from "react";
import { useAuth } from "@/lib/auth/AuthContext";
import { executeGraphQL } from "@/lib/graphql/client";
import { GET_AUDIT_LOGS } from "@/lib/graphql/operations";
import { History, ShieldAlert } from "lucide-react";

interface AuditEntry {
  id: string;
  action: string;
  entityType: string;
  entityId: string;
  userEmail: string;
  createdAt: string;
}

export default function AuditLogsPage() {
  const { token, activeBusiness } = useAuth();
  const [logs, setLogs] = useState<AuditEntry[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function fetchLogs() {
      if (!token || !activeBusiness) return;
      const res = await executeGraphQL(GET_AUDIT_LOGS, { limit: 100 }, token, activeBusiness.id);
      if (res.data?.auditLogs) {
        setLogs(res.data.auditLogs);
      }
      setLoading(false);
    }
    fetchLogs();
  }, [token, activeBusiness]);

  return (
    <div>
      <div style={{ marginBottom: "28px" }}>
        <h1 style={{ fontSize: "1.75rem", fontWeight: 700 }}>Security & Operation Audit Trail</h1>
        <p style={{ color: "var(--text-secondary)", marginTop: "4px" }}>
          Immutable change history for {activeBusiness?.name || "active business"}.
        </p>
      </div>

      {loading ? (
        <p style={{ color: "var(--text-secondary)" }}>Loading audit records...</p>
      ) : logs.length === 0 ? (
        <div className="glass-panel" style={{ padding: "48px", textAlign: "center" }}>
          <History size={32} color="var(--text-muted)" style={{ margin: "0 auto 12px auto" }} />
          <h3 style={{ fontSize: "1.125rem", fontWeight: 600 }}>No audit logs found</h3>
          <p style={{ color: "var(--text-secondary)", fontSize: "0.875rem", marginTop: "4px" }}>
            Operational actions will appear here in chronological sequence.
          </p>
        </div>
      ) : (
        <div className="table-container">
          <table>
            <thead>
              <tr>
                <th>Timestamp</th>
                <th>Action</th>
                <th>Entity Type</th>
                <th>Entity ID</th>
                <th>Actor User</th>
              </tr>
            </thead>
            <tbody>
              {logs.map((log) => (
                <tr key={log.id}>
                  <td style={{ color: "var(--text-secondary)", whiteSpace: "nowrap" }}>
                    {new Date(log.createdAt).toLocaleString()}
                  </td>
                  <td>
                    <span className="badge badge-warning" style={{ fontFamily: "var(--font-mono)" }}>
                      {log.action}
                    </span>
                  </td>
                  <td>{log.entityType}</td>
                  <td style={{ fontFamily: "var(--font-mono)", fontSize: "0.8125rem", color: "var(--text-muted)" }}>
                    {log.entityId}
                  </td>
                  <td style={{ fontWeight: 500 }}>{log.userEmail}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
