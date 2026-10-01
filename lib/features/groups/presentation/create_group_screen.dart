import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/routes.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/common.dart';
import '../../profile/domain/profile.dart';
import '../data/group_repository.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key, required this.members});

  final List<Profile> members;

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  File? _avatar;
  bool _creating = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024);
    if (picked != null) setState(() => _avatar = File(picked.path));
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _creating = true);
    try {
      final chatId = await ref
          .read(groupRepositoryProvider)
          .create(name: _name.text.trim(), memberIds: [for (final m in widget.members) m.id], avatar: _avatar);
      if (!mounted) return;
      // Reset the stack to Chats, then open the new group on top of it.
      context.go(Routes.chats);
      context.push(Routes.chat(chatId));
    } catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      showErrorSnack(context, errorMessage(context.l10n, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.newGroup)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickAvatar,
                child: CircleAvatar(
                  radius: 52,
                  backgroundColor: scheme.primaryContainer,
                  foregroundImage: _avatar == null ? null : FileImage(_avatar!),
                  child: Icon(Icons.add_a_photo_outlined, size: 36, color: scheme.onPrimaryContainer),
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _name,
              autofocus: true,
              maxLength: 50,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l10n.groupName, prefixIcon: const Icon(Icons.groups_outlined)),
              validator: (v) => (v == null || v.trim().isEmpty) ? l10n.groupNameRequired : null,
              onFieldSubmitted: (_) => _create(),
            ),
            const SizedBox(height: 8),
            Text(l10n.membersCount(widget.members.length + 1), style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in widget.members)
                  Chip(
                    avatar: UserAvatar(url: m.avatarUrl, name: m.displayName, radius: 12),
                    label: Text(m.displayName),
                  ),
              ],
            ),
            const SizedBox(height: 32),
            LoadingButton(label: l10n.create, loading: _creating, onPressed: _create),
          ],
        ),
      ),
    );
  }
}
