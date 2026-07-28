import 'dart:convert';

class BadgeTemplate {
  final String imagePath;
  final double widthMm;
  final double heightMm;
  final double qrX;      // normalized X offset (0.0 to 1.0)
  final double qrY;      // normalized Y offset (0.0 to 1.0)
  final double qrSize;   // normalized QR size (0.0 to 1.0) relative to card width

  BadgeTemplate({
    required this.imagePath,
    required this.widthMm,
    required this.heightMm,
    required this.qrX,
    required this.qrY,
    required this.qrSize,
  });

  Map<String, dynamic> toMap() {
    return {
      'imagePath': imagePath,
      'widthMm': widthMm,
      'heightMm': heightMm,
      'qrX': qrX,
      'qrY': qrY,
      'qrSize': qrSize,
    };
  }

  factory BadgeTemplate.fromMap(Map<String, dynamic> map) {
    return BadgeTemplate(
      imagePath: map['imagePath'] as String,
      widthMm: (map['widthMm'] as num).toDouble(),
      heightMm: (map['heightMm'] as num).toDouble(),
      qrX: (map['qrX'] as num).toDouble(),
      qrY: (map['qrY'] as num).toDouble(),
      qrSize: (map['qrSize'] as num).toDouble(),
    );
  }

  String toJson() => json.encode(toMap());

  factory BadgeTemplate.fromJson(String source) => 
      BadgeTemplate.fromMap(json.decode(source) as Map<String, dynamic>);
}
