import 'package:flutter/material.dart';

/// ReadJournal App Color Palette
/// โทนสี Warm & Cozy สำหรับแอปบันทึกการอ่าน
class AppColors {
  AppColors._(); // ป้องกันการสร้าง instance

  // ─── Primary (สีหลัก) ─────────────────────────────────────────
  // Warm Amber / Terracotta — ใช้กับปุ่มหลัก (CTA), แท็บที่เลือก, ไฮไลต์ดาว Rating
  static const Color primary = Color(0xFFC86D51);
  static const Color primaryDark = Color(0xFF8C5A3C);

  // ─── Secondary (สีรอง) ────────────────────────────────────────
  // Soft Cream / Parchment — สีพื้นหลัง ให้ความรู้สึกเหมือนกระดาษถนอมสายตา
  static const Color secondary = Color(0xFFFDFBF7);

  // ─── Accent (สีเน้น) ──────────────────────────────────────────
  // Sage Green — ใช้กับ Genre Tags หรือ Status (อ่านจบแล้ว, กำลังอ่าน)
  static const Color accent = Color(0xFF768A76);

  // ─── Text & Dark Elements ─────────────────────────────────────
  // Espresso / Dark Charcoal — สีข้อความหลัก สบายตาเวลาอ่านเยอะๆ
  static const Color textPrimary = Color(0xFF2B2523);

  // ─── Derived Colors (สีที่ปรับจากสีหลัก) ──────────────────────
  static const Color primaryLight = Color(0xFFE8A48E);
  static const Color accentLight = Color(0xFFB5C5B5);
  static const Color textSecondary = Color(0xFF6B5E5A);
  static const Color divider = Color(0xFFE8E2DA);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color starActive = primary;        // ดาว Rating ที่เลือก
  static const Color starInactive = Color(0xFFD4C8C0); // ดาว Rating ที่ยังไม่เลือก
}
