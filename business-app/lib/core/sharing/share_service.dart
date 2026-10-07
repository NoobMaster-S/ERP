import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

abstract class ShareService {
  Future<void> shareText(String text, {String? subject});
  Future<void> shareFileBytes(Uint8List bytes, String filename, {String? subject, String? text});
}

class NativeShareService implements ShareService {
  @override
  Future<void> shareText(String text, {String? subject}) async {
    await Share.share(text, subject: subject);
  }

  @override
  Future<void> shareFileBytes(
    Uint8List bytes,
    String filename, {
    String? subject,
    String? text,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$filename');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: subject,
      text: text,
    );
  }
}
