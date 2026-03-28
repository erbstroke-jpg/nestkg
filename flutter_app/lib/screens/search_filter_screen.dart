import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nestkg/l10n/generated/app_localizations.dart';
import '../providers/providers.dart';

class SearchFilterScreen extends ConsumerStatefulWidget {
  const SearchFilterScreen({super.key});
  @override
  ConsumerState<SearchFilterScreen> createState() => _SearchFilterScreenState();
}

class _SearchFilterScreenState extends ConsumerState<SearchFilterScreen> {
  final _search = TextEditingController();
  final _city = TextEditingController();
  final _minPrice = TextEditingController();
  final _maxPrice = TextEditingController();
  int? _categoryId;
  String? _condition;
  String _sortBy = 'newest';

  @override
  void initState() {
    super.initState();
    final f = ref.read(feedFilterProvider);
    _search.text = f.search ?? '';
    _city.text = f.city ?? '';
    _minPrice.text = f.minPrice?.toString() ?? '';
    _maxPrice.text = f.maxPrice?.toString() ?? '';
    _categoryId = f.categoryId;
    _condition = f.condition;
    _sortBy = f.sortBy;
  }

  @override
  void dispose() { _search.dispose(); _city.dispose(); _minPrice.dispose(); _maxPrice.dispose(); super.dispose(); }

  void _apply() {
    ref.read(feedFilterProvider.notifier).state = FeedFilter(
      search: _search.text.trim().isEmpty ? null : _search.text.trim(),
      categoryId: _categoryId,
      city: _city.text.trim().isEmpty ? null : _city.text.trim(),
      minPrice: double.tryParse(_minPrice.text),
      maxPrice: double.tryParse(_maxPrice.text),
      condition: _condition,
      sortBy: _sortBy,
    );
    Navigator.pop(context);
  }

  void _reset() {
    ref.read(feedFilterProvider.notifier).state = const FeedFilter();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final lang = ref.watch(localeProvider);
    final catsAsync = ref.watch(categoriesProvider);
    final cats = catsAsync.valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(title: Text(loc.filter), actions: [
        TextButton(onPressed: _reset, child: Text(loc.reset)),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
          controller: _search,
          decoration: InputDecoration(labelText: loc.search, prefixIcon: const Icon(Icons.search)),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int?>(
          value: _categoryId,
          decoration: InputDecoration(labelText: loc.category),
          items: [
            DropdownMenuItem(value: null, child: Text(loc.allCategories)),
            ...cats.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name(lang)))),
          ],
          onChanged: (v) => setState(() => _categoryId = v),
        ),
        const SizedBox(height: 12),
        TextField(controller: _city, decoration: InputDecoration(labelText: loc.city)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(controller: _minPrice, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: loc.minPrice))),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: _maxPrice, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: loc.maxPrice))),
        ]),
        const SizedBox(height: 12),
        DropdownButtonFormField<String?>(
          value: _condition,
          decoration: InputDecoration(labelText: loc.condition),
          items: [
            const DropdownMenuItem(value: null, child: Text('Any')),
            DropdownMenuItem(value: 'new_building', child: Text(loc.conditionNew)),
            DropdownMenuItem(value: 'renovated', child: Text(loc.conditionLikeNew)),
            DropdownMenuItem(value: 'secondary', child: Text(loc.conditionGood)),
            DropdownMenuItem(value: 'needs_renovation', child: Text(loc.conditionFair)),
            DropdownMenuItem(value: 'under_construction', child: Text(loc.conditionParts)),
          ],
          onChanged: (v) => setState(() => _condition = v),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _sortBy,
          decoration: InputDecoration(labelText: loc.sort),
          items: [
            DropdownMenuItem(value: 'newest', child: Text(loc.newest)),
            DropdownMenuItem(value: 'oldest', child: Text(loc.oldest)),
            DropdownMenuItem(value: 'price_asc', child: Text(loc.priceAsc)),
            DropdownMenuItem(value: 'price_desc', child: Text(loc.priceDesc)),
          ],
          onChanged: (v) => setState(() => _sortBy = v ?? 'newest'),
        ),
        const SizedBox(height: 24),
        ElevatedButton(onPressed: _apply, child: Text(loc.apply)),
      ]),
    );
  }
}
