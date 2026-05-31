import { NavLink, Navigate, Route, Routes } from "react-router-dom";
import { useAuth } from "./context/AuthContext";
import Login from "./pages/Login";
import Dashboard from "./pages/Dashboard";
import BookShipment from "./pages/BookShipment";
import Shipments from "./pages/Shipments";
import ShipmentDetail from "./pages/ShipmentDetail";
import RiderAssign from "./pages/RiderAssign";
import CodReport from "./pages/CodReport";

export default function App() {
  const { user, logout } = useAuth();

  if (!user) {
    return (
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="*" element={<Navigate to="/login" replace />} />
      </Routes>
    );
  }

  const isStaff = user.role === "Admin" || user.role === "BranchManager";

  // Route-level guard: staff-only pages redirect non-staff back to the dashboard
  // instead of rendering a broken page that fires calls the API will 403. (Nav
  // hiding alone is not access control — the URLs are still reachable.)
  const staffOnly = (el: JSX.Element) => (isStaff ? el : <Navigate to="/" replace />);

  return (
    <div className="app">
      <aside className="sidebar">
        <h1>Courier Admin</h1>
        <nav>
          <NavLink to="/" end>Dashboard</NavLink>
          {isStaff && <NavLink to="/book">Book shipment</NavLink>}
          <NavLink to="/shipments">Shipments</NavLink>
          {isStaff && <NavLink to="/assign">Rider assignment</NavLink>}
          {isStaff && <NavLink to="/cod">COD reconciliation</NavLink>}
        </nav>
        <div className="who">
          <div><strong>{user.name}</strong></div>
          <div>{user.role}{user.branchCode ? ` · ${user.branchCode}` : " · HQ"}</div>
          <button className="secondary" style={{ marginTop: 8 }} onClick={logout}>Log out</button>
        </div>
      </aside>
      <main className="main">
        <Routes>
          <Route path="/" element={<Dashboard />} />
          <Route path="/book" element={staffOnly(<BookShipment />)} />
          <Route path="/shipments" element={<Shipments />} />
          <Route path="/shipments/:id" element={<ShipmentDetail />} />
          <Route path="/assign" element={staffOnly(<RiderAssign />)} />
          <Route path="/cod" element={staffOnly(<CodReport />)} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </main>
    </div>
  );
}
