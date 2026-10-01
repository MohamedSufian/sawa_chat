import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/utils/error_message.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/session_controller.dart';
import '../data/profile_repository.dart';

enum _UsernameCheck { idle, checking, available, taken, invalid }

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  static const _totalSteps = 2;

  final _pageController = PageController();
  final _step1Key = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();

  int _step = 0;
  File? _avatar;
  bool _saving = false;
  _UsernameCheck _usernameCheck = _UsernameCheck.idle;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _pageController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _goTo(int step) {
    FocusScope.of(context).unfocus();
    setState(() => _step = step);
    _pageController.animateToPage(step, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
  }

  void _next() {
    if (_step1Key.currentState!.validate()) _goTo(1);
  }

  void _onUsernameChanged(String value) {
    _debounce?.cancel();
    final username = value.toLowerCase();
    if (!ProfileRepository.usernamePattern.hasMatch(username)) {
      setState(() => _usernameCheck = username.isEmpty ? _UsernameCheck.idle : _UsernameCheck.invalid);
      return;
    }
    setState(() => _usernameCheck = _UsernameCheck.checking);
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        final available = await ref.read(profileRepositoryProvider).isUsernameAvailable(username);
        // Ignore stale answers if the user kept typing.
        if (!mounted || _usernameController.text.toLowerCase() != username) return;
        setState(() => _usernameCheck = available ? _UsernameCheck.available : _UsernameCheck.taken);
      } catch (_) {
        if (mounted) setState(() => _usernameCheck = _UsernameCheck.idle);
      }
    });
  }

  Future<void> _pickAvatar() async {
    final l10n = context.l10n;
    final source = await showModalBottomSheet<ImageSource?>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.pickFromGallery),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.takePhoto),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            if (_avatar != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(l10n.removePhoto),
                onTap: () {
                  setState(() => _avatar = null);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await ImagePicker().pickImage(source: source, maxWidth: 1024, imageQuality: 90);
    if (picked != null) setState(() => _avatar = File(picked.path));
  }

  Future<void> _finish() async {
    if (_usernameCheck != _UsernameCheck.available) {
      _onUsernameChanged(_usernameController.text);
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(profileRepositoryProvider);
      final avatarUrl = _avatar == null ? null : await repo.uploadAvatar(_avatar!);
      final profile = await repo.create(
        username: _usernameController.text,
        displayName: _nameController.text,
        bio: _bioController.text,
        avatarUrl: avatarUrl,
      );
      ref.read(sessionControllerProvider.notifier).profileCreated(profile);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showErrorSnack(context, errorMessage(context.l10n, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goTo(0);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.setupTitle),
          leading: _step > 0 ? BackButton(onPressed: () => _goTo(0)) : null,
          automaticallyImplyLeading: false,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(value: (_step + 1) / _totalSteps),
          ),
        ),
        body: SafeArea(
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [_buildStep1(l10n, theme), _buildStep2(l10n, theme)],
          ),
        ),
      ),
    );
  }

  Widget _stepHeader(String subtitle, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.setupStep(_step + 1, _totalSteps),
          style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _buildStep1(AppLocalizations l10n, ThemeData theme) {
    final scheme = theme.colorScheme;
    return Form(
      key: _step1Key,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _stepHeader(l10n.setupStep1Subtitle, theme),
          Center(
            child: GestureDetector(
              onTap: _pickAvatar,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 64,
                    backgroundColor: scheme.primaryContainer,
                    foregroundImage: _avatar == null ? null : FileImage(_avatar!),
                    child: Icon(Icons.person_rounded, size: 64, color: scheme.onPrimaryContainer),
                  ),
                  PositionedDirectional(
                    bottom: 0,
                    end: 0,
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: scheme.primary,
                      child: Icon(Icons.photo_camera_rounded, size: 20, color: scheme.onPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            maxLength: 40,
            decoration: InputDecoration(labelText: l10n.displayName, prefixIcon: const Icon(Icons.badge_outlined)),
            validator: (v) => (v == null || v.trim().isEmpty) ? l10n.displayNameRequired : null,
            onFieldSubmitted: (_) => _next(),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _next, child: Text(l10n.next)),
        ],
      ),
    );
  }

  Widget _buildStep2(AppLocalizations l10n, ThemeData theme) {
    final scheme = theme.colorScheme;
    final (String? helper, String? error, Widget? suffix) = switch (_usernameCheck) {
      _UsernameCheck.idle => (l10n.usernameHelper, null, null),
      _UsernameCheck.checking => (
        l10n.usernameHelper,
        null,
        const Padding(
          padding: EdgeInsets.all(14),
          child: SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
      _UsernameCheck.available => (
        l10n.usernameAvailable,
        null,
        Icon(Icons.check_circle_rounded, color: scheme.primary),
      ),
      _UsernameCheck.taken => (null, l10n.usernameTaken, Icon(Icons.cancel_rounded, color: scheme.error)),
      _UsernameCheck.invalid => (null, l10n.usernameInvalid, null),
    };

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _stepHeader(l10n.setupStep2Subtitle, theme),
        Directionality(
          textDirection: TextDirection.ltr,
          child: TextField(
            controller: _usernameController,
            autocorrect: false,
            enableSuggestions: false,
            maxLength: 20,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
              TextInputFormatter.withFunction((_, next) => next.copyWith(text: next.text.toLowerCase())),
            ],
            decoration: InputDecoration(
              labelText: l10n.username,
              prefixText: '@',
              helperText: helper,
              errorText: error,
              suffixIcon: suffix,
            ),
            onChanged: _onUsernameChanged,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _bioController,
          maxLength: 140,
          maxLines: 3,
          minLines: 1,
          decoration: InputDecoration(labelText: l10n.bio, hintText: l10n.bioHint),
        ),
        const SizedBox(height: 16),
        LoadingButton(
          label: l10n.finish,
          loading: _saving,
          onPressed: _usernameCheck == _UsernameCheck.available ? _finish : null,
        ),
      ],
    );
  }
}
