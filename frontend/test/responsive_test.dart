import 'package:ecommerce_frontend/core/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Renders a probe under a fixed window (pane) width and reads what the
  // Responsive extension reports — this is exactly the value the app sees when
  // the OS shrinks the window in split view.
  Future<T> readAt<T>(
    WidgetTester tester,
    double width,
    T Function(BuildContext) read,
  ) async {
    late T value;
    await tester.pumpWidget(MediaQuery(
      data: MediaQueryData(size: Size(width, 800)),
      child: Builder(builder: (context) {
        value = read(context);
        return const SizedBox();
      }),
    ));
    return value;
  }

  testWidgets('window class follows the pane width', (tester) async {
    expect(await readAt(tester, 400, (c) => c.windowClass), WindowClass.compact);
    expect(await readAt(tester, 700, (c) => c.windowClass), WindowClass.medium);
    expect(
        await readAt(tester, 1000, (c) => c.windowClass), WindowClass.expanded);
  });

  testWidgets('boundaries are 600 and 840', (tester) async {
    expect(await readAt(tester, 599, (c) => c.windowClass), WindowClass.compact);
    expect(await readAt(tester, 600, (c) => c.windowClass), WindowClass.medium);
    expect(await readAt(tester, 839, (c) => c.windowClass), WindowClass.medium);
    expect(
        await readAt(tester, 840, (c) => c.windowClass), WindowClass.expanded);
  });

  testWidgets('isExpanded gates the permanent side navigation', (tester) async {
    expect(await readAt(tester, 500, (c) => c.isExpanded), isFalse);
    expect(await readAt(tester, 900, (c) => c.isExpanded), isTrue);
  });

  testWidgets('contentMaxWidth grows with the window class', (tester) async {
    expect(await readAt(tester, 400, (c) => c.contentMaxWidth), 600);
    expect(await readAt(tester, 700, (c) => c.contentMaxWidth), 840);
    expect(await readAt(tester, 1000, (c) => c.contentMaxWidth), 1100);
  });
}
