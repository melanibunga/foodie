import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/theme/app_palette.dart';
import '../core/theme/app_shadows.dart';
import '../core/theme/app_text.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../providers/cooked_provider.dart';
import '../providers/ratings_provider.dart';
import '../providers/recipes_provider.dart';
import '../providers/ui_helper.dart';
import '../widgets/ui/app_button.dart';

/// Halaman Mode Memasak (Start Cooking) sesuai PRD §7.1, §16:
/// - Layar penuh, tanpa AppBottomNav dan AppHeader.
/// - Top bar tutup (x) + "Langkah N dari M" + progress bar segmen accent.
/// - Konten besar dalam PageView (swipe kiri-kanan):
///   - Lingkaran accent bernomor (64x64, teks onAccent 28/700).
///   - Judul langkah (24/700 textStrong).
///   - Deskripsi langkah (16/400 textBody, line height 26).
///   - Chip timer dengan countdown (Timer.periodic) jika durationMin ada.
/// - Tombol navigasi bawah: "Sebelumnya" (outline), "Berikutnya" (primary), "Selesai" (accent di langkah terakhir).
/// - Layar selesai: ikon centang accent, "Selamat, masakanmu siap! 🎉", tombol "Kembali ke Beranda",
///   dan counter user.cooked +1 (sekali per sesi).
/// - Layar dijaga tetap menyala dengan wakelock_plus selama halaman aktif.
class CookPage extends ConsumerStatefulWidget {
  final String recipeId;

  const CookPage({super.key, required this.recipeId});

  @override
  ConsumerState<CookPage> createState() => _CookPageState();
}

class _CookPageState extends ConsumerState<CookPage> {
  late final PageController _pageController;
  int _currentIndex = 0;
  bool _isCompleted = false;
  bool _cookedIncremented = false;
  int _selectedRating = 0;
  bool _ratingSubmitted = false;

