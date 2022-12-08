import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:puppeteer/puppeteer.dart';
import 'package:test/test.dart';

void main() {
  late Browser browser;
  late BrowserContext context;
  late Page page;

  setUpAll(() async {
    var extensionPath = p.join('test', 'assets', 'simple-devtools-extension');
    var extensionOptions = [
      '--disable-extensions-except=$extensionPath',
      '--load-extension=$extensionPath',
    ];

    browser = await puppeteer.launch(devTools: true, args: extensionOptions);
  });

  tearDownAll(() async {
    await browser.close();
  });

  setUp(() async {
    context = await browser.createIncognitoBrowserContext();
    page = (await browser.pages).first;
  });

  tearDown(() async {
    await context.close();
  });

  group('Chrome DevTools', () {
    test('should be able to set type to be a "page"', () async {
      await page.bringToFront();
      final devToolsTarget = browser.targets
          .firstWhere((target) => target.url.startsWith('devtools://devtools'));
      expect(devToolsTarget.isPage, equals(false));
      devToolsTarget.type = 'page';
      expect(devToolsTarget.isPage, equals(true));
    });

    // Note: The following test checks that an extension panel added by
    // a Chrome Extension can be interacted with as described in:
    // https://github.com/puppeteer/puppeteer/issues/4247#issue-429876229
    test('should be able to interact with a DevTools Chrome Extension',
        () async {
      await page.bringToFront();
      // Set the devtools target type to be a "page":
      final devToolsTarget = browser.targets
          .firstWhere((target) => target.url.startsWith('devtools://devtools'));
      devToolsTarget.type = 'page';
      final devToolsPage = await devToolsTarget.page;
      // Slight delay to guarantee that the extension panel has been added:
      await Future.delayed(Duration(milliseconds: 500));
      var panelTargetFuture =
          browser.waitForTarget((target) => target.url.contains('panel.html'));
      // Toggle to the last panel in Chrome DevTools:
      await devToolsPage.keyboard.down(_modifierKey);
      await devToolsPage.keyboard.press(Key.bracketLeft);
      await devToolsPage.keyboard.press(_modifierKey);
      // Set the panel target type to be a "page":
      var panelTarget = await panelTargetFuture;
      panelTarget.type = 'page';
      var panelPage = await panelTarget.page;
      // The DOM added by the Chrome Extension is in the panel's frame:
      var frame = panelPage.frames[0];
      var panelElement = await frame.$OrNull('#simple-devtools-extension');
      expect(panelElement, isNotNull);
    });
  });
}

Key get _modifierKey => Platform.isMacOS ? Key.meta : Key.control;