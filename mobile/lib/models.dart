class Photo {
  final String id;
  final String url;
  const Photo({required this.id, required this.url});

  factory Photo.fromJson(Map<String, dynamic> j) =>
      Photo(id: j['id'] as String, url: j['url'] as String);
}

class UserProfile {
  final String id;
  final String name;
  final int age;
  final String gender;
  final String bio;
  final List<String> interests;
  final List<Photo> photos;
  final int? distanceKm;

  // Yalnızca kendi profilimizde dolu gelir:
  final String? email;
  final String? birthdate;
  final List<String> interestedIn;
  final int minAge;
  final int maxAge;
  final int maxDistanceKm;
  final bool hasLocation;

  const UserProfile({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.bio,
    required this.interests,
    required this.photos,
    this.distanceKm,
    this.email,
    this.birthdate,
    this.interestedIn = const [],
    this.minAge = 18,
    this.maxAge = 99,
    this.maxDistanceKm = 50,
    this.hasLocation = false,
  });

  String? get firstPhoto => photos.isEmpty ? null : photos.first.url;

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        id: j['id'] as String,
        name: j['name'] as String,
        age: (j['age'] as num).toInt(),
        gender: j['gender'] as String,
        bio: (j['bio'] ?? '') as String,
        interests: List<String>.from(j['interests'] ?? const []),
        photos: (j['photos'] as List? ?? const [])
            .map((p) => Photo.fromJson(Map<String, dynamic>.from(p as Map)))
            .toList(),
        distanceKm: (j['distanceKm'] as num?)?.toInt(),
        email: j['email'] as String?,
        birthdate: j['birthdate'] as String?,
        interestedIn: List<String>.from(j['interestedIn'] ?? const []),
        minAge: (j['minAge'] as num?)?.toInt() ?? 18,
        maxAge: (j['maxAge'] as num?)?.toInt() ?? 99,
        maxDistanceKm: (j['maxDistanceKm'] as num?)?.toInt() ?? 50,
        hasLocation: j['hasLocation'] == true,
      );
}

class ChatMessage {
  final String id;
  final String matchId;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  const ChatMessage({
    required this.id,
    required this.matchId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  ChatMessage copyWith({DateTime? readAt}) => ChatMessage(
        id: id,
        matchId: matchId,
        senderId: senderId,
        body: body,
        createdAt: createdAt,
        readAt: readAt ?? this.readAt,
      );

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String,
        matchId: j['matchId'] as String,
        senderId: j['senderId'] as String,
        body: j['body'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String).toLocal(),
        readAt: j['readAt'] == null ? null : DateTime.parse(j['readAt'] as String).toLocal(),
      );
}

class Match {
  final String id;
  final DateTime createdAt;
  final UserProfile user;
  final ChatMessage? lastMessage;
  final int unread;

  const Match({
    required this.id,
    required this.createdAt,
    required this.user,
    this.lastMessage,
    this.unread = 0,
  });

  Match copyWith({ChatMessage? lastMessage, int? unread}) => Match(
        id: id,
        createdAt: createdAt,
        user: user,
        lastMessage: lastMessage ?? this.lastMessage,
        unread: unread ?? this.unread,
      );

  factory Match.fromJson(Map<String, dynamic> j) => Match(
        id: j['id'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String).toLocal(),
        user: UserProfile.fromJson(Map<String, dynamic>.from(j['user'] as Map)),
        lastMessage: j['lastMessage'] == null
            ? null
            : ChatMessage.fromJson(Map<String, dynamic>.from(j['lastMessage'] as Map)),
        unread: (j['unread'] as num?)?.toInt() ?? 0,
      );
}

const genderLabels = {'female': 'Kadın', 'male': 'Erkek', 'other': 'Diğer'};
