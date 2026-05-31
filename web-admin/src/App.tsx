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
          <Route path="/book" element={<BookShipment />} />
          <Route path="/shipments" element={<Shipments />} />
          <Route path="/shipments/:id" element={<ShipmentDetail />} />
          <Route path="/assign" element={<RiderAssign />} />
          <Route path="/cod" element={<CodReport />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </main>
    </div>
  );
}
