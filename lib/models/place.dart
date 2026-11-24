class Place {
  final String id;
  final String name;
  final String cuisine;
  final String type; // Amenity type: restaurant, cafe, fast_food, food_court
  final String? openingHours;
  final Map<String, dynamic>? tags;
  final int priceMin;
  final int priceMax;
  final int distanceM;
  final int walkMin;
  final bool open;
  final double x; // Posisi di peta ilustrasi (0–100)
  final double y;
  final double? lat;
  final double? lng;
  final bool isUnknownHours;

  double get latitude => lat ?? (-7.7653 + (y - 50.0) * 0.00015);
  double get longitude => lng ?? (110.3789 + (x - 50.0) * 0.00015);

  const Place({
    required this.id,
    required this.name,
    required this.cuisine,
    this.type = 'restaurant',
    this.openingHours,
    this.tags,
    required this.priceMin,
    required this.priceMax,
    required this.distanceM,
    required this.walkMin,
    required this.open,
    required this.x,
    required this.y,
    this.lat,
    this.lng,
    this.isUnknownHours = false,
  });

  Place copyWith({
    String? id,
    String? name,
    String? cuisine,
    String? type,
    String? openingHours,
    Map<String, dynamic>? tags,
    int? priceMin,
    int? priceMax,
    int? distanceM,
    int? walkMin,
    bool? open,
    double? x,
    double? y,
    double? lat,
    double? lng,
    bool? isUnknownHours,
  }) {
    return Place(
      id: id ?? this.id,
      name: name ?? this.name,
      cuisine: cuisine ?? this.cuisine,
      type: type ?? this.type,
      openingHours: openingHours ?? this.openingHours,
      tags: tags ?? this.tags,
      priceMin: priceMin ?? this.priceMin,
      priceMax: priceMax ?? this.priceMax,
      distanceM: distanceM ?? this.distanceM,
      walkMin: walkMin ?? this.walkMin,
      open: open ?? this.open,
      x: x ?? this.x,
      y: y ?? this.y,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      isUnknownHours: isUnknownHours ?? this.isUnknownHours,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'cuisine': cuisine,
      'type': type,
      if (openingHours != null) 'openingHours': openingHours,
      if (tags != null) 'tags': tags,
      'priceMin': priceMin,
      'priceMax': priceMax,
      'distanceM': distanceM,
      'walkMin': walkMin,
      'open': open,
      'x': x,
      'y': y,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      'isUnknownHours': isUnknownHours,
    };
  }

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      cuisine: json['cuisine'] as String? ?? '',
      type: json['type'] as String? ?? 'restaurant',
      openingHours: json['openingHours'] as String?,
      tags: json['tags'] != null
          ? Map<String, dynamic>.from(json['tags'] as Map)
          : null,
      priceMin: (json['priceMin'] as num?)?.toInt() ?? 0,
      priceMax: (json['priceMax'] as num?)?.toInt() ?? 0,
      distanceM: (json['distanceM'] as num?)?.toInt() ?? 0,
      walkMin: (json['walkMin'] as num?)?.toInt() ?? 0,
      open: json['open'] as bool? ?? false,
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      isUnknownHours: json['isUnknownHours'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Place && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
