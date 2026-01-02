import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termux_flutter_ide/core/responsive.dart';

void main() {
  group('Responsive Unit Tests', () {
    testWidgets('Detection of Mobile form factor', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(400, 800)),
          child: Builder(builder: (context) {
            expect(Responsive.isMobile(context), isTrue);
            expect(Responsive.getFormFactor(context), DeviceFormFactor.mobile);
            return const Placeholder();
          }),
        ),
      );
    });

    testWidgets('Detection of Tablet form factor', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(800, 1000)),
          child: Builder(builder: (context) {
            expect(Responsive.isTablet(context), isTrue);
            expect(Responsive.getFormFactor(context), DeviceFormFactor.tablet);
            return const Placeholder();
          }),
        ),
      );
    });

    testWidgets('Detection of Desktop form factor', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(1600, 1000)),
          child: Builder(builder: (context) {
            expect(Responsive.isDesktop(context), isTrue);
            expect(Responsive.getFormFactor(context), DeviceFormFactor.desktop);
            return const Placeholder();
          }),
        ),
      );
    });

    testWidgets('Detection of Cover Screen', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data:
              const MediaQueryData(size: Size(450, 1000)), // High aspect ratio
          child: Builder(builder: (context) {
            expect(Responsive.isCoverScreen(context), isTrue);
            // Form factor should fallback to mobile if no fold is detected
            expect(Responsive.getFormFactor(context), DeviceFormFactor.mobile);
            return const Placeholder();
          }),
        ),
      );
    });

    testWidgets('Detection of Flex Mode', (tester) async {
      const flexDisplayFeature = DisplayFeature(
        bounds: Rect.fromLTWH(0, 400, 800, 20),
        type: DisplayFeatureType.fold,
        state: DisplayFeatureState.postureHalfOpened,
      );

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(800, 900),
            displayFeatures: [flexDisplayFeature],
          ),
          child: Builder(builder: (context) {
            expect(Responsive.isFlexMode(context), isTrue);
            expect(Responsive.getFlexModeSplitPosition(context), 400.0);
            return const Placeholder();
          }),
        ),
      );
    });

    testWidgets('Detection of Unfolded Foldable (Flat)', (tester) async {
      const flatFoldDisplayFeature = DisplayFeature(
        bounds: Rect.fromLTWH(390, 0, 20, 800), // Vertical hinge
        type: DisplayFeatureType.fold,
        state: DisplayFeatureState.postureFlat,
      );

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(800, 800),
            displayFeatures: [flatFoldDisplayFeature],
          ),
          child: Builder(builder: (context) {
            expect(Responsive.isFoldableOpen(context), isTrue);
            expect(Responsive.isFlexMode(context), isFalse);
            expect(Responsive.getFormFactor(context),
                DeviceFormFactor.foldableOpen);
            // Hinge width test
            expect(Responsive.getHingeWidth(context), 20.0);
            return const Placeholder();
          }),
        ),
      );
    });
  });
}
