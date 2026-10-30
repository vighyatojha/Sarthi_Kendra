// lib/core/cloudinary.dart
// Uploads photos and voice notes to Cloudinary (free plan) with an unsigned
// upload preset. IDENTICAL in both apps. Returns the secure https URL.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'app_config.dart';

class CloudinaryException implements Exception {
  final String message;
  const CloudinaryException(this.message);
  @override
  String toString() => message;
}

class Cloudinary {
  Cloudinary._();

  /// [folder] e.g. 'jobs/<uid>' or 'profiles'. Uses the "auto" resource type,
  /// so images and audio both work.
  static Future<String> upload(File file, {required String folder, void Function(double)? onProgress}) async {
    if (AppConfig.cloudinaryCloudName.startsWith('YOUR_')) {
      throw const CloudinaryException('Cloudinary is not configured (lib/core/app_config.dart).');
    }
    final size = await file.length();
    if (size > 6 * 1024 * 1024) {
      throw const CloudinaryException('File is too large (max 6 MB).');
    }
    final uri = Uri.parse('https://api.cloudinary.com/v1_1/${AppConfig.cloudinaryCloudName}/auto/upload');
    final req = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = AppConfig.cloudinaryUploadPreset
      ..fields['folder'] = 'sarthi/$folder'
      ..files.add(await http.MultipartFile.fromPath('file', file.path));
    onProgress?.call(0.1);
    final http.StreamedResponse res;
    try {
      res = await req.send().timeout(const Duration(seconds: 90));
    } catch (_) {
      throw const CloudinaryException('Upload failed. Check your internet and try again.');
    }
    final body = await res.stream.bytesToString();
    onProgress?.call(1);
    if (res.statusCode != 200) {
      throw CloudinaryException('Upload failed (${res.statusCode}). Please try again.');
    }
    final url = (jsonDecode(body) as Map<String, dynamic>)['secure_url'];
    if (url is! String || !url.startsWith('https://res.cloudinary.com/')) {
      throw const CloudinaryException('Upload failed. Please try again.');
    }
    return url;
  }

  /// Smaller image for lists: inserts a Cloudinary transformation into the URL.
  static String thumb(String url, {int width = 300}) =>
      url.contains('/image/upload/') ? url.replaceFirst('/image/upload/', '/image/upload/c_limit,w_$width,q_auto,f_auto/') : url;
}