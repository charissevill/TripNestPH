import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/widgets/buttons/animated_button.dart';
import '../../core/widgets/inputs/hero_image_picker.dart';
import '../../data/repositories/business_repository.dart';
import '../../data/repositories/province_repository.dart';
import '../../domain/models/business.dart';
import '../../domain/models/province.dart';

/// A `businessOwner` account's self-service listing. Shows the owner's
/// current listing (any status) with an edit form, or an empty "create
/// yours" state if they haven't listed one yet. Writes go through
/// [BusinessRepository], which matches `firestore.rules`'s owner-scoped
/// permissions exactly — the resubmit-after-rejection flow is a single
/// button, not a separate screen.
class MyBusinessScreen extends StatefulWidget {
  const MyBusinessScreen({super.key, required this.uid});

  final String uid;

  @override
  State<MyBusinessScreen> createState() => _MyBusinessScreenState();
}

class _MyBusinessScreenState extends State<MyBusinessScreen> {
  final BusinessRepository _repository = BusinessRepository();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Symbols.arrow_back_rounded), onPressed: () => context.pop()),
        title: const Text('My Business'),
      ),
      body: SafeArea(
        child: StreamBuilder<List<Business>>(
          stream: _repository.streamForOwner(widget.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final businesses = snapshot.data ?? const [];
            final existing = businesses.isEmpty ? null : businesses.first;
            return _BusinessForm(uid: widget.uid, existing: existing);
          },
        ),
      ),
    );
  }
}

class _BusinessForm extends StatefulWidget {
  const _BusinessForm({required this.uid, this.existing});

  final String uid;
  final Business? existing;

  @override
  State<_BusinessForm> createState() => _BusinessFormState();
}

class _BusinessFormState extends State<_BusinessForm> {
  final BusinessRepository _repository = BusinessRepository();

  late final _nameController = TextEditingController(text: widget.existing?.name ?? '');
  late final _descController = TextEditingController(text: widget.existing?.description ?? '');
  late final _addressController = TextEditingController(text: widget.existing?.address ?? '');
  late final _contactController = TextEditingController(text: widget.existing?.contactNumber ?? '');
  late final _websiteController = TextEditingController(text: widget.existing?.websiteUrl ?? '');
  late String _heroImageUrl = widget.existing?.heroImageUrl ?? '';

  late String _category = widget.existing?.category ?? BusinessCategory.accommodation;
  Province? _selectedProvince;
  late Future<List<Province>> _provincesFuture;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _provincesFuture = ProvinceRepository().getAll().then((provinces) {
      final existingId = widget.existing?.provinceId;
      if (existingId != null) {
        for (final p in provinces) {
          if (p.id == existingId) {
            _selectedProvince = p;
            break;
          }
        }
      }
      return provinces..sort((a, b) => a.name.compareTo(b.name));
    });
  }

  @override
  void dispose() {
    for (final c in [_nameController, _descController, _addressController, _contactController, _websiteController]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save({bool resubmit = false}) async {
    final province = _selectedProvince;
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Business name is required.')));
      return;
    }
    if (province == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Province is required.')));
      return;
    }
    if (_descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A short description is required.')));
      return;
    }

    setState(() => _saving = true);
    final business = Business(
      id: widget.existing?.id ?? '',
      ownerId: widget.uid,
      name: _nameController.text.trim(),
      category: _category,
      description: _descController.text.trim(),
      provinceId: province.id,
      provinceName: province.name,
      address: _addressController.text.trim(),
      contactNumber: _contactController.text.trim(),
      websiteUrl: _websiteController.text.trim(),
      heroImageUrl: _heroImageUrl,
    );

    try {
      if (widget.existing == null) {
        await _repository.create(business);
      } else if (resubmit) {
        await _repository.resubmit(widget.existing!.id, business);
      } else {
        await _repository.update(widget.existing!.id, business);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.existing == null ? 'Listing submitted for review.' : 'Listing updated.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _statusBanner(Business business) {
    final theme = Theme.of(context);
    switch (business.status) {
      case 'approved':
        return _Banner(color: AppColors.success, icon: Symbols.check_circle_rounded, text: 'Live — travelers can see this listing on your province page.');
      case 'rejected':
        return _Banner(
          color: AppColors.error,
          icon: Symbols.error_rounded,
          text: business.rejectionReason.isEmpty ? 'Rejected. Edit and resubmit below.' : 'Rejected: ${business.rejectionReason}\nEdit and resubmit below.',
        );
      case 'suspended':
        return const _Banner(color: AppColors.error, icon: Symbols.block_rounded, text: 'Suspended by an admin — contact support if you believe this is a mistake.');
      default:
        return _Banner(color: AppColors.warning, icon: Symbols.hourglass_top_rounded, text: 'Pending review.', textStyle: theme.textTheme.bodyMedium);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Province>>(
      future: _provincesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final provinces = snapshot.data ?? const [];
        final existing = widget.existing;
        return ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.huge),
          children: [
            if (existing != null) ...[_statusBanner(existing), const SizedBox(height: AppSpacing.lg)],
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Business Name')),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: BusinessCategory.all.map((c) => DropdownMenuItem(value: c, child: Text(BusinessCategory.label(c)))).toList(),
              onChanged: (value) => setState(() => _category = value ?? _category),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<Province>(
              initialValue: _selectedProvince,
              decoration: const InputDecoration(labelText: 'Province'),
              isExpanded: true,
              items: provinces.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
              onChanged: (value) => setState(() => _selectedProvince = value),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(controller: _descController, maxLines: 4, decoration: const InputDecoration(labelText: 'Description', alignLabelWithHint: true)),
            const SizedBox(height: AppSpacing.md),
            TextField(controller: _addressController, decoration: const InputDecoration(labelText: 'Address')),
            const SizedBox(height: AppSpacing.md),
            TextField(controller: _contactController, decoration: const InputDecoration(labelText: 'Contact Number')),
            const SizedBox(height: AppSpacing.md),
            TextField(controller: _websiteController, decoration: const InputDecoration(labelText: 'Website URL')),
            const SizedBox(height: AppSpacing.md),
            HeroImagePicker(
              imageUrl: _heroImageUrl,
              folder: FirestorePaths.storageBusinessGallery,
              ownerId: widget.uid,
              onChanged: (url) => setState(() => _heroImageUrl = url),
            ),
            const SizedBox(height: AppSpacing.xxl),
            AnimatedButton(
              label: existing == null ? 'Submit for Review' : (existing.isRejected ? 'Edit & Resubmit' : 'Save Changes'),
              isLoading: _saving,
              onPressed: () => _save(resubmit: existing?.isRejected ?? false),
            ),
          ],
        );
      },
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.color, required this.icon, required this.text, this.textStyle});

  final Color color;
  final IconData icon;
  final String text;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: (textStyle ?? const TextStyle()).copyWith(color: color))),
        ],
      ),
    );
  }
}
