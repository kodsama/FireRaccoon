/// In-memory FireRacoon app state persisted as one encrypted JSON document.
class AppState {
  AppState({
    FireflyConnection? firefly,
    List<Map<String, dynamic>>? people,
    Map<String, dynamic>? peopleAuth,
    List<Map<String, dynamic>>? accountOwnerships,
    Map<String, dynamic>? devicePrefs,
    Map<String, dynamic>? classifications,
    Map<String, dynamic>? sideMenu,
    Map<String, dynamic>? accountColumns,
    Map<String, dynamic>? transactionColumns,
    Map<String, dynamic>? viewMode,
    Map<String, dynamic>? prognosis,
    Map<String, dynamic>? undo,
    Map<String, dynamic>? sessions,
    List<Map<String, dynamic>>? agentKeys,
    Map<String, String>? avatars,
  }) : firefly = firefly ?? FireflyConnection.empty(),
       agentKeys = agentKeys ?? <Map<String, dynamic>>[],
       people = people ?? <Map<String, dynamic>>[],
       peopleAuth =
           peopleAuth ?? <String, dynamic>{'byPersonId': <String, dynamic>{}},
       accountOwnerships = accountOwnerships ?? <Map<String, dynamic>>[],
       devicePrefs = devicePrefs ?? <String, dynamic>{},
       classifications = classifications ?? <String, dynamic>{},
       sideMenu = sideMenu ?? <String, dynamic>{},
       accountColumns = accountColumns ?? <String, dynamic>{},
       transactionColumns = transactionColumns ?? <String, dynamic>{},
       viewMode = viewMode ?? <String, dynamic>{},
       prognosis = prognosis ?? <String, dynamic>{},
       undo = undo ?? <String, dynamic>{'entries': <dynamic>[], 'index': 0},
       sessions = sessions ?? <String, dynamic>{},
       avatars = avatars ?? <String, String>{};

  FireflyConnection firefly;
  List<Map<String, dynamic>> people;
  Map<String, dynamic> peopleAuth;
  List<Map<String, dynamic>> accountOwnerships;
  Map<String, dynamic> devicePrefs;
  Map<String, dynamic> classifications;
  Map<String, dynamic> sideMenu;
  Map<String, dynamic> accountColumns;
  Map<String, dynamic> transactionColumns;
  Map<String, dynamic> viewMode;
  Map<String, dynamic> prognosis;
  Map<String, dynamic> undo;
  Map<String, dynamic> sessions;

  /// MCP agent keys. Each record carries its digest and, so the owner can
  /// read the key back rather than reissue it, the secret itself. See
  /// `AgentKey` in fireracoon_engine.
  List<Map<String, dynamic>> agentKeys;

  /// personId → base64 PNG
  Map<String, String> avatars;

  bool get setupRequired =>
      people.isEmpty || firefly.url.isEmpty || firefly.token.isEmpty;

  bool get requirePasswordLogin {
    final value = peopleAuth['requirePasswordLogin'];
    return value is bool ? value : true;
  }

  set requirePasswordLogin(bool value) {
    peopleAuth['requirePasswordLogin'] = value;
  }

  Map<String, dynamic> get authByPersonId {
    final raw = peopleAuth['byPersonId'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    final empty = <String, dynamic>{};
    peopleAuth['byPersonId'] = empty;
    return empty;
  }

  Map<String, dynamic> toJson() => {
    'firefly': firefly.toJson(),
    'people': people,
    'peopleAuth': peopleAuth,
    'accountOwnerships': accountOwnerships,
    'devicePrefs': devicePrefs,
    'classifications': classifications,
    'sideMenu': sideMenu,
    'accountColumns': accountColumns,
    'transactionColumns': transactionColumns,
    'viewMode': viewMode,
    'prognosis': prognosis,
    'undo': undo,
    'sessions': sessions,
    'agentKeys': agentKeys,
    'avatars': avatars,
  };

  factory AppState.fromJson(Map<String, dynamic> json) {
    return AppState(
      firefly: FireflyConnection.fromJson(
        (json['firefly'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      people: _listOfMaps(json['people']),
      peopleAuth:
          (json['peopleAuth'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{'byPersonId': <String, dynamic>{}},
      accountOwnerships: _listOfMaps(json['accountOwnerships']),
      devicePrefs: (json['devicePrefs'] as Map?)?.cast<String, dynamic>() ?? {},
      classifications:
          (json['classifications'] as Map?)?.cast<String, dynamic>() ?? {},
      sideMenu: (json['sideMenu'] as Map?)?.cast<String, dynamic>() ?? {},
      accountColumns:
          (json['accountColumns'] as Map?)?.cast<String, dynamic>() ?? {},
      transactionColumns:
          (json['transactionColumns'] as Map?)?.cast<String, dynamic>() ?? {},
      viewMode: (json['viewMode'] as Map?)?.cast<String, dynamic>() ?? {},
      prognosis: (json['prognosis'] as Map?)?.cast<String, dynamic>() ?? {},
      undo:
          (json['undo'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{'entries': <dynamic>[], 'index': 0},
      sessions: (json['sessions'] as Map?)?.cast<String, dynamic>() ?? {},
      agentKeys: _listOfMaps(json['agentKeys']),
      avatars:
          (json['avatars'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v.toString()),
          ) ??
          {},
    );
  }

  static List<Map<String, dynamic>> _listOfMaps(Object? raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map<Object?, Object?>>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
        .toList();
  }
}

class FireflyConnection {
  FireflyConnection({
    required this.url,
    required this.token,
    this.allowInsecure = false,
  });

  factory FireflyConnection.empty() =>
      FireflyConnection(url: '', token: '', allowInsecure: false);

  factory FireflyConnection.fromJson(Map<String, dynamic> json) {
    return FireflyConnection(
      url: json['url'] as String? ?? '',
      token: json['token'] as String? ?? '',
      allowInsecure: json['allowInsecure'] as bool? ?? false,
    );
  }

  String url;
  String token;
  bool allowInsecure;

  Map<String, dynamic> toJson() => {
    'url': url,
    'token': token,
    'allowInsecure': allowInsecure,
  };

  Map<String, dynamic> toPublicJson() => {
    'url': url,
    'allowInsecure': allowInsecure,
    'configured': url.isNotEmpty && token.isNotEmpty,
  };
}
