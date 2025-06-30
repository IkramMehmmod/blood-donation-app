import 'package:cloud_firestore/cloud_firestore.dart';

class RequestModel {
  final String? id;
  final String requesterId;
  final String requesterName;
  final String patientName;
  final String bloodGroup;
  final int units;
  final String hospital;
  final String location;
  final String contactNumber;
  final String urgency;
  final String status;
  final DateTime createdAt;
  final DateTime requiredDate;
  final String additionalInfo;
  final List<String> responders;

  RequestModel({
    this.id,
    required this.requesterId,
    required this.requesterName,
    required this.patientName,
    required this.bloodGroup,
    required this.units,
    required this.hospital,
    required this.location,
    required this.contactNumber,
    required this.urgency,
    required this.status,
    required this.createdAt,
    required this.requiredDate,
    this.additionalInfo = '',
    this.responders = const [],
  });

  factory RequestModel.fromJson(Map<String, dynamic> json) {
    return RequestModel(
      id: json['id'],
      requesterId: json['requesterId'] ?? '',
      requesterName: json['requesterName'] ?? '',
      patientName: json['patientName'] ?? '',
      bloodGroup: json['bloodGroup'] ?? '',
      units: json['units'] ?? 0,
      hospital: json['hospital'] ?? '',
      location: json['location'] ?? '',
      contactNumber: json['contactNumber'] ?? '',
      urgency: json['urgency'] ?? 'normal',
      status: json['status'] ?? 'open',
      createdAt: _parseDateTime(json['createdAt']),
      requiredDate: _parseDateTime(json['requiredDate']),
      additionalInfo: json['additionalInfo'] ?? '',
      responders: List<String>.from(json['responders'] ?? []),
    );
  }

  // Helper method to parse different date formats
  static DateTime _parseDateTime(dynamic dateValue) {
    if (dateValue == null) return DateTime.now();

    if (dateValue is Timestamp) {
      return dateValue.toDate();
    } else if (dateValue is String) {
      try {
        return DateTime.parse(dateValue);
      } catch (e) {
        return DateTime.now();
      }
    } else if (dateValue is DateTime) {
      return dateValue;
    }

    return DateTime.now();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'requesterId': requesterId,
      'requesterName': requesterName,
      'patientName': patientName,
      'bloodGroup': bloodGroup,
      'units': units,
      'hospital': hospital,
      'location': location,
      'contactNumber': contactNumber,
      'urgency': urgency,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'requiredDate': requiredDate.toIso8601String(),
      'additionalInfo': additionalInfo,
      'responders': responders,
    };
  }

  RequestModel copyWith({
    String? id,
    String? requesterId,
    String? requesterName,
    String? patientName,
    String? bloodGroup,
    int? units,
    String? hospital,
    String? location,
    String? contactNumber,
    String? urgency,
    String? status,
    DateTime? createdAt,
    DateTime? requiredDate,
    String? additionalInfo,
    List<String>? responders,
  }) {
    return RequestModel(
      id: id ?? this.id,
      requesterId: requesterId ?? this.requesterId,
      requesterName: requesterName ?? this.requesterName,
      patientName: patientName ?? this.patientName,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      units: units ?? this.units,
      hospital: hospital ?? this.hospital,
      location: location ?? this.location,
      contactNumber: contactNumber ?? this.contactNumber,
      urgency: urgency ?? this.urgency,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      requiredDate: requiredDate ?? this.requiredDate,
      additionalInfo: additionalInfo ?? this.additionalInfo,
      responders: responders ?? this.responders,
    );
  }
}
