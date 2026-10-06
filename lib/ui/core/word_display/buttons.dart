import "package:ciyue/core/app_globals.dart";
import "package:ciyue/services/audio.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/tags_list.dart";
import "package:ciyue/ui/core/word_display/audio_waveform.dart";
import "package:ciyue/viewModels/audio.dart";
import "package:ciyue/viewModels/wordbook.dart";
import "package:material_ui/material_ui.dart";
import "package:go_router/go_router.dart";
import "package:provider/provider.dart";

class Button extends StatefulWidget {
  final String word;

  const Button({super.key, required this.word});

  @override
  State<Button> createState() => _ButtonState();
}

class _ButtonState extends State<Button> {
  Future<bool>? stared;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: buildReadLoudlyButton(context, widget.word),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: buildStarButton(context),
        ),
      ],
    );
  }

  Widget buildReadLoudlyButton(BuildContext context, String word) {
    final colorScheme = Theme.of(context).colorScheme;
    final audioModel = Provider.of<AudioModel?>(context);
    final isPlaying = audioModel?.isWordPlaying(word) ?? false;

    return PulsingFab(
      isPulsing: isPlaying,
      ringColor: colorScheme.primary,
      child: FloatingActionButton.small(
        heroTag: "readLoudly_$word",
        tooltip: AppLocalizations.of(context)!.readLoudly,
        foregroundColor: colorScheme.primary,
        backgroundColor: colorScheme.primaryContainer,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: isPlaying
              ? AudioWaveformIcon(
                  key: const ValueKey("playing"),
                  color: colorScheme.primary,
                  size: 20,
                )
              : const Icon(Icons.volume_up, key: ValueKey("idle")),
        ),
        onPressed: () async {
          if (audioModel != null) {
            if (audioModel.isWordPlaying(word)) {
              await audioModel.stopAudio();
            } else {
              await audioModel.playWord(word);
            }
          } else {
            await playSoundOfWord(word, []);
          }
        },
      ),
    );
  }

  Widget buildStarButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final locale = AppLocalizations.of(context)!;

    return FutureBuilder(
      future: stared,
      builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
        if (!snapshot.hasData) {
          return FloatingActionButton.small(
            heroTag: "star_${widget.word}",
            tooltip: locale.wordBook,
            foregroundColor: colorScheme.primary,
            backgroundColor: colorScheme.surface,
            child: const Icon(Icons.star_outline),
            onPressed: () {},
          );
        }

        return FloatingActionButton.small(
          heroTag: "star_${widget.word}",
          tooltip: locale.wordBook,
          foregroundColor: colorScheme.primary,
          backgroundColor: colorScheme.primaryContainer,
          child: Icon(snapshot.data! ? Icons.star : Icons.star_outline),
          onPressed: () async {
            Future<void> star() async {
              if (snapshot.data!) {
                await context.read<WordbookModel>().delete(widget.word);
              } else {
                await context.read<WordbookModel>().add(widget.word);
              }

              checkStared();
            }

            if (wordbookTagsDao.tagExist) {
              final tagsOfWord = await wordbookDao.tagsOfWord(widget.word),
                  tags = await wordbookTagsDao.getAllTags();

              final toAdd = <int>[], toDel = <int>[];

              if (!context.mounted) return;

              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text(locale.tags),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TagsList(
                          tags: tags,
                          tagsOfWord: tagsOfWord,
                          toAdd: toAdd,
                          toDel: toDel,
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        child: Text(locale.remove),
                        onPressed: () async {
                          await context
                              .read<WordbookModel>()
                              .removeWordWithAllTags(widget.word);

                          if (context.mounted) {
                            context.pop();
                          }

                          checkStared();
                        },
                      ),
                      TextButton(
                        child: Text(locale.confirm),
                        onPressed: () async {
                          if (!snapshot.data!) {
                            await context.read<WordbookModel>().add(
                              widget.word,
                            );
                          }

                          if (!context.mounted) return;

                          for (final tag in toAdd) {
                            await context.read<WordbookModel>().add(
                              widget.word,
                              tag: tag,
                            );
                          }

                          if (!context.mounted) return;

                          for (final tag in toDel) {
                            await context.read<WordbookModel>().delete(
                              widget.word,
                              tag: tag,
                            );
                          }

                          if (context.mounted) {
                            context.pop();
                          }

                          checkStared();
                        },
                      ),
                    ],
                  );
                },
              );
            } else {
              await star();
            }
          },
        );
      },
    );
  }

  void checkStared() {
    setState(() {
      stared = wordbookDao.wordExist(widget.word);
    });
  }

  @override
  void initState() {
    super.initState();

    stared = wordbookDao.wordExist(widget.word);
  }
}
