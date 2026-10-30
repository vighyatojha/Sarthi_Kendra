// lib/core/app_config.dart
// Settings shared by Trouble Sarthi and Sarthi Kendra (IDENTICAL in both apps).
// Fill in the three values marked TODO before building.

class AppConfig {
  AppConfig._();

  /// Cloudinary (free plan) for request photos, voice notes and profile photos.
  /// Cloudinary console → Settings → Upload → Upload presets → Add preset:
  ///   Signing mode: Unsigned · Folder: sarthi · Max file size: 6 MB
  ///   Allowed formats: jpg, jpeg, png, webp, heic, m4a, aac, mp3, mp4
  static const cloudinaryCloudName = 'YOUR_CLOUD_NAME'; // TODO
  static const cloudinaryUploadPreset = 'sarthi_unsigned'; // TODO (the preset name you created)

  /// Cloudflare Worker that sends push notifications (worker/ folder).
  /// After `npx wrangler deploy` it prints a URL like the one below.
  static const notifyWorkerUrl = 'https://sarthi-notify.YOUR-SUBDOMAIN.workers.dev'; // TODO

  /// Business rules (the same numbers are enforced in firestore.rules).
  static const searchRadiusKm = 5.0;
  static const nowPitchWindow = Duration(minutes: 20);
  static const nowExpiry = Duration(minutes: 60);
  static const scheduledPitchWindowMax = Duration(hours: 6);
  static const minScheduleLead = Duration(minutes: 70);
  static const maxPhotos = 5;
  static const maxAudioSeconds = 120;
  static const pitchMinRupees = 50;
  static const pitchMaxRupees = 100000;
  static const pitchMaxEdits = 3;
}