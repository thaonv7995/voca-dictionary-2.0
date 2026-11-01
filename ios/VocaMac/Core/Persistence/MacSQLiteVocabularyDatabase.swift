import Foundation
import SQLite3

/// Account-partitioned SQLite + FTS5 local persistence store for Voca on macOS.
///
/// Provides fast local reads, transactional batch upserts, and full-text search
/// (`FTS5`) over vocabulary terms, pronunciations, meanings, tags, and notes.
final class MacSQLiteVocabularyDatabase: @unchecked Sendable {
    private var db: OpaquePointer?
    private let lock = NSLock()
    let databaseURL: URL?

    init(accountID: String? = nil, inMemory: Bool = false) {
        if inMemory {
            databaseURL = nil
            openDatabase(path: ":memory:")
        } else {
            let url = Self.resolveDatabaseURL(accountID: accountID)
            databaseURL = url
            openDatabase(path: url.path)
        }
        createSchemaIfNeeded()
    }

    deinit {
        lock.lock()
        if let db {
            sqlite3_close(db)
        }
        lock.unlock()
    }

    // MARK: - CRUD & Batch Upsert

    func upsertItems(_ items: [MacVocabularyItem]) {
        lock.lock()
        defer { lock.unlock() }
        guard let db else { return }

        executeRaw("BEGIN TRANSACTION;", on: db)

        let upsertSQL = """
        INSERT INTO vocabulary_items (
            id, term, pronunciation, meaning, language, level,
            tags_json, examples_json, personal_note, is_favorite, is_due, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            term = excluded.term,
            pronunciation = excluded.pronunciation,
            meaning = excluded.meaning,
            language = excluded.language,
            level = excluded.level,
            tags_json = excluded.tags_json,
            examples_json = excluded.examples_json,
            personal_note = excluded.personal_note,
            is_favorite = excluded.is_favorite,
            is_due = excluded.is_due,
            updated_at = excluded.updated_at;
        """

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, upsertSQL, -1, &statement, nil) == SQLITE_OK,
           let statement {
            let now = Date().timeIntervalSince1970

            for item in items {
                sqlite3_reset(statement)
                sqlite3_clear_bindings(statement)

                bindText(item.id, at: 1, in: statement)
                bindText(item.term, at: 2, in: statement)
                bindOptionalText(item.pronunciation, at: 3, in: statement)
                bindText(item.meaning, at: 4, in: statement)
                bindText(item.language.rawValue, at: 5, in: statement)
                bindOptionalText(item.level, at: 6, in: statement)
                bindText(encodeStringArray(item.tags), at: 7, in: statement)
                bindText(encodeStringArray(item.examples), at: 8, in: statement)
                bindText(item.personalNote, at: 9, in: statement)
                sqlite3_bind_int(statement, 10, item.isFavorite ? 1 : 0)
                sqlite3_bind_int(statement, 11, item.isDue ? 1 : 0)
                sqlite3_bind_double(statement, 12, now)

                sqlite3_step(statement)
                updateFTSIndex(for: item, on: db)
            }
            sqlite3_finalize(statement)
        }

