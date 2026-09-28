import 'package:flutter_test/flutter_test.dart';
import 'package:wakeed_app/models/models.dart';
import 'package:wakeed_app/state/app_controller.dart';

void main() {
  test('dialog keeps skipped names through persist json', () {
    final data = DialogData(
      phase: SubmitPhase.success,
      title: 'موجود في السجل',
      message: 'تم تخطي أسماء',
      details: 'تفاصيل',
      skippedNames: ['أحمد', '', 'سارة'],
    );
    expect(data.skippedNames, ['أحمد', 'سارة']);
    final restored = DialogData.fromJson(data.toJson());
    expect(restored.skippedNames, ['أحمد', 'سارة']);
    expect(restored.phase, SubmitPhase.success);
    expect(restored.title, 'موجود في السجل');
  });
}
