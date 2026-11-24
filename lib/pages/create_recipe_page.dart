import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme/app_palette.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_shadows.dart';
import '../core/theme/app_text.dart';
import '../models/models.dart';
import '../providers/recipes_provider.dart';
import '../providers/ui_helper.dart';
import '../widgets/expandable_card_list.dart';
import '../widgets/page_with_header.dart';
import '../widgets/ui/app_bottom_sheet.dart';
import '../widgets/ui/app_button.dart';
import '../widgets/ui/app_chip.dart';
import '../widgets/ui/smart_image.dart';
import '../widgets/ui/sticky_bottom_bar.dart';

/// Halaman Create Recipe (/add) sesuai PRD §6.6, §7.3, §7.4, §7.5, §10 dan design/add.jpg:
/// - AppHeader global di atas.
/// - Baris judul: "<  Create Recipe" (kembali ke /home).
/// - "Recipe Title" + input abu fieldAdd (#D6D6D6).
/// - Dua kolom:
///   - Kiri: "Add Cover Image" (image_picker, max 1MB, simpan data URI JPEG).
///   - Kanan: "Ingredients" (kotak abu lingkaran sage +; tap -> sheet bahan).
/// - "Serving Size": chip dropdown (ikon users + angka + chevron).
/// - "Cooking Instructions": kotak abu (tap -> sheet langkah).
/// - Tombol actionBg pill "DONE" (uppercase, 362x55) sticky di bawah.
/// - Validasi: judul, >=1 bahan, >=1 langkah (pesan error di bawah field).
/// - Submit -> simpan ke recipesProvider -> dialog sukses -> /my-recipes.
class CreateRecipePage extends ConsumerStatefulWidget {
  const CreateRecipePage({super.key});

  @override
  ConsumerState<CreateRecipePage> createState() => _CreateRecipePageState();
}

class _CreateRecipePageState extends ConsumerState<CreateRecipePage> {
  final TextEditingController _titleController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();

  String? _coverImageUri;
  final List<Ingredient> _ingredients = [];
  final List<RecipeStep> _steps = [];
  int _servingSize = 2;

  String? _titleError;
  String? _ingredientsError;
  String? _stepsError;

  @override
  void dispose() {
    _titleController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickCoverImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        imageQuality: 80,
      );

      if (pickedFile == null) return;

      final bytes = await pickedFile.readAsBytes();
      if (bytes.lengthInBytes > 1024 * 1024) {
        if (mounted) {
          showAppToast(context, 'Ukuran foto maksimal 1 MB');
        }
        return;
      }

