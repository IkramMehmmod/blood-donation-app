import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String? id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String city;
  final String state;
  final String country;
  final String bloodGroup;
  final bool isDonor;
  final DateTime? lastDonation;
  final String imageUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;

  UserModel({
    this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.city,
    required this.state,
    required this.country,
    required this.bloodGroup,
    required this.isDonor,
    this.lastDonation,
    required this.imageUrl,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;

    try {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.parse(value);
      } else if (value is DateTime) {
        return value;
      }
    } catch (e) {
      debugPrint('Error parsing date: $e');
    }

    return null;
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    DateTime? lastDonation =
        _parseDateTime(json['last_donation'] ?? json['lastDonation']);

    return UserModel(
      id: json['id'],
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      address: json['address'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      country: json['country'] ?? '',
      bloodGroup: json['blood_group'] ?? json['bloodGroup'] ?? '',
      isDonor: json['is_donor'] ?? json['isDonor'] ?? false,
      lastDonation: lastDonation,
      imageUrl: json['image_url'] ?? json['imageUrl'] ?? '',
      createdAt: _parseDateTime(json['created_at'] ?? json['createdAt']) ??
          DateTime.now(),
      updatedAt: _parseDateTime(json['updated_at'] ?? json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'city': city,
      'state': state,
      'country': country,
      'bloodGroup': bloodGroup,
      'isDonor': isDonor,
      'lastDonation': lastDonation?.toIso8601String(),
      'imageUrl': imageUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  // Create a copy with updated fields
  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? address,
    String? city,
    String? state,
    String? country,
    String? bloodGroup,
    bool? isDonor,
    DateTime? lastDonation,
    String? imageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      isDonor: isDonor ?? this.isDonor,
      lastDonation: lastDonation ?? this.lastDonation,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
