import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class HiveFlowApiException implements Exception {
  const HiveFlowApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class HiveFlowApi {
  HiveFlowApi({required this.baseUrl, this._client});

  final String baseUrl;
  http.Client? _client;

  http.Client get _httpClient => _client ??= http.Client();

  static String defaultBaseUrl() {
    const configuredUrl = String.fromEnvironment('HIVEFLOW_API_URL');
    if (configuredUrl.isNotEmpty) return configuredUrl;
    if (kIsWeb) {
      final host = Uri.base.host.isEmpty ? 'localhost' : Uri.base.host;
      return 'http://$host:3000';
    }
    return switch (defaultTargetPlatform) {
      // Real phones need a laptop Wi-Fi IP; 10.0.2.2 is emulator-only.
      TargetPlatform.android => '',
      _ => 'http://127.0.0.1:3000',
    };
  }

  Future<Map<String, dynamic>> get(String path) => _request('GET', path);

  Future<Map<String, dynamic>> post(
    String path, [
    Map<String, dynamic> body = const {},
  ]) => _request('POST', path, body);

  Future<Map<String, dynamic>> _request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final trimmedBase = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse('$trimmedBase/api$path');
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      throw const HiveFlowApiException(
        'Enter a valid server address, for example http://192.168.1.5:3000',
      );
    }

    try {
      final request = http.Request(method, uri)
        ..headers['Accept'] = 'application/json';
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      final streamed = await _httpClient
          .send(request)
          .timeout(const Duration(seconds: 8));
      final response = await http.Response.fromStream(streamed);
      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const HiveFlowApiException(
          'The server returned an unexpected response.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = decoded['error'];
        final message = error is Map ? error['message'] : null;
        throw HiveFlowApiException(
          message is String
              ? message
              : 'Request failed (${response.statusCode}).',
        );
      }
      return decoded;
    } on HiveFlowApiException {
      rethrow;
    } on FormatException {
      throw const HiveFlowApiException(
        'The server response could not be read. Check the API is up to date.',
      );
    } on Exception catch (error) {
      throw HiveFlowApiException(
        'Could not reach $trimmedBase. Start the HiveFlow backend and check the address. ($error)',
      );
    }
  }

  void close() => _client?.close();

  static String newEventId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
