# Hardware Printing Abstraction Specification

## 1. Overview & Business Use-Cases

The ERP platform operates across diverse physical retail and wholesale environments:
* **Mobile / Counter POS**: 58mm / 80mm ESC/POS Bluetooth and USB thermal receipt printers.
* **Warehouse / Logistics**: Network IP label and receipt printers.
* **Office & Desktop**: Standard A4/Letter laser/inkjet printers via OS print spooler.
* **Digital Sharing**: Generating standardized PDF documents for WhatsApp, Email, or cloud archival.

---

## 2. Clean Architecture Print Service Interface

To prevent coupling UI widgets or transactional BLoCs to printer driver implementations, all printing operations pass through an abstract `PrintService`:

```dart
abstract class PrintService {
  /// Check availability of printer subsystem on this platform
  Future<bool> isSupported();

  /// Discover available printers (Bluetooth paired, USB, or Network mDNS)
  Future<List<PrinterDevice>> discoverPrinters();

  /// Prints an invoice, receipt, or document model
  Future<PrintResult> printDocument({
    required PrintableDocument document,
    required PrinterConfiguration configuration,
  });

  /// Feeds paper and triggers cash drawer kick if configured
  Future<void> openCashDrawer({required PrinterConfiguration configuration});
}
```

### Implementations:
1. `SystemPrintService`: Interfaces with OS print dialog using `printing` package (Android, iOS, Web, Windows).
2. `ThermalPrintService`: Connects directly via Bluetooth RFCOMM or Network TCP socket (raw ESC/POS byte commands) for high-speed counter printing.
3. `PdfRenderService`: Converts document templates into high-fidelity vectorized PDF bytes for previewing or saving.
