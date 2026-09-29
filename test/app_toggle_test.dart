import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/shared/widgets/app_toggle.dart';

class _ToggleHost extends StatefulWidget {
  const _ToggleHost({
    this.initialValue = false,
    this.offLabel,
    this.onLabel,
    this.showValueLabel = true,
    this.enabled = true,
    this.onChanged,
  });

  final bool initialValue;
  final String? offLabel;
  final String? onLabel;
  final bool showValueLabel;
  final bool enabled;
  final ValueChanged<bool>? onChanged;

  @override
  State<_ToggleHost> createState() => _ToggleHostState();
}

class _ToggleHostState extends State<_ToggleHost> {
  late bool _value = widget.initialValue;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 420,
            child: AppToggle(
              label: 'Test Anahtarı',
              description: 'Açıklama metni.',
              icon: Icons.info_outline,
              value: _value,
              enabled: widget.enabled,
              offLabel: widget.offLabel,
              onLabel: widget.onLabel,
              showValueLabel: widget.showValueLabel,
              onChanged: (next) {
                widget.onChanged?.call(next);
                setState(() => _value = next);
              },
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('kapalıyken Hayır, açıkken Evet yazar', (tester) async {
    var value = false;

    await tester.pumpWidget(_ToggleHost(onChanged: (next) => value = next));
    await tester.pumpAndSettle();

    expect(find.text('Hayır'), findsOneWidget);
    expect(find.text('Evet'), findsNothing);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(value, isTrue);
    expect(find.text('Evet'), findsOneWidget);
    expect(find.text('Hayır'), findsNothing);
  });

  testWidgets('durum metni etiket ve açıklamayla birlikte görünür', (
    tester,
  ) async {
    await tester.pumpWidget(const _ToggleHost());
    await tester.pumpAndSettle();

    expect(find.text('Test Anahtarı'), findsOneWidget);
    expect(find.text('Açıklama metni.'), findsOneWidget);
    expect(find.text('Hayır'), findsOneWidget);
  });

  testWidgets('özel karşılık metinlerini kullanır', (tester) async {
    await tester.pumpWidget(const _ToggleHost(offLabel: 'Yok', onLabel: 'Var'));
    await tester.pumpAndSettle();

    expect(find.text('Yok'), findsOneWidget);
    expect(find.text('Hayır'), findsNothing);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('Var'), findsOneWidget);
    expect(find.text('Evet'), findsNothing);
  });

  testWidgets('showValueLabel false ile durum metnini gizler', (tester) async {
    await tester.pumpWidget(const _ToggleHost(showValueLabel: false));
    await tester.pumpAndSettle();

    expect(find.byType(Switch), findsOneWidget);
    expect(find.text('Hayır'), findsNothing);
    expect(find.text('Test Anahtarı'), findsOneWidget);
  });

  testWidgets('pasif durumda metin yine de görünür', (tester) async {
    await tester.pumpWidget(
      const _ToggleHost(initialValue: true, enabled: false),
    );
    await tester.pumpAndSettle();

    expect(find.text('Evet'), findsOneWidget);
    final switchFinder = tester.widget<Switch>(find.byType(Switch));
    expect(switchFinder.onChanged, isNull);
  });
}
