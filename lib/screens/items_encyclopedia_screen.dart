// lib/screens/items_encyclopedia_screen.dart
import 'package:flutter/material.dart';
import '../models/item.dart';
import '../services/pokemon_service.dart';
import '../utils/string_extensions.dart';
import 'item_detail_screen.dart';

class ItemsEncyclopediaScreen extends StatefulWidget {
  const ItemsEncyclopediaScreen({super.key});

  @override
  State<ItemsEncyclopediaScreen> createState() => _ItemsEncyclopediaScreenState();
}

class _ItemsEncyclopediaScreenState extends State<ItemsEncyclopediaScreen> {
  final PokemonService _pokemonService = PokemonService();
  List<Map<String, String>> _allItems = [];
  List<Map<String, String>> _filteredItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final itemsList = await _pokemonService.fetchAllItemsList();
      if (mounted) {
        setState(() {
          _allItems = itemsList;
          _filteredItems = _allItems;
          _isLoading = false;
        });
      }
    } catch (e) {
    }
  }

  void _filterItems(String query) {
    final filtered = _allItems.where((item) {
      return item['name']!.toLowerCase().replaceAll('-', ' ').contains(query.toLowerCase());
    }).toList();
    setState(() {
      _filteredItems = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enciclopédia de Itens'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: _filterItems,
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Procurar Item',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: theme.colorScheme.surface,
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _filteredItems.length,
                    itemBuilder: (context, index) {
                      final itemData = _filteredItems[index];
                      return _ItemTile(
                        name: itemData['name']!,
                        url: itemData['url']!,
                        pokemonService: _pokemonService,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  final String name;
  final String url;
  final PokemonService pokemonService;

  const _ItemTile({required this.name, required this.url, required this.pokemonService});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.cardColor,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: FutureBuilder<Item>(
        future: pokemonService.fetchResourceDetails(url, (json) => Item.fromApiJson(json)),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return ListTile(
              leading: const SizedBox(width: 40, height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
              title: Text(name.replaceAll('-', ' ').capitalise(), style: TextStyle(color: theme.colorScheme.onSurface)),
            );
          }
          final item = snapshot.data!;
          return ListTile(
            leading: Image.network(
              item.imageUrl,
              width: 40,
              height: 40,
              errorBuilder: (c, e, s) => Icon(Icons.help_outline, color: theme.hintColor),
            ),
            title: Text(item.name, style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
            subtitle: Text(item.category, style: TextStyle(color: theme.hintColor)),
            trailing: Icon(Icons.chevron_right, color: theme.hintColor),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ItemDetailScreen(item: item)),
              );
            },
          );
        },
      ),
    );
  }
}