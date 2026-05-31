import { useState } from "react";
import { api } from "../api/client";
import type { CodReconBranch, CodReconRider } from "../api/types";

function todayMinus(days: number): string {
  const d = new Date();
  d.setDate(d.getDate() - days);
  return d.toISOString().slice(0, 10);
}

export default function CodReport() {
  const [mode, setMode] = useState<"rider" | "branch">("rider");
  const [from, setFrom] = useState(todayMinus(7));
  const [to, setTo] = useState(todayMinus(0));
  const [riderRows, setRiderRows] = useState<CodReconRider[]>([]);
  const [branchRows, setBranchRows] = useState<CodReconBranch[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function run() {
    setBusy(true);
    setError(null);
    // 'to' is exclusive end -> add a day so the chosen end date is included.
    const toExclusive = new Date(to);
    toExclusive.setDate(toExclusive.getDate() + 1);
    const qs = `from=${from}&to=${toExclusive.toISOString().slice(0, 10)}`;
    try {
      if (mode === "rider") {
        setRiderRows(await api.get<CodReconRider[]>(`/api/cod/reconciliation/by-rider?${qs}`));
      } else {
        setBranchRows(await api.get<CodReconBranch[]>(`/api/cod/reconciliation/by-branch?${qs}`));
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : "Report failed");
    } finally {
      setBusy(false);
    }
  }

  const money = (n: number) => `₹${n?.toFixed(2) ?? "0.00"}`;

  return (
    <>
      <h2>COD reconciliation</h2>
      <div className="card">
        <div className="row">
          <div className="field" style={{ maxWidth: 180 }}>
            <label>Group by</label>
            <select value={mode} onChange={(e) => setMode(e.target.value as "rider" | "branch")}>
              <option value="rider">Rider</option>
              <option value="branch">Branch</option>
            </select>
          </div>
          <div className="field" style={{ maxWidth: 180 }}><label>From</label><input type="date" value={from} onChange={(e) => setFrom(e.target.value)} /></div>
          <div className="field" style={{ maxWidth: 180 }}><label>To</label><input type="date" value={to} onChange={(e) => setTo(e.target.value)} /></div>
          <div className="field" style={{ maxWidth: 140, justifyContent: "flex-end" }}>
            <button onClick={run} disabled={busy}>{busy ? "Running…" : "Run report"}</button>
          </div>
        </div>
        {error && <p className="error">{error}</p>}

        {mode === "rider" ? (
          <table>
            <thead><tr><th>Rider</th><th>COD shipments</th><th>Expected</th><th>Collected</th><th>Deposited</th><th>Outstanding</th></tr></thead>
            <tbody>
              {riderRows.map((r) => (
                <tr key={r.riderId}>
                  <td>{r.riderName}</td><td>{r.codShipments}</td>
                  <td>{money(r.totalExpected)}</td><td>{money(r.totalCollected)}</td>
                  <td>{money(r.totalDeposited)}</td><td>{money(r.outstanding)}</td>
                </tr>
              ))}
              {riderRows.length === 0 && <tr><td colSpan={6} className="muted">No data. Run the report.</td></tr>}
            </tbody>
          </table>
        ) : (
          <table>
            <thead><tr><th>Branch</th><th>COD shipments</th><th>Expected</th><th>Collected</th><th>Deposited</th><th>Outstanding</th></tr></thead>
            <tbody>
              {branchRows.map((r) => (
                <tr key={r.branchId}>
                  <td>{r.branchCode} · {r.branchName}</td><td>{r.codShipments}</td>
                  <td>{money(r.totalExpected)}</td><td>{money(r.totalCollected)}</td>
                  <td>{money(r.totalDeposited)}</td><td>{money(r.outstanding)}</td>
                </tr>
              ))}
              {branchRows.length === 0 && <tr><td colSpan={6} className="muted">No data. Run the report.</td></tr>}
            </tbody>
          </table>
        )}
      </div>
    </>
  );
}
