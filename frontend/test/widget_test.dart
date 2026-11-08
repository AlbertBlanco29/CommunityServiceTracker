import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('Community Service Tracker login page loads',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CommunityServiceApp());

    expect(find.text('Community Service'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
