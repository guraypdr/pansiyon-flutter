import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/features/duty/domain/duty_models.dart';
import 'package:pansiyon_yonetim/features/duty/presentation/duty_settings_tab.dart';

/// Sekmeyi gerçek davranışıyla besleyen konteyner: kaydedilen ayarları
/// saklar ve bir sonraki karede widget'a geri verir.
class _SettingsHost extends StatefulWidget {
  const _SettingsHost({
    required this.initial,
    required this.onSaved,
  });

  final DutySettings initial;
  final ValueChanged<DutySettings> onSaved;

  @override
  State<_SettingsHost> createState() => _SettingsHostState();
}

class _SettingsHostState extends State<_SettingsHost> {
  late DutySettings _settings = widget.initial;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: DutySettingsTab(
          settings: _settings,
          sections: const [null],
          selectedSectionKey: null,
          floorOptions: const ['A Blok - Zemin Kat', 'B Blok - 1. Kat'],
          calendarYear: 2026,
          calendarMonth: 10,
          onSectionChanged: (_) {},
          onCalendarChanged: (_, _) {},
          onSaveSettings: (value) async {
            setState(() => _settings = value);
            widget.onSaved(value);
          },
        ),
      ),
    );
  }
}

void main() {
  // Nöbet yerleri kullanıcı tarafından serbestçe yazılabilir; hazır blok/kat
  // listesi yalnızca bir kısayol. Bu testler manuel girişi korur.

  Future<void> pumpSettings(
    WidgetTester tester,
    ValueChanged<DutySettings> onSaved, {
    DutySettings initial = const DutySettings(sectionKey: null, dailyCount: 2),
  }) => tester.pumpWidget(_SettingsHost(initial: initial, onSaved: onSaved));

  Finder fieldFor(int slot) => find.descendant(
    of: find.byKey(Key('duty_location_slot_$slot')),
    matching: find.byType(TextField),
  );

  Future<void> submit(WidgetTester tester, int slot, String value) async {
    await tester.enterText(fieldFor(slot), value);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  testWidgets('nöbet yeri kutusu yazılabilir bir metin alanıdır', (
    tester,
  ) async {
    await pumpSettings(tester, (_) {});

    expect(fieldFor(0), findsOneWidget);
  });

  testWidgets('kullanıcının yazdığı ad kaydedilir', (tester) async {
    var saved = const DutySettings(sectionKey: null, dailyCount: 2);
    await pumpSettings(tester, (value) => saved = value);

    await submit(tester, 0, 'Gece Nöbeti');

    expect(saved.locationForSlot(0), 'Gece Nöbeti');
  });

  testWidgets('listede olmayan ad da kabul edilir', (tester) async {
    var saved = const DutySettings(sectionKey: null, dailyCount: 2);
    await pumpSettings(tester, (value) => saved = value);

    await submit(tester, 1, 'Bahçe Kapısı Önü');

    expect(saved.locationForSlot(1), 'Bahçe Kapısı Önü');
  });

  testWidgets('alan boşaltılırsa nöbet yeri temizlenir', (tester) async {
    var saved = const DutySettings(
      sectionKey: null,
      dailyCount: 2,
      locations: ['A Blok - Zemin Kat', 'B Blok'],
    );
    await pumpSettings(
      tester,
      (value) => saved = value,
      initial: const DutySettings(
        sectionKey: null,
        dailyCount: 2,
        locations: ['A Blok - Zemin Kat', 'B Blok'],
      ),
    );

    await submit(tester, 0, '');

    expect(saved.locationForSlot(0), isEmpty);
    expect(saved.locationForSlot(1), 'B Blok');
  });

  testWidgets('hazır liste düğmesi açılır', (tester) async {
    await pumpSettings(tester, (_) {});

    await tester.tap(find.byIcon(Icons.expand_more_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('A Blok - Zemin Kat'), findsWidgets);
  });
}
