//
//  CSVService.swift
//  WordCardAI
//
//  Created by YuyaFuruichi on 2026/03/07.
//

import Foundation

struct CSVService {

    // MARK: - カラム定義

    static let columns = ["Japanese", "English", "Comment", "Tags"]
    static let header = columns.joined(separator: ",")

    // MARK: - エクスポート

    static func export(cards: [WordCard]) -> String {
        var lines = [header]

        for card in cards {
            let fields: [String] = [
                escaped(card.japanese),
                escaped(card.english),
                escaped(card.note ?? ""),
                escaped(card.tags.joined(separator: "|"))
            ]
            lines.append(fields.joined(separator: ","))
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - インポート

    static func `import`(csvString: String, into collectionId: UUID) throws -> CSVImportResult {
        let normalized = csvString.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        var lines = normalized.components(separatedBy: "\n")
        while lines.last?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            lines.removeLast()
        }

        guard !lines.isEmpty else {
            throw CSVError.emptyFile
        }

        var startIndex = 0
        if let firstLine = lines.first,
           parseCSVLine(firstLine).map({ $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }) == columns.map({ $0.lowercased() }) {
            startIndex = 1
        }

        var cards: [WordCard] = []
        var skippedRows: [CSVImportSkippedRow] = []

        for index in startIndex..<lines.count {
            let line = lines[index]
            let rowNumber = index + 1

            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                skippedRows.append(CSVImportSkippedRow(rowNumber: rowNumber, rawValue: line, reason: .emptyLine))
                continue
            }

            let fields = parseCSVLine(line)
            guard fields.count >= 2 else {
                skippedRows.append(CSVImportSkippedRow(rowNumber: rowNumber, rawValue: line, reason: .missingRequiredColumns))
                continue
            }

            let japanese = unescaped(fields[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            let english = unescaped(fields[1]).trimmingCharacters(in: .whitespacesAndNewlines)

            guard !japanese.isEmpty, !english.isEmpty else {
                skippedRows.append(CSVImportSkippedRow(rowNumber: rowNumber, rawValue: line, reason: .missingRequiredValues))
                continue
            }

            let noteRaw = unescaped(fields[safe: 2] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let note: String? = noteRaw.isEmpty ? nil : noteRaw

            let tagsRaw = unescaped(fields[safe: 3] ?? "")
            let tags = tagsRaw
                .components(separatedBy: "|")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            cards.append(
                WordCard(
                    collectionId: collectionId,
                    front: japanese,
                    back: english,
                    note: note,
                    tags: tags
                )
            )
        }

        return CSVImportResult(importedCards: cards, skippedRows: skippedRows)
    }

    // MARK: - Private Helpers

    private static func escaped(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    private static func unescaped(_ value: String) -> String {
        var v = value
        if v.hasPrefix("\"") && v.hasSuffix("\"") {
            v = String(v.dropFirst().dropLast())
            v = v.replacingOccurrences(of: "\"\"", with: "\"")
        }
        return v
    }

    private static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var i = line.startIndex

        while i < line.endIndex {
            let c = line[i]
            if inQuotes {
                if c == "\"" {
                    let next = line.index(after: i)
                    if next < line.endIndex && line[next] == "\"" {
                        current.append("\"")
                        i = line.index(after: next)
                        continue
                    } else {
                        inQuotes = false
                    }
                } else {
                    current.append(c)
                }
            } else {
                if c == "\"" {
                    inQuotes = true
                } else if c == "," {
                    fields.append(current)
                    current = ""
                } else {
                    current.append(c)
                }
            }
            i = line.index(after: i)
        }
        fields.append(current)
        return fields
    }
}

struct CSVImportResult {
    let importedCards: [WordCard]
    let skippedRows: [CSVImportSkippedRow]

    var importedCount: Int { importedCards.count }
    var skippedCount: Int { skippedRows.count }
}

struct CSVImportSkippedRow: Identifiable {
    let id = UUID()
    let rowNumber: Int
    let rawValue: String
    let reason: CSVImportSkipReason
}

enum CSVImportSkipReason: String {
    case emptyLine
    case missingRequiredColumns
    case missingRequiredValues

    var description: String {
        switch self {
        case .emptyLine:
            return "空行のためスキップ"
        case .missingRequiredColumns:
            return "Japanese / English 列が不足しているためスキップ"
        case .missingRequiredValues:
            return "Japanese または English が空のためスキップ"
        }
    }
}

// MARK: - Array safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - エラー定義

enum CSVError: LocalizedError {
    case emptyFile

    var errorDescription: String? {
        switch self {
        case .emptyFile:
            return "CSVファイルにデータがありません"
        }
    }
}
