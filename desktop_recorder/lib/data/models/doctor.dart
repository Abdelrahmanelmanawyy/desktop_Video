/// Firestore model for Doctor (Windows/kiosk context).
/// Maps to Firestore collection: `doctors`
class Doctor {
  const Doctor({
    required this.doctorId,
    this.name = '',
  });

  final String doctorId;
  final String name;

  /// Create from Firestore document map.
  factory Doctor.fromFirestore(Map<String, dynamic> data) {
    return Doctor(
      doctorId: data['doctor_id'] as String? ?? '',
      name: data['name'] as String? ?? '',
    );
  }

  /// Convert to Firestore document map.
  Map<String, dynamic> toFirestore() {
    return {
      'doctor_id': doctorId,
      'name': name,
    };
  }
}
