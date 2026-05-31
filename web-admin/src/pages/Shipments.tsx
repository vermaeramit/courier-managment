import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { api } from "../api/client";
import { SHIPMENT_STATUSES, type ShipmentListItem } from "../api/types";

export default function Shipments() {
  const [rows, setRows] = useState<ShipmentListItem[]>([]);
  const [status, setStatus] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  function load() {
    setLoading(true);
    const qs = status ? `?status=${status}` : "";
    api.get<ShipmentListItem[]>(`/api/shipments${qs}`)
      .then(setRows)
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false));
  }

  useEffect(load, [status]);

  return (
    <>
      <h2>Shipments</h2>
      <div className="card">
        <div className="field" style={{ maxWidth: 220 }}>
          <label>Filter by status</label>
          <select value={status} onChange={(e) => setStatus(e.target.value)}>
            <option value="">All</option>
            {SHIPMENT_STATUSES.map((s) => <option key={s}>{s}</option>)}
          </select>
        </div>
        {error && <p className="error">{error}</p>}
        {loading ? <p className="muted">Loading…</p> : (
          <table>
            <thead>
              <tr>
                <th>Tracking</th><th>Route</th><th>Receiver</th><th>Service</th>
                <th>Payment</th><th>Rider</th><th>Status</th><th>Created</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((s) => (
                <tr key={s.id}>
                  <td><Link to={`/shipments/${s.id}`}>{s.trackingId}</Link></td>
                  <td>{s.originBranchCode} → {s.destBranchCode}</td>
                  <td>{s.receiverName}<br /><span className="muted">{s.receiverPincode}</span></td>
                  <td>{s.serviceType}</td>
                  <td>{s.paymentMode}{s.paymentMode === "COD" ? ` ₹${s.codAmount}` : ""}</td>
                  <td>{s.assignedRiderName ?? <span className="muted">—</span>}</td>
                  <td><span className="badge">{s.status}</span></td>
                  <td className="muted">{new Date(s.createdAt).toLocaleString()}</td>
                </tr>
              ))}
              {rows.length === 0 && <tr><td colSpan={8} className="muted">No shipments.</td></tr>}
            </tbody>
          </table>
        )}
      </div>
    </>
  );
}
