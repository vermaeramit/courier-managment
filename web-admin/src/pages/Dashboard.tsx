import { useEffect, useState } from "react";
import { api } from "../api/client";
import type { Dashboard as DashboardDto } from "../api/types";

export default function Dashboard() {
  const [data, setData] = useState<DashboardDto | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api.get<DashboardDto>("/api/dashboard")
      .then(setData)
      .catch((e) => setError(e.message));
  }, []);

  if (error) return <p className="error">{error}</p>;
  if (!data) return <p className="muted">Loading…</p>;

  const cards = [
    { label: "Bookings today", value: data.bookingsToday },
    { label: "Deliveries today", value: data.deliveriesToday },
    { label: "Pending shipments", value: data.pendingShipments },
    { label: "COD collected today", value: `₹${data.codCollectedToday.toFixed(2)}` },
  ];

  return (
    <>
      <h2>Dashboard</h2>
      <div className="grid-stats">
        {cards.map((c) => (
          <div className="card" key={c.label}>
            <div className="stat">{c.value}</div>
            <div className="stat-label">{c.label}</div>
          </div>
        ))}
      </div>
      <p className="muted">Figures are branch-scoped for managers and HQ-wide for admins.</p>
    </>
  );
}
