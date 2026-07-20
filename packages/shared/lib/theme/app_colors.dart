import 'package:flutter/material.dart';

/// Homely brand palette. Every colour has one deliberate job — appetite/urgency
/// is gold, trust/navigation is blue, positive/verified states are sage, the
/// ground is warm cream, and all text is a soft charcoal-brown (never pure
/// black). Neutrals are biased warm so the app feels homely, not clinical.
class HomelyColors {
  HomelyColors._();

  // ── Ground & ink ─────────────────────────────────────────────────────
  static const cream = Color(0xFFFBF8F3); // app background
  static const surface = Color(0xFFFFFFFF); // cards, sheets
  static const surfaceAlt = Color(0xFFF3EEE6); // quiet raised fills
  static const ink = Color(0xFF2E2420); // primary text
  static const inkSoft = Color(0xFF6B615B); // secondary text
  static const inkFaint = Color(0xFF9A918B); // hints / disabled

  // ── Trust Blue (brand) ───────────────────────────────────────────────
  static const blue = Color(0xFF6FB7C7); // brand hue: badges, tints, outlines
  static const blueDeep = Color(0xFF3F94A6); // button fills (legible white text)
  static const blueTint = Color(0xFFEAF4F6); // quiet fills, chips

  // ── Turmeric Gold (appetite / urgency) ───────────────────────────────
  static const gold = Color(0xFFE8A33D); // Add, Place order, active order
  static const goldDeep = Color(0xFFC6841D); // price + on-cream gold text
  static const goldTint = Color(0xFFFBEED8);

  // ── Sage (positive / verified) ───────────────────────────────────────
  static const sage = Color(0xFF7FA88C); // ratings, Cooking Today, in-stock
  static const sageDeep = Color(0xFF5C8570);
  static const sageTint = Color(0xFFE9F0EB);

  // ── Lines & semantic ─────────────────────────────────────────────────
  static const line = Color(0x1A2E2420); // ~10% ink hairline
  static const lineSoft = Color(0x122E2420); // ~7% ink
  static const danger = Color(0xFFC0392B);
  static const nonVeg = Color(0xFFB4472F);
}