  // State timer per step
  Timer? _timer;
  int? _activeTimerStep;
  final Map<int, int> _stepRemainingSeconds = {};
  final Map<int, bool> _stepTimerRunning = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);

    // Jaga layar tetap aktif selama sesi memasak
    try {
      WakelockPlus.enable();
    } catch (_) {}
  }

  @override
  void dispose() {
    try {
      WakelockPlus.disable();
    } catch (_) {}
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startTimer(int stepIndex, int totalMinutes) {
    if (_activeTimerStep != null && _activeTimerStep != stepIndex) {
      _pauseTimer(_activeTimerStep!);
    }

    if (!_stepRemainingSeconds.containsKey(stepIndex)) {
      _stepRemainingSeconds[stepIndex] = totalMinutes * 60;
    }

    setState(() {
      _activeTimerStep = stepIndex;
      _stepTimerRunning[stepIndex] = true;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final remaining = _stepRemainingSeconds[stepIndex] ?? 0;
      if (remaining <= 1) {
        timer.cancel();
        setState(() {
          _stepRemainingSeconds[stepIndex] = 0;
          _stepTimerRunning[stepIndex] = false;
          _activeTimerStep = null;
        });
      } else {
        setState(() {
          _stepRemainingSeconds[stepIndex] = remaining - 1;
        });
      }
    });
  }

  void _pauseTimer(int stepIndex) {
    _timer?.cancel();
    setState(() {
      _stepTimerRunning[stepIndex] = false;
      if (_activeTimerStep == stepIndex) {
        _activeTimerStep = null;
      }
    });
  }

  void _resetTimer(int stepIndex, int totalMinutes) {
    _timer?.cancel();
    setState(() {
      _stepRemainingSeconds[stepIndex] = totalMinutes * 60;
      _stepTimerRunning[stepIndex] = false;
      if (_activeTimerStep == stepIndex) {
        _activeTimerStep = null;
      }
    });
  }

  void _goToPrevious() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToNext(int totalSteps) {
    if (_currentIndex < totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _finishCooking() {
    _timer?.cancel();
    if (!_cookedIncremented) {
      _cookedIncremented = true;
      ref.read(authProvider.notifier).incrementCooked();
      ref.read(cookedProvider.notifier).add(widget.recipeId);
    }
    setState(() {
      _isCompleted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final recipeAsync = ref.watch(recipeDetailProvider(widget.recipeId));

    return Scaffold(
      backgroundColor: palette.bg,
      body: recipeAsync.when(
        data: (recipe) {
          if (recipe == null) {
            return _buildNotFound(context);
          }
          if (_isCompleted) {
            return _buildCompletionScreen(context, recipe);
          }
          return _buildCookingContent(context, recipe);
        },
        loading: () =>
            Center(child: CircularProgressIndicator(color: palette.actionBg)),
        error: (err, stack) => _buildError(context),
      ),
    );
  }

  Widget _buildNotFound(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.chefHat, size: 64.0, color: palette.textSecondary),
            const SizedBox(height: 16.0),
            Text(
              'Resep tidak ditemukan',
              style: AppText.sectionTitle.copyWith(color: palette.textStrong),
            ),
            const SizedBox(height: 24.0),
            AppButton(
              label: 'Kembali',
              variant: AppButtonVariant.primary,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.alertTriangle, size: 48.0, color: palette.danger),
            const SizedBox(height: 16.0),
            Text(
              'Gagal memuat resep',
              style: AppText.sectionTitle.copyWith(color: palette.textStrong),
            ),
            const SizedBox(height: 24.0),
            AppButton(
              label: 'Coba lagi',
              variant: AppButtonVariant.primary,
              onPressed: () =>
                  ref.refresh(recipeDetailProvider(widget.recipeId)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCookingContent(BuildContext context, Recipe recipe) {
    final palette = context.palette;
    final steps = recipe.steps;
    final totalSteps = steps.isNotEmpty ? steps.length : 1;
    final topPadding = math.max(MediaQuery.paddingOf(context).top, 24.0);
    final bottomPadding = math.max(MediaQuery.paddingOf(context).bottom, 24.0);

    return Column(
      children: [
        // Top Bar
        Container(
          padding: EdgeInsets.only(
            top: topPadding + 8.0,
            left: 20.0,
            right: 20.0,
            bottom: 12.0,
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Tombol tutup (x)
                  Semantics(
                    label: 'Tutup',
                    button: true,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Container(
                        width: 40.0,
                        height: 40.0,
                        decoration: BoxDecoration(
                          color: palette.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: palette.border),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          LucideIcons.x,
                          size: 20.0,
                          color: palette.textStrong,
                        ),
                      ),
                    ),
                  ),

                  // Teks "Langkah N dari M"
                  Text(
                    'Langkah ${_currentIndex + 1} dari $totalSteps',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14.0,
                      fontWeight: FontWeight.w600,
                      color: palette.textSecondary,
                    ),
                  ),

                  // Spacer penyeimbang
                  const SizedBox(width: 40.0, height: 40.0),
                ],
              ),

              const SizedBox(height: 12.0),

              // Progress bar segmen accent
              Row(
                children: List.generate(totalSteps, (i) {
                  final isFilled = i <= _currentIndex;
                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.symmetric(
                        horizontal: i == 0 || i == totalSteps - 1 ? 0 : 2.5,
                      ),
                      height: 4.0,
                      decoration: BoxDecoration(
                        color: isFilled ? palette.accent : palette.chip,
                        borderRadius: BorderRadius.circular(2.0),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),

        // Konten besar dalam PageView
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: totalSteps,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final step = steps[index];
              return _buildStepPage(context, index, step);
            },
          ),
        ),

        // Bottom Controls
        Container(
          padding: EdgeInsets.only(
            left: 25.0,
            right: 25.0,
            bottom: bottomPadding,
            top: 12.0,
          ),
          child: _currentIndex == 0
              ? (totalSteps > 1
                    ? AppButton(
                        label: 'Berikutnya',
                        variant: AppButtonVariant.primary,
                        size: AppButtonSize.lg,
                        fullWidth: true,
                        onPressed: () => _goToNext(totalSteps),
                      )
                    : AppButton(
                        label: 'Selesai',
                        variant: AppButtonVariant.accent,
                        size: AppButtonSize.lg,
                        fullWidth: true,
                        onPressed: _finishCooking,
                      ))
              : Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: AppButton(
                        label: 'Sebelumnya',
                        variant: AppButtonVariant.outline,
                        size: AppButtonSize.lg,
                        fullWidth: true,
                        onPressed: _goToPrevious,
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      flex: 3,
                      child: AppButton(
                        label: _currentIndex == totalSteps - 1
                            ? 'Selesai'
                            : 'Berikutnya',
                        variant: _currentIndex == totalSteps - 1
                            ? AppButtonVariant.accent
                            : AppButtonVariant.primary,
                        size: AppButtonSize.lg,
                        fullWidth: true,
                        onPressed: _currentIndex == totalSteps - 1
                            ? _finishCooking
                            : () => _goToNext(totalSteps),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildStepPage(BuildContext context, int index, RecipeStep step) {
    final palette = context.palette;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20.0),

          // Lingkaran accent besar (64) berisi nomor langkah
          Container(
            width: 64.0,
            height: 64.0,
            decoration: BoxDecoration(
              color: palette.accent,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 28.0,
                fontWeight: FontWeight.w700,
                color: palette.onAccent,
              ),
            ),
          ),

          const SizedBox(height: 24.0),

          // Judul langkah (24/700 textStrong)
          Text(
            step.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 24.0,
              fontWeight: FontWeight.w700,
              color: palette.textStrong,
            ),
          ),

          const SizedBox(height: 16.0),

          // Deskripsi (16/400, tinggi baris 26)
          Text(
            step.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16.0,
              fontWeight: FontWeight.w400,
              color: palette.textBody,
              height: 26.0 / 16.0,
            ),
          ),

          // Chip timer bila step.durationMin ada
          if (step.durationMin != null && step.durationMin! > 0) ...[
            const SizedBox(height: 28.0),
            _buildTimerChip(context, index, step.durationMin!),
          ],

          const SizedBox(height: 32.0),
        ],
      ),
    );
  }

  Widget _buildTimerChip(
    BuildContext context,
    int stepIndex,
    int totalMinutes,
  ) {
    final palette = context.palette;
    final remainingSeconds =
        _stepRemainingSeconds[stepIndex] ?? (totalMinutes * 60);
    final isRunning = _stepTimerRunning[stepIndex] ?? false;

    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    final formattedTime =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: palette.summaryBg,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.timer, size: 18.0, color: palette.textStrong),
          const SizedBox(width: 8.0),
          Text(
            isRunning || remainingSeconds < (totalMinutes * 60)
                ? '⏱ $formattedTime'
                : '⏱ $totalMinutes menit',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14.0,
              fontWeight: FontWeight.w600,
              color: palette.textStrong,
            ),
          ),
          const SizedBox(width: 14.0),
          if (remainingSeconds == 0) ...[
            GestureDetector(
              onTap: () => _resetTimer(stepIndex, totalMinutes),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10.0,
                  vertical: 5.0,
                ),
                decoration: BoxDecoration(
                  color: palette.actionBg,
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(
                  'Ulangi',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.0,
                    fontWeight: FontWeight.w600,
                    color: palette.onAction,
                  ),
                ),
              ),
            ),
          ] else if (isRunning) ...[
            GestureDetector(
              onTap: () => _pauseTimer(stepIndex),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 5.0,
                ),
                decoration: BoxDecoration(
                  color: palette.danger,
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(
                  'Jeda',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.0,
                    fontWeight: FontWeight.w600,
                    color: palette.onDanger,
                  ),
                ),
              ),
            ),
          ] else ...[
            GestureDetector(
              onTap: () => _startTimer(stepIndex, totalMinutes),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 5.0,
                ),
                decoration: BoxDecoration(
                  color: palette.accent,
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(
                  'Mulai',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.0,
                    fontWeight: FontWeight.w600,
                    color: palette.onAccent,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompletionScreen(BuildContext context, Recipe recipe) {
    final palette = context.palette;
    final bottomPadding = math.max(MediaQuery.paddingOf(context).bottom, 24.0);

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 25.0,
            right: 25.0,
            bottom: bottomPadding,
            top: 24.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ikon centang accent
              Container(
                width: 80.0,
                height: 80.0,
                decoration: BoxDecoration(
                  color: palette.accent,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  LucideIcons.check,
                  size: 42.0,
                  color: palette.onAccent,
                ),
              ),

              const SizedBox(height: 20.0),

              // Judul selesai
              Text(
                'Selamat, masakanmu siap! 🎉',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 22.0,
                  fontWeight: FontWeight.w700,
                  color: palette.textStrong,
                ),
              ),

              const SizedBox(height: 8.0),

              // Sub judul
              Text(
                'Kamu baru saja menyelesaikan resep ${recipe.title}. Selamat menikmati hasil masakanmu!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13.0,
                  fontWeight: FontWeight.w400,
                  color: palette.textSecondary,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 20.0),

              // Kartu Rating (PRD §14.9)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 16.0,
                ),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(16.0),
                  boxShadow: AppShadows.card,
                  border: Border.all(color: palette.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Beri rating untuk ${recipe.title}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13.0,
                        fontWeight: FontWeight.w600,
                        color: palette.textStrong,
                      ),
                    ),
                    const SizedBox(height: 10.0),

                    // 5 Bintang amber (tap target >= 40)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final starNumber = index + 1;
                        final isFilled = starNumber <= _selectedRating;

                        return Semantics(
                          label: 'Rating $starNumber bintang',
                          button: true,
                          child: GestureDetector(
                            onTap: _ratingSubmitted
                                ? null
                                : () {
                                    setState(() {
                                      _selectedRating = starNumber;
                                    });
                                  },
                            child: Container(
                              width: 44.0,
                              height: 44.0,
                              alignment: Alignment.center,
                              child: Icon(
                                isFilled ? Icons.star : Icons.star_border,
                                color: isFilled
                                    ? palette.accent
                                    : palette.textSecondary,
                                size: 32.0,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 14.0),

                    // Tombol Kirim rating / Rating terkirim
                    SizedBox(
                      width: double.infinity,
                      height: 44.0,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _ratingSubmitted
                              ? palette.chip
                              : (_selectedRating > 0
                                    ? palette.actionBg
                                    : palette.chip),
                          foregroundColor: _ratingSubmitted
                              ? palette.textSecondary
                              : (_selectedRating > 0
                                    ? palette.onAction
                                    : palette.textSecondary),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                        ),
                        onPressed: (_selectedRating > 0 && !_ratingSubmitted)
                            ? () async {
                                await ref
                                    .read(ratingsProvider.notifier)
                                    .rate(recipe.id, _selectedRating);
                                setState(() {
                                  _ratingSubmitted = true;
                                });
                                if (context.mounted) {
                                  showAppToast(
                                    context,
                                    'Terima kasih atas ratingmu',
                                  );
                                }
                              }
                            : null,
                        child: Text(
                          _ratingSubmitted ? 'Rating terkirim' : 'Kirim rating',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13.0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    if (!_ratingSubmitted) ...[
                      const SizedBox(height: 6.0),
                      // Tombol ghost "Lewati"
                      GestureDetector(
                        onTap: () => context.go('/home'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            'Lewati',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13.0,
                              fontWeight: FontWeight.w500,
                              color: palette.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20.0),

              // Tombol "Kembali ke Beranda"
              AppButton(
                label: 'Kembali ke Beranda',
                variant: AppButtonVariant.primary,
                size: AppButtonSize.lg,
                fullWidth: true,
                onPressed: () => context.go('/home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
