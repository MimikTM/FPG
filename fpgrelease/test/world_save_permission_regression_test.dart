import 'package:flutter_test/flutter_test.dart';
import 'package:fpg/database/world_save.dart';

void main() {
  test('storage preparation never blocks save on unsupported platforms', () async {
    expect(await WorldSave.prepareStorageAccess(), isTrue);
  });
}
