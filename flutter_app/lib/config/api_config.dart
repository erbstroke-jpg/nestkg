import 'package:flutter/foundation.dart' show kIsWeb;

const String _envUrl = String.fromEnvironment('BASE_URL', defaultValue: '');

final String kBaseUrl = _envUrl.isNotEmpty ? _envUrl : 'http://localhost:8000';
