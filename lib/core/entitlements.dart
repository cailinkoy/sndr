// lib/core/entitlements.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'feature_flags.dart';

enum Tier { free, premium }

class Entitlements {
  static late SharedPreferences _prefs;

  static const _kUserTier = 'ent.tier';
  static const _kPremium = 'premium';
  static const _kFree = 'free';

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static Tier get current {
    final raw = _prefs.getString(_kUserTier) ?? _kFree;
    return raw == _kPremium ? Tier.premium : Tier.free;
  }

  /// Temporary helper to simulate upgrades during QA.
  static Future<void> grantPremium({bool value = true}) async {
    await _prefs.setString(_kUserTier, value ? _kPremium : _kFree);
  }

  static bool get isPremium => current == Tier.premium;
}

/// A single decision point for “can use premium feature?”
class Gate {
  static bool canUsePremiumFeature(bool featureFlag) {
    // If the paywall is disabled globally, everyone gets in.
    if (!FeatureFlags.paywallEnabled) return true;

    // If feature itself isn’t marked premium, it’s open.
    if (!featureFlag) return true;

    // Otherwise, require premium.
    return Entitlements.isPremium;
  }
}
