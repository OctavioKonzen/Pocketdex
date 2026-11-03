// lib/utils/profanity.dart
//
// Filtro de palavrões para nomes de treinador e de time — igual ao do site
// (web-site/src/lib/profanity.js). Compara o começo de cada palavra, depois de
// tirar acentos, "leetspeak" (p0rr4 → porra) e letras repetidas.

const _badStems = [
  // português
  'porra', 'caralh', 'buceta', 'boceta', 'xoxota', 'xota', 'puta', 'puto', 'putinh', 'fdp', 'vsf', 'vtnc', 'tnc',
  'foda', 'fode', 'foder', 'fodid', 'fuder', 'fudid', 'merda', 'bosta', 'cuzao', 'cuzinh', 'arrombad', 'viado', 'viadinh',
  'bicha', 'traveco', 'piroca', 'pinto', 'rola', 'punheta', 'siririca', 'vagabund', 'vadia', 'corno', 'otario',
  'babaca', 'retardad', 'mongoloid', 'escroto', 'desgracad', 'paunocu', 'filhodaputa', 'filhadaputa', 'macaco',
  'crioulo', 'estupr', 'pedofil', 'nazi', 'hitler',
  // inglês
  'fuck', 'shit', 'bitch', 'cunt', 'dick', 'cock', 'pussy', 'asshole', 'bastard', 'whore', 'slut', 'nigg', 'fag',
  'retard', 'rape', 'porn',
];

// Palavras curtas só contam quando são a palavra inteira ("rola" sim, "rolagem" não).
const _exactOnly = {'rola', 'pinto', 'bicha', 'puto', 'tnc', 'fag', 'dick', 'cock', 'macaco', 'corno', 'rape'};

const _leet = {'0': 'o', '1': 'i', '3': 'e', '4': 'a', '5': 's', '7': 't', '8': 'b', '@': 'a', r'$': 's', '!': 'i'};
const _accents = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
const _plain = 'aaaaaeeeeiiiiooooouuuucn';

String _normalize(String text) {
  final out = StringBuffer();
  for (final ch in text.toLowerCase().split('')) {
    final i = _accents.indexOf(ch);
    out.write(i >= 0 ? _plain[i] : (_leet[ch] ?? ch));
  }
  return out.toString().replaceAll(RegExp(r'[^a-z\s]'), '');
}

String _squeeze(String word) => word.replaceAllMapped(RegExp(r'(.)\1+'), (m) => m[1]!);

bool _matches(String word) {
  for (final stem in _badStems) {
    final exact = _exactOnly.contains(stem);
    for (final (w, s) in [(word, stem), (_squeeze(word), _squeeze(stem))]) {
      if (exact ? w == s : w.startsWith(s)) return true;
    }
  }
  return false;
}

/// O texto tem palavrão? (também pega letras separadas: "p o r r a").
bool isOffensive(String? text) {
  final clean = _normalize(text ?? '');
  final words = clean.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.any(_matches)) return true;
  final joined = clean.replaceAll(RegExp(r'\s+'), '');
  return words.length > 1 && words.every((w) => w.length <= 2) && _matches(joined);
}
