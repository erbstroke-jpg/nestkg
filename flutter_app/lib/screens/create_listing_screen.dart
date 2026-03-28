import 'main_shell.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nestkg/l10n/generated/app_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/api_client.dart';
import '../config/theme.dart';

class _PickedImage {
  final String name;
  final Uint8List bytes;
  _PickedImage({required this.name, required this.bytes});
}

class CreateListingScreen extends ConsumerStatefulWidget {
  final Listing? existing;
  const CreateListingScreen({super.key, this.existing});
  @override
  ConsumerState<CreateListingScreen> createState() =>
      _CreateListingScreenState();
}

class _CreateListingScreenState extends ConsumerState<CreateListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _price = TextEditingController();
  final _city = TextEditingController();
  int? _categoryId;
  String? _condition;
  bool _negotiable = false;
  LatLng? _location;
  final List<_PickedImage> _newImages = [];
  bool _submitting = false;
  bool get _isEdit => widget.existing != null;

  // Dynamic category attributes
  Map<String, dynamic> _attributes = {};
  Map<String, dynamic>? _currentSchema;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final l = widget.existing!;
      _title.text = l.title;
      _desc.text = l.description;
      _price.text = l.price.toStringAsFixed(0);
      _city.text = l.city;
      _categoryId = l.categoryId;
      _condition = l.condition;
      _negotiable = l.isNegotiable;
      _attributes = Map.from(l.attributesJson ?? {});
      if (l.latitude != null && l.longitude != null)
        _location = LatLng(l.latitude!, l.longitude!);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _price.dispose();
    _city.dispose();
    super.dispose();
  }

  void _onCategoryChanged(int? id, List<Category> cats) {
    setState(() {
      _categoryId = id;
      if (id != null) {
        final cat = cats.where((c) => c.id == id).firstOrNull;
        _currentSchema = cat?.attributesSchema;
        // Reset attributes when category changes (unless editing)
        if (!_isEdit) _attributes = {};
      } else {
        _currentSchema = null;
        _attributes = {};
      }
    });
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(imageQuality: 80);
    for (final xfile in images) {
      final bytes = await xfile.readAsBytes();
      setState(
          () => _newImages.add(_PickedImage(name: xfile.name, bytes: bytes)));
    }
  }

  Future<void> _submit({bool submitForReview = false}) async {
    if (!_formKey.currentState!.validate() || _categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Заполните все обязательные поля')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final svc = ref.read(listingsServiceProvider);
      // Clean attributes - remove empty values
      final cleanAttrs = Map.fromEntries(_attributes.entries
          .where((e) => e.value != null && e.value.toString().isNotEmpty));

      Listing listing;
      if (_isEdit) {
        listing = await svc.update(widget.existing!.id, {
          'category_id': _categoryId,
          'title': _title.text.trim(),
          'description': _desc.text.trim(),
          'price': double.parse(_price.text),
          'city': _city.text.trim(),
          'latitude': _location?.latitude,
          'longitude': _location?.longitude,
          'condition': _condition,
          'is_negotiable': _negotiable,
          'submit_for_review': submitForReview,
          'attributes_json': cleanAttrs.isNotEmpty ? cleanAttrs : null,
        });
      } else {
        listing = await svc.create(
          categoryId: _categoryId!,
          title: _title.text.trim(),
          description: _desc.text.trim(),
          price: double.parse(_price.text),
          city: _city.text.trim(),
          latitude: _location?.latitude,
          longitude: _location?.longitude,
          condition: _condition,
          isNegotiable: _negotiable,
          submitForReview: submitForReview,
          attributesJson: cleanAttrs.isNotEmpty ? cleanAttrs : null,
        );
      }
      for (int i = 0; i < _newImages.length; i++) {
        await svc.uploadMediaBytes(
            listing.id, _newImages[i].bytes, _newImages[i].name,
            isPrimary: i == 0 && !_isEdit);
      }
      if (!mounted) return;
      final loc = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEdit ? loc.listingUpdated : loc.listingCreated)));
      if (Navigator.canPop(context)) {
        Navigator.pop(context, true);
      } else {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const MainShell()));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _pickLocation() {
    final initial = _location ?? const LatLng(42.8746, 74.5698);
    showDialog(
        context: context,
        builder: (_) => _MapPicker(
            initial: initial,
            onPicked: (ll) => setState(() => _location = ll)));
  }

  // ── Attribute label translation ──
  static const _attrLabelsRu = {
    'rooms': 'Комнат',
    'area_sqm': 'Площадь (м²)',
    'floor': 'Этаж',
    'total_floors': 'Всего этажей',
    'building_type': 'Тип дома',
    'renovation': 'Ремонт',
    'furnishing': 'Мебель',
    'land_sqm': 'Участок (сотки)',
    'floors': 'Этажей',
    'heating': 'Отопление',
    'garage': 'Гараж',
    'property_type': 'Тип объекта',
    'parking_spaces': 'Парковка',
    'land_type': 'Тип земли',
    'utilities': 'Коммуникации',
    'rental_period': 'Период аренды',
    'utilities_included': 'Комм. включены',
  };
  static const _enumOptionsRu = {
    'brick': 'Кирпич',
    'panel': 'Панель',
    'monolith': 'Монолит',
    'block': 'Блок',
    'adobe': 'Саман',
    'frame': 'Каркас',
    'concrete': 'Бетон',
    'euro': 'Евро',
    'cosmetic': 'Косметический',
    'designer': 'Дизайнерский',
    'needs_repair': 'Без ремонта',
    'furnished': 'С мебелью',
    'semi': 'Частично',
    'unfurnished': 'Без мебели',
    'central': 'Центральное',
    'gas': 'Газ',
    'electric': 'Электрическое',
    'solid_fuel': 'Твёрдое',
    'office': 'Офис',
    'retail': 'Магазин',
    'warehouse': 'Склад',
    'restaurant': 'Ресторан',
    'hotel': 'Отель',
    'residential': 'Жилая',
    'agricultural': 'С/х',
    'industrial': 'Промышленная',
    'commercial': 'Коммерческая',
    'all': 'Все',
    'electricity_only': 'Только свет',
    'none': 'Нет',
    'daily': 'Посуточно',
    'monthly': 'Помесячно',
    'long_term': 'Долгосрочно',
  };

  Widget _buildAttributeField(
      String key, Map<String, dynamic> schema, String lang) {
    final label = lang == 'ru'
        ? (schema['label_ru'] ?? _attrLabelsRu[key] ?? key.replaceAll('_', ' '))
        : (schema['label_en'] ?? key.replaceAll('_', ' '));
    final type = schema['type'] ?? 'string';
    final required = schema['required'] == true;

    if (type == 'enum') {
      final options = (schema['options'] as List?)?.cast<String>() ?? [];
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<String>(
          value: _attributes[key]?.toString(),
          decoration:
              InputDecoration(labelText: '$label${required ? " *" : ""}'),
          items: options
              .map((o) => DropdownMenuItem(
                  value: o,
                  child: Text(lang == 'ru' ? (_enumOptionsRu[o] ?? o) : o)))
              .toList(),
          onChanged: (v) => setState(() => _attributes[key] = v),
          validator: required ? (v) => v == null ? 'Обязательное' : null : null,
        ),
      );
    }
    if (type == 'boolean') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SwitchListTile(
          title: Text(label),
          value: _attributes[key] == true,
          onChanged: (v) => setState(() => _attributes[key] = v),
          contentPadding: EdgeInsets.zero,
        ),
      );
    }
    // integer, float, string
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: _attributes[key]?.toString() ?? '',
        keyboardType: (type == 'integer' || type == 'float')
            ? TextInputType.number
            : TextInputType.text,
        decoration: InputDecoration(labelText: '$label${required ? " *" : ""}'),
        onChanged: (v) {
          if (type == 'integer')
            _attributes[key] = int.tryParse(v);
          else if (type == 'float')
            _attributes[key] = double.tryParse(v);
          else
            _attributes[key] = v;
        },
        validator: required
            ? (v) => (v == null || v.isEmpty) ? 'Обязательное' : null
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final lang = ref.watch(localeProvider);
    final cats = ref.watch(categoriesProvider).valueOrNull ?? [];

    // Load schema on first build if editing
    if (_isEdit && _currentSchema == null && cats.isNotEmpty) {
      final cat = cats.where((c) => c.id == _categoryId).firstOrNull;
      _currentSchema = cat?.attributesSchema;
    }

    return Scaffold(
      appBar: AppBar(
          title: Text(_isEdit ? loc.editListing : loc.createListing),
          backgroundColor: AppTheme.appBarBg),
      body: Form(
          key: _formKey,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            // Category
            DropdownButtonFormField<int>(
                value: _categoryId,
                decoration: InputDecoration(labelText: loc.selectCategory),
                items: cats
                    .map((c) => DropdownMenuItem(
                        value: c.id, child: Text(c.name(lang))))
                    .toList(),
                onChanged: (v) => _onCategoryChanged(v, cats),
                validator: (v) => v == null ? 'Обязательное' : null),
            const SizedBox(height: 14),

            // Title
            TextFormField(
                controller: _title,
                decoration: InputDecoration(
                    labelText: loc.title, hintText: loc.enterTitle),
                validator: (v) =>
                    v != null && v.length >= 3 ? null : 'Минимум 3 символа'),
            const SizedBox(height: 14),

            // Description
            TextFormField(
                controller: _desc,
                maxLines: 4,
                decoration: InputDecoration(
                    labelText: loc.description, hintText: loc.enterDescription),
                validator: (v) =>
                    v != null && v.length >= 10 ? null : 'Минимум 10 символов'),
            const SizedBox(height: 14),

            // Price + Negotiable
            Row(children: [
              Expanded(
                  child: TextFormField(
                      controller: _price,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          labelText: loc.price, prefixText: '\$ '),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Обязательное';
                        if (double.tryParse(v) == null) return 'Число';
                        return null;
                      })),
              const SizedBox(width: 12),
              Column(children: [
                Text(loc.negotiable, style: const TextStyle(fontSize: 12)),
                Switch(
                    value: _negotiable,
                    onChanged: (v) => setState(() => _negotiable = v),
                    activeColor: AppTheme.primary)
              ]),
            ]),
            const SizedBox(height: 14),

            // City
            TextFormField(
                controller: _city,
                decoration: InputDecoration(
                    labelText: loc.city, hintText: loc.enterCity),
                validator: (v) =>
                    v != null && v.isNotEmpty ? null : 'Обязательное'),
            const SizedBox(height: 14),

            // Condition
            DropdownButtonFormField<String>(
                value: _condition,
                decoration: InputDecoration(labelText: loc.selectCondition),
                items: [
                  DropdownMenuItem(
                      value: 'new_building', child: Text(loc.conditionNew)),
                  DropdownMenuItem(
                      value: 'renovated', child: Text(loc.conditionLikeNew)),
                  DropdownMenuItem(
                      value: 'secondary', child: Text(loc.conditionGood)),
                  DropdownMenuItem(
                      value: 'needs_renovation',
                      child: Text(loc.conditionFair)),
                  DropdownMenuItem(
                      value: 'under_construction',
                      child: Text(loc.conditionParts)),
                ],
                onChanged: (v) => setState(() => _condition = v)),
            const SizedBox(height: 16),

            // ── Dynamic Category Attributes ──
            if (_currentSchema != null && _currentSchema!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.tune, size: 18, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        Text('Характеристики',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: Colors.grey[800])),
                      ]),
                      const SizedBox(height: 14),
                      ..._currentSchema!.entries.map((e) =>
                          _buildAttributeField(
                              e.key, e.value as Map<String, dynamic>, lang)),
                    ]),
              ),
              const SizedBox(height: 16),
            ],

            // Location
            OutlinedButton.icon(
                onPressed: _pickLocation,
                icon: const Icon(Icons.map),
                label: Text(_location != null
                    ? '${_location!.latitude.toStringAsFixed(4)}, ${_location!.longitude.toStringAsFixed(4)}'
                    : loc.selectLocation)),
            const SizedBox(height: 16),

            // Photos
            Text(loc.addPhotos, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_isEdit && widget.existing!.media.isNotEmpty) ...[
              SizedBox(
                  height: 80,
                  child: ListView(scrollDirection: Axis.horizontal, children: [
                    for (final m in widget.existing!.media)
                      Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(mediaUrl(m.fileUrl),
                                  width: 80, height: 80, fit: BoxFit.cover))),
                  ])),
              const SizedBox(height: 8),
            ],
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (int i = 0; i < _newImages.length; i++)
                Stack(children: [
                  ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(_newImages[i].bytes,
                          width: 80, height: 80, fit: BoxFit.cover)),
                  Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                          onTap: () => setState(() => _newImages.removeAt(i)),
                          child: Container(
                              decoration: const BoxDecoration(
                                  color: Colors.red, shape: BoxShape.circle),
                              child: const Icon(Icons.close,
                                  size: 18, color: Colors.white)))),
                ]),
              GestureDetector(
                  onTap: _pickImages,
                  child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                          border: Border.all(
                              color: Colors.grey[300]!,
                              width: 2,
                              strokeAlign: BorderSide.strokeAlignInside),
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.grey[50]),
                      child: Icon(Icons.add_photo_alternate_outlined,
                          color: Colors.grey[400], size: 28))),
            ]),
            const SizedBox(height: 28),

            // Submit
            Row(children: [
              Expanded(
                  child: OutlinedButton(
                      onPressed: _submitting
                          ? null
                          : () => _submit(submitForReview: false),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: Text(loc.saveDraft))),
              const SizedBox(width: 12),
              Expanded(
                  child: ElevatedButton(
                      onPressed: _submitting
                          ? null
                          : () => _submit(submitForReview: true),
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(loc.submitForReview))),
            ]),
            const SizedBox(height: 24),
          ])),
    );
  }
}

class _MapPicker extends StatefulWidget {
  final LatLng initial;
  final ValueChanged<LatLng> onPicked;
  const _MapPicker({required this.initial, required this.onPicked});
  @override
  State<_MapPicker> createState() => _MapPickerState();
}

class _MapPickerState extends State<_MapPicker> {
  late LatLng _selected;
  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Выберите место'),
        content: SizedBox(
            width: double.maxFinite,
            height: 350,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FlutterMap(
                options: MapOptions(
                    initialCenter: _selected,
                    initialZoom: 12,
                    onTap: (_, ll) => setState(() => _selected = ll)),
                children: [
                  TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
                  MarkerLayer(markers: [
                    Marker(
                        point: _selected,
                        child: const Icon(Icons.location_pin,
                            color: Colors.red, size: 40))
                  ])
                ],
              ),
            )),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена')),
          ElevatedButton(
              onPressed: () {
                widget.onPicked(_selected);
                Navigator.pop(context);
              },
              child: const Text('Готово'))
        ],
      );
}
