import 'package:flutter/widgets.dart';

import '../../l10n/gen/app_localizations.dart';

/// Shortcut: `context.l10n.libraryTitle` alih-alih `AppLocalizations.of(context)!.libraryTitle`.
extension L10nExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
