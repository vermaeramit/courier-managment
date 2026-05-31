import { useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import { api } from "../api/client";
import { SHIPMENT_STATUSES, type PublicTracking, type Shipment } from "../api/types";

export default function ShipmentDetail() {
  const { id } = useParams();
  const [shipment, setShipment] = useState<Shipment | null>(null);
  const [tracking, setTracking] = useState<PublicTracking | null>(null);
  const [newStatus, setNewStatus] = useState("");
  const [remarks, setRemarks] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function load() {
    try {
      const s = await api.get<Shipment>(`/api/shipments/${id}`);
      setShipment(s);
      setNewStatus(s.status);
      const t = await api.get<PublicTracking>(`/api/track/${s.trackingId}`);
      setTracking(t);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Load failed");
    }
  }

  useEffect(() => { load(); /* eslint-disable-next-line */ }, [id]);

  async function updateStatus() {
    if (!shipment) return;
    setBusy(true);
    setError(null);
    try {
      await api.post(`/api/shipments/${shipment.id}/status`, {
        shipmentId: shipment.id,
        status: newStatus,
        remarks: remarks || null,
      });
      setRemarks("");
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Update failed");
    } finally {
      setBusy(false);
    }
  }

  if (error) return <p className="error">{error}</p>;
  if (!shipment) return <p className="muted">Loading…</p>;

  return (
    <>
      <h2>{shipment.trackingId} <span className="badge">{shipment.status}</span></h2>

      <div className="card">
        <div className="row">
          <div className="field"><label>Route</label><div>{shipment.originBranchCode} → {shipment.destBranchCode}</div></div>
          <div className="field"><label>Service / payment</label><div>{shipment.serviceType} · {shipment.paymentMode}{shipment.paymentMode === "COD" ? ` · ₹${shipment.codAmount}` : ""}</div></div>
          <div className="field"><label>Rider</label><div>{shipment.assignedRiderName ?? "—"}</div></div>
        </div>
        <div className="row">
          <div className="field"><label>Sender</label><div>{shipment.senderName}, {shipment.senderPhone}<br />{shipment.senderAddress} ({shipment.senderPincode})</div></div>
          <div className="field"><label>Receiver</label><div>{shipment.receiverName}, {shipment.receiverPhone}<br />{shipment.receiverAddress} ({shipment.receiverPincode})</div></div>
        </div>
      </div>

      <div className="card">
        <h3>Update status</h3>
        <div className="row">
          <div className="field">
            <label>Status</label>
            <select value={newStatus} onChange={(e) => setNewStatus(e.target.value)}>
              {SHIPMENT_STATUSES.map((s) => <option key={s}>{s}</option>)}
            </select>
          </div>
          <div className="field"><label>Remarks</label><input value={remarks} onChange={(e) => setRemarks(e.target.value)} /></div>
        </div>
        <button onClick={updateStatus} disabled={busy}>{busy ? "Saving…" : "Update"}</button>
      </div>

      <div className="card">
        <h3>Tracking timeline</h3>
        <ul className="timeline">
          {tracking?.events.map((ev, i) => (
            <li key={i}>
              <strong>{ev.status}</strong>{ev.branchName ? ` · ${ev.branchName}` : ""}
              <div className="muted">{new Date(ev.createdAt).toLocaleString()}{ev.remarks ? ` — ${ev.remarks}` : ""}</div>
              {ev.latitude != null && ev.longitude != null && (
                <div className="muted">Loc: {ev.latitude}, {ev.longitude}</div>
              )}
            </li>
          ))}
          {(!tracking || tracking.events.length === 0) && <li className="muted">No events yet.</li>}
        </ul>
      </div>
    </>
  );
}
