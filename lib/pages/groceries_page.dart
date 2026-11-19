import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../app/app_shell.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_shadows.dart';
import '../core/utils/format_rupiah.dart';
import '../models/models.dart';
import '../providers/cart_provider.dart';
import '../providers/ui_helper.dart';
import '../widgets/ui/app_checkbox.dart';
import '../widgets/ui/empty_state.dart';

/// Halaman My Groceries (/groceries) sesuai PRD §6.11, §7.6 dan design/Daftar Belanja.jpg:
/// - Tanpa header global dan tanpa bottom nav.
/// - Top bar: tombol panah kiri + "My Groceries" (24/700 olive).
/// - Add bar: ikon cart chipGray, placeholder "+ Tambah bahan belanja…", input angka "Rp", tombol plus olive 36x36.
///   Item baru masuk grup "Belanjaan Kamu Nich" (item custom).
/// - Grup kartu per menu: header nama menu (15/700) + "Hapus menu" (maroon 11/600),
///   baris item (checkbox kotak 22, nama 14/600 + takaran 11 sage, harga 13/600).
///   Item dicentang: nama dicoret & warna sage, checkbox olive.
///   Footer kanan-bawah: "Subtotal Rp X" (10 sage), tidak tampil pada grup custom.
/// - Catatan kecil: "Harga estimasi, ketuk item untuk mengubah" (tap harga untuk edit inline).
/// - Panel ringkasan sticky bawah (putih, radius atas 24, padding 24):
///   "Total estimasi (belum dibeli)" (11 sage) + total besar (24/700 olive) + tombol "Kosongkan semua" (164x44).
/// - Aturan hitung:
///   Subtotal grup = jumlah SEMUA item di grup itu.
///   Total estimasi = jumlah SEMUA item yang BELUM DICENTANG di seluruh grup.
class GroceriesPage extends ConsumerStatefulWidget {
  const GroceriesPage({super.key});

  @override
  ConsumerState<GroceriesPage> createState() => _GroceriesPageState();
}

