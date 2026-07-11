enum AttendanceVerificationStatus {
  idle,
  scanningBluetooth,
  bluetoothFound,
  bluetoothNotFound,
  locationMismatch,
  verified,
  failed,
}

class StudentScanResult {
  final AttendanceVerificationStatus status;
  final String message;
  final bool isSuccess;

  const StudentScanResult({
    required this.status,
    required this.message,
    required this.isSuccess,
  });
}

class DecodedPayload {
  final String courseId;
  final String subjectName;
  final String group;
  final String teacherId;
  final int timestamp;
  final double latitude;
  final double longitude;
  final double locationAccuracy;
  final String btDeviceName;

  DecodedPayload({
    required this.courseId,
    required this.subjectName,
    required this.group,
    required this.teacherId,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.locationAccuracy,
    required this.btDeviceName,
  });

  factory DecodedPayload.fromMap(Map<String, dynamic> map) => DecodedPayload(
        courseId: map['course_id'] as String? ?? '',
        subjectName: map['subject'] as String? ?? '',
        group: map['group'] as String? ?? '',
        teacherId: map['teacher_id'] as String? ?? '',
        timestamp: map['time'] as int? ?? 0,
        latitude: (map['lat'] as num?)?.toDouble() ?? 0.0,
        longitude: (map['lng'] as num?)?.toDouble() ?? 0.0,
        locationAccuracy: (map['acc'] as num?)?.toDouble() ?? 0.0,
        btDeviceName: map['bt'] as String? ?? '',
      );
}
