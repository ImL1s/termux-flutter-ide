00:00 +0: loading D:/SideProject/termux-flutter-ide/integration_test/editor_lsp_test.dart
Running Gradle task 'assembleDebug'...                             16.9s
??Built build\app\outputs\flutter-apk\app-debug.apk
Installing build\app\outputs\flutter-apk\app-debug.apk...          16.6s
00:00 +0: LSP UI Integration Test: Auto-completion appears (Mocked)
Starting Termux Environment Fix...
Termux Environment Fix Completed.
UI Dump:
IntegrationTestWidgetsFlutterBinding - DEBUG MODE
[root]
?iew(state: _ViewState#a7d78)
 ?awView
  ?RawViewInternal-[_DeprecatedRawViewKey TestFlutterView#ce88c](renderObject: _ReusableRenderView#62df4)
   ?ViewScope
    ?PipelineOwnerScope
     ?MediaQueryFromView(state: _MediaQueryFromViewState#0db93)
      ?ediaQuery(MediaQueryData(size: Size(384.0, 832.0), devicePixelRatio: 2.8, textScaler: no scaling, platformBrightness: Brightness.dark, padding: EdgeInsets(0.0, 29.9, 0.0, 14.9), viewPadding: EdgeInsets(0.0, 29.9, 0.0, 14.9), viewInsets: EdgeInsets.zero, systemGestureInsets: EdgeInsets(39.8, 42.0, 39.8, 32.0), alwaysUse24HourFormat: false, accessibleNavigation: false, highContrast: false, onOffSwitchLabels: false, disableAnimations: false, invertColors: false, boldText: false, navigationMode: traditional, gestureSettings: DeviceGestureSettings(touchSlop: 8.177777777777777), displayFeatures: [DisplayFeature(rect: Rect.fromLTRB(183.1, 0.0, 201.2, 29.9), type: DisplayFeatureType.cutout, state: DisplayFeatureState.unknown)], supportsShowingSystemContextMenu: false))
       ?ocusTraversalGroup(policy: ReadingOrderTraversalPolicy#5bd7b, state: _FocusTraversalGroupState#d452c)
        ?ocus(debugLabel: "FocusTraversalGroup", focusNode: _FocusTraversalGroupNode#eab46(FocusTraversalGroup [IN FOCUS PATH]), state: _FocusState#85c2c)
         ?FocusInheritedScope
          ?FocusScopeWithExternalFocusNode(debugLabel: "View Scope", focusNode: FocusScopeNode#250ab(View Scope [IN FOCUS PATH]), dependencies: [_FocusInheritedScope], state: _FocusScopeState#9a994)
           ?FocusInheritedScope
            ?epaintBoundary(renderObject: RenderRepaintBoundary#58e41)
             ?roviderScope(state: ProviderScopeState#6da15)
              ?ncontrolledProviderScope
               ?ermuxFlutterIDE(dependencies: [UncontrolledProviderScope], state: _TermuxFlutterIDEState#efa9a)
                ?aterialApp(state: _MaterialAppState#1fa71)
                 ?crollConfiguration(behavior: MaterialScrollBehavior)
                  ?eroControllerScope
                   ?ocus(dependencies: [_FocusInheritedScope], state: _FocusState#0d732)
                    ?FocusInheritedScope
                     ?emantics(container: false, properties: SemanticsProperties, renderObject: RenderSemanticsAnnotations#89640)
                      ?idgetsApp-[GlobalObjectKey _MaterialAppState#1fa71](state: _WidgetsAppState#ef45f)
                       ?ootRestorationScope(state: _RootRestorationScopeState#55407)
                        ?nmanagedRestorationScope
                         ?estorationScope(dependencies: [UnmanagedRestorationScope], state: _RestorationScopeState#ab8b8)
                          ?nmanagedRestorationScope
                           ?haredAppData(state: _SharedAppDataState#9eb71)
                            ?SharedAppModel
                             ?otificationListener<NavigationNotification>
                              ?hortcuts(shortcuts: <Default WidgetsApp Shortcuts>, state: _ShortcutsState#a181b)
                               ?ocus(debugLabel: "Shortcuts", dependencies: [_FocusInheritedScope], state: _FocusState#8eb51)
                                ?FocusInheritedScope
                                 ?emantics(container: false, properties: SemanticsProperties, renderObject: RenderSemanticsAnnotations#d23e2)
                                  ?efaultTextEditingShortcuts
                                   ?hortcuts(shortcuts: <Default Text Editing Shortcuts>, state: _ShortcutsState#fd648)
                                    ?ocus(debugLabel: "Shortcuts", dependencies: [_FocusInheritedScope], state: _FocusState#e8935)
                                     ?FocusInheritedScope
                                      ?emantics(container: false, properties: SemanticsProperties, renderObject: RenderSemanticsAnnotations#3d36d)
                                       ?ctions(dispatcher: null, actions: {DoNothingIntent: DoNothingAction#33176, DoNothingAndStopPropagationIntent: DoNothingAction#846fd, RequestFocusIntent: RequestFocusAction#c67fb, NextFocusIntent: NextFocusAction#c5eaa, PreviousFocusIntent: PreviousFocusAction#efdc0, DirectionalFocusIntent: DirectionalFocusAction#000e8, ScrollIntent: _OverridableContextAction<ScrollIntent>#ccc99(defaultAction: ScrollAction#f5f37), PrioritizedIntents: PrioritizedAction#ab117, VoidCallbackIntent: VoidCallbackAction#06000}, state: _ActionsState#49c27)
                                        ?ActionsScope
                                         ?ocusTraversalGroup(policy: ReadingOrderTraversalPolicy#0aa25, state: _FocusTraversalGroupState#38f2c)
                                          ?ocus(debugLabel: "FocusTraversalGroup", focusNode: _FocusTraversalGroupNode#ff8b8(FocusTraversalGroup [IN FOCUS PATH]), dependencies: [_FocusInheritedScope], state: _FocusState#95a57)
                                           ?FocusInheritedScope
                                            ?apRegionSurface(renderObject: RenderTapRegionSurface#5dbcc)
                                             ?hortcutRegistrar(state: _ShortcutRegistrarState#13a87)
                                              ?ShortcutRegistrarScope
                                               ?hortcuts(manager: ShortcutManager#cddba(shortcuts: {}), shortcuts: {}, state: _ShortcutsState#797b3)
                                                ?ocus(debugLabel: "Shortcuts", dependencies: [_FocusInheritedScope], state: _FocusState#8b2dc)
                                                 ?FocusInheritedScope
                                                  ?emantics(container: false, properties: SemanticsProperties, renderObject: RenderSemanticsAnnotations#6a1f3)
                                                   ?ocalizations(locale: en_US, delegates: [DefaultMaterialLocalizations.delegate(en_US), DefaultCupertinoLocalizations.delegate(en_US), DefaultWidgetsLocalizations.delegate(en_US)], state: _LocalizationsState#1e4e6)
                                                    ?emantics(container: false, properties: SemanticsProperties, textDirection: ltr, renderObject: RenderSemanticsAnnotations#417ba)
                                                     ?LocalizationsScope-[GlobalKey#a3c50]
                                                      ?irectionality(textDirection: ltr)
                                                       ?itle(title: "Termux Flutter IDE", color: Color(alpha: 1.0000, red: 0.0588, green: 0.0824, blue: 0.0706, colorSpace: ColorSpace.sRGB))
                                                        ?alueListenableBuilder<bool>(state: _ValueListenableBuilderState<bool>#9392b)
                                                         ?efaultTextStyle(debugLabel: fallback style; consider putting your text in a Material, inherit: true, color: Color(alpha: 0.8157, red: 1.0000, green: 0.0000, blue: 0.0000, colorSpace: ColorSpace.sRGB), family: monospace, size: 48.0, weight: 900, decoration: double Color(alpha: 1.0000, red: 1.0000, green: 1.0000, blue: 0.0000, colorSpace: ColorSpace.sRGB) TextDecoration.underline, softWrap: wrapping at box width, overflow: clip)
                                                          ?uilder(dependencies: [MediaQuery])
                                                           ?caffoldMessenger-[LabeledGlobalKey<ScaffoldMessengerState>#0374b](dependencies: [MediaQuery], state: ScaffoldMessengerState#64f7c)
                                                            ?ScaffoldMessengerScope
                                                             ?efaultSelectionStyle
                                                              ?nimatedTheme(duration: 200ms, state: _AnimatedThemeState#9dee6(ticker inactive, ThemeDataTween(ThemeData#1e84d ??ThemeData#1e84d)))
                                                               ?heme(ThemeData#1e84d, dependencies: [DefaultSelectionStyle])
                                                                ?InheritedTheme
                                                                 ?upertinoTheme(brightness: dark, primaryColor: Color(alpha: 1.0000, red: 0.5333, green: 0.8392, blue: 0.7333, colorSpace: ColorSpace.sRGB), primaryContrastingColor: Color(alpha: 1.0000, red: 0.0000, green: 0.2196, blue: 0.1686, colorSpace: ColorSpace.sRGB), scaffoldBackgroundColor: Color(alpha: 1.0000, red: 0.1176, green: 0.1176, blue: 0.1804, colorSpace: ColorSpace.sRGB), actionTextStyle: TextStyle(inherit: false, color: Color(alpha: 1.0000, red: 0.5333, green: 0.8392, blue: 0.7333, colorSpace: ColorSpace.sRGB), family: CupertinoSystemText, size: 17.0, letterSpacing: -0.4, decoration: TextDecoration.none), actionSmallTextStyle: TextStyle(inherit: false, color: Color(alpha: 1.0000, red: 0.5333, green: 0.8392, blue: 0.7333, colorSpace: ColorSpace.sRGB), family: CupertinoSystemText, size: 15.0, letterSpacing: -0.2, decoration: TextDecoration.none), navActionTextStyle: TextStyle(inherit: false, color: Color(alpha: 1.0000, red: 0.5333, green: 0.8392, blue: 0.7333, colorSpace: ColorSpace.sRGB), family: CupertinoSystemText, size: 17.0, letterSpacing: -0.4, decoration: TextDecoration.none))
                                                                  ?nheritedCupertinoTheme
                                                                   ?conTheme(color: Color(alpha: 1.0000, red: 0.5333, green: 0.8392, blue: 0.7333, colorSpace: ColorSpace.sRGB))
                                                                    ?conTheme(color: Color(alpha: 1.0000, red: 1.0000, green: 1.0000, blue: 1.0000, colorSpace: ColorSpace.sRGB))
                                                                     ?efaultSelectionStyle
                                                                      ?outer<Object>(dependencies: [UnmanagedRestorationScope], state: _RouterState<Object>#8a15e)
                                                                       ?nmanagedRestorationScope
                                                                        ?RouterScope
                                                                         ?uilder
                                                                          ?nheritedGoRouter(goRouter: Instance of 'GoRouter')
                                                                           ?uilder
                                                                            ?oRouterStateRegistryScope
                                                                             ?nheritedGoRouter(goRouter: Instance of 'GoRouter')
                                                                              ?avigator-[LabeledGlobalKey<NavigatorState>#bb94c](dependencies: [HeroControllerScope, UnmanagedRestorationScope], state: NavigatorState#f6fec(tickers: tracking 1 ticker))
                                                                               ?eroControllerScope
                                                                                ?otificationListener<NavigationNotification>
                                                                                 ?istener(listeners: [down, up, cancel], behavior: deferToChild, renderObject: RenderPointerListener#a0ea0)
                                                                                  ?bsorbPointer(absorbing: false, renderObject: RenderAbsorbPointer#c6811)
                                                                                   ?ocusTraversalGroup(policy: ReadingOrderTraversalPolicy#0aa25, state: _FocusTraversalGroupState#aea9b)
                                                                                    ?ocus(debugLabel: "FocusTraversalGroup", focusNode: _FocusTraversalGroupNode#2ff82(FocusTraversalGroup [IN FOCUS PATH]), dependencies: [_FocusInheritedScope], state: _FocusState#c41d1)
                                                                                     ?FocusInheritedScope
                                                                                      ?ocus(debugLabel: "Navigator", AUTOFOCUS, focusNode: FocusNode#eb262(Navigator [IN FOCUS PATH]), dependencies: [_FocusInheritedScope], state: _FocusState#acaa4)
                                                                                       ?FocusInheritedScope
00:02 +0 -1: LSP UI Integration Test: Auto-completion appears (Mocked) [E]
  Test failed. See exception logs above.
  The test description was: LSP UI Integration Test: Auto-completion appears (Mocked)
  
00:02 +0 -1: (tearDownAll)
00:03 +0 -1: Some tests failed.
