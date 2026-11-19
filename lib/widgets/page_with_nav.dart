import 'package:flutter/material.dart';

import '../app/app_shell.dart';

/// Wrapper konten halaman yang memiliki bottom nav.
/// Menambahkan padding bawah ≈ 120 px agar konten paling bawah tidak tertutup nav.
class PageWithNav extends StatelessWidget {
  final Widget child;

  const PageWithNav({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppShell.bottomNavPadding),
      child: child,
    );
  }
}
