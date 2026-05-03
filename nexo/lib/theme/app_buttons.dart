import 'package:flutter/material.dart';

class AppButtons {
  static ButtonStyle primary = ElevatedButton.styleFrom(
    backgroundColor: Colors.black,
    foregroundColor: Colors.white,
    elevation: 0,
    minimumSize: const Size.fromHeight(56),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    ),
    textStyle: const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.1,
    ),
  );
}
