import 'package:flutter_test/flutter_test.dart';
import 'package:activity_tracker/main.dart';

void main() {
  testWidgets('App renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const ActivityTrackerApp());
    expect(find.text('Activity Tracker'), findsOneWidget);
  });
}
