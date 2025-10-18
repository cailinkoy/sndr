// lib/core/feature_flags.dart
import 'package:shared_preferences/shared_preferences.dart';

class FeatureFlags {
  static late SharedPreferences _prefs;

  /// Initialize once at app startup.
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ===== Defaults for first store submission =====
  // Keep paywall OFF to avoid app-store review issues (no IAP wired yet).
  static const _defaultPaywallEnabled = false;
  static const _defaultPremiumGiftIdeas =
      true; // feature exists, but gate disabled

  // Keys
  static const _kPaywallEnabled = 'ff.paywallEnabled';
  static const _kPremiumGiftIdeas = 'ff.premiumGiftIdeas';

  // Getters
  static bool get paywallEnabled =>
      _prefs.getBool(_kPaywallEnabled) ?? _defaultPaywallEnabled;

  static bool get premiumGiftIdeas =>
      _prefs.getBool(_kPremiumGiftIdeas) ?? _defaultPremiumGiftIdeas;

  // Setters (for QA/dev toggles)
  static Future<void> setPaywallEnabled(bool v) async =>
      _prefs.setBool(_kPaywallEnabled, v);

  static Future<void> setPremiumGiftIdeas(bool v) async =>
      _prefs.setBool(_kPremiumGiftIdeas, v);
}
