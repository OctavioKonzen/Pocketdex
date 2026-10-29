import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/deep_links.dart';

void main() {
  test('a rota vem do link do site ou do pocketdex://', () {
    expect(DeepLinks.route('https://octaviokonzen.github.io/Pocketdex/#/times/importar/PDX1abc'), '/times/importar/PDX1abc');
    expect(DeepLinks.route('https://octaviokonzen.github.io/Pocketdex/#/batalha/replay?d=xyz'), '/batalha/replay?d=xyz');
    expect(DeepLinks.route('pocketdex://open?u=%2Fjogo%3Fdesafio%3Dabc'), '/jogo?desafio=abc');
    expect(DeepLinks.route('https://octaviokonzen.github.io/Pocketdex/'), '');
  });
}
