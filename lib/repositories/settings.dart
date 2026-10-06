import "package:ciyue/core/app_globals.dart";
import "package:ciyue/models/hunspell.dart";
import "package:material_ui/material_ui.dart";

final settings = Settings();

enum TabBarPosition { top, bottom }

enum DictionarySwitchStyle { expansion, tag }

class Settings {
  late ThemeMode themeMode;
  late bool enableDynamicColor;
  late bool pureBlackDarkMode;
  late Color themeSeedColor;
  late String dictionaryCustomCss;
  late Color? dictionaryBackgroundColor;
  late bool dictionaryDarkReaderEnabled;
  String? language;
  late bool searchBarInAppBar;
  late TabBarPosition tabBarPosition;
  late bool showSidebarIcon;
  late bool showMoreOptionsButton;
  late bool showSearchBarInWordDisplay;
  late DictionarySwitchStyle dictionarySwitchStyle;

  late bool autoRemoveSearchWord;
  late bool autoFocusSearch;

  late bool secureScreen;

  late bool notification;

  late bool enableHistory;
  late bool skipTaggedWord;
  late bool advance;

  late bool enableHunspellMorphology;
  late HunspellLookupMode hunspellLookupMode;

  late bool mdmAutoSync;

  late String? ttsEngine;
  late String? ttsLanguage;

  late bool launchAtStartup;
  late int flashcardDailyNewLimit;

  Settings() {
    launchAtStartup = prefs.getBool("launchAtStartup") ?? false;
    flashcardDailyNewLimit = prefs.getInt("flashcardDailyNewLimit") ?? 20;

    autoRemoveSearchWord = prefs.getBool("autoRemoveSearchWord") ?? false;
    autoFocusSearch = prefs.getBool("autoFocusSearch") ?? false;

    secureScreen = prefs.getBool("secureScreen") ?? false;

    language = prefs.getString("language") ?? "system";
    enableDynamicColor = prefs.getBool("enableDynamicColor") ?? true;
    pureBlackDarkMode = prefs.getBool("pureBlackDarkMode") ?? false;
    final int? themeSeedColorValue = prefs.getInt("themeSeedColor");
    themeSeedColor = Color(themeSeedColorValue ?? Colors.blue.toARGB32());
    dictionaryCustomCss = prefs.getString("dictionaryCustomCss") ?? "";
    final backgroundColorValue = prefs.getInt("dictionaryBackgroundColor");
    dictionaryBackgroundColor = backgroundColorValue == null
        ? null
        : Color(backgroundColorValue);
    dictionaryDarkReaderEnabled =
        prefs.getBool("dictionaryDarkReaderEnabled") ?? false;
    searchBarInAppBar = prefs.getBool("searchBarInAppBar") ?? true;
    showSidebarIcon = prefs.getBool("showSidebarIcon") ?? true;
    showMoreOptionsButton = prefs.getBool("showMoreOptionsButton") ?? true;
    showSearchBarInWordDisplay =
        prefs.getBool("showSearchBarInWordDisplay") ?? true;

    final dictionarySwitchStyleString = prefs.getString(
      "dictionarySwitchStyle",
    );
    if (dictionarySwitchStyleString == null) {
      dictionarySwitchStyle = DictionarySwitchStyle.expansion;
    } else {
      dictionarySwitchStyle = DictionarySwitchStyle.values.byName(
        dictionarySwitchStyleString,
      );
    }

    notification = prefs.getBool("notification") ?? false;

    enableHistory = prefs.getBool("enableHistory") ?? true;

    advance = prefs.getBool("advance") ?? false;

    enableHunspellMorphology =
        prefs.getBool("enableHunspellMorphology") ?? false;
    final hunspellLookupModeName = prefs.getString("hunspellLookupMode");
    hunspellLookupMode = HunspellLookupMode.values.firstWhere(
      (mode) => mode.name == hunspellLookupModeName,
      orElse: () => HunspellLookupMode.fallback,
    );

    skipTaggedWord = prefs.getBool("skipTaggedWord") ?? false;

    mdmAutoSync = prefs.getBool("mdmAutoSync") ?? true;

    ttsEngine = prefs.getString("ttsEngine");
    ttsLanguage = prefs.getString("ttsLanguage");

    final tabBarPositionString = prefs.getString("tabBarPosition");
    if (tabBarPositionString == null) {
      tabBarPosition = TabBarPosition.top;
    } else {
      tabBarPosition = TabBarPosition.values.byName(tabBarPositionString);
    }

    final themeModeString = prefs.getString("themeMode");
    switch (themeModeString) {
      case "light":
        themeMode = ThemeMode.light;
      case "dark":
        themeMode = ThemeMode.dark;
      case "system" || null:
        themeMode = ThemeMode.system;
    }
  }

