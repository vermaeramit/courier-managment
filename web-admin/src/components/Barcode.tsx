import { useEffect, useRef } from "react";
import JsBarcode from "jsbarcode";

/**
 * Renders a scannable Code128 barcode (the courier-standard 1D symbology) for the
 * given value. The rider app's mobile_scanner reads Code128, so scanning the
 * printed label returns the TrackingId verbatim — no manual entry needed.
 */
export default function Barcode({
  value,
  height = 60,
}: {
  value: string;
  height?: number;
}) {
  const ref = useRef<SVGSVGElement>(null);

  useEffect(() => {
    if (!ref.current || !value) return;
    try {
      JsBarcode(ref.current, value, {
        format: "CODE128",
        height,
        displayValue: true, // print the human-readable TrackingId under the bars
        fontSize: 14,
        margin: 6,
        width: 2,
      });
    } catch {
      // Invalid value for the symbology — leave the element empty rather than throw.
    }
  }, [value, height]);

  return <svg ref={ref} aria-label={`Barcode ${value}`} />;
}
