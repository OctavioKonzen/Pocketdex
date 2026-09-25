// lib/screens/items_encyclopedia_screen.dart
import 'package:flutter/material.dart';
import '../widgets/expandable_entry.dart';
import '../models/item.dart';
import '../services/pokemon_service.dart';
import '../utils/string_extensions.dart';
import '../utils/responsive.dart';
import '../utils/app_images.dart';

class ItemsEncyclopediaScreen extends StatefulWidget {
  const ItemsEncyclopediaScreen({super.key});

  @override
  State<ItemsEncyclopediaScreen> createState() =>
      _ItemsEncyclopediaScreenState();
}

class _ItemsEncyclopediaScreenState extends State<ItemsEncyclopediaScreen> {
  final PokemonService _pokemonService = PokemonService();
  // Item aberto na lista (abre embaixo, empurrando os outros).
  final ValueNotifier<String?> _openId = ValueNotifier(null);

  @override
  void dispose() {
    _openId.dispose();
    super.dispose();
  }

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
    } catch (e) {}
  }

  void _filterItems(String query) {
    final filtered = _allItems.where((item) {
      return item['name']!
          .toLowerCase()
          .replaceAll('-', ' ')
          .contains(query.toLowerCase());
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
      body: ReadableWidth(
          child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: _filterItems,
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Procurar Item',
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                        openId: _openId,
                      );
                    },
                  ),
          ),
        ],
      )),
    );
  }
}

class _ItemTile extends StatelessWidget {
  final String name;
  final String url;
  final PokemonService pokemonService;
  final ValueNotifier<String?> openId;

  const _ItemTile({required this.name, required this.url, required this.pokemonService, required this.openId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpandableEntry<Item>(
      id: url,
      openId: openId,
      accent: const Color(0xFF8D6E63),
      load: () => pokemonService.fetchResourceDetails(url, (json) => Item.fromApiJson(json)),
      header: (context, item, open) => ListTile(
        leading: item == null
            ? const SizedBox(width: 40, height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
            : Image(
                image: AppImages.provider(item.imageUrl),
                width: 40,
                height: 40,
                filterQuality: FilterQuality.none,
                errorBuilder: (c, e, s) => Icon(Icons.help_outline, color: theme.hintColor),
              ),
        title: Text(item?.name ?? name.replaceAll('-', ' ').capitalise(),
            style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
        subtitle: item == null ? null : Text(item.category, style: TextStyle(color: theme.hintColor)),
      ),
      details: (context, item) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image(
            image: AppImages.provider(item.imageUrl),
            width: 96,
            height: 96,
            filterQuality: FilterQuality.none,
            errorBuilder: (c, e, s) => const SizedBox(width: 96),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(item.effect, style: theme.textTheme.bodyLarge?.copyWith(height: 1.5))),
        ],
      ),
    );
  }
}