      final base64Str = base64Encode(bytes);
      setState(() {
        _coverImageUri = 'data:image/jpeg;base64,$base64Str';
      });
    } catch (_) {
      if (mounted) {
        showAppToast(context, 'Gagal memilih foto sampul');
      }
    }
  }

  void _openServingSizePicker() {
    final palette = context.palette;
    showAppBottomSheet(
      context: context,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pilih Jumlah Porsi',
                style: AppText.sectionTitle.copyWith(color: palette.textStrong),
              ),
              const SizedBox(height: 16.0),
              Wrap(
                spacing: 10.0,
                runSpacing: 10.0,
                children: List.generate(12, (index) {
                  final size = index + 1;
                  final isSelected = size == _servingSize;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _servingSize = size;
                      });
                      Navigator.of(sheetContext).pop();
                    },
                    child: Container(
                      width: 52.0,
                      height: 44.0,
                      decoration: BoxDecoration(
                        color: isSelected ? palette.actionBg : palette.chip,
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$size',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14.0,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? palette.onAction
                              : palette.textStrong,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20.0),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openIngredientsSheet() async {
    FocusManager.instance.primaryFocus?.unfocus();
    _titleFocusNode.unfocus();

    final result = await showAppBottomSheet<List<Ingredient>>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _IngredientsSheetContent(
          initialIngredients: _ingredients,
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        _ingredients.clear();
        _ingredients.addAll(result);
        if (_ingredients.isNotEmpty) {
          _ingredientsError = null;
        }
      });
    }
  }

  void _openCookingInstructionsSheet() {
    final palette = context.palette;
    FocusScope.of(context).unfocus();
    _titleFocusNode.unfocus();
    final tempSteps = List<RecipeStep>.from(_steps);

    showAppBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetBuilderContext, setSheetState) {
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 8.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Langkah Memasak',
                        style: AppText.sectionTitle.copyWith(
                          color: palette.textStrong,
                        ),
                      ),
                      IconButton(
                        icon: Icon(LucideIcons.x, color: palette.textStrong),
                        onPressed: () => Navigator.of(sheetContext).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12.0),

                  // Daftar langkah
                  if (tempSteps.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Center(
                        child: Text(
                          'Belum ada langkah. Tekan "+ Tambah Langkah" di bawah.',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12.0,
                            color: palette.textSecondary,
                          ),
                        ),
                      ),
                    )
                  else
                    ...tempSteps.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final step = entry.value;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12.0),
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(color: palette.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 24.0,
                                  height: 24.0,
                                  decoration: BoxDecoration(
                                    color: palette.accent,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${idx + 1}',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 12.0,
                                      fontWeight: FontWeight.w700,
                                      color: palette.onAccent,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8.0),
                                Expanded(
                                  child: Text(
                                    step.title.isNotEmpty
                                        ? step.title
                                        : 'Langkah ${idx + 1}',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 13.0,
                                      fontWeight: FontWeight.w700,
                                      color: palette.textStrong,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    setSheetState(() {
                                      tempSteps.removeAt(idx);
                                    });
                                  },
                                  child: Icon(
                                    LucideIcons.trash2,
                                    size: 16.0,
                                    color: palette.danger,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6.0),
                            Text(
                              step.description,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12.0,
                                color: palette.textSecondary,
                              ),
                            ),
                            if (step.durationMin != null &&
                                step.durationMin! > 0) ...[
                              const SizedBox(height: 4.0),
                              Text(
                                '⏱ ${step.durationMin} menit',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11.0,
                                  fontWeight: FontWeight.w600,
                                  color: palette.accent,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),

                  // Tombol Tambah Langkah
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.actionBg,
                      side: BorderSide(color: palette.actionBg),
                      minimumSize: const Size(double.infinity, 44.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                    icon: const Icon(LucideIcons.plus, size: 16.0),
                    label: const Text(
                      'Tambah Langkah',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () {
                      _showAddStepDialog(context, (newStep) {
                        setSheetState(() {
                          tempSteps.add(newStep);
                        });
                      });
                    },
                  ),

                  const SizedBox(height: 20.0),

                  // Tombol Simpan
                  AppButton(
                    label: 'Simpan',
                    variant: AppButtonVariant.primary,
                    size: AppButtonSize.lg,
                    fullWidth: true,
                    onPressed: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      setState(() {
                        _steps.clear();
                        _steps.addAll(tempSteps);
                        if (_steps.isNotEmpty) {
                          _stepsError = null;
                        }
                      });
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                  const SizedBox(height: 8.0),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddStepDialog(
    BuildContext context,
    ValueChanged<RecipeStep> onAdded,
  ) {
    final palette = context.palette;
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final durationCtrl = TextEditingController();
    String? titleError;

    showDialog<void>(
      context: context,
      barrierColor: palette.dialogBarrier,
      builder: (dlgContext) {
        return StatefulBuilder(
          builder: (dialogCtx, setDlgState) {
            return Dialog(
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.cardLarge,
              ),
              backgroundColor: palette.surface,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detail Langkah',
                        style: AppText.sectionTitle.copyWith(
                          color: palette.textStrong,
                        ),
                      ),
                      const SizedBox(height: 12.0),
                      Row(
                        children: [
                          Text(
                            'Judul Langkah',
                            style: AppText.formLabel.copyWith(
                              color: palette.textStrong,
                            ),
                          ),
                          const SizedBox(width: 4.0),
                          Text(
                            '*',
                            style: TextStyle(
                              color: palette.danger,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4.0),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        decoration: BoxDecoration(
                          color: palette.chip,
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(
                            color: titleError != null
                                ? palette.danger
                                : Colors.transparent,
                            width: 1.0,
                          ),
                        ),
                        child: TextField(
                          controller: titleCtrl,
                          style: AppText.body.copyWith(color: palette.textBody),
                          onChanged: (_) {
                            if (titleError != null) {
                              setDlgState(() => titleError = null);
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'Mis. Tumis Bawang',
                            hintStyle: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13.0,
                              color: palette.textSecondary,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      if (titleError != null) ...[
                        const SizedBox(height: 4.0),
                        Text(
                          titleError!,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11.0,
                            color: palette.danger,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12.0),
                      Text(
                        'Deskripsi',
                        style: AppText.formLabel.copyWith(
                          color: palette.textStrong,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 8.0,
                        ),
                        decoration: BoxDecoration(
                          color: palette.chip,
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: TextField(
                          controller: descCtrl,
                          maxLines: 3,
                          style: AppText.body.copyWith(color: palette.textBody),
                          decoration: InputDecoration(
                            hintText: 'Tuliskan detail langkah...',
                            hintStyle: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13.0,
                              color: palette.textSecondary,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12.0),
                      Text(
                        'Durasi Menit (Opsional)',
                        style: AppText.formLabel.copyWith(
                          color: palette.textStrong,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        decoration: BoxDecoration(
                          color: palette.chip,
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: TextField(
                          controller: durationCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          style: AppText.body.copyWith(color: palette.textBody),
                          decoration: InputDecoration(
                            hintText: '0',
                            hintStyle: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13.0,
                              color: palette.textSecondary,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20.0),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                            child: Text(
                              'Batal',
                              style: TextStyle(color: palette.textSecondary),
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: palette.actionBg,
                              foregroundColor: palette.onAction,
                            ),
                            onPressed: () {
                              final title = titleCtrl.text.trim();
                              if (title.isEmpty) {
                                setDlgState(() {
                                  titleError = 'Judul langkah wajib diisi';
                                });
                                return;
                              }
                              final desc = descCtrl.text.trim();
                              final dur = int.tryParse(
                                durationCtrl.text.trim(),
                              );
                              onAdded(
                                RecipeStep(
                                  id: 'step-${DateTime.now().millisecondsSinceEpoch}',
                                  title: title,
                                  description: desc,
                                  durationMin: dur,
                                ),
                              );
                              Navigator.of(dialogCtx).pop();
                            },
                            child: const Text('Tambahkan'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleSubmit() async {
    final title = _titleController.text.trim();

    setState(() {
      _titleError = title.isEmpty ? 'Recipe Title tidak boleh kosong' : null;
      _ingredientsError = _ingredients.isEmpty
          ? 'Minimal tambahkan 1 bahan'
          : null;
      _stepsError = _steps.isEmpty
          ? 'Minimal tambahkan 1 langkah memasak'
          : null;
    });

    if (_titleError != null ||
        _ingredientsError != null ||
        _stepsError != null) {
      return;
    }

    final newRecipe = Recipe(
      id: 'custom-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: _steps.isNotEmpty
          ? _steps.first.description
          : 'Resep kreasi sendiri',
      image: _coverImageUri,
      category: 'Kreasi',
      cuisine: 'Indonesian',
      meal: MealType.dinner,
      mainIngredient: _ingredients.isNotEmpty
          ? _ingredients.first.name
          : 'Campuran',
      rating: 5.0,
      reviews: 1,
      timeMin: _steps.fold<int>(0, (sum, s) => sum + (s.durationMin ?? 5)),
      servings: _servingSize,
      kcal: 350,
      difficulty: Difficulty.mudah,
      ingredients: List.from(_ingredients),
      steps: List.from(_steps),
      authorId: 'user-default-1',
    );

    await ref.read(recipesProvider.notifier).addCustomRecipe(newRecipe);

    if (!mounted) return;

    await showAppSuccessDialog(
      context,
      title: 'Resep berhasil disimpan',
      message: 'Resepmu sudah bisa dilihat di Resep Saya.',
    );

    if (!mounted) return;
    context.go('/my-recipes');
  }

  Widget _buildInlineIngredientsList() {
    if (_ingredients.isEmpty) return const SizedBox.shrink();
    final palette = context.palette;

    return ExpandableCardList(
      title: 'Ingredients (${_ingredients.length})',
      itemCount: _ingredients.length,
      itemBuilder: (context, index) {
        final ing = _ingredients[index];
        final isLast = index == _ingredients.length - 1;

        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0.0 : 8.0),
          child: Row(
            children: [
              // Nama bahan
              Expanded(
                child: Text(
                  ing.name,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13.0,
                    fontWeight: FontWeight.w600,
                    color: palette.textStrong,
                  ),
                ),
              ),
              const SizedBox(width: 8.0),
              // Takaran/satuan rata kanan
              Text(
                '${ing.qty} ${ing.unit ?? ''}'.trim(),
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13.0,
                  fontWeight: FontWeight.w500,
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(width: 12.0),
              // Tombol hapus (trash danger, aria/Semantics)
              Semantics(
                label: 'Hapus ${ing.name}',
                button: true,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _ingredients.removeAt(index);
                      if (_ingredients.isEmpty) {
                        _ingredientsError = 'Tambahkan minimal 1 bahan resep';
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4.0),
                    alignment: Alignment.center,
                    child: Icon(
                      LucideIcons.trash2,
                      size: 16.0,
                      color: palette.danger,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInlineStepsList() {
    if (_steps.isEmpty) return const SizedBox.shrink();
    final palette = context.palette;

    return ExpandableCardList(
      title: 'Cooking Instructions (${_steps.length})',
      itemCount: _steps.length,
      itemBuilder: (context, index) {
        final step = _steps[index];
        final isLast = index == _steps.length - 1;

        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0.0 : 10.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Lingkaran aksen 28 bernomor
              Container(
                width: 28.0,
                height: 28.0,
                decoration: BoxDecoration(
                  color: palette.accent,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.0,
                    fontWeight: FontWeight.w700,
                    color: palette.onAccent,
                  ),
                ),
              ),
              const SizedBox(width: 10.0),

              // Judul langkah + deskripsi
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      step.title.isNotEmpty
                          ? step.title
                          : 'Langkah ${index + 1}',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14.0,
                        fontWeight: FontWeight.w600,
                        color: palette.textStrong,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1.0),
                    Text(
                      step.durationMin != null && step.durationMin! > 0
                          ? '${step.description} • ⏱ ${step.durationMin} mnt'
                          : step.description,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11.0,
                        fontWeight: FontWeight.w400,
                        color: palette.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8.0),

              // Tombol hapus
              Semantics(
                label: 'Hapus langkah ${index + 1}',
                button: true,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _steps.removeAt(index);
                      if (_steps.isEmpty) {
                        _stepsError = 'Tambahkan minimal 1 langkah memasak';
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4.0),
                    alignment: Alignment.center,
                    child: Icon(
                      LucideIcons.trash2,
                      size: 16.0,
                      color: palette.danger,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return PageWithHeader(
      resizeToAvoidBottomInset: false,
      body: CustomScrollView(
        slivers: [
          // 1. Baris Judul: "<  Create Recipe"
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(
                left: 20.0,
                right: 24.0,
                top: 4.0,
                bottom: 16.0,
              ),
              child: Row(
                children: [
                  Semantics(
                    label: 'Kembali',
                    button: true,
                    child: GestureDetector(
                      onTap: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/home');
                        }
                      },
                      child: Container(
                        width: 36.0,
                        height: 36.0,
                        alignment: Alignment.centerLeft,
                        child: Icon(
                          LucideIcons.chevronLeft,
                          size: 24.0,
                          color: palette.textStrong,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4.0),
                  Text(
                    'Create Recipe',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 20.0,
                      fontWeight: FontWeight.w700,
                      color: palette.textStrong,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Form Input
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // "Recipe Title"
                  Text(
                    'Recipe Title',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14.0,
                      fontWeight: FontWeight.w700,
                      color: palette.textStrong,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Container(
                    height: 48.0,
                    padding: const EdgeInsets.symmetric(horizontal: 14.0),
                    decoration: BoxDecoration(
                      color: palette.fieldAdd,
                      borderRadius: BorderRadius.circular(10.0),
                      boxShadow: AppShadows.card,
                    ),
                    alignment: Alignment.centerLeft,
                    child: TextField(
                      controller: _titleController,
                      focusNode: _titleFocusNode,
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14.0,
                        color: palette.textBody,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Type your recipe name here',
                        hintStyle: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13.0,
                          color: palette.textSecondary,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (_) {
                        if (_titleError != null) {
                          setState(() => _titleError = null);
                        }
                      },
                    ),
                  ),
                  if (_titleError != null) ...[
                    const SizedBox(height: 4.0),
                    Text(
                      _titleError!,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11.0,
                        color: palette.danger,
                      ),
                    ),
                  ],

                  const SizedBox(height: 18.0),

                  // Dua Kolom: "Add Cover Image" (kiri) & "Ingredients" (kanan)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Kolom Kiri: Add Cover Image
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add Cover Image',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14.0,
                                fontWeight: FontWeight.w700,
                                color: palette.textStrong,
                              ),
                            ),
                            const SizedBox(height: 8.0),
                            GestureDetector(
                              onTap: _pickCoverImage,
                              child: Container(
                                height: 104.0,
                                decoration: BoxDecoration(
                                  color: palette.fieldAdd,
                                  borderRadius: BorderRadius.circular(10.0),
                                  boxShadow: AppShadows.card,
                                ),
                                clipBehavior: Clip.antiAlias,
                                alignment: Alignment.center,
                                child: _coverImageUri != null
                                    ? Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          SmartImage(
                                            src: _coverImageUri,
                                            fit: BoxFit.cover,
                                          ),
                                          Positioned(
                                            right: 6.0,
                                            bottom: 6.0,
                                            child: Container(
                                              padding: const EdgeInsets.all(
                                                4.0,
                                              ),
                                              decoration: BoxDecoration(
                                                color: palette.actionBg,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                LucideIcons.edit2,
                                                size: 12.0,
                                                color: palette.onAction,
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            LucideIcons.camera,
                                            size: 26.0,
                                            color: palette.textSecondary,
                                          ),
                                          const SizedBox(height: 6.0),
                                          Text(
                                            'Add Cover Image',
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 11.0,
                                              fontWeight: FontWeight.w600,
                                              color: palette.textStrong,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 14.0),

                      // Kolom Kanan: Ingredients
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ingredients',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14.0,
                                fontWeight: FontWeight.w700,
                                color: palette.textStrong,
                              ),
                            ),
                            const SizedBox(height: 8.0),
                            GestureDetector(
                              key: const Key('add-ingredients-button'),
                              onTap: _openIngredientsSheet,
                              child: Container(
                                height: 104.0,
                                decoration: BoxDecoration(
                                  color: palette.fieldAdd,
                                  borderRadius: BorderRadius.circular(10.0),
                                  boxShadow: AppShadows.card,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                ),
                                alignment: Alignment.center,
                                child: _ingredients.isNotEmpty
                                    ? Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 32.0,
                                            height: 32.0,
                                            decoration: BoxDecoration(
                                              color: palette.actionBg,
                                              shape: BoxShape.circle,
                                            ),
                                            alignment: Alignment.center,
                                            child: Icon(
                                              LucideIcons.check,
                                              size: 18.0,
                                              color: palette.onAction,
                                            ),
                                          ),
                                          const SizedBox(height: 6.0),
                                          Text(
                                            '${_ingredients.length} ingredients',
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 12.0,
                                              fontWeight: FontWeight.w700,
                                              color: palette.textStrong,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          CircleAvatar(
                                            radius: 14.0,
                                            backgroundColor:
                                                palette.textSecondary,
                                            child: Icon(
                                              LucideIcons.plus,
                                              size: 16.0,
                                              color: palette.onAction,
                                            ),
                                          ),
                                          const SizedBox(height: 6.0),
                                          Text(
                                            'Add ingredients to recipe',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 11.0,
                                              fontWeight: FontWeight.w600,
                                              color: palette.textStrong,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            if (_ingredientsError != null) ...[
                              const SizedBox(height: 4.0),
                              Text(
                                _ingredientsError!,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11.0,
                                  color: palette.danger,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Daftar bahan yang sudah ditambahkan (Fase B5 §14.8)
                  if (_ingredients.isNotEmpty) ...[
                    const SizedBox(height: 14.0),
                    _buildInlineIngredientsList(),
                  ],

                  const SizedBox(height: 18.0),

                  // "Serving Size"
                  Text(
                    'Serving Size',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14.0,
                      fontWeight: FontWeight.w700,
                      color: palette.textStrong,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  GestureDetector(
                    onTap: _openServingSizePicker,
                    child: Container(
                      height: 44.0,
                      padding: const EdgeInsets.symmetric(horizontal: 14.0),
                      decoration: BoxDecoration(
                        color: palette.fieldAdd,
                        borderRadius: BorderRadius.circular(10.0),
                        boxShadow: AppShadows.card,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.users,
                            size: 18.0,
                            color: palette.textStrong,
                          ),
                          const SizedBox(width: 8.0),
                          Text(
                            '$_servingSize Porsi',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13.0,
                              fontWeight: FontWeight.w600,
                              color: palette.textStrong,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            LucideIcons.chevronDown,
                            size: 16.0,
                            color: palette.textStrong,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18.0),

                  // "Cooking Instructions"
                  Text(
                    'Cooking Instructions',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14.0,
                      fontWeight: FontWeight.w700,
                      color: palette.textStrong,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  GestureDetector(
                    onTap: _openCookingInstructionsSheet,
                    child: Container(
                      height: 72.0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14.0,
                        vertical: 12.0,
                      ),
                      decoration: BoxDecoration(
                        color: palette.fieldAdd,
                        borderRadius: BorderRadius.circular(10.0),
                        boxShadow: AppShadows.card,
                      ),
                      alignment: Alignment.centerLeft,
                      child: _steps.isNotEmpty
                          ? Row(
                              children: [
                                Container(
                                  width: 28.0,
                                  height: 28.0,
                                  decoration: BoxDecoration(
                                    color: palette.actionBg,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    LucideIcons.check,
                                    size: 16.0,
                                    color: palette.onAction,
                                  ),
                                ),
                                const SizedBox(width: 10.0),
                                Text(
                                  '${_steps.length} steps configured',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13.0,
                                    fontWeight: FontWeight.w600,
                                    color: palette.textStrong,
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  LucideIcons.edit2,
                                  size: 16.0,
                                  color: palette.textStrong,
                                ),
                              ],
                            )
                          : Text(
                              'Add one or multiple steps',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13.0,
                                color: palette.textSecondary,
                              ),
                            ),
                    ),
                  ),
                  if (_stepsError != null) ...[
                    const SizedBox(height: 4.0),
                    Text(
                      _stepsError!,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11.0,
                        color: palette.danger,
                      ),
                    ),
                  ],

                  // List langkah yang sudah ditambahkan (PRD §15.5)
                  _buildInlineStepsList(),

                  const SizedBox(height: 24.0),
                ],
              ),
            ),
          ),

          // Tombol DONE di ujung form: lebar lebih kecil dari navbar (300 < 365)
          // dan padding bawah cukup (bottomGap + 75 + 32) agar tidak tertutup navbar (PRD §15.5)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(
                left: 24.0,
                right: 24.0,
                top: 8.0,
                bottom: bottomGap(context) + 75.0 + 32.0,
              ),
              child: Center(
                child: SizedBox(
                  width: 300.0,
                  height: 52.0,
                  child: ElevatedButton(
                    key: const Key('add-done-button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.actionBg,
                      foregroundColor: palette.onAction,
                      elevation: 4.0,
                      shadowColor: palette.shadowColor,
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.pill,
                      ),
                    ),
                    onPressed: _handleSubmit,
                    child: Text(
                      'DONE',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16.0,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: palette.onAction,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IngredientsSheetContent extends StatefulWidget {
  final List<Ingredient> initialIngredients;

  const _IngredientsSheetContent({
    required this.initialIngredients,
  });

  @override
  State<_IngredientsSheetContent> createState() =>
      _IngredientsSheetContentState();
}

class _IngredientsSheetContentState extends State<_IngredientsSheetContent> {
  late final List<Ingredient> _tempIngredients;
  late final TextEditingController _nameController;
  late final TextEditingController _qtyController;
  late final TextEditingController _unitController;
  late final TextEditingController _priceController;

  late final FocusNode _nameFocusNode;
  late final FocusNode _qtyFocusNode;
  late final FocusNode _unitFocusNode;
  late final FocusNode _priceFocusNode;

  static const _units = [
    'g',
    'kg',
    'ml',
    'l',
    'sdm',
    'sdt',
    'butir',
    'siung',
    'buah',
    'bungkus',
    'ikat',
    'secukupnya',
  ];

  @override
  void initState() {
    super.initState();
    _tempIngredients = List<Ingredient>.from(widget.initialIngredients);
    _nameController = TextEditingController();
    _qtyController = TextEditingController();
    _unitController = TextEditingController();
    _priceController = TextEditingController();

    _nameFocusNode = FocusNode();
    _qtyFocusNode = FocusNode();
    _unitFocusNode = FocusNode();
    _priceFocusNode = FocusNode();

    _unitFocusNode.addListener(_onUnitFocusChanged);
  }

  void _onUnitFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _unitFocusNode.removeListener(_onUnitFocusChanged);
    _nameFocusNode.dispose();
    _qtyFocusNode.dispose();
    _unitFocusNode.dispose();
    _priceFocusNode.dispose();
    _nameController.dispose();
    _qtyController.dispose();
    _unitController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _addIngredient() {
    final name = _nameController.text.trim();
    final qty = _qtyController.text.trim();
    final unit = _unitController.text.trim();
    final effectiveUnit = unit.isNotEmpty ? unit : 'g';
    if (name.isEmpty) {
      _nameFocusNode.requestFocus();
      return;
    }

    final price = int.tryParse(_priceController.text.trim()) ?? 0;
    setState(() {
      _tempIngredients.add(
        Ingredient(
          id: 'ing-${DateTime.now().millisecondsSinceEpoch}',
          name: name,
          qty: qty.isNotEmpty ? qty : '1',
          unit: effectiveUnit,
          price: price,
        ),
      );
      _nameController.clear();
      _qtyController.clear();
      _unitController.clear();
      _priceController.clear();
    });
    _nameFocusNode.requestFocus();
  }

  void _saveAndPop() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      final qty = _qtyController.text.trim();
      final unit = _unitController.text.trim();
      final effectiveUnit = unit.isNotEmpty ? unit : 'g';
      final price = int.tryParse(_priceController.text.trim()) ?? 0;
      _tempIngredients.add(
        Ingredient(
          id: 'ing-${DateTime.now().millisecondsSinceEpoch}',
          name: name,
          qty: qty.isNotEmpty ? qty : '1',
          unit: effectiveUnit,
          price: price,
        ),
      );
    }
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop(_tempIngredients);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final currentUnit = _unitController.text.trim();
    final isUnitFocused = _unitFocusNode.hasFocus;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 24.0,
        vertical: 8.0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tambah Bahan',
                style: AppText.sectionTitle.copyWith(
                  color: palette.textStrong,
                ),
              ),
              IconButton(
                icon: Icon(LucideIcons.x, color: palette.textStrong),
                onPressed: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
          const SizedBox(height: 12.0),

          // Input Nama Bahan
          Text(
            'Nama Bahan',
            style: AppText.formLabel.copyWith(
              color: palette.textStrong,
            ),
          ),
          const SizedBox(height: 6.0),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14.0),
            decoration: BoxDecoration(
              color: palette.chip,
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: TextField(
              controller: _nameController,
              focusNode: _nameFocusNode,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _qtyFocusNode.requestFocus(),
              scrollPadding: const EdgeInsets.symmetric(
                vertical: 32.0,
                horizontal: 20.0,
              ),
              style: AppText.body.copyWith(color: palette.textBody),
              decoration: InputDecoration(
                hintText: 'Mis. Bawang merah',
                hintStyle: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13.0,
                  color: palette.textSecondary,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 12.0),

          // Input Jumlah & Satuan
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kolom Jumlah
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jumlah',
                      style: AppText.formLabel.copyWith(
                        color: palette.textStrong,
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14.0,
                      ),
                      decoration: BoxDecoration(
                        color: palette.chip,
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: TextField(
                        controller: _qtyController,
                        focusNode: _qtyFocusNode,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => _unitFocusNode.requestFocus(),
                        scrollPadding: const EdgeInsets.symmetric(
                          vertical: 32.0,
                          horizontal: 20.0,
                        ),
                        style: AppText.body.copyWith(
                          color: palette.textBody,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Mis. 4',
                          hintStyle: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13.0,
                            color: palette.textSecondary,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12.0),
              // Kolom Satuan (TextField biasa, keyboard tetap terbuka)
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Satuan',
                      style: AppText.formLabel.copyWith(
                        color: palette.textStrong,
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14.0,
                      ),
                      decoration: BoxDecoration(
                        color: palette.chip,
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: TextField(
                        controller: _unitController,
                        focusNode: _unitFocusNode,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => _priceFocusNode.requestFocus(),
                        onChanged: (_) => setState(() {}),
                        scrollPadding: const EdgeInsets.symmetric(
                          vertical: 32.0,
                          horizontal: 20.0,
                        ),
                        style: AppText.body.copyWith(
                          color: palette.textBody,
                        ),
                        decoration: InputDecoration(
                          hintText: 'g, sdm, butir…',
                          hintStyle: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13.0,
                            color: palette.textSecondary,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Baris Chip Saran Satuan (tinggi ±36 dp)
          if (currentUnit.isNotEmpty && !isUnitFocused)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: SizedBox(
                height: 36.0,
                child: Row(
                  children: [
                    AppChip(
                      label: currentUnit,
                      selected: true,
                      icon: Icon(
                        Icons.close,
                        size: 14,
                        color: palette.onChipSelected,
                      ),
                      onTap: () {
                        setState(() {
                          _unitController.clear();
                        });
                        _unitFocusNode.requestFocus();
                      },
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Builder(
              builder: (context) {
                final filtered = currentUnit.isEmpty
                    ? _units
                    : _units
                          .where(
                            (u) => u.toLowerCase().contains(
                              currentUnit.toLowerCase(),
                            ),
                          )
                          .toList();

                if (filtered.isEmpty) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: SizedBox(
                    height: 36.0,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: filtered.map((u) {
                          final isSelected =
                              currentUnit.toLowerCase() ==
                              u.toLowerCase();
                          return Padding(
                            padding: const EdgeInsets.only(
                              right: 6.0,
                            ),
                            child: AppChip(
                              label: u,
                              selected: isSelected,
                              onTap: () {
                                setState(() {
                                  _unitController.text = u;
                                });
                                // Pindahkan fokus tanpa menutup keyboard
                                _priceFocusNode.requestFocus();
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],

          const SizedBox(height: 12.0),

          // Input Estimasi Harga
          Text(
            'Estimasi Harga (Rp, opsional)',
            style: AppText.formLabel.copyWith(
              color: palette.textStrong,
            ),
          ),
          const SizedBox(height: 6.0),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14.0),
            decoration: BoxDecoration(
              color: palette.chip,
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: TextField(
              controller: _priceController,
              focusNode: _priceFocusNode,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _addIngredient(),
              scrollPadding: const EdgeInsets.symmetric(
                vertical: 32.0,
                horizontal: 20.0,
              ),
              style: AppText.body.copyWith(color: palette.textBody),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13.0,
                  color: palette.textSecondary,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 14.0),

          // Tombol Tambah ke daftar
          SizedBox(
            width: double.infinity,
            height: 44.0,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.accent,
                foregroundColor: palette.onAccent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
              onPressed: _addIngredient,
              child: Text(
                '+ Tambah ke Daftar',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13.0,
                  fontWeight: FontWeight.w700,
                  color: palette.onAccent,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16.0),

          // Daftar bahan yang sudah ditambahkan
          if (_tempIngredients.isNotEmpty) ...[
            Text(
              'Bahan Terdaftar:',
              style: AppText.formLabel.copyWith(
                color: palette.textStrong,
              ),
            ),
            const SizedBox(height: 8.0),
            ..._tempIngredients.asMap().entries.map((entry) {
              final idx = entry.key;
              final ing = entry.value;

              return Container(
                margin: const EdgeInsets.only(bottom: 6.0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 8.0,
                ),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: palette.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${ing.name} (${ing.qty} ${ing.unit ?? ''})',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13.0,
                          fontWeight: FontWeight.w600,
                          color: palette.textStrong,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _tempIngredients.removeAt(idx);
                        });
                      },
                      child: Icon(
                        LucideIcons.trash2,
                        size: 16.0,
                        color: palette.danger,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16.0),
          ],

          // Tombol Simpan
          AppButton(
            label: 'Simpan',
            variant: AppButtonVariant.primary,
            size: AppButtonSize.lg,
            fullWidth: true,
            onPressed: _saveAndPop,
          ),
          const SizedBox(height: 8.0),
        ],
      ),
    );
  }
}
