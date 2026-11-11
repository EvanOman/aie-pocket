# Third-party content

The [MIT license](LICENSE) covers this project's original app code and documentation. Third-party assets, dependencies, and event content retain their own terms; this repository does not grant rights to conference branding or speaker material.

- **Roboto fonts:** `assets/fonts/Roboto-*.ttf`, from [Google Fonts' Roboto project](https://github.com/googlefonts/roboto), use the Apache License 2.0. The full license is retained in [assets/fonts/LICENSE.txt](assets/fonts/LICENSE.txt).
- **Conference catalogue:** `assets/schedule.json` contains a normalized snapshot of event metadata and short field-guide summaries. It is excluded from the app's MIT license; see [data provenance](docs/DATA.md) for sources and limitations. The project does not include full talk abstracts, slides, recordings, or speaker photographs.
- **Framework assets and packages:** Flutter, its template icons, the Flutter/Dart packages pinned in `pubspec.lock`, and the CocoaPods dependencies pinned in `ios/Podfile.lock` retain their upstream licenses. The generated Flutter build includes its dependency notices. The iPhone and web icons are still Flutter template assets; no affiliation or endorsement is implied.

The app screenshots in `docs/screenshots/` show the project's UI with the attributed event metadata. The Apple Watch screenshots are physical-device captures; the iPhone screenshot is from a simulator.
