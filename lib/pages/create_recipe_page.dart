import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_shadows.dart';
import '../core/theme/app_text.dart';
import '../models/models.dart';
import '../providers/recipes_provider.dart';
import '../providers/ui_helper.dart';
import '../widgets/page_with_header.dart';
import '../widgets/ui/app_bottom_sheet.dart';
import '../widgets/ui/app_button.dart';
import '../widgets/ui/smart_image.dart';
import '../widgets/ui/sticky_bottom_bar.dart';

/// Halaman Create Recipe (/add) sesuai PRD §6.6, §7.3, §7.4, §7.5, §10 dan design/add.jpg:
/// - AppHeader global di atas.
/// - Baris judul: "<  Create Recipe" (kembali ke /home).
/// - "Recipe Title" + input abu fieldGray (#D6D6D6).
/// - Dua kolom:
///   - Kiri: "Add Cover Image" (image_picker, max 1MB, simpan data URI JPEG).
///   - Kanan: "Ingredients" (kotak abu lingkaran sage +; tap -> sheet bahan).
/// - "Serving Size": chip dropdown (ikon users + angka + chevron).
/// - "Cooking Instructions": kotak abu (tap -> sheet langkah).
/// - Tombol olive pill "DONE" (uppercase, 362x55) sticky di bawah.
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
    showAppBottomSheet(
      context: context,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pilih Jumlah Porsi', style: AppText.sectionTitle),
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
                        color: isSelected
                            ? AppColors.olive
                            : AppColors.chipGray,
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$size',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14.0,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? AppColors.white : AppColors.olive,
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

  void _openIngredientsSheet() {
    final tempIngredients = List<Ingredient>.from(_ingredients);

    final nameController = TextEditingController();
    final qtyController = TextEditingController();
    final priceController = TextEditingController();
    String selectedUnit = 'g';

    final units = [
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
    ];

    showAppBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
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
                      Text('Tambah Bahan', style: AppText.sectionTitle),
                      IconButton(
                        icon: const Icon(LucideIcons.x, color: AppColors.olive),
                        onPressed: () => Navigator.of(sheetContext).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12.0),

                  // Input Nama Bahan
                  const Text('Nama Bahan', style: AppText.formLabel),
                  const SizedBox(height: 6.0),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14.0),
                    decoration: BoxDecoration(
                      color: AppColors.chipGray,
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: TextField(
                      controller: nameController,
                      style: AppText.body,
                      decoration: const InputDecoration(
                        hintText: 'Mis. Bawang merah',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12.0),

                  // Input Jumlah & Satuan
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Jumlah', style: AppText.formLabel),
                            const SizedBox(height: 6.0),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14.0,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.chipGray,
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              child: TextField(
                                controller: qtyController,
                                style: AppText.body,
                                decoration: const InputDecoration(
                                  hintText: 'Mis. 4',
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Satuan', style: AppText.formLabel),
                            const SizedBox(height: 6.0),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12.0,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.chipGray,
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedUnit,
                                  isExpanded: true,
                                  items: units.map((u) {
                                    return DropdownMenuItem(
                                      value: u,
                                      child: Text(u, style: AppText.body),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setSheetState(() => selectedUnit = val);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12.0),

                  // Input Estimasi Harga
                  const Text(
                    'Estimasi Harga (Rp, opsional)',
                    style: AppText.formLabel,
                  ),
                  const SizedBox(height: 6.0),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14.0),
                    decoration: BoxDecoration(
                      color: AppColors.chipGray,
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: AppText.body,
                      decoration: const InputDecoration(
                        hintText: '0',
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
                        backgroundColor: AppColors.amber,
                        foregroundColor: AppColors.olive,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                      onPressed: () {
                        final name = nameController.text.trim();
                        final qty = qtyController.text.trim();
                        if (name.isEmpty) return;

                        final price =
                            int.tryParse(priceController.text.trim()) ?? 0;
                        setSheetState(() {
                          tempIngredients.add(
                            Ingredient(
                              id: 'ing-${DateTime.now().millisecondsSinceEpoch}',
                              name: name,
                              qty: qty.isNotEmpty ? qty : '1',
                              unit: selectedUnit,
                              price: price,
                            ),
                          );
                          nameController.clear();
                          qtyController.clear();
                          priceController.clear();
                        });
                      },
                      child: const Text(
                        '+ Tambah ke Daftar',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13.0,
                          fontWeight: FontWeight.w700,
                          color: AppColors.olive,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16.0),

                  // Daftar bahan yang sudah ditambahkan
                  if (tempIngredients.isNotEmpty) ...[
                    const Text('Bahan Terdaftar:', style: AppText.formLabel),
                    const SizedBox(height: 8.0),
                    ...tempIngredients.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final ing = entry.value;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6.0),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 8.0,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${ing.name} (${ing.qty} ${ing.unit ?? ''})',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.olive,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setSheetState(() {
                                  tempIngredients.removeAt(idx);
                                });
                              },
                              child: const Icon(
                                LucideIcons.trash2,
                                size: 16.0,
                                color: AppColors.maroon,
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
                    onPressed: () {
                      setState(() {
                        _ingredients.clear();
                        _ingredients.addAll(tempIngredients);
                        if (_ingredients.isNotEmpty) {
                          _ingredientsError = null;
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

  void _openCookingInstructionsSheet() {
    final tempSteps = List<RecipeStep>.from(_steps);

    showAppBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
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
                      Text('Langkah Memasak', style: AppText.sectionTitle),
                      IconButton(
                        icon: const Icon(LucideIcons.x, color: AppColors.olive),
                        onPressed: () => Navigator.of(sheetContext).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12.0),

                  // Daftar langkah
                  if (tempSteps.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Center(
                        child: Text(
                          'Belum ada langkah. Tekan "+ Tambah Langkah" di bawah.',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12.0,
                            color: AppColors.sage,
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
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 24.0,
                                  height: 24.0,
                                  decoration: const BoxDecoration(
                                    color: AppColors.amber,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${idx + 1}',
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 12.0,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.olive,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8.0),
                                Expanded(
                                  child: Text(
                                    step.title.isNotEmpty
                                        ? step.title
                                        : 'Langkah ${idx + 1}',
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 13.0,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.olive,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    setSheetState(() {
                                      tempSteps.removeAt(idx);
                                    });
                                  },
                                  child: const Icon(
                                    LucideIcons.trash2,
                                    size: 16.0,
                                    color: AppColors.maroon,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6.0),
                            Text(
                              step.description,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12.0,
                                color: AppColors.sage,
                              ),
                            ),
                            if (step.durationMin != null &&
                                step.durationMin! > 0) ...[
                              const SizedBox(height: 4.0),
                              Text(
                                '⏱ ${step.durationMin} menit',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11.0,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.amber,
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
                      foregroundColor: AppColors.olive,
                      side: const BorderSide(color: AppColors.olive),
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
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final durationCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      barrierColor: AppColors.dialogBarrier,
      builder: (dlgContext) {
        return Dialog(
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.cardLarge,
          ),
          backgroundColor: AppColors.white,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Detail Langkah', style: AppText.sectionTitle),
                  const SizedBox(height: 12.0),
                  const Text('Judul Langkah', style: AppText.formLabel),
                  const SizedBox(height: 4.0),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    decoration: BoxDecoration(
                      color: AppColors.chipGray,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: TextField(
                      controller: titleCtrl,
                      style: AppText.body,
                      decoration: const InputDecoration(
                        hintText: 'Mis. Tumis Bawang',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  const Text('Deskripsi', style: AppText.formLabel),
                  const SizedBox(height: 4.0),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 8.0,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.chipGray,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: TextField(
                      controller: descCtrl,
                      maxLines: 3,
                      style: AppText.body,
                      decoration: const InputDecoration(
                        hintText: 'Tuliskan detail langkah...',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  const Text(
                    'Durasi Menit (Opsional)',
                    style: AppText.formLabel,
                  ),
                  const SizedBox(height: 4.0),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    decoration: BoxDecoration(
                      color: AppColors.chipGray,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: TextField(
                      controller: durationCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: AppText.body,
                      decoration: const InputDecoration(
                        hintText: '0',
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
                        onPressed: () => Navigator.of(dlgContext).pop(),
                        child: const Text(
                          'Batal',
                          style: TextStyle(color: AppColors.sage),
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.olive,
                          foregroundColor: AppColors.white,
                        ),
                        onPressed: () {
                          final title = titleCtrl.text.trim();
                          final desc = descCtrl.text.trim();
                          if (title.isEmpty && desc.isEmpty) return;

                          final dur = int.tryParse(durationCtrl.text.trim());
                          onAdded(
                            RecipeStep(
                              id: 'step-${DateTime.now().millisecondsSinceEpoch}',
                              title: title.isNotEmpty ? title : 'Langkah',
                              description: desc,
                              durationMin: dur,
                            ),
                          );
                          Navigator.of(dlgContext).pop();
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

  @override
  Widget build(BuildContext context) {
    final scrollBottomPadding =
        StickyBottomBar.scrollPadding(context, barHeight: 55.0, extra: 24.0) +
        MediaQuery.viewInsetsOf(context).bottom;

    return PageWithHeader(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Konten Scrollable
          Positioned.fill(
            child: CustomScrollView(
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
                              child: const Icon(
                                LucideIcons.chevronLeft,
                                size: 24.0,
                                color: AppColors.olive,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4.0),
                        const Text(
                          'Create Recipe',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 20.0,
                            fontWeight: FontWeight.w700,
                            color: AppColors.olive,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. Form Input
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // "Recipe Title"
                        const Text(
                          'Recipe Title',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14.0,
                            fontWeight: FontWeight.w700,
                            color: AppColors.olive,
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        Container(
                          height: 48.0,
                          padding: const EdgeInsets.symmetric(horizontal: 14.0),
                          decoration: BoxDecoration(
                            color: AppColors.fieldGray, // #D6D6D6 persis desain
                            borderRadius: BorderRadius.circular(10.0),
                            boxShadow: AppShadows.card,
                          ),
                          alignment: Alignment.centerLeft,
                          child: TextField(
                            controller: _titleController,
                            focusNode: _titleFocusNode,
                            onTapOutside: (_) =>
                                FocusManager.instance.primaryFocus?.unfocus(),
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14.0,
                              color: AppColors.textBody,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Type your recipe name here',
                              hintStyle: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13.0,
                                color: AppColors.sage,
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
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11.0,
                              color: AppColors.maroon,
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
                                  const Text(
                                    'Add Cover Image',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 14.0,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.olive,
                                    ),
                                  ),
                                  const SizedBox(height: 8.0),
                                  GestureDetector(
                                    onTap: _pickCoverImage,
                                    child: Container(
                                      height: 104.0,
                                      decoration: BoxDecoration(
                                        color: AppColors.fieldGray,
                                        borderRadius: BorderRadius.circular(
                                          10.0,
                                        ),
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
                                                    padding:
                                                        const EdgeInsets.all(
                                                          4.0,
                                                        ),
                                                    decoration:
                                                        const BoxDecoration(
                                                          color:
                                                              AppColors.olive,
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                    child: const Icon(
                                                      LucideIcons.edit2,
                                                      size: 12.0,
                                                      color: AppColors.white,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            )
                                          : const Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  LucideIcons.camera,
                                                  size: 26.0,
                                                  color: AppColors.sage,
                                                ),
                                                SizedBox(height: 6.0),
                                                Text(
                                                  'Add Cover Image',
                                                  style: TextStyle(
                                                    fontFamily: 'Poppins',
                                                    fontSize: 11.0,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.olive,
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
                                  const Text(
                                    'Ingredients',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 14.0,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.olive,
                                    ),
                                  ),
                                  const SizedBox(height: 8.0),
                                  GestureDetector(
                                    onTap: _openIngredientsSheet,
                                    child: Container(
                                      height: 104.0,
                                      decoration: BoxDecoration(
                                        color: AppColors.fieldGray,
                                        borderRadius: BorderRadius.circular(
                                          10.0,
                                        ),
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
                                                  decoration:
                                                      const BoxDecoration(
                                                        color: AppColors.olive,
                                                        shape: BoxShape.circle,
                                                      ),
                                                  alignment: Alignment.center,
                                                  child: const Icon(
                                                    LucideIcons.check,
                                                    size: 18.0,
                                                    color: AppColors.white,
                                                  ),
                                                ),
                                                const SizedBox(height: 6.0),
                                                Text(
                                                  '${_ingredients.length} ingredients',
                                                  style: const TextStyle(
                                                    fontFamily: 'Poppins',
                                                    fontSize: 12.0,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.olive,
                                                  ),
                                                ),
                                              ],
                                            )
                                          : const Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                CircleAvatar(
                                                  radius: 14.0,
                                                  backgroundColor:
                                                      AppColors.sage,
                                                  child: Icon(
                                                    LucideIcons.plus,
                                                    size: 16.0,
                                                    color: AppColors.white,
                                                  ),
                                                ),
                                                SizedBox(height: 6.0),
                                                Text(
                                                  'Add ingredients to recipe',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontFamily: 'Poppins',
                                                    fontSize: 11.0,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.olive,
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
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 11.0,
                                        color: AppColors.maroon,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18.0),

                        // "Serving Size"
                        const Text(
                          'Serving Size',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14.0,
                            fontWeight: FontWeight.w700,
                            color: AppColors.olive,
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        GestureDetector(
                          onTap: _openServingSizePicker,
                          child: Container(
                            height: 44.0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14.0,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.fieldGray,
                              borderRadius: BorderRadius.circular(10.0),
                              boxShadow: AppShadows.card,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  LucideIcons.users,
                                  size: 18.0,
                                  color: AppColors.olive,
                                ),
                                const SizedBox(width: 8.0),
                                Text(
                                  '$_servingSize Porsi',
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13.0,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.olive,
                                  ),
                                ),
                                const Spacer(),
                                const Icon(
                                  LucideIcons.chevronDown,
                                  size: 16.0,
                                  color: AppColors.olive,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 18.0),

                        // "Cooking Instructions"
                        const Text(
                          'Cooking Instructions',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14.0,
                            fontWeight: FontWeight.w700,
                            color: AppColors.olive,
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
                              color: AppColors.fieldGray,
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
                                        decoration: const BoxDecoration(
                                          color: AppColors.olive,
                                          shape: BoxShape.circle,
                                        ),
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          LucideIcons.check,
                                          size: 16.0,
                                          color: AppColors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 10.0),
                                      Text(
                                        '${_steps.length} steps configured',
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 13.0,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.olive,
                                        ),
                                      ),
                                      const Spacer(),
                                      const Icon(
                                        LucideIcons.edit2,
                                        size: 16.0,
                                        color: AppColors.olive,
                                      ),
                                    ],
                                  )
                                : const Text(
                                    'Add one or multiple steps',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 13.0,
                                      color: AppColors.sage,
                                    ),
                                  ),
                          ),
                        ),
                        if (_stepsError != null) ...[
                          const SizedBox(height: 4.0),
                          Text(
                            _stepsError!,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11.0,
                              color: AppColors.maroon,
                            ),
                          ),
                        ],

                        const SizedBox(height: 36.0),
                      ],
                    ),
                  ),
                ),

                // Padding Bawah agar tidak tertutup tombol DONE (+ keyboard)
                SliverToBoxAdapter(
                  child: SizedBox(height: scrollBottomPadding),
                ),
              ],
            ),
          ),

          // Tombol Olive Pill "DONE" Sticky di Bawah Layar
          StickyBottomBar(
            child: SizedBox(
              width: 362.0,
              height: 55.0,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.olive,
                  foregroundColor: AppColors.white,
                  elevation: 6.0,
                  shadowColor: AppColors.olive.withValues(alpha: 0.35),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.pill,
                  ),
                ),
                onPressed: _handleSubmit,
                child: const Text(
                  'DONE',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16.0,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: AppColors.white,
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
