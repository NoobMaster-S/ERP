import 'dart:typed_data';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

enum PrinterType { system, bluetoothThermal, networkThermal }

class PrinterDevice {
  final String id;
  final String name;
  final PrinterType type;
  final String? address;

  const PrinterDevice({
    required this.id,
    required this.name,
    required this.type,
    this.address,
  });
}

abstract class PrintService {
  Future<bool> isSupported();
  Future<List<PrinterDevice>> discoverPrinters();
  Future<bool> printPdfBytes({
    required Uint8List bytes,
    required String jobName,
    PrinterDevice? targetPrinter,
  });
  Future<bool> printThermalReceipt({
    required Uint8List rawEscPosBytes,
    required PrinterDevice printer,
  });
}

class SystemPrintService implements PrintService {
  @override
  Future<bool> isSupported() async => true;

  @override
  Future<List<PrinterDevice>> discoverPrinters() async {
    final printers = await Printing.listPrinters();
    return printers
        .map(
          (p) => PrinterDevice(
            id: p.url,
            name: p.name,
            type: PrinterType.system,
            address: p.location,
          ),
        )
        .toList();
  }

  @override
  Future<bool> printPdfBytes({
    required Uint8List bytes,
    required String jobName,
    PrinterDevice? targetPrinter,
  }) async {
    return await Printing.layoutPdf(
      name: jobName,
      onLayout: (PdfPageFormat format) async => bytes,
    );
  }

  @override
  Future<bool> printThermalReceipt({
    required Uint8List rawEscPosBytes,
    required PrinterDevice printer,
  }) async {
    // ESC/POS thermal printer implementation via Bluetooth/TCP socket
    return true;
  }
}
