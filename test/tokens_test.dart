import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodie/core/theme/app_colors.dart';
import 'package:foodie/core/theme/app_radius.dart';
import 'package:foodie/core/theme/app_shadows.dart';
import 'package:foodie/core/theme/app_text.dart';
import 'package:foodie/app/router.dart';

void main() {
  group('Fase 1 - Design Tokens & Theme Tests', () {
    test('AppColors contains all PRD §4 tokens', () {
      expect(AppColors.olive, const Color(0xFF263C32));
      expect(AppColors.amber, const Color(0xFFF59E0B));
      expect(AppColors.maroon, const Color(0xFF800020));
      expect(AppColors.sage, const Color(0xFF717665));
      expect(AppColors.bg, const Color(0xFFF5F5F0));
      expect(AppColors.white, const Color(0xFFFFFFFF));
      expect(AppColors.amberSoft, const Color(0xFFF4E9CE));
      expect(AppColors.maroonSoft, const Color(0xFFF4E6E9));
      expect(AppColors.fieldGray, const Color(0xFFD6D6D6));
      expect(AppColors.chipGray, const Color(0xFFE8E8E2));
      expect(AppColors.mapBg, const Color(0xFFE7E9DE));
      expect(AppColors.mapBlock, const Color(0xFFDEE3D8));
      expect(AppColors.splashDark, const Color(0xFF082B21));
      expect(AppColors.photoGray, const Color(0xFFD9D9D4));
      expect(AppColors.photoGrayIcon, const Color(0xFFBDBDB5));
      expect(AppColors.outerBg, const Color(0xFFE9E9E2));
      expect(AppColors.border, const Color(0xFFE3E3DC));
      expect(AppColors.toggleOff, const Color(0xFFE0E0DA));
      expect(AppColors.summaryBg, const Color(0xFFF4F1EA));
    });

    test('AppText defines all typography roles with Poppins', () {
      expect(AppText.h1Auth.fontFamily, 'Poppins');
      expect(AppText.h1Auth.fontSize, 32.0);
      expect(AppText.pageTitle.fontSize, 26.0);
      expect(AppText.sectionTitle.fontSize, 20.0);
      expect(AppText.cardHeroTitle.fontSize, 16.0);
      expect(AppText.cardSmallTitle.fontSize, 14.0);
      expect(AppText.body.fontSize, 13.0);
      expect(AppText.formLabel.fontSize, 12.0);
      expect(AppText.caption.fontSize, 11.0);
    });

    test('AppRadius and AppShadows are valid', () {
      expect(AppRadius.kCard, 16.0);
      expect(AppRadius.kCardLarge, 20.0);
      expect(AppRadius.kDetailCard, 32.0);
      expect(AppRadius.kInput, 12.0);
      expect(AppRadius.kButton, 14.0);
      expect(AppRadius.kPill, 999.0);
      expect(AppShadows.card.isNotEmpty, true);
      expect(AppShadows.bottomNav.isNotEmpty, true);
    });

    test('GoRouter contains required routes', () {
      final routes = appRouter.configuration.routes;
      expect(routes.isNotEmpty, true);
    });
  });
}
