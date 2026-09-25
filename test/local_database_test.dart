import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/models/ability.dart';
import 'package:pocket_dex/models/generation.dart';
import 'package:pocket_dex/models/item.dart';
import 'package:pocket_dex/models/move.dart';
import 'package:pocket_dex/services/local_database.dart';
import 'package:pocket_dex/services/pokemon_service.dart';
import 'package:pocket_dex/utils/app_images.dart';

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
    expect(byId['sprites']['front_default'], 'assets/database/sprites/pokemon/25.png');
    expect(byId['abilities'].map((a) => a['ability']['name']), containsAll(['static', 'lightning-rod']));
  });

  test('guarda todos os golpes com a forma de aprendizado', () async {
    final pikachu = await service.fetchPokemonJson('pikachu');
    final methods = {
      for (final m in pikachu['moves'] as List)
        for (final d in m['version_group_details'] as List) d['move_learn_method']['name'],
    };
    expect(methods, containsAll(['level-up', 'machine', 'tutor']));
  });

  test('todas as imagens (normal, shiny e arte oficial) estão no banco', () async {
    final db = LocalDatabase.instance;
    final pokemon = await db.pokemonJson('charizard-mega-x');
    final sprites = pokemon!['sprites'];
    final paths = [
      sprites['front_default'],
      sprites['front_shiny'],
      sprites['other']['official-artwork']['front_default'],
      sprites['other']['official-artwork']['front_shiny'],
    ];
    for (final path in paths) {
      expect(path, startsWith('assets/database/sprites/'));
      expect((await rootBundle.load(path)).lengthInBytes, greaterThan(0), reason: path);
    }
    // URLs antigas salvas em times/treinos são convertidas para o arquivo local.
    final legacy = AppImages.assetPath(
        'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/shiny/6.png');
    expect((await rootBundle.load(legacy!)).lengthInBytes, greaterThan(0));
    final item = await db.itemJson('master-ball');
    expect((await rootBundle.load(item!['sprites']['default'])).lengthInBytes, greaterThan(0));
  });

  test('inclui formas cosméticas', () async {
    final unown = await LocalDatabase.instance.formsOfPokemon(201);
    expect(unown.length, greaterThanOrEqualTo(28));
    final shiny = unown.last['sprites']['front_shiny'] as String;
    expect((await rootBundle.load(shiny)).lengthInBytes, greaterThan(0));
  });
}