  Future<void> setEnableDynamicColor(bool value) async {
    enableDynamicColor = value;
    await prefs.setBool("enableDynamicColor", value);
  }

  Future<void> setThemeSeedColor(Color color) async {
    themeSeedColor = color;
    await prefs.setInt("themeSeedColor", color.toARGB32());
  }

  Future<void> setPureBlackDarkMode(bool value) async {
    pureBlackDarkMode = value;
    await prefs.setBool("pureBlackDarkMode", value);
  }

  Future<void> setDictionaryCustomCss(String value) async {
    dictionaryCustomCss = value;
    await prefs.setString("dictionaryCustomCss", value);
  }

  Future<void> setDictionaryBackgroundColor(Color? color) async {
    dictionaryBackgroundColor = color;
    if (color == null) {
      await prefs.remove("dictionaryBackgroundColor");
    } else {
      await prefs.setInt("dictionaryBackgroundColor", color.toARGB32());
    }
  }

  Future<void> setDictionaryDarkReaderEnabled(bool value) async {
    dictionaryDarkReaderEnabled = value;
    await prefs.setBool("dictionaryDarkReaderEnabled", value);
  }

  Future<void> setTabBarPosition(TabBarPosition position) async {
    tabBarPosition = position;
    await prefs.setString("tabBarPosition", position.name);
  }

  Future<void> setDictionarySwitchStyle(DictionarySwitchStyle style) async {
    dictionarySwitchStyle = style;
    await prefs.setString("dictionarySwitchStyle", style.name);
  }

  Future<void> setTTSEngine(String engine) async {
    ttsEngine = engine;
    await prefs.setString("ttsEngine", engine);
  }

  Future<void> setTTSLanguage(String lang) async {
    ttsLanguage = lang;
    await prefs.setString("ttsLanguage", lang);
  }

  Future<void> setAdvance(bool value) async {
    advance = value;
    await prefs.setBool("advance", value);
  }

  Future<void> setEnableHunspellMorphology(bool value) async {
    enableHunspellMorphology = value;
    await prefs.setBool("enableHunspellMorphology", value);
  }

  Future<void> setHunspellLookupMode(HunspellLookupMode mode) async {
    hunspellLookupMode = mode;
    await prefs.setString("hunspellLookupMode", mode.name);
  }

  Future<void> setEnableHistory(bool value) async {
    enableHistory = value;
    await prefs.setBool("enableHistory", value);
  }

  Future<void> setMdmAutoSync(bool value) async {
    mdmAutoSync = value;
    await prefs.setBool("mdmAutoSync", value);
  }

  Future<void> setLaunchAtStartup(bool value) async {
    launchAtStartup = value;
    await prefs.setBool("launchAtStartup", value);
  }

  Future<void> setFlashcardDailyNewLimit(int value) async {
    flashcardDailyNewLimit = value.clamp(0, 9999);
    await prefs.setInt("flashcardDailyNewLimit", flashcardDailyNewLimit);
  }
}
