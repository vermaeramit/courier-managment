import Barcode from "./Barcode";

/** The printable courier label with a scannable Code128 barcode. Shared by the
 *  booking screen and the shipment-detail reprint flow. */
export interface LabelData {
  trackingId: string;
  invoiceNumber?: string | null;
  barcodeValue?: string | null;
  originBranchCode?: string | null;
  destBranchCode?: string | null;
  receiverName: string;
  receiverPincode: string;
  serviceType: string;
  paymentMode: string;
  codAmount: number;
}

export default function ShipmentLabel({ s }: { s: LabelData }) {
  return (
    <div className="label-print printable">
      <div><strong>COURIER LABEL</strong></div>
      <div>Tracking: {s.trackingId}</div>
      <div>Invoice: {s.invoiceNumber}</div>
      <div>{s.originBranchCode} → {s.destBranchCode}</div>
      <div>To: {s.receiverName}, {s.receiverPincode}</div>
      <div>
        {s.serviceType} · {s.paymentMode}
        {s.paymentMode === "COD" ? ` · ₹${s.codAmount}` : ""}
      </div>
      {/* Scannable Code128 barcode — the rider app scans this to open the shipment. */}
      <div className="barcode" style={{ marginTop: 8 }}>
        <Barcode value={s.barcodeValue || s.trackingId} />
      </div>
    </div>
  );
}
