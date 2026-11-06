// services/security.dart - 应用锁 PIN 哈希
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

String generateSalt() => const Uuid().v4();

String hashPin(String pin, String salt) =>
    sha256.convert(utf8.encode('$salt::$pin')).toString();

String maskPin(String pin) =>
    List<String>.generate(pin.length, (_) => '●').join();
