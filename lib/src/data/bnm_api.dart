import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import '../domain/dates.dart';

/// The rates source could not be reached (no network, timeout, server error).
class SourceUnavailableException implements Exception {
  const SourceUnavailableException(this.message);
  final String message;

  @override
  String toString() => 'SourceUnavailableException: $message';
}

/// Anything that can return the raw BNM document for a day.
/// The repository depends on this interface, tests use a fake.
abstract interface class RateSource {
  Future<String> fetchDay(DateTime day);
}

/// HTTP client for the official BNM feed.
class BnmApi implements RateSource {
  BnmApi({http.Client? client, this.timeout = const Duration(seconds: 10)})
      : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  /// The Russian feed is used so currency names come in Russian.
  static Uri urlFor(DateTime day) => Uri.parse(
        'https://www.bnm.md/ru/official_exchange_rates?get_xml=1&date=${formatDay(day)}',
      );

  @override
  Future<String> fetchDay(DateTime day) async {
    final http.Response response;
    try {
      response = await _client.get(urlFor(day)).timeout(timeout);
    } on TimeoutException {
      throw SourceUnavailableException(
        'НБМ не ответил за ${timeout.inSeconds} секунд',
      );
    } on SocketException {
      throw const SourceUnavailableException('Нет подключения к интернету');
    } on http.ClientException {
      throw const SourceUnavailableException('Не удалось связаться с сервером НБМ');
    }

    if (response.statusCode != 200) {
      throw SourceUnavailableException(
        'Сервер НБМ временно недоступен (код ${response.statusCode})',
      );
    }
    // BNM sends UTF-8; decode explicitly so Cyrillic names are not mangled.
    return utf8.decode(response.bodyBytes, allowMalformed: true);
  }
}
