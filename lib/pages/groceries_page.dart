import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../app/app_shell.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_shadows.dart';
import '../core/utils/format_rupiah.dart';
import '../models/models.dart';
import '../providers/cart_provider.dart';
import '../providers/ui_helper.dart';
import '../widgets/grocery_group_header.dart';
import '../widgets/ui/app_checkbox.dart';
import '../widgets/ui/empty_state.dart';
import '../widgets/ui/sticky_bottom_bar.dart';

/// Halaman My Groceries (/groceries) sesuai PRD §6.11, §15.7, §15.8, §16 dan design/Daftar Belanja.jpg:
/// - Tanpa header global dan tanpa bottom nav.
/// - Top bar: tombol panah kiri + "My Groceries" (24/700 textStrong).
/// - Add bar: ikon cart surfaceAlt, placeholder "+ Tambah bahan belanja…", input angka "Rp", tombol plus actionBg 36x36.
///   Item baru masuk grup "Belanjaan Kamu Nich" (item custom).
/// - K1 Urutan: grup resep diurutkan descending (terbaru di atas). Item di custom group juga terbaru di atas.
/// - K2 Kartu pin: grup custom ("Belanjaan Kamu Nich") SELALU di paling atas, selalu tampil walau kosong.
///   Background accentSoft, border 1px amber @ 40%, ikon pin kecil di samping judul.
///   Teks textStrong, takaran accentSoftTextAlt, checkbox actionBg/accent. Tanpa tombol "Hapus menu" dan tanpa subtotal.
///   Hapus item per bahan lewat swipe ke kiri (Dismissible endToStart latar danger + trash onDanger) + Semantics "Hapus".
/// - Grup kartu per menu: header nama menu (15/700) + "Hapus menu" (danger 11/600),
///   baris item (checkbox kotak 22, nama 14/600 + takaran 11 sage, harga 13/600).
///   Footer kanan-bawah: "Subtotal Rp X" (10 sage).
/// - Catatan kecil: "Harga estimasi, ketuk item untuk mengubah" (tap harga untuk edit inline).
/// - Panel ringkasan sticky bawah (surface, radius atas 24, padding 24):
///   "Total estimasi (belum dibeli)" (11 textSecondary) + total besar (24/700 textStrong) + tombol "Kosongkan semua" (164x44).
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
    final palette = context.palette;
    final displayGroups = ref.watch(displayCartGroupsProvider);
    final totalUnchecked = ref.watch(cartTotalUncheckedProvider);
    final totalItemsCount = ref.watch(cartCountProvider);

    final topInset = AppShell.topChrome(context);
    final bottomInset = bottomGap(context);
    final hasItems = totalItemsCount > 0;
    final scrollBottomPadding =
        (hasItems ? (bottomInset + 88.0 + 24.0) : 40.0) +
        MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: palette.bg,
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
                              child: Icon(
                                LucideIcons.arrowLeft,
                                size: 24.0,
                                color: palette.textStrong,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: Text(
                            'My Groceries',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 24.0,
                              fontWeight: FontWeight.w700,
                              color: palette.textStrong,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. Add Bar (Kartu surface radius 14, tinggi ≈ 52)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Container(
                      height: 52.0,
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(14.0),
                        border: Border.all(color: palette.border),
                        boxShadow: AppShadows.card,
                      ),
                      child: Row(
                        children: [
                          // Lingkaran surfaceAlt berisi ikon cart
                          Container(
                            width: 34.0,
                            height: 34.0,
                            decoration: BoxDecoration(
                              color: palette.surfaceAlt,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              LucideIcons.shoppingBag,
                              size: 16.0,
                              color: palette.textStrong,
                            ),
                          ),
                          const SizedBox(width: 10.0),

                          // Input teks placeholder "+ Tambah bahan belanja…"
                          Expanded(
                            child: TextField(
                              controller: _nameController,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13.0,
                                color: palette.textBody,
                              ),
                              decoration: InputDecoration(
                                hintText: '+ Tambah bahan belanja…',
                                hintStyle: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13.0,
                                  color: palette.textSecondary,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onSubmitted: (_) => _handleAddCustomItem(),
                            ),
                          ),

                          const SizedBox(width: 8.0),

                          // Pill harga surfaceAlt "Rp" (input angka)
                          Container(
                            height: 34.0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                            ),
                            decoration: BoxDecoration(
                              color: palette.surfaceAlt,
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Rp ',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11.0,
                                    fontWeight: FontWeight.w600,
                                    color: palette.textStrong,
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
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 12.0,
                                      fontWeight: FontWeight.w600,
                                      color: palette.textStrong,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: '0',
                                      hintStyle: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 12.0,
                                        color: palette.textSecondary,
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

                          // Tombol persegi actionBg 36 x 36 radius 10 dengan ikon "+"
                          GestureDetector(
                            onTap: _handleAddCustomItem,
                            child: Container(
                              width: 36.0,
                              height: 36.0,
                              decoration: BoxDecoration(
                                color: palette.actionBg,
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                LucideIcons.plus,
                                size: 18.0,
                                color: palette.onAction,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 20.0)),

                // 3. Daftar Grup Kartu
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final group = displayGroups[index];
                      return _buildGroupCard(context, group);
                    }, childCount: displayGroups.length),
                  ),
                ),

                // EmptyState ditampilkan jika seluruh item keranjang kosong
                if (displayGroups.every((g) => g.items.isEmpty))
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 24.0),
                      child: EmptyState(
                        icon: LucideIcons.shoppingBag,
                        title: 'Keranjang Belanja Kosong',
                        subtitle: 'Bahan dari resep yang kamu tambahkan akan muncul di sini.',
                      ),
                    ),
                  ),

                // 4. Catatan Kecil: "Harga estimasi, ketuk item untuk mengubah"
                if (hasItems)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
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
                            color: palette.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),

                // 5. Padding Bawah agar konten terakhir tidak tertutup sticky panel (+ keyboard)
                SliverToBoxAdapter(
                  child: SizedBox(height: scrollBottomPadding),
                ),
              ],
            ),
          ),

          // 6. Panel Ringkasan Sticky Bawah (surface, radius atas 24, padding 24)
          if (hasItems)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24.0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: palette.shadowColor,
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
                          Text(
                            'Total estimasi (belum dibeli)',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11.0,
                              fontWeight: FontWeight.w400,
                              color: palette.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2.0),
                          Text(
                            formatRupiah(totalUnchecked),
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 24.0,
                              fontWeight: FontWeight.w700,
                              color: palette.textStrong,
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
                          backgroundColor: palette.actionBg,
                          foregroundColor: palette.onAction,
                          elevation: 0,
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.button,
                          ),
                        ),
                        onPressed: _handleClearAll,
                        child: Text(
                          'Kosongkan semua',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12.0,
                            fontWeight: FontWeight.w600,
                            color: palette.onAction,
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
    final palette = context.palette;
    final subtotal = ref.watch(cartSubtotalProvider(group.id));
    final isCustomGroup = group.recipeId == null;

    final cardBg = isCustomGroup ? palette.accentSoft : palette.surface;
    final cardBorder = isCustomGroup
        ? Border.all(color: palette.accent.withValues(alpha: 0.4), width: 1.0)
        : Border.all(color: palette.border);

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16.0),
        border: cardBorder,
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Nama menu (15/700) + ikon pin jika custom / "Hapus menu" (danger 11/600) jika resep
          if (isCustomGroup)
            Row(
              children: [
                Flexible(
                  child: Text(
                    group.name,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15.0,
                      fontWeight: FontWeight.w700,
                      color: palette.textStrong,
                    ),
                  ),
                ),
                const SizedBox(width: 6.0),
                Icon(LucideIcons.pin, size: 14.0, color: palette.textStrong),
              ],
            )
          else
            GroceryGroupHeader(
              title: group.name,
              onRemove: () => _handleRemoveGroup(group),
            ),

          const SizedBox(height: 12.0),

          // Teks hint jika grup custom masih kosong
          if (isCustomGroup && group.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Belum ada bahan. Tambahkan lewat kolom di atas.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.0,
                  fontWeight: FontWeight.w400,
                  color: palette.accentSoftTextAlt,
                ),
              ),
            ),

          // Daftar baris item
          ...group.items.asMap().entries.map((entry) {
            final item = entry.value;
            final isEditing = _editingItemId == item.id;

            final Widget itemRow = Padding(
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
                              color: isCustomGroup
                                  ? (item.checked
                                        ? palette.textStrong.withValues(
                                            alpha: 0.6,
                                          )
                                        : palette.textStrong)
                                  : (item.checked
                                        ? palette.textSecondary
                                        : palette.textBody),
                              decoration: item.checked
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                          Text(
                            item.qty,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11.0,
                              fontWeight: FontWeight.w400,
                              color: isCustomGroup
                                  ? palette.accentSoftTextAlt
                                  : palette.textSecondary,
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
                        color: isCustomGroup
                            ? palette.surface
                            : palette.summaryBg,
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: palette.actionBg),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Rp ',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11.0,
                              fontWeight: FontWeight.w600,
                              color: palette.textStrong,
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
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12.0,
                                fontWeight: FontWeight.w600,
                                color: palette.textStrong,
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
                            child: Icon(
                              LucideIcons.check,
                              size: 16.0,
                              color: palette.actionBg,
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
                          color: isCustomGroup
                              ? (item.checked
                                    ? palette.textStrong.withValues(alpha: 0.6)
                                    : palette.textStrong)
                              : (item.checked
                                    ? palette.textSecondary
                                    : palette.textBody),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );

            // Item di grup custom dapat di-swipe ke kiri untuk dihapus (Dismissible endToStart)
            if (isCustomGroup) {
              return Semantics(
                customSemanticsActions: {
                  const CustomSemanticsAction(label: 'Hapus'): () {
                    ref
                        .read(cartProvider.notifier)
                        .removeItem(group.id, item.id);
                    showAppToast(context, 'Bahan dihapus');
                  },
                },
                child: Dismissible(
                  key: ValueKey('dismiss-${item.id}'),
                  direction: DismissDirection.endToStart,
                  dismissThresholds: const {DismissDirection.endToStart: 0.4},
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16.0),
                    decoration: BoxDecoration(
                      color: palette.danger,
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Icon(
                      LucideIcons.trash2,
                      color: palette.onDanger,
                      size: 20.0,
                    ),
                  ),
                  secondaryBackground: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16.0),
                    decoration: BoxDecoration(
                      color: palette.danger,
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Icon(
                      LucideIcons.trash2,
                      color: palette.onDanger,
                      size: 20.0,
                    ),
                  ),
                  onDismissed: (direction) {
                    ref
                        .read(cartProvider.notifier)
                        .removeItem(group.id, item.id);
                    showAppToast(context, 'Bahan dihapus');
                  },
                  child: itemRow,
                ),
              );
            }

            return itemRow;
          }),

          // Footer: "Subtotal Rp X" (10 sage) — HANYA jika bukan grup custom
          if (!isCustomGroup) ...[
            const SizedBox(height: 8.0),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Subtotal ${formatRupiah(subtotal)}',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10.0,
                  fontWeight: FontWeight.w400,
                  color: palette.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
