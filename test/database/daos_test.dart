import "package:ciyue/database/app/app.dart";
import "package:ciyue/database/app/daos.dart";
import "package:drift/native.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  late AppDatabase database;
  late WordbookDao wordbookDao;

  setUp(() {
    // Use an in-memory database for testing
    database = AppDatabase(NativeDatabase.memory());
    wordbookDao = WordbookDao(database);
  });

  tearDown(() async {
    await database.close();
  });

  group("WordbookDao", () {
    test("addAllWords should avoid duplicates based on word and tag", () async {
      // 1. Insert an initial record
      await wordbookDao.addWord("apple", tag: 1);

      final now = DateTime.now();
      // 2. Prepare import data
      final newWords = [
        // Duplicate: same word and tag (should be skipped)
        WordbookData(word: "apple", tag: 1, createdAt: now),
        // New: same word but different tag (should be inserted)
        WordbookData(word: "apple", tag: 2, createdAt: now),
        // New: different word (should be inserted)
        WordbookData(word: "banana", tag: 1, createdAt: now),
      ];

      // 3. Perform batch add
      await wordbookDao.addAllWords(newWords);

      // 4. Verify results
      final allWords = await wordbookDao.getAllWords();

      // We expect 3 records total:
      // 1. original 'apple' (tag 1)
      // 2. 'apple' (tag 2)
      // 3. 'banana' (tag 1)
      expect(allWords.length, 3);

      // Verify duplicate was not added (count remains 1 for apple/tag:1)
      expect(allWords.where((w) => w.word == "apple" && w.tag == 1).length, 1);

      // Verify new records were added
      expect(allWords.where((w) => w.word == "apple" && w.tag == 2).length, 1);
      expect(allWords.where((w) => w.word == "banana").length, 1);
    });
  });
}
