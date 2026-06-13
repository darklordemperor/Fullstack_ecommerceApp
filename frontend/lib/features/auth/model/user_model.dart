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
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        lastname: json['lastname'] ?? '',
        age: json['age'] ?? 0,
        gender: json['gender'] ?? '',
        email: json['email'] ?? '',
        role: List<String>.from(json['role'] ?? const ['customer']),
        banned: json['banned'] ?? false,
        address: json['address'],
        profileImage: json['profile_image'],
        shopName: json['shop_name'],
        shopLocation: json['shop_location'],
        taxPayerNumber: json['tax_payer_number'],
        sellerStatus: json['seller_status'],
      );
}
