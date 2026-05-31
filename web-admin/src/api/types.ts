// Shared response shapes (mirror the API's response DTOs).

export interface User {
  id: number;
  branchId: number | null;
  name: string;
  role: "Admin" | "BranchManager" | "Rider";
  phone?: string | null;
  email: string;
  status: string;
  branchCode?: string | null;
  branchName?: string | null;
}

export interface LoginResponse {
  token: string;
  user: User;
}

export interface Branch {
  id: number;
  code: string;
  name: string;
  city: string;
  pincode: string;
  managerId: number | null;
  isActive: boolean;
  createdAt: string;
}

export interface Shipment {
  id: number;
  trackingId: string;
  invoiceNumber?: string | null;
  barcodeValue?: string | null;
  originBranchId: number;
  originBranchCode?: string | null;
  originBranchName?: string | null;
  destBranchId: number;
  destBranchCode?: string | null;
  destBranchName?: string | null;
  currentBranchId?: number | null;
  senderName: string;
  senderPhone: string;
  senderAddress: string;
  senderPincode: string;
  receiverName: string;
  receiverPhone: string;
  receiverAddress: string;
  receiverPincode: string;
  weight: number;
  serviceType: string;
  paymentMode: string;
  codAmount: number;
  status: string;
  assignedRiderId?: number | null;
  assignedRiderName?: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface ShipmentListItem {
  id: number;
  trackingId: string;
  invoiceNumber?: string | null;
  originBranchCode?: string | null;
  destBranchCode?: string | null;
  receiverName: string;
  receiverPincode: string;
  serviceType: string;
  paymentMode: string;
  codAmount: number;
  status: string;
  assignedRiderId?: number | null;
  assignedRiderName?: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface TrackingEvent {
  status: string;
  remarks?: string | null;
  latitude?: number | null;
  longitude?: number | null;
  branchName?: string | null;
  createdAt: string;
}

export interface PublicTracking {
  summary: {
    trackingId: string;
    status: string;
    serviceType: string;
    paymentMode: string;
    originBranchName?: string | null;
    originCity?: string | null;
    destBranchName?: string | null;
    destCity?: string | null;
    receiverName: string;
    createdAt: string;
    updatedAt: string;
  } | null;
  events: TrackingEvent[];
}

export interface CodReconRider {
  riderId: number;
  riderName: string;
  branchId: number | null;
  codShipments: number;
  totalExpected: number;
  totalCollected: number;
  totalDeposited: number;
  outstanding: number;
}

export interface CodReconBranch {
  branchId: number;
  branchCode: string;
  branchName: string;
  codShipments: number;
  totalExpected: number;
  totalCollected: number;
  totalDeposited: number;
  outstanding: number;
}

export interface Dashboard {
  bookingsToday: number;
  deliveriesToday: number;
  pendingShipments: number;
  codCollectedToday: number;
}

export const SHIPMENT_STATUSES = [
  "Booked", "PickedUp", "AtOriginHub", "InTransit", "AtDestinationHub",
  "OutForDelivery", "Delivered", "Failed", "RTO",
] as const;
