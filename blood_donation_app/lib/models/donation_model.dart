class DonationModel {
  final String? id;
  final String userId;
  final String bloodGroup;
  final int units;
  final DateTime date;
  final String location;
  final String status;
  final String? requestId; // Link to the blood request
  final String patientName; // Patient who received the blood
  final String hospital; // Hospital where donation was made
  final String requesterName;

  DonationModel({
    this.id,
    required this.userId,
    required this.bloodGroup,
    required this.units,
    required this.date,
    required this.location,
    required this.status,
    this.requestId,
    required this.patientName,
    required this.hospital,
    required this.requesterName,
  });

  factory DonationModel.fromJson(Map<String, dynamic> json) {
    return DonationModel(
      id: json['id'],
      userId: json['userId'] ?? '',
      bloodGroup: json['bloodGroup'] ?? '',
      units: json['units'] ?? 1,
      date: json['date'] is DateTime
          ? json['date']
          : DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      location: json['location'] ?? '',
      status: json['status'] ?? 'Completed',
      requestId: json['requestId'],
      patientName: json['patientName'] ?? '',
      hospital: json['hospital'] ?? '',
      requesterName: json['requesterName'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'bloodGroup': bloodGroup,
      'units': units,
      'date': date.toIso8601String(),
      'location': location,
      'status': status,
      'requestId': requestId,
      'patientName': patientName,
      'hospital': hospital,
      'requesterName': requesterName,
    };
  }

  DonationModel copyWith({
    String? id,
    String? userId,
    String? bloodGroup,
    int? units,
    DateTime? date,
    String? location,
    String? status,
    String? requestId,
    String? patientName,
    String? hospital,
    String? requesterName,
  }) {
    return DonationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      units: units ?? this.units,
      date: date ?? this.date,
      location: location ?? this.location,
      status: status ?? this.status,
      requestId: requestId ?? this.requestId,
      patientName: patientName ?? this.patientName,
      hospital: hospital ?? this.hospital,
      requesterName: requesterName ?? this.requesterName,
    );
  }
}
