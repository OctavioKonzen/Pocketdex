// lib/services/pix.dart
//
// Pix para apoiar o projeto — igual ao site (web-site/src/lib/pix.js).
// Preencha a chave, o nome e a cidade de quem recebe; vazio = o cartão de
// apoio não aparece.

import 'dart:convert';

class Pix {
  Pix._();

  static const key = '';
  static const name = ''; // até 25 letras, sem acento
  static const city = ''; // até 15 letras, sem acento

  static bool get enabled => key.isNotEmpty && name.isNotEmpty && city.isNotEmpty;

  static String _field(String id, String value) => '$id${value.length.toString().padLeft(2, '0')}$value';

  static String _plain(String text, int max) {
    const accents = 'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ';
    const plain = 'aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN';
    final out = StringBuffer();
    for (final ch in text.split('')) {
      final i = accents.indexOf(ch);
      out.write(i >= 0 ? plain[i] : ch);
    }
    final clean = out.toString().replaceAll(RegExp(r'[^A-Za-z0-9 ]'), '');
    return clean.length > max ? clean.substring(0, max) : clean;
  }

  /// CRC16-CCITT (0x1021, começa em 0xFFFF), como pede o padrão do Pix.
  static String crc16(String text) {
    var crc = 0xFFFF;
    for (final byte in utf8.encode(text)) {
      crc ^= byte << 8;
      for (var i = 0; i < 8; i++) {
        crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) & 0xFFFF : (crc << 1) & 0xFFFF;
      }
    }
    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }

  /// Código "Pix copia e cola" (BR Code) sem valor fixo: a pessoa escolhe quanto doar.
  static String code({String key = Pix.key, String name = Pix.name, String city = Pix.city}) {
    final payload = _field('00', '01') +
        _field('26', _field('00', 'br.gov.bcb.pix') + _field('01', key)) +
        _field('52', '0000') +
        _field('53', '986') +
        _field('58', 'BR') +
        _field('59', _plain(name, 25)) +
        _field('60', _plain(city, 15)) +
        _field('62', _field('05', '***')) +
        '6304';
    return payload + crc16(payload);
  }
}
