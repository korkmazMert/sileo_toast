import 'package:material_ui/material_ui.dart';
import 'package:sileo_toast/sileo_toast.dart';

import 'package:sileo_toast_example/playground_page.dart';

void main() => runApp(const SileoExampleApp());

/// Light and dark follow the system.
class SileoExampleApp extends StatelessWidget {
  const new({super.key});

  static const _seed = Color(0xFF3B5BDB);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'sileo_toast playground',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: _seed),
      darkTheme: ThemeData(colorSchemeSeed: _seed, brightness: Brightness.dark),
      // Above the Navigator, so toasts outlive route changes.
      builder: (context, child) {
        final theme = Theme.of(context);
        return SileoToaster(
          theme: theme.brightness == Brightness.dark
              ? SileoThemeMode.dark
              : SileoThemeMode.light,
          textStyle: theme.textTheme.bodyMedium,
          child: child!,
        );
      },
      home: const PlaygroundPage(),
    );
  }
}
