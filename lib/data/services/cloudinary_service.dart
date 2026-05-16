import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class CloudinaryService {
  static const _cloudName = 'dfjyaohet';
  static const _uploadPreset = 'ziscord';

  final _picker = ImagePicker();

  Future<List<XFile>> pickImages() async {
    return _picker.pickMultiImage(imageQuality: 80, maxWidth: 1280);
  }

  /// Returns the secure URL on success, throws a descriptive String on failure.
  Future<String> uploadImage(XFile file) async {
    final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
    final bytes = await file.readAsBytes();
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: file.name,
      ));

    final response = await request.send();
    final body = jsonDecode(await response.stream.bytesToString())
        as Map<String, dynamic>;

    if (response.statusCode == 200) {
      final url = body['secure_url'] as String?;
      if (url != null) return url;
      throw 'Cloudinary không trả về URL';
    }
    // Surface Cloudinary's error message
    final error = body['error']?['message'] ?? 'HTTP ${response.statusCode}';
    throw error;
  }

  /// Returns (url, null) on success, (null, errorMessage) on failure.
  /// Returns (null, null) if user cancelled the picker.
  Future<(String?, String?)> pickAndUpload() async {
    final files = await pickImages();
    if (files.isEmpty) return (null, null);
    final file = files.first;
    try {
      final url = await uploadImage(file);
      return (url, null);
    } catch (e) {
      return (null, e.toString());
    }
  }
}
