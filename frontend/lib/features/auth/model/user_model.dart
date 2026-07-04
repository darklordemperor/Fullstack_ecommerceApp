class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.lastname,
    required this.age,
    required this.gender,
    required this.email,
    required this.role,
    this.banned = false,
    this.address,
    this.profileImage,
    this.shopName,
    this.shopLocation,
    this.taxPayerNumber,
    this.sellerStatus,
  });

  final String id;
  final String name;
  final String lastname;
  final int age;
  final String gender;
  final String email;
  final List<String> role;
  final bool banned;
  final String? address;
  final String? profileImage;
  final String? shopName;
  final String? shopLocation;
  final String? taxPayerNumber;
  final String? sellerStatus;

  String get fullName => '$name $lastname';
  String get initials =>
      '${name.isNotEmpty ? name[0] : ''}${lastname.isNotEmpty ? lastname[0] : ''}'
          .toUpperCase();
  bool get isApprovedSeller =>
      role.contains('seller') && sellerStatus == 'approved';
  bool get isAdmin => role.contains('admin');

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        lastname: json['lastname'] as String? ?? '',
        age: (json['age'] as num? ?? 0).toInt(),
        gender: json['gender'] as String? ?? '',
        email: json['email'] as String? ?? '',
        role: (json['role'] as List<dynamic>? ?? const ['customer'])
            .map((role) => role.toString())
            .toList(),
        banned: json['banned'] as bool? ?? false,
        address: json['address'] as String?,
        profileImage: json['profile_image'] as String?,
        shopName: json['shop_name'] as String?,
        shopLocation: json['shop_location'] as String?,
        taxPayerNumber: json['tax_payer_number'] as String?,
        sellerStatus: json['seller_status'] as String?,
      );
}
