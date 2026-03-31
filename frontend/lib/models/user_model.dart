class UserModel {
  final String id;
  final String name;
  final String email;
  final int? age;
  final String? gender;
  final String bio;
  final List<String> photos;
  final List<double>? locationCoordinates;
  final UserPreferences preferences;
  final List<String> interests;
  final String? job;
  final String? school;
  final bool isProfileComplete;
  final DateTime? lastActive;
  final double? distance; // from discovery

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.age,
    this.gender,
    this.bio = '',
    this.photos = const [],
    this.locationCoordinates,
    UserPreferences? preferences,
    this.interests = const [],
    this.job,
    this.school,
    this.isProfileComplete = false,
    this.lastActive,
    this.distance,
  }) : preferences = preferences ?? UserPreferences();

  factory UserModel.fromJson(Map<String, dynamic> json) {
    List<double>? coords;
    if (json['location'] != null && json['location']['coordinates'] != null) {
      final raw = json['location']['coordinates'] as List;
      coords = raw.map((e) => (e as num).toDouble()).toList();
    }

    return UserModel(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      age: json['age'],
      gender: json['gender'],
      bio: json['bio'] ?? '',
      photos: List<String>.from(json['photos'] ?? []),
      locationCoordinates: coords,
      preferences: json['preferences'] != null
          ? UserPreferences.fromJson(json['preferences'])
          : UserPreferences(),
      interests: List<String>.from(json['interests'] ?? []),
      job: json['job'],
      school: json['school'],
      isProfileComplete: json['isProfileComplete'] ?? false,
      lastActive: json['lastActive'] != null
          ? DateTime.tryParse(json['lastActive'])
          : null,
      distance: json['distance'] != null
          ? (json['distance'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'email': email,
      'age': age,
      'gender': gender,
      'bio': bio,
      'photos': photos,
      'preferences': preferences.toJson(),
      'interests': interests,
      'job': job,
      'school': school,
      'isProfileComplete': isProfileComplete,
    };
  }

  String get firstPhoto => photos.isNotEmpty ? photos.first : '';

  bool get isOnline {
    if (lastActive == null) return false;
    return DateTime.now().difference(lastActive!).inMinutes < 5;
  }

  UserModel copyWith({
    String? name,
    int? age,
    String? gender,
    String? bio,
    List<String>? photos,
    UserPreferences? preferences,
    List<String>? interests,
    String? job,
    String? school,
    bool? isProfileComplete,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      bio: bio ?? this.bio,
      photos: photos ?? this.photos,
      locationCoordinates: locationCoordinates,
      preferences: preferences ?? this.preferences,
      interests: interests ?? this.interests,
      job: job ?? this.job,
      school: school ?? this.school,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      lastActive: lastActive,
    );
  }
}

class UserPreferences {
  final List<String> genderPreference;
  final int minAge;
  final int maxAge;
  final int maxDistance;

  UserPreferences({
    this.genderPreference = const ['male', 'female', 'other'],
    this.minAge = 18,
    this.maxAge = 50,
    this.maxDistance = 50,
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      genderPreference: List<String>.from(json['genderPreference'] ?? ['male', 'female', 'other']),
      minAge: json['minAge'] ?? 18,
      maxAge: json['maxAge'] ?? 50,
      maxDistance: json['maxDistance'] ?? 50,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'genderPreference': genderPreference,
      'minAge': minAge,
      'maxAge': maxAge,
      'maxDistance': maxDistance,
    };
  }
}
