<p align="center"><b>harmony_ui</b></p>

## Introduction

`harmony_ui` is a Material/Cupertino-style Flutter widget library that fully implements the **HarmonyOS design language** (Huawei "Design Basics" specification). It covers all **42 controls in 6 categories** from the official "Controls Overview" documentation, and implements immersive light material, responsive layout, transition motion, plus enhanced capabilities aligned with Huawei's "UI Design Kit" documentation — point light, press shadow, side bar, resident snackbar, dynamic blur app bar, and more.

Widget naming and APIs are aligned with Flutter's built-in `Material*` / `Cupertino*` widgets, so anyone who can write Flutter can use it directly. It is pure Dart / Flutter with zero platform-channel calls; the only third-party dependency is the `qr` package for QR code generation.

- Repository (AtomGit): [oh-flutter/harmony_ui](https://atomgit.com/oh-flutter/harmony_ui)
- Repository (GitHub): [shaohushuo/harmony_ui](https://github.com/shaohushuo/harmony_ui)
- Companion icon package: [ohos_icons](https://pub.dev/packages/ohos_icons) (HarmonyOS Symbol font icons, published on pub.dev)
- Changelog: [CHANGELOG.OpenHarmony.md](./CHANGELOG.OpenHarmony.md)

## Installation

Add the git dependency in `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  harmony_ui:
    git:
      url: https://atomgit.com/oh-flutter/harmony_ui.git
      ref: main
  ohos_icons: ^0.1.0   # optional, companion HarmonyOS Symbol font icons
```

Fetch dependencies:

```bash
flutter pub get
```

> Note: this library requires the OpenHarmony community Flutter fork ([CPF-Flutter/flutter_flutter](https://atomgit.com/CPF-Flutter/flutter_flutter)), recommended branch `oh-3.35.7-release`. We suggest managing it with [fvm](https://fvm.app): `fvm use ohos/oh-3.35.7-release`. Since it is pure Dart, it also runs on a standard Flutter SDK without the ohos platform (for cross-platform debugging only; the font falls back to the system font).

Current version and branch mapping:

| Library version | Branch / TAG | Flutter version |
| --- | --- | --- |
| 0.2.0 | `main` | oh-3.35.7-release |
| 0.1.0 | historical commit | oh-3.35.7-release |

## Constraints

### Compatibility

Flutter: oh-3.35.7-release (CPF-Flutter community fork), DevEco Studio: 5.0.0 release (node/ohpm/hvigor toolchain required), SDK: 26.0.0 (API 26), ROM: 5.1.0 (verified on OpenHarmony emulator 1280×2832).

### Permissions

None. This is a pure UI widget library and requires no system permissions.

## Usage Example

```dart
// 1. Import modules
import 'package:flutter/material.dart';
import 'package:harmony_ui/harmony_ui.dart';

// 2. Initialize: wrap the app root with OhosTheme
void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: OhosTheme(
        data: OhosThemeData.light(), // or OhosThemeData.dark()
        child: const HomePage(),
      ),
    );
  }
}

// 3. Implementation: page skeleton + core widgets
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return OhosScaffold(
      appBar: OhosAppBar(
        title: const Text('My App'),
        lightMaterial: true, // immersive light material app bar
      ),
      body: Center(
        child: OhosButton(
          onPressed: () {},
          child: const Text('Get Started'),
        ),
      ),
      bottomNavigationBar: OhosNavigationBar(
        currentIndex: _index,
        onDestinationSelected: (int i) => setState(() => _index = i),
        destinations: const [
          OhosNavigationDestination(icon: Icon(Icons.home_filled), label: 'Home'),
          OhosNavigationDestination(icon: Icon(Icons.person_filled), label: 'Me'),
        ],
      ),
    );
  }
}
```

```bash
# 4. Output: build the HAP and install it on the OpenHarmony emulator
cd example
fvm flutter create --platforms ohos .
fvm flutter build hap --debug --no-codesign
hdc install -r build/ohos/hap/entry-default-unsigned.hap
hdc shell aa start -a EntryAbility -b com.example.ohos_ui_example
```

## Instructions

1. **Theme first**: wrap inside `MaterialApp` with `OhosTheme`; `OhosThemeData.light()` / `dark()` work out of the box. All widget colors come from theme tokens, and `copyWith` supports brand customization.
2. **Replace widgets one by one**: `ElevatedButton` → `OhosButton`, `ListTile` → `OhosListTile`, etc. API names map one-to-one, so most cases can be migrated with a global replace.
3. **Upgrade to light material on demand**: enable `lightMaterial: true` on the app bar / bottom navigation / bottom sheet to get the immersive light effect.
4. **Full demo**: the gallery app under `example/` covers every control (6 categories + layout & motion, 7 entries) and serves as an API reference.

## API Reference

### Widgets

Control list (mapping to the 42 controls in the official "Controls Overview"):

| Category | Control | Implementation |
| --- | --- | --- |
| Navigation | App bar | `OhosAppBar` (light material / dynamic blur) |
| Navigation | Tab bar | `OhosTabBar` (underline / capsule, follow-scroll divider) |
| Navigation | Bottom navigation | `OhosNavigationBar` (tile / float, glow pool, badge) |
| Navigation | Page indicator / Swiper | `OhosPageIndicator` / `OhosSwiper` |
| Display | Text / Subheader | `OhosText` (13-level type scale) / `OhosSubheader` |
| Display | Image | `OhosImage` (selection stroke / placeholder) |
| Display | Divider / Progress | `OhosDivider` / `OhosProgressIndicator` |
| Display | Badge / Alphabet indexer | `OhosBadge` / `OhosAlphabetIndexer` |
| Display | Scrollbar / Toast | `OhosScrollbar` / `showOhosToast` |
| Display | Popup / Data panel | `showOhosPopup` / `OhosDataPanel` |
| Display | QR code / Blank / Text clock | `OhosQrCode` / `OhosBlank` / `OhosTextClock` |
| Action | Button | `OhosButton` (5 styles × 3 shapes + loading) |
| Action | Select / Toggle button | `OhosSelect` / `OhosToggleButton` |
| Action | Chip / Toolbar | `OhosChip` / `OhosToolbar` |
| Action | Action bar / Menu | `OhosActionBar` / `showOhosMenu` |
| Input | Text field / Search bar | `OhosTextField` / `OhosSearchBar` |
| Input | Counter / Pattern lock | `OhosCounter` / `OhosPatternLock` |
| Selection | Checkbox / Radio / Switch | `OhosCheckbox` / `OhosRadio` / `OhosSwitch` |
| Selection | Rating bar / Slider | `OhosRatingBar` / `OhosSlider` |
| Selection | Picker / Color picker | `showOhosPicker` / `OhosColorPicker` |
| Selection | Segmented button | `OhosSegmentedButton` |
| Container | List / List tile | `OhosList` / `OhosListTile` |
| Container | Card | `OhosCard` |
| Container | Dialog | `OhosAlertDialog` / `showOhosDialog` |
| Container | Popup / Bottom sheet | `showOhosPopup` / `showOhosBottomSheet` |

### Properties (Theme)

```dart
final OhosThemeData theme = OhosTheme.of(context);
theme.highlightColor;        // brand color #0A59F7
theme.backgroundColor;       // page background
theme.cardColor;             // card background
theme.multiColors;           // 11-color palette
theme.typography.bodyLarge;  // text style
```

### API (UI Design Kit enhancements)

| Capability | Widget / API |
| --- | --- |
| Point light | `OhosLightSource` + `OhosIlluminated` |
| Press shadow | `OhosPressShadow` |
| Side bar / Side menu | `OhosSideBar` + `OhosSideMenu` |
| Swipe list item | `OhosListItem` |
| Resident snackbar | `showOhosSnackBar(resident: true)` |
| Tab divider | `OhosTabBar(divider:)` |
| Dynamic blur app bar | `OhosAppBar(scrollEffect:)` |
| Expandable action bar | `OhosActionBar(expandable: true)` |
| Layered icon / Multi-window entry | `OhosLayeredIcon` / `OhosMultiWindowEntry` |
| Immersive light material | `OhosLightMaterial` (5 levels + `OhosLightEffectTuning`) |
| Responsive layout | `OhosResponsiveBuilder` / `OhosGrid` / `OhosGridItem` |
| Transition motion | `OhosGeometry` (spring/easeOut/sharedElement) |

## New Features

v0.2.0 adds UI Design Kit enhanced components and immersive light enhancements (glow pools, lens specular, light scatter). See [CHANGELOG.OpenHarmony.md](./CHANGELOG.OpenHarmony.md) for details.

## FAQ

- **`npm not found` during build?** Add the DevEco Studio built-in tools (node/ohpm/hvigor) to your PATH; the repo ships an `env.sh` that can be `source`d directly.
- **`flutter build hap` fails with a signing error?** Build with `--no-codesign`, then `hdc install`; the emulator runs unsigned HAPs.
- **Does it run on a standard (non-OHOS) Flutter?** Yes — it is pure Dart with no platform-channel calls. Only the font and native light effect differ; for production use on OpenHarmony, use the community fork with the ohos platform.

## Directory Structure

```
harmony_ui/
├── lib/
│   ├── harmony_ui.dart          # unified exports
│   └── src/
│       ├── theme/               # design tokens: OhosColors / OhosThemeData / OhosGeometry
│       └── widgets/             # 50+ widgets: button/list/navigation/selection/sheet/light/Kit
├── example/                     # gallery app (7 entries)
│   └── ohos/                    # platform project from flutter create --platforms ohos
├── test/                        # widget tests
├── doc/screenshots/             # emulator screenshots
├── env.sh                       # DevEco toolchain environment
├── README.OpenHarmony.md        # English documentation (this file)
├── README.OpenHarmony_CN.md     # Chinese documentation
└── CHANGELOG.OpenHarmony.md     # changelog
```

## Contributing

Issues and pull requests are welcome:

- AtomGit repository issues: [oh-flutter/harmony_ui/issues](https://atomgit.com/oh-flutter/harmony_ui/issues)
- AtomGit repository pull requests: [oh-flutter/harmony_ui/pulls](https://atomgit.com/oh-flutter/harmony_ui/pulls)
- GitHub repository: [shaohushuo/harmony_ui](https://github.com/shaohushuo/harmony_ui)

To join the OpenHarmony ecosystem, visit the OpenHarmony Cross-Platform Community: <https://openharmonycrossplatform.csdn.net>

## License

[MIT](./LICENSE)
