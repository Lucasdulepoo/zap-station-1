class Profile {
  const Profile({required this.id, this.displayName, this.avatarPath});

  factory Profile.fromMap(Map<String, dynamic> map) => Profile(
        id: map['id'] as String,
        displayName: map['display_name'] as String?,
        avatarPath: map['avatar_path'] as String?,
      );

  final String id;
  final String? displayName;
  final String? avatarPath;

  bool get hasDisplayName => displayName != null && displayName!.trim().isNotEmpty;

  /// Valida o nome exibido (mesma regra do CHECK no banco: 1 a 60 caracteres não vazios).
  static String? validateDisplayName(String raw) {
    final name = raw.trim();
    if (name.isEmpty) return 'Digite seu nome.';
    if (name.length > 60) return 'Use no máximo 60 caracteres.';
    return null;
  }
}
