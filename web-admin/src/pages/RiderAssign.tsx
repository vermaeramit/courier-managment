import { useEffect, useState } from "react";
import { api } from "../api/client";
import type { ShipmentListItem, User } from "../api/types";

// Manual rider assignment: pick unassigned/active shipments and a rider.
export default function RiderAssign() {
  const [shipments, setShipments] = useState<ShipmentListItem[]>([]);
  const [riders, setRiders] = useState<User[]>([]);
  const [riderByShipment, setRiderByShipment] = useState<Record<number, number>>({});
  const [error, setError] = useState<string | null>(null);
  const [msg, setMsg] = useState<string | null>(null);

  async function load() {
    try {
      const [s, r] = await Promise.all([
        api.get<ShipmentListItem[]>("/api/shipments"),
        api.get<User[]>("/api/users?role=Rider"),
      ]);
      // Assignable = not yet delivered / failed / returned.
      setShipments(s.filter((x) => !["Delivered", "Failed", "RTO"].includes(x.status)));
      setRiders(r);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Load failed");
    }
  }

  useEffect(() => { load(); }, []);

  async function assign(shipmentId: number) {
    const riderId = riderByShipment[shipmentId];
    if (!riderId) return;
    setError(null);
    setMsg(null);
    try {
      await api.post(`/api/shipments/${shipmentId}/assign-rider`, { shipmentId, riderId });
      setMsg(`Assigned rider to shipment ${shipmentId}.`);
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Assign failed");
    }
  }

  return (
    <>
      <h2>Rider assignment</h2>
      <div className="card">
        {error && <p className="error">{error}</p>}
        {msg && <p className="ok">{msg}</p>}
        <table>
          <thead><tr><th>Tracking</th><th>Receiver</th><th>Status</th><th>Current rider</th><th>Assign</th></tr></thead>
          <tbody>
            {shipments.map((s) => (
              <tr key={s.id}>
                <td>{s.trackingId}</td>
                <td>{s.receiverName} <span className="muted">({s.receiverPincode})</span></td>
                <td><span className="badge">{s.status}</span></td>
                <td>{s.assignedRiderName ?? <span className="muted">—</span>}</td>
                <td>
                  <div className="row" style={{ gap: 6 }}>
                    <select value={riderByShipment[s.id] ?? ""}
                            onChange={(e) => setRiderByShipment((m) => ({ ...m, [s.id]: Number(e.target.value) }))}>
                      <option value="">Select rider…</option>
                      {riders.map((r) => <option key={r.id} value={r.id}>{r.name}</option>)}
                    </select>
                    <button onClick={() => assign(s.id)} disabled={!riderByShipment[s.id]}>Assign</button>
                  </div>
                </td>
              </tr>
            ))}
            {shipments.length === 0 && <tr><td colSpan={5} className="muted">Nothing to assign.</td></tr>}
          </tbody>
        </table>
      </div>
    </>
  );
}
