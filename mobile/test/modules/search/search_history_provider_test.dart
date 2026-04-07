import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tum2/modules/search/providers/search_history_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SearchHistoryNotifier', () {
    test('deduplica, respeta maximo 10 y persiste', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = SearchHistoryNotifier();

      for (var i = 0; i < 12; i++) {
        await notifier.add('busqueda-$i');
      }
      await notifier.add('Busqueda-5');

      expect(notifier.state.length, 10);
      expect(notifier.state.first, 'Busqueda-5');
      expect(
          notifier.state
              .where((item) => item.toLowerCase() == 'busqueda-5')
              .length,
          1);

      final reloaded = SearchHistoryNotifier();
      await reloaded.load();
      expect(reloaded.state.length, 10);
      expect(reloaded.state.first, 'Busqueda-5');
    });
  });
}
