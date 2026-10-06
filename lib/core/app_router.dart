import "package:ciyue/core/app_globals.dart";
import "package:ciyue/repositories/open_records.dart";
import "package:ciyue/ui/core/word_display.dart";
import "package:ciyue/ui/pages/main/main.dart";
import "package:ciyue/ui/pages/settings/about.dart";
import "package:ciyue/ui/pages/settings/appearance.dart";
import "package:ciyue/ui/pages/settings/audio.dart";
import "package:ciyue/ui/pages/settings/dict_library.dart";
import "package:ciyue/ui/pages/settings/history.dart";
import "package:ciyue/ui/pages/settings/hunspell.dart";
import "package:ciyue/ui/pages/settings/manage_dictionaries/main.dart";
import "package:ciyue/ui/pages/settings/manage_dictionaries/properties.dart";
import "package:ciyue/ui/pages/settings/manage_dictionaries/settings_dictionary.dart";
import "package:ciyue/ui/pages/settings/other.dart";
import "package:ciyue/ui/pages/settings/privacy_policy.dart";
import "package:ciyue/ui/pages/settings/sync.dart";
import "package:ciyue/ui/pages/settings/terms_of_service.dart";
import "package:ciyue/ui/pages/settings/logs.dart";
import "package:ciyue/ui/pages/settings/wordbook_stats.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter_smart_dialog/flutter_smart_dialog.dart";
import "package:go_router/go_router.dart";
import "package:ciyue/ui/pages/settings/storage_management.dart";
import "package:ciyue/viewModels/storage_management.dart";
import "package:ciyue/ui/pages/flashcards/study_page.dart";
import "package:ciyue/ui/pages/flashcards/settings.dart";
import "package:provider/provider.dart";
import "package:talker_flutter/talker_flutter.dart";

final navigatorKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: navigatorKey,
  observers: [TalkerRouteObserver(talker), FlutterSmartDialog.observer],
  routes: [
    GoRoute(
      path: "/",
      builder: (context, state) {
        return const Home();
      },
    ),
    GoRoute(
      path: "/word/:word",
      builder: (context, state) {
        final word = state.pathParameters["word"];
        final extra = state.extra;

        if (extra is WordListContext && extra.words.isNotEmpty) {
          return WordDisplayPager(
            words: extra.words,
            initialIndex: extra.initialIndex,
          );
        }

        Provider.of<OpenRecordsRepository>(
          navigatorKey.currentContext!,
          listen: false,
        ).add(word!);

        final dictIdParam = state.uri.queryParameters["dictId"];
        final initialDictId = dictIdParam != null
            ? int.tryParse(dictIdParam)
            : null;

        return WordDisplay(word: word, initialDictId: initialDictId);
      },
    ),
    GoRoute(
      path: "/description/:dictId",
      builder: (context, state) => WebviewDisplayDescription(
        dictId: int.parse(state.pathParameters["dictId"]!),
      ),
    ),
    GoRoute(
      path: "/settings/dictionaries",
      builder: (context, state) => const ManageDictionariesPage(),
    ),
    GoRoute(
      path: "/settings/dict_library",
      builder: (context, state) => const DictLibraryPage(),
    ),
    GoRoute(
      path: "/settings/sync",
      builder: (context, state) => const SchoolSyncSettingsPage(),
    ),
    GoRoute(
      path: "/settings/terms_of_service",
      builder: (context, state) => const TermsOfServicePage(),
    ),
    GoRoute(
      path: "/settings/privacy_policy",
      builder: (context, state) => const PrivacyPolicyPage(),
    ),
    GoRoute(
      path: "/settings/audio",
      builder: (context, state) => const AudioSettingsPage(),
    ),
    GoRoute(
      path: "/settings/appearance",
      builder: (context, state) => const AppearanceSettingsPage(),
    ),
    GoRoute(
      path: "/settings/other",
      builder: (context, state) => const OtherSettingsPage(),
    ),
    GoRoute(
      path: "/settings/hunspell",
      builder: (context, state) => const HunspellSettingsPage(),
    ),
    GoRoute(
      path: "/settings/about",
      builder: (context, state) => const AboutSettingsPage(),
    ),
    GoRoute(
      path: "/settings/history",
      builder: (context, state) => const HistorySettingsPage(),
    ),
    GoRoute(
      path: "/settings/dictionary/:dictId",
      builder: (context, state) => SettingsDictionaryPage(
        dictId: int.parse(state.pathParameters["dictId"]!),
      ),
    ),
    GoRoute(
      path: "/settings/storage_management",
      builder: (context, state) => ChangeNotifierProvider(
        create: (context) => StorageManagementViewModel(),
        child: const StorageManagementPage(),
      ),
    ),
    GoRoute(
      path: "/properties",
      builder: (context, state) => PropertiesDictionaryPage(
        path: (state.extra as Map<String, dynamic>)["path"],
        id: (state.extra as Map<String, dynamic>)["id"],
      ),
    ),
    GoRoute(
      path: "/settings/logs",
      builder: (context, state) => const LogsPage(),
    ),
    GoRoute(
      path: "/settings/wordbook_stats",
      builder: (context, state) => const WordbookStatsPage(),
    ),
    GoRoute(
      path: "/flashcards/review",
      builder: (context, state) => FlashcardStudyPage(
        tag: int.tryParse(state.uri.queryParameters["tag"] ?? ""),
      ),
    ),
    GoRoute(
      path: "/settings/flashcards",
      builder: (context, state) => const FlashcardSettingsPage(),
    ),
  ],
);