class _GroceriesPageState extends ConsumerState<GroceriesPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _inlinePriceController = TextEditingController();

  String? _editingItemId;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _inlinePriceController.dispose();
    super.dispose();
  }

  Future<void> _handleAddCustomItem() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final price = int.tryParse(_priceController.text.trim()) ?? 0;

    FocusScope.of(context).unfocus();
    _nameController.clear();
    _priceController.clear();

    await ref
        .read(cartProvider.notifier)
        .addCustomItem(name: name, qty: '1 pcs', price: price);

    if (mounted) {
      showAppToast(context, 'Bahan belanjaan ditambahkan');
    }
  }

  Future<void> _handleRemoveGroup(CartGroup group) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Hapus menu dari keranjang?',
      message:
          'Apakah kamu yakin ingin menghapus "${group.name}" beserta bahannya?',
      confirmLabel: 'Hapus',
      cancelLabel: 'Batal',
      isDanger: true,
    );

    if (confirmed && mounted) {
      await ref.read(cartProvider.notifier).removeGroup(group.id);
      if (mounted) {
        showAppToast(context, 'Menu dihapus dari keranjang');
      }
    }
  }

  Future<void> _handleClearAll() async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Kosongkan keranjang?',
      message: 'Semua bahan belanjaan akan dihapus dari daftar.',
      confirmLabel: 'Kosongkan',
      cancelLabel: 'Batal',
      isDanger: true,
    );

    if (confirmed && mounted) {
      await ref.read(cartProvider.notifier).clearAll();
      if (mounted) {
        showAppToast(context, 'Keranjang belanja dikosongkan');
      }
    }
  }

  void _saveInlinePrice(String groupId, String itemId) {
    final newPrice = int.tryParse(_inlinePriceController.text.trim());
    if (newPrice != null && newPrice >= 0) {
      ref.read(cartProvider.notifier).updatePrice(groupId, itemId, newPrice);
    }
    setState(() {
      _editingItemId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cartGroups = ref.watch(cartProvider);
    final totalUnchecked = ref.watch(cartTotalUncheckedProvider);

    final topInset = AppShell.topChrome(context);
    final bottomInset = math.max(MediaQuery.paddingOf(context).bottom, 24.0);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // Konten Scrollable
          Positioned.fill(
            child: CustomScrollView(
              key: const PageStorageKey<String>('groceries_scroll_view'),
              slivers: [
                // 1. Top Bar: Panah Kiri + "My Groceries"
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 20.0,
                      right: 20.0,
                      top: topInset + 16.0,
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
                              width: 40.0,
                              height: 40.0,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.centerLeft,
                              child: const Icon(
                                LucideIcons.arrowLeft,
                                size: 24.0,
                                color: AppColors.olive,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        const Text(
                          'My Groceries',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 24.0,
                            fontWeight: FontWeight.w700,
                            color: AppColors.olive,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. Add Bar (Kartu putih radius 14, tinggi ≈ 52)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Container(
                      height: 52.0,
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(14.0),
                        border: Border.all(color: AppColors.border),
                        boxShadow: AppShadows.card,
                      ),
                      child: Row(
                        children: [
                          // Lingkaran chipGray berisi ikon cart
                          Container(
                            width: 34.0,
                            height: 34.0,
                            decoration: const BoxDecoration(
                              color: AppColors.chipGray,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              LucideIcons.shoppingBag,
                              size: 16.0,
                              color: AppColors.olive,
                            ),
                          ),
                          const SizedBox(width: 10.0),

                          // Input teks placeholder "+ Tambah bahan belanja…"
                          Expanded(
                            child: TextField(
                              controller: _nameController,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13.0,
                                color: AppColors.textBody,
                              ),
                              decoration: const InputDecoration(
                                hintText: '+ Tambah bahan belanja…',
                                hintStyle: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13.0,
                                  color: AppColors.sage,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onSubmitted: (_) => _handleAddCustomItem(),
                            ),
                          ),

                          const SizedBox(width: 8.0),

                          // Pill harga chipGray "Rp" (input angka)
                          Container(
                            height: 34.0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.chipGray,
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Rp ',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11.0,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.olive,
                                  ),
                                ),
                                SizedBox(
                                  width: 58.0,
                                  child: TextField(
                                    controller: _priceController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 12.0,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.olive,
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: '0',
                                      hintStyle: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 12.0,
                                        color: AppColors.sage,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onSubmitted: (_) => _handleAddCustomItem(),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 8.0),

                          // Tombol persegi olive 36 x 36 radius 10 dengan ikon "+"
                          GestureDetector(
                            onTap: _handleAddCustomItem,
                            child: Container(
                              width: 36.0,
                              height: 36.0,
                              decoration: BoxDecoration(
                                color: AppColors.olive,
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                LucideIcons.plus,
                                size: 18.0,
                                color: AppColors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 20.0)),

                // 3. Daftar Grup Kartu Per Menu
                if (cartGroups.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 40.0),
                      child: EmptyState(
                        icon: LucideIcons.shoppingBag,
                        title: 'Keranjang Belanja Kosong',
                        subtitle: 'Bahan dari resep yang kamu tambahkan akan muncul di sini.',
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final group = cartGroups[index];
                        return _buildGroupCard(context, group);
                      }, childCount: cartGroups.length),
                    ),
                  ),

                // 4. Catatan Kecil: "Harga estimasi, ketuk item untuk mengubah"
                if (cartGroups.isNotEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 12.0,
                      ),
                      child: Center(
                        child: Text(
                          'Harga estimasi, ketuk item untuk mengubah',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11.0,
                            fontWeight: FontWeight.w400,
                            color: AppColors.sage,
                          ),
                        ),
                      ),
                    ),
                  ),

                // 5. Padding Bawah agar konten terakhir tidak tertutup sticky panel
                SliverToBoxAdapter(
                  child: SizedBox(height: bottomInset + 88.0 + 24.0),
                ),
              ],
            ),
          ),

          // 6. Panel Ringkasan Sticky Bawah (Putih, radius atas 24, padding 24)
          if (cartGroups.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24.0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowOlive,
                      offset: const Offset(0, -4),
                      blurRadius: 16.0,
                    ),
                  ],
                ),
                padding: EdgeInsets.only(
                  left: 24.0,
                  right: 24.0,
                  top: 20.0,
                  bottom: bottomInset,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Total estimasi (belum dibeli)',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11.0,
                              fontWeight: FontWeight.w400,
                              color: AppColors.sage,
                            ),
                          ),
                          const SizedBox(height: 2.0),
                          Text(
                            formatRupiah(totalUnchecked),
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 24.0,
                              fontWeight: FontWeight.w700,
                              color: AppColors.olive,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    SizedBox(
                      width: 164.0,
                      height: 44.0,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.olive,
                          foregroundColor: AppColors.white,
                          elevation: 0,
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.button,
                          ),
                        ),
                        onPressed: _handleClearAll,
                        child: const Text(
                          'Kosongkan semua',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12.0,
                            fontWeight: FontWeight.w600,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(BuildContext context, CartGroup group) {
    final subtotal = ref.watch(cartSubtotalProvider(group.id));
    final isCustomGroup = group.recipeId == null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Nama menu (15/700 olive) + "Hapus menu" (maroon 11/600)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  group.name,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15.0,
                    fontWeight: FontWeight.w700,
                    color: AppColors.olive,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _handleRemoveGroup(group),
                child: const Text(
                  'Hapus menu',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11.0,
                    fontWeight: FontWeight.w600,
                    color: AppColors.maroon,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12.0),

          // Daftar baris item
          ...group.items.asMap().entries.map((entry) {
            final item = entry.value;
            final isEditing = _editingItemId == item.id;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Checkbox kotak 22
                  AppCheckbox(
                    value: item.checked,
                    onChanged: (_) {
                      ref
                          .read(cartProvider.notifier)
                          .toggleItem(group.id, item.id);
                    },
                  ),
                  const SizedBox(width: 12.0),

                  // Nama + takaran
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _editingItemId = item.id;
                          _inlinePriceController.text = item.price.toString();
                        });
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14.0,
                              fontWeight: FontWeight.w600,
                              color: item.checked
                                  ? AppColors.sage
                                  : AppColors.textBody,
                              decoration: item.checked
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                          Text(
                            item.qty,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11.0,
                              fontWeight: FontWeight.w400,
                              color: AppColors.sage,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Harga rata kanan (tap harga untuk edit inline)
                  if (isEditing) ...[
                    Container(
                      height: 32.0,
                      padding: const EdgeInsets.symmetric(horizontal: 6.0),
                      decoration: BoxDecoration(
                        color: AppColors.summaryBg,
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: AppColors.olive),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Rp ',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11.0,
                              fontWeight: FontWeight.w600,
                              color: AppColors.olive,
                            ),
                          ),
                          SizedBox(
                            width: 60.0,
                            child: TextField(
                              controller: _inlinePriceController,
                              autofocus: true,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12.0,
                                fontWeight: FontWeight.w600,
                                color: AppColors.olive,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onSubmitted: (_) =>
                                  _saveInlinePrice(group.id, item.id),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _saveInlinePrice(group.id, item.id),
                            child: const Icon(
                              LucideIcons.check,
                              size: 16.0,
                              color: AppColors.olive,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _editingItemId = item.id;
                          _inlinePriceController.text = item.price.toString();
                        });
                      },
                      child: Text(
                        formatRupiah(item.price),
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13.0,
                          fontWeight: FontWeight.w600,
                          color: item.checked
                              ? AppColors.sage
                              : AppColors.textBody,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),

          // Footer: "Subtotal Rp X" (10 sage) — HANYA jika bukan grup custom
          if (!isCustomGroup) ...[
            const SizedBox(height: 8.0),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Subtotal ${formatRupiah(subtotal)}',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10.0,
                  fontWeight: FontWeight.w400,
                  color: AppColors.sage,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
