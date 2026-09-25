import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/models/ability.dart';
import 'package:pocket_dex/models/generation.dart';
import 'package:pocket_dex/models/item.dart';
import 'package:pocket_dex/models/move.dart';
import 'package:pocket_dex/services/pokemon_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = PokemonService();

  test('lista todos os Pokémon', () async {
    final list = await service.fetchAllPokemonList();
    expect(list.length, greaterThanOrEqualTo(1025));
    expect(list.first.name, 'bulbasaur');
    expect(list.first.id, '1');
  });

  test('carrega a Pokédex de uma geração', () async {
    final kanto = await service.fetchPokedex(generations.first);
    expect(kanto.length, 151);
    expect(kanto.last.name, 'mew');
  });

  test('carrega detalhes completos de um Pokémon', () async {
    final details = await service.fetchPokemonDetails(6);
    expect(details.name, 'charizard');
    expect(details.genus, isNotEmpty);
    expect(details.evolutionChain.map((e) => e.toPokemonName), containsAll(['charmeleon', 'charizard']));
    expect(details.forms.map((f) => f.apiName), contains('charizard-mega-x'));
    expect(details.forms.first.types, ['fire', 'flying']);
    expect(details.allTypeDetails['fire']!['damage_relations']['double_damage_from'], isNotEmpty);
    expect(details.allMoveDetails, isNotEmpty);
  });

  test('filtra por dois tipos', () async {
    final list = await service.fetchPokemonByTypes(['fire', 'flying']);
    expect(list.map((p) => p.name), contains('charizard'));
    expect(list.map((p) => p.name), isNot(contains('charmander')));
  });

  test('encontra parceiros de breeding', () async {
    final details = await service.fetchPokemonDetails(1);
    final partners = await service.fetchCompatiblePartners(details);
    expect(partners.map((p) => p.name), contains('ivysaur'));
  });

  test('enciclopédia de golpes, itens e habilidades', () async {
    final moves = await service.fetchAllMovesList();
    final move = await service.fetchResourceDetails(moves.first['url']!, Move.fromApiJson);
    expect(move.name, 'Pound');
    expect(move.power, 40);

    final items = await service.fetchAllItemsList();
    final item = await service.fetchResourceDetails(items.first['url']!, Item.fromApiJson);
    expect(item.imageUrl, contains('master-ball'));

    final abilities = await service.fetchAllAbilitiesList();
    final ability = await service.fetchResourceDetails(abilities.first['url']!, Ability.fromApiJson);
    expect(ability.description, isNot(startsWith('No description')));

    expect(await service.fetchPokemonWhoLearnMove('Thunderbolt'), isNotEmpty);
    expect(await service.fetchPokemonWithAbility('Overgrow'), isNotEmpty);
  });

  test('busca Pokémon por nome ou id', () async {
    final byName = await service.fetchPokemonJson('pikachu');
    final byId = await service.fetchPokemonJson('25');
    expect(byName['id'], 25);
    expect(byId['name'], 'pikachu');
    expect(byId['sprites']['front_default'], startsWith('https://'));
  });
}
