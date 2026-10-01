import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phone_form_field/phone_form_field.dart';

import '../../../core/router/routes.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/common.dart';
import '../data/auth_repository.dart';

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controller = PhoneController(
    initialValue: const PhoneNumber(isoCode: IsoCode.PS, nsn: ''),
  );
  bool _loading = false;

  static const _favoriteCountries = [
    IsoCode.PS,
    IsoCode.JO,
    IsoCode.EG,
    IsoCode.SA,
    IsoCode.AE,
    IsoCode.QA,
    IsoCode.TR,
    IsoCode.DE,
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final phone = _controller.value.international;

    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).sendOtp(phone);
      if (mounted) context.push(Routes.otp, extra: phone);
    } catch (e) {
      if (mounted) showErrorSnack(context, errorMessage(context.l10n, e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            children: [
              const Center(child: AppLogo()),
              const SizedBox(height: 32),
              Text(
                l10n.phoneTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.phoneSubtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 32),
              // Phone numbers read left-to-right in every language.
              Directionality(
                textDirection: TextDirection.ltr,
                child: PhoneFormField(
                  controller: _controller,
                  autofocus: true,
                  enabled: !_loading,
                  decoration: InputDecoration(labelText: l10n.phoneLabel),
                  countrySelectorNavigator: const CountrySelectorNavigator.draggableBottomSheet(
                    favorites: _favoriteCountries,
                  ),
                  countryButtonStyle: const CountryButtonStyle(showFlag: true, showDialCode: true),
                  validator: PhoneValidator.compose([
                    PhoneValidator.required(context, errorText: l10n.phoneInvalid),
                    PhoneValidator.validMobile(context, errorText: l10n.phoneInvalid),
                  ]),
                  autofillHints: const [AutofillHints.telephoneNumber],
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(height: 24),
              LoadingButton(label: l10n.sendCode, loading: _loading, onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}
