import 'package:flutter/widgets.dart';
import 'package:sileo_toast/sileo_toast.dart';

void main() => runApp(const _App());

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      color: const Color(0xFFFFFFFF),
      builder: (context, _) => const Directionality(
        textDirection: TextDirection.ltr,
        child: SileoToaster(
          theme: SileoThemeMode.light,
          textStyle: TextStyle(
            fontSize: 14,
            color: Color(0xFFFFFFFF),
            decoration: TextDecoration.none,
          ),
          child: _Home(),
        ),
      ),
      pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
        settings: settings,
        pageBuilder: (context, _, _) => builder(context),
      ),
    );
  }
}

class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) {
    final sileo = Sileo.of(context);
    return ColoredBox(
      color: const Color(0xFFF5F5F5),
      child: Center(
        child: Wrap(
          spacing: 12,
          children: [
            _Button(
              label: 'Success',
              onTap: () => sileo.success(
                SileoOptions(
                  title: 'Saved',
                  description: const Text('Your changes are live.'),
                ),
              ),
            ),
            _Button(
              label: 'Large',
              onTap: () => sileo.success(
                SileoOptions(
                  title: 'Order shipped',
                  description: const Text('Your parcel is on its way.'),
                  size: SileoSize.large,
                  trailing: const ColoredBox(color: Color(0xFF4F8EF7)),
                  button: SileoButton(title: 'Track', onPressed: () {}),
                  secondaryButton: SileoButton(
                    title: 'Later',
                    onPressed: () {},
                  ),
                ),
              ),
            ),
            _Button(
              label: 'Island',
              onTap: () => sileo.info(
                SileoOptions(
                  title: 'Now playing',
                  description: const Text('Grown out of the camera cutout.'),
                  position: SileoPosition.island,
                ),
              ),
            ),
            _Button(
              label: 'Error',
              onTap: () => sileo.error(SileoOptions(title: 'Failed')),
            ),
            _Button(
              label: 'Promise',
              onTap: () => sileo.promise(
                Future<String>.delayed(const Duration(seconds: 2), () => 'ok'),
                SileoPromiseOptions<String>(
                  loading: SileoOptions(title: 'Loading'),
                  success: (data) => SileoOptions(title: 'Done: $data'),
                  error: (e) => SileoOptions(title: 'Failed'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ColoredBox(
        color: const Color(0xFF1A1A1A),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 14),
          ),
        ),
      ),
    );
  }
}
