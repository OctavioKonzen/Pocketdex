// Conversão entre os modelos do app e o formato da conta (o mesmo do site).

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/models/team.dart';
import 'package:pocket_dex/models/training_pokemon.dart';
import 'package:pocket_dex/services/account_format.dart';
import 'package:pocket_dex/services/auth_service.dart';
import 'package:pocket_dex/utils/app_images.dart';

void main() {
  test('time do app vira time do site e volta igual', () {
    final team = Team(id: 't1', name: 'Meu time', color: 'ff42a5f5', pokemons: [
      {'id': '6', 'imageUrl': AppImages.pokemonArtwork(10034)}, // Mega Charizard X
      {},
      {'id': '25', 'imageUrl': AppImages.pokemonArtwork(25)},
    ]);
    final account = AccountFormat.teamToAccount(team);
    expect(account['color'], '#42A5F5');
    expect(account['pokemon'], [10034, null, 25, null, null, null]);

    final back = AccountFormat.teamFromAccount(account);
    expect(back.name, 'Meu time');
    expect(back.color, 'ff42a5f5');
    expect(back.pokemons[0]['imageUrl'], AppImages.pokemonArtwork(10034));
    expect(back.pokemons[1], isEmpty);
  });

  test('time criado no site mantém campos que o app não usa', () {
    final site = {'id': 'x', 'name': 'Site', 'color': null, 'pokemon': [1, null, null, null, null, null], 'extra': 1};
    final team = AccountFormat.teamFromAccount(site);
    final again = AccountFormat.teamToAccount(team, site);
    expect(again['extra'], 1);
    expect(again['pokemon'], [1, null, null, null, null, null]);
  });

  test('treino de EVs usa as mesmas chaves do site', () {
    final p = TrainingPokemon(
        id: 'a', pokemonId: '25', pokemonName: 'pikachu', imageUrl: AppImages.pokemonArtwork(25), speedEVs: 252, hpEVs: 4);
    final account = AccountFormat.trainingToAccount(p);
    expect(account['pokemonId'], 25);
    expect(account['sprite'], 'pokemon/25.png');
    expect(account['evs'], {'hp': 4, 'speed': 252});
    final back = AccountFormat.trainingFromAccount({...account, 'box': [1, 2, 3, 4, 96, 96]});
    expect(back.speedEVs, 252);
    expect(AccountFormat.trainingToAccount(back, {...account, 'box': [1, 2, 3, 4, 96, 96]})['box'], isNotNull);
  });

  test('nomes iguais com maiúsculas, acentos e espaços são o mesmo nome', () {
    expect(AuthService.nameKey('  Ash   Ketchum '), 'ash ketchum');
    expect(AuthService.nameKey('JOÃO'), AuthService.nameKey('joao'));
    expect(AuthService.validateName('Al'), contains('pelo menos'));
    expect(AuthService.validateName('Mestre Pokémon_1'), isNull);
  });
}
