import { useEffect, useState } from "react";
import { api } from "../api/client";
import type { Branch, Shipment } from "../api/types";
import { useAuth } from "../context/AuthContext";
import ShipmentLabel from "../components/ShipmentLabel";

const SERVICE_TYPES = ["Standard", "Express", "SameDay"];
const PAYMENT_MODES = ["Prepaid", "COD"];

export default function BookShipment() {
  const { user } = useAuth();
  const [branches, setBranches] = useState<Branch[]>([]);
  const [form, setForm] = useState({
    originBranchId: 0,
    destBranchId: 0,
    senderName: "", senderPhone: "", senderAddress: "", senderPincode: "",
    receiverName: "", receiverPhone: "", receiverAddress: "", receiverPincode: "",
    weight: 1,
    serviceType: "Standard",
    paymentMode: "Prepaid",
    codAmount: 0,
  });
  const [serviceable, setServiceable] = useState<boolean | null>(null);
  const [created, setCreated] = useState<Shipment | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    api.get<Branch[]>("/api/branches?onlyActive=true").then((b) => {
      setBranches(b);
      const origin = user?.branchId ?? b[0]?.id ?? 0;
      setForm((f) => ({ ...f, originBranchId: origin, destBranchId: b[0]?.id ?? 0 }));
    }).catch((e) => setError(e.message));
  }, [user]);

  function set<K extends keyof typeof form>(key: K, value: (typeof form)[K]) {
    setForm((f) => ({ ...f, [key]: value }));
  }

  async function checkPincode() {
    setServiceable(null);
    if (!form.receiverPincode) return;
    try {
      const res = await api.get<{ serviceable: boolean }>(
        `/api/branches/serviceability/${form.receiverPincode}`);
      setServiceable(res.serviceable);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Check failed");
    }
  }

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    setCreated(null);
    try {
      const payload = {
        ...form,
        weight: Number(form.weight),
        codAmount: form.paymentMode === "COD" ? Number(form.codAmount) : 0,
      };
      const shipment = await api.post<Shipment>("/api/shipments", payload);
      setCreated(shipment);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Booking failed");
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <h2>Book shipment</h2>
      <form className="card" onSubmit={submit}>
        <div className="row">
          <div className="field">
            <label>Origin branch</label>
            <select value={form.originBranchId} onChange={(e) => set("originBranchId", Number(e.target.value))}
                    disabled={user?.role !== "Admin"}>
              {branches.map((b) => <option key={b.id} value={b.id}>{b.code} · {b.name}</option>)}
            </select>
          </div>
          <div className="field">
            <label>Destination branch</label>
            <select value={form.destBranchId} onChange={(e) => set("destBranchId", Number(e.target.value))}>
              {branches.map((b) => <option key={b.id} value={b.id}>{b.code} · {b.name}</option>)}
            </select>
          </div>
        </div>

        <h4>Sender</h4>
        <div className="row">
          <div className="field"><label>Name</label><input value={form.senderName} onChange={(e) => set("senderName", e.target.value)} required /></div>
          <div className="field"><label>Phone</label><input value={form.senderPhone} onChange={(e) => set("senderPhone", e.target.value)} required /></div>
          <div className="field"><label>Pincode</label><input value={form.senderPincode} onChange={(e) => set("senderPincode", e.target.value)} required /></div>
        </div>
        <div className="field"><label>Address</label><input value={form.senderAddress} onChange={(e) => set("senderAddress", e.target.value)} required /></div>

        <h4>Receiver</h4>
        <div className="row">
          <div className="field"><label>Name</label><input value={form.receiverName} onChange={(e) => set("receiverName", e.target.value)} required /></div>
          <div className="field"><label>Phone</label><input value={form.receiverPhone} onChange={(e) => set("receiverPhone", e.target.value)} required /></div>
          <div className="field">
            <label>Pincode</label>
            <input value={form.receiverPincode}
                   onChange={(e) => { set("receiverPincode", e.target.value); setServiceable(null); }}
                   onBlur={checkPincode} required />
            {serviceable === true && <span className="ok">Serviceable ✓</span>}
            {serviceable === false && <span className="error">Not serviceable ✗</span>}
          </div>
        </div>
        <div className="field"><label>Address</label><input value={form.receiverAddress} onChange={(e) => set("receiverAddress", e.target.value)} required /></div>

        <h4>Parcel</h4>
        <div className="row">
          <div className="field"><label>Weight (kg)</label><input type="number" step="0.01" value={form.weight} onChange={(e) => set("weight", Number(e.target.value))} /></div>
          <div className="field">
            <label>Service</label>
            <select value={form.serviceType} onChange={(e) => set("serviceType", e.target.value)}>
              {SERVICE_TYPES.map((s) => <option key={s}>{s}</option>)}
            </select>
          </div>
          <div className="field">
            <label>Payment</label>
            <select value={form.paymentMode} onChange={(e) => set("paymentMode", e.target.value)}>
              {PAYMENT_MODES.map((s) => <option key={s}>{s}</option>)}
            </select>
          </div>
          {form.paymentMode === "COD" && (
            <div className="field"><label>COD amount (₹)</label><input type="number" step="0.01" value={form.codAmount} onChange={(e) => set("codAmount", Number(e.target.value))} /></div>
          )}
        </div>

        {error && <p className="error">{error}</p>}
        <button type="submit" disabled={busy || serviceable === false}>
          {busy ? "Booking…" : "Book shipment"}
        </button>
      </form>

      {created && (
        <div className="card">
          <h3>Booked ✓ — {created.trackingId}</h3>
          <ShipmentLabel s={created} />
          <p style={{ marginTop: 8 }}>
            <button className="secondary no-print" onClick={() => window.print()}>Print label</button>
          </p>
        </div>
      )}
    </>
  );
}
