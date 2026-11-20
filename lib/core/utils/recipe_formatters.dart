import '../../models/models.dart';

/// Formatter dan parser cerdas untuk bahan-bahan resep (Ingredient) dan langkah memasak (RecipeStep)
/// sesuai PRD §17 (Fase G3) agar tampilan Detail Menu rapi dan bebas dari error/duplikasi API.
class RecipeFormatters {
  /// Bersihkan dan rapikan daftar bahan dari berbagai format mentah API
  static List<Ingredient> formatIngredients(List<Ingredient> rawList) {
    return rawList.map((ing) => formatSingleIngredient(ing)).toList();
  }

  /// Bersihkan dan rapikan 1 bahan masakan
  static Ingredient formatSingleIngredient(Ingredient ing) {
    String name = ing.name.trim();
    String qty = ing.qty.trim();
    String? unit = ing.unit?.trim();

    // 1. Bersihkan duplikasi kata berturut-turut (mis. "secukupnya secukupnya")
    qty = _removeDuplicateWords(qty);
    if (unit != null) {
      unit = _removeDuplicateWords(unit);
    }

    // 2. Jika nama atau qty mengandung tanda kurung instruksi yang sangat panjang, ringkas
    name = name
        .replaceAll(
          RegExp(r'\(direbus[^\)]*\)', caseSensitive: false),
          '(rebus)',
        )
        .trim();
    qty = qty
        .replaceAll(
          RegExp(r'\(direbus[^\)]*\)', caseSensitive: false),
          '(rebus)',
        )
        .trim();

    // 3. Jika unit sudah ada di dalam qty (mis. qty="15 siung", unit="siung"), bersihkan unit
    if (unit != null &&
        unit.isNotEmpty &&
        qty.toLowerCase().contains(unit.toLowerCase())) {
      unit = null;
    }

    // 4. Deteksi kata 'secukupnya'
    final hasSecukupnya =
        name.toLowerCase().contains('secukupnya') ||
        qty.toLowerCase().contains('secukupnya');

    // 5. Jika qty sama persis dengan name ATAU qty sangat panjang (duplikasi teks) ATAU kosong
    final isRawDuplicated =
        qty.toLowerCase() == name.toLowerCase() ||
        qty.toLowerCase().contains(name.toLowerCase()) ||
        name.toLowerCase().contains(qty.toLowerCase()) ||
        qty.length > 25 ||
        qty.isEmpty;

    if (isRawDuplicated) {
      // Coba ekstrak angka dan unit dari name atau qty
      final extracted = _extractQtyFromName(name) ?? _extractQtyFromName(qty);
      if (extracted != null) {
        name = extracted.cleanedName;
        qty = extracted.qty;
        unit = extracted.unit;
      } else if (hasSecukupnya) {
        name = name
            .replaceAll(RegExp(r'\bsecukupnya\b', caseSensitive: false), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        qty = 'secukupnya';
        unit = null;
      } else {
        qty = 'secukupnya';
        unit = null;
      }
    } else {
      // Periksa apakah nama bahan diawali dengan takaran (mis. "1 kg Daging Sapi", qty: "1 kg")
      final prefixMatch = RegExp(
        r'^(\d+(?:[\.,/]\d+)?\s*(?:kg|g|gram|liter|l|ml|sdm|sdt|siung|buah|batang|lembar|ekor|cm|biji|butir|ikat|bungkus|ruas)?)\s+',
        caseSensitive: false,
      ).firstMatch(name);
      if (prefixMatch != null) {
        final prefix = prefixMatch.group(1)!.trim();
        if (qty.toLowerCase().contains(prefix.toLowerCase()) ||
            prefix.toLowerCase().contains(qty.toLowerCase())) {
          name = name.substring(prefixMatch.end).trim();
        }
      }

      // Jika di dalam nama ada pola seperti "1 buah", mis. "Air perasan 1 buah Jeruk limau"
      final inlineQtyMatch = RegExp(
        r'\b(\d+(?:[\.,/]\d+)?\s*(?:buah|lembar|batang|butir|siung|sdm|sdt|ekor|kg|g|liter|cm))\b',
        caseSensitive: false,
      ).firstMatch(name);
      if (inlineQtyMatch != null &&
          (qty.toLowerCase().contains('air perasan') ||
              qty.toLowerCase() == name.toLowerCase())) {
        qty = inlineQtyMatch.group(1)!.trim();
        name = name
            .replaceAll(inlineQtyMatch.group(0)!, '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
      }
    }

    // 5. Jika qty hanya berupa angka murni tanpa unit (mis. "10" untuk "Cabai rawit")
    if (RegExp(r'^\d+$').hasMatch(qty) && (unit == null || unit.isEmpty)) {
      final nLower = name.toLowerCase();
      if (nLower.contains('cabai') ||
          nLower.contains('jeruk') ||
          nLower.contains('tomat') ||
          nLower.contains('asam')) {
        unit = 'buah';
      } else if (nLower.contains('bawang') || nLower.contains('kemiri')) {
        unit = 'siung';
      } else if (nLower.contains('serai') || nLower.contains('seledri')) {
        unit = 'batang';
      } else if (nLower.contains('daun')) {
        unit = 'lembar';
      } else if (nLower.contains('telur')) {
        unit = 'butir';
      } else if (nLower.contains('ayam') ||
          nLower.contains('bebek') ||
          nLower.contains('ikan')) {
        unit = 'ekor';
      }
    }

    // Rapikan kapitalisasi awal nama
    if (name.isNotEmpty) {
      name = name[0].toUpperCase() + name.substring(1);
    }

    // Satukan qty dan unit bila ada
    final effectiveQty = (unit != null && unit.isNotEmpty)
        ? '$qty $unit'.trim()
        : qty;

    return ing.copyWith(
      name: name,
      qty: effectiveQty,
      unit: null, // unit sudah disatukan ke qty dengan bersih
    );
  }

  /// Ekstrak takaran dari dalam nama jika nama dan takaran bercampur
  static _ExtractedQty? _extractQtyFromName(String text) {
    final match = RegExp(
      r'(\d+(?:[\.,/]\d+)?)\s*(kg|g|gram|liter|l|ml|sdm|sdt|siung|buah|batang|lembar|ekor|cm|biji|butir|ikat|bungkus|ruas|secukupnya)?',
      caseSensitive: false,
    ).firstMatch(text);

    if (match != null) {
      final fullMatch = match.group(0)!;
      final amount = match.group(1);
      final unit = match.group(2);

      String cleaned = text
          .replaceFirst(fullMatch, '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (cleaned.isEmpty) cleaned = text;

      return _ExtractedQty(
        cleanedName: cleaned,
        qty: amount ?? '1',
        unit: unit,
      );
    }
    return null;
  }

  /// Format dan pecah langkah-langkah memasak agar memiliki judul deskriptif
  static List<RecipeStep> formatSteps(
    List<RecipeStep> rawSteps, {
    String? rawContent,
  }) {
    List<RecipeStep> steps = List.from(rawSteps);

    // 1. Jika langkah hanya 1 atau kosong, tetapi ada blok teks panjang
    if ((steps.length <= 1) &&
        rawContent != null &&
        rawContent.trim().isNotEmpty) {
      final parsed = _splitRawStepText(rawContent);
      if (parsed.isNotEmpty) {
        steps = parsed;
      }
    } else if (steps.length == 1 &&
        steps.first.description.length > 120 &&
        steps.first.description.contains('\n')) {
      final parsed = _splitRawStepText(steps.first.description);
      if (parsed.isNotEmpty) {
        steps = parsed;
      }
    }

    // 2. Beri judul bermakna untuk setiap langkah
    final result = <RecipeStep>[];
    for (int i = 0; i < steps.length; i++) {
      final step = steps[i];
      final title = _generateMeaningfulStepTitle(
        step.title,
        step.description,
        i + 1,
        steps.length,
      );
      result.add(step.copyWith(title: title));
    }
    return result;
  }

  /// Memecah teks blok langkah menjadi daftar RecipeStep
  static List<RecipeStep> _splitRawStepText(String raw) {
    final lines = raw
        .split(RegExp(r'(?:\r?\n)+|\b(?=\d+\.\s)'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && l.length > 5)
        .toList();

    final result = <RecipeStep>[];
    int idx = 1;
    for (final line in lines) {
      // Hapus prefix nomor seperti "1. " atau "Langkah 1: "
      final cleanedDesc = line
          .replaceFirst(
            RegExp(
              r'^(?:\d+[\.\)]|\bLangkah\s+\d+:?)\s*',
              caseSensitive: false,
            ),
            '',
          )
          .trim();
      if (cleanedDesc.isNotEmpty) {
        result.add(
          RecipeStep(
            id: 'step-$idx',
            title: 'Langkah $idx',
            description: cleanedDesc,
          ),
        );
        idx++;
      }
    }
    return result;
  }

  /// Menghasilkan judul langkah yang bermakna sesuai gambar contoh benar
  static String _generateMeaningfulStepTitle(
    String rawTitle,
    String description,
    int stepNum,
    int totalSteps,
  ) {
    final trimmedTitle = rawTitle.trim();
    // Jika sudah memiliki judul bermakna (bukan generic "Langkah N" atau "Step N")
    if (trimmedTitle.isNotEmpty &&
        !RegExp(
          r'^(?:langkah|step)\s*\d*$',
          caseSensitive: false,
        ).hasMatch(trimmedTitle)) {
      return trimmedTitle;
    }

    final dLower = description.toLowerCase();

    // Deteksi kata kunci kuliner khas Nusantara
    if (dLower.contains('sangrai') ||
        dLower.contains('menyangrai') ||
        dLower.contains('sangray')) {
      return 'Menyangrai Bumbu';
    }
    if (dLower.contains('masukkan daging') ||
        dLower.contains('masukan daging') ||
        dLower.contains('daging sapi') ||
        dLower.contains('daging kambing')) {
      return 'Memasukkan Daging';
    }
    if (dLower.contains('masukkan ayam') ||
        dLower.contains('masukan ayam') ||
        dLower.contains('daging ayam')) {
      return 'Memasukkan Ayam';
    }
    if (dLower.contains('slow cook') ||
        dLower.contains('api kecil') ||
        dLower.contains('mengecilkan api') ||
        dLower.contains('kuah menyusut') ||
        dLower.contains('berjam-jam')) {
      return 'Proses Slow Cooking';
    }
    if (dLower.contains('tumis') ||
        dLower.contains('menumis') ||
        dLower.contains('harum')) {
      return 'Menumis Bumbu';
    }
    if (dLower.contains('haluskan') ||
        dLower.contains('menghaluskan') ||
        dLower.contains('blender') ||
        dLower.contains('ulek') ||
        dLower.contains('giling')) {
      return 'Menghaluskan Bumbu';
    }
    if (dLower.contains('rebus') ||
        dLower.contains('merebus') ||
        dLower.contains('didih')) {
      return 'Merebus Bahan';
    }
    if (dLower.contains('bakar') ||
        dLower.contains('panggang') ||
        dLower.contains('bara api')) {
      return 'Membakar / Memanggang';
    }
    if (dLower.contains('marinasi') ||
        dLower.contains('lumuri') ||
        dLower.contains('rendam')) {
      return 'Memarinasi Bahan';
    }
    if (dLower.contains('goreng') || dLower.contains('menggoreng')) {
      return 'Menggoreng Bahan';
    }
    if (stepNum == totalSteps ||
        dLower.contains('angkat') ||
        dLower.contains('sajikan') ||
        dLower.contains('tiriskan') ||
        dLower.contains('siap dinikmati')) {
      return 'Penyelesaian';
    }
    if (stepNum == 1) {
      return 'Persiapan Bahan';
    }

    // Fallback cerdas: Ambil 2-3 kata pertama kalimat instruksi
    final words = description
        .replaceAll(RegExp(r'^[^\w]+'), '')
        .split(RegExp(r'\s+'))
        .take(3)
        .join(' ');
    if (words.length > 3) {
      return words[0].toUpperCase() + words.substring(1);
    }

    return 'Langkah $stepNum';
  }

  static String _removeDuplicateWords(String text) {
    final words = text.split(RegExp(r'\s+'));
    final result = <String>[];
    for (final w in words) {
      if (result.isEmpty || result.last.toLowerCase() != w.toLowerCase()) {
        result.add(w);
      }
    }
    return result.join(' ');
  }
}

class _ExtractedQty {
  final String cleanedName;
  final String qty;
  final String? unit;

  _ExtractedQty({required this.cleanedName, required this.qty, this.unit});
}