        executeRaw("COMMIT;", on: db)
    }

    func deleteItem(id: String) {
        lock.lock()
        defer { lock.unlock() }
        guard let db else { return }

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(
            db,
            "DELETE FROM vocabulary_items WHERE id = ?;",
            -1,
            &statement,
            nil
        ) == SQLITE_OK, let statement {
            bindText(id, at: 1, in: statement)
            sqlite3_step(statement)
            sqlite3_finalize(statement)
        }

        if sqlite3_prepare_v2(
            db,
            "DELETE FROM vocabulary_fts WHERE id = ?;",
            -1,
            &statement,
            nil
        ) == SQLITE_OK, let statement {
            bindText(id, at: 1, in: statement)
            sqlite3_step(statement)
            sqlite3_finalize(statement)
        }
    }

    func fetchAllItems() -> [MacVocabularyItem] {
        lock.lock()
        defer { lock.unlock() }
        guard let db else { return [] }

        let sql = """
        SELECT id, term, pronunciation, meaning, language, level,
               tags_json, examples_json, personal_note, is_favorite, is_due
        FROM vocabulary_items
        ORDER BY term COLLATE NOCASE ASC;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        var results: [MacVocabularyItem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let item = decodeRow(from: statement) {
                results.append(item)
            }
        }
        return results
    }

    /// Performs a fast full-text search across term, pronunciation, meaning, tags, and personal notes.
    func searchItems(query: String) -> [MacVocabularyItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return fetchAllItems()
        }

        lock.lock()
        defer { lock.unlock() }
        guard let db else { return [] }

        let sanitizedTokens = trimmed
            .components(separatedBy: .whitespacesAndNewlines)
            .map { token in
                token.filter { char in
                    char.isLetter || char.isNumber || char == "-" || char == "_"
                }
            }
            .filter { !$0.isEmpty }

        if sanitizedTokens.isEmpty {
            return fallbackLikeSearch(query: trimmed, on: db)
        }

        let ftsQuery = sanitizedTokens.map { "\"\($0)\"*" }.joined(separator: " AND ")
        let sql = """
        SELECT v.id, v.term, v.pronunciation, v.meaning, v.language, v.level,
               v.tags_json, v.examples_json, v.personal_note, v.is_favorite, v.is_due
        FROM vocabulary_fts f
        JOIN vocabulary_items v ON v.id = f.id
        WHERE vocabulary_fts MATCH ?
        ORDER BY bm25(vocabulary_fts), v.term COLLATE NOCASE ASC;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            return fallbackLikeSearch(query: trimmed, on: db)
        }
        defer { sqlite3_finalize(statement) }

        bindText(ftsQuery, at: 1, in: statement)

        var results: [MacVocabularyItem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let item = decodeRow(from: statement) {
                results.append(item)
            }
        }

        if results.isEmpty {
            return fallbackLikeSearch(query: trimmed, on: db)
        }
        return results
    }

    func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        guard let db else { return }

        executeRaw("DELETE FROM vocabulary_items;", on: db)
        executeRaw("DELETE FROM vocabulary_fts;", on: db)
    }

    // MARK: - Internal Helpers

    private func openDatabase(path: String) {
        var pointer: OpaquePointer?
        if sqlite3_open(path, &pointer) == SQLITE_OK {
            db = pointer
            if let db {
                executeRaw("PRAGMA journal_mode = WAL;", on: db)
                executeRaw("PRAGMA synchronous = NORMAL;", on: db)
            }
        }
    }

    private func createSchemaIfNeeded() {
        lock.lock()
        defer { lock.unlock() }
        guard let db else { return }

        let createMainTable = """
        CREATE TABLE IF NOT EXISTS vocabulary_items (
            id TEXT PRIMARY KEY NOT NULL,
            term TEXT NOT NULL,
            pronunciation TEXT,
            meaning TEXT NOT NULL,
            language TEXT NOT NULL,
            level TEXT,
            tags_json TEXT NOT NULL DEFAULT '[]',
            examples_json TEXT NOT NULL DEFAULT '[]',
            personal_note TEXT NOT NULL DEFAULT '',
            is_favorite INTEGER NOT NULL DEFAULT 0,
            is_due INTEGER NOT NULL DEFAULT 0,
            updated_at REAL NOT NULL DEFAULT 0
        );
        """

        let createFTSTable = """
        CREATE VIRTUAL TABLE IF NOT EXISTS vocabulary_fts USING fts5(
            id UNINDEXED,
            term,
            pronunciation,
            meaning,
            tags,
            personal_note
        );
        """

        executeRaw(createMainTable, on: db)
        executeRaw(createFTSTable, on: db)
    }

    private func updateFTSIndex(
        for item: MacVocabularyItem,
        on db: OpaquePointer
    ) {
        var deleteStmt: OpaquePointer?
        if sqlite3_prepare_v2(
            db,
            "DELETE FROM vocabulary_fts WHERE id = ?;",
            -1,
            &deleteStmt,
            nil
        ) == SQLITE_OK, let deleteStmt {
            bindText(item.id, at: 1, in: deleteStmt)
            sqlite3_step(deleteStmt)
            sqlite3_finalize(deleteStmt)
        }

        var insertStmt: OpaquePointer?
        let insertSQL = """
        INSERT INTO vocabulary_fts (id, term, pronunciation, meaning, tags, personal_note)
        VALUES (?, ?, ?, ?, ?, ?);
        """
        if sqlite3_prepare_v2(db, insertSQL, -1, &insertStmt, nil) == SQLITE_OK,
           let insertStmt {
            bindText(item.id, at: 1, in: insertStmt)
            bindText(item.term, at: 2, in: insertStmt)
            bindText(item.pronunciation ?? "", at: 3, in: insertStmt)
            bindText(item.meaning, at: 4, in: insertStmt)
            bindText(item.tags.joined(separator: " "), at: 5, in: insertStmt)
            bindText(item.personalNote, at: 6, in: insertStmt)
            sqlite3_step(insertStmt)
            sqlite3_finalize(insertStmt)
        }
    }

    private func fallbackLikeSearch(
        query: String,
        on db: OpaquePointer
    ) -> [MacVocabularyItem] {
        let sql = """
        SELECT id, term, pronunciation, meaning, language, level,
               tags_json, examples_json, personal_note, is_favorite, is_due
        FROM vocabulary_items
        WHERE term LIKE ? OR meaning LIKE ? OR pronunciation LIKE ? OR tags_json LIKE ? OR personal_note LIKE ?
        ORDER BY term COLLATE NOCASE ASC;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        let pattern = "%\(query)%"
        for index in 1...5 {
            bindText(pattern, at: Int32(index), in: statement)
        }

        var results: [MacVocabularyItem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let item = decodeRow(from: statement) {
                results.append(item)
            }
        }
        return results
    }

    private func decodeRow(from statement: OpaquePointer) -> MacVocabularyItem? {
        guard let id = columnText(at: 0, in: statement),
              let term = columnText(at: 1, in: statement),
              let meaning = columnText(at: 3, in: statement),
              let languageRaw = columnText(at: 4, in: statement)
        else {
            return nil
        }

        let pronunciation = columnText(at: 2, in: statement)
        let level = columnText(at: 5, in: statement)
        let tagsJSON = columnText(at: 6, in: statement) ?? "[]"
        let examplesJSON = columnText(at: 7, in: statement) ?? "[]"
        let personalNote = columnText(at: 8, in: statement) ?? ""
        let isFavorite = sqlite3_column_int(statement, 9) != 0
        let isDue = sqlite3_column_int(statement, 10) != 0

        let language = MacVocabularyItem.Language(rawValue: languageRaw) ?? .english

        return MacVocabularyItem(
            id: id,
            term: term,
            pronunciation: pronunciation?.isEmpty == true ? nil : pronunciation,
            meaning: meaning,
            language: language,
            level: level?.isEmpty == true ? nil : level,
            tags: decodeStringArray(tagsJSON),
            isFavorite: isFavorite,
            isDue: isDue,
            examples: decodeStringArray(examplesJSON),
            personalNote: personalNote
        )
    }

    private func executeRaw(_ sql: String, on db: OpaquePointer) {
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    private func bindText(
        _ value: String,
        at index: Int32,
        in statement: OpaquePointer
    ) {
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(statement, index, (value as NSString).utf8String, -1, transient)
    }

    private func bindOptionalText(
        _ value: String?,
        at index: Int32,
        in statement: OpaquePointer
    ) {
        if let value {
            bindText(value, at: index, in: statement)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

    private func columnText(
        at index: Int32,
        in statement: OpaquePointer
    ) -> String? {
        guard let cString = sqlite3_column_text(statement, index) else {
            return nil
        }
        return String(cString: cString)
    }

    private func encodeStringArray(_ array: [String]) -> String {
        guard let data = try? JSONEncoder().encode(array),
              let string = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return string
    }

    private func decodeStringArray(_ json: String) -> [String] {
        guard let data = json.data(using: .utf8),
              let array = try? JSONDecoder().decode([String].self, from: data)
        else {
            return []
        }
        return array
    }

    private static func resolveDatabaseURL(accountID: String?) -> URL {
        let rawPartition = (accountID ?? UserDefaults.standard.string(forKey: "mac.session.account.id") ?? "default")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let safePartition = rawPartition.filter {
            $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_"
        }
        let folderName = safePartition.isEmpty ? "default" : safePartition

        let baseDir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory())

        let accountDir = baseDir
            .appendingPathComponent("Voca", isDirectory: true)
            .appendingPathComponent("accounts", isDirectory: true)
            .appendingPathComponent(folderName, isDirectory: true)

        try? FileManager.default.createDirectory(
            at: accountDir,
            withIntermediateDirectories: true
        )

        return accountDir.appendingPathComponent("voca.sqlite")
    }
}
