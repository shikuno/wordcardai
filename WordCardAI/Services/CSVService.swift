
//
//  CSVService.swift
//  WordCardAI
//
//  Created by YuyaFuruichi on 2026/03/07.
//

import Foundation

struct CSVService {

    // MARK: - カラム定義
    // Japanese（必須）, English（必須）, Comment（任意）, Tags（任意・複数値は"|"区切り）

    static let header = "Japanese,English,Comment,Tags"

    // MARK: - エクスポート

    /// WordCard の配列を CSV 文字列に変換する（ヘッダー行付き）
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

    /// CSV 文字列を WordCard の配列にパースする
    /// - Parameter collectionId: インポート先のコレクション ID
    /// - Parameter csvString: パース対象の CSV 文字列
    static func `import`(csvString: String, into collectionId: UUID) throws -> [WordCard] {
        var lines = csvString.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else {
            throw CSVError.emptyFile
        }

        // 先頭がヘッダー行なら読み飛ばす（"Japanese" または "japanese" で始まる行）
        if lines.first?.lowercased().hasPrefix("japanese") == true {
            lines.removeFirst()
        }

        guard !lines.isEmpty else {
            throw CSVError.emptyFile
        }

        var cards: [WordCard] = []

        for (index, line) in lines.enumerated() {
            let fields = parseCSVLine(line)

            // Japanese と English は必須（最低2列）
            guard fields.count >= 2 else {
                throw CSVError.invalidFormat(line: index + 2)
            }

            let japanese = unescaped(fields[0])
            let english   = unescaped(fields[1])

            // Japanese・English が空文字の行はスキップ
            guard !japanese.isEmpty, !english.isEmpty else {
                throw CSVError.invalidFormat(line: index + 2)
            }

            let noteRaw = unescaped(fields[safe: 2] ?? "")
            let note: String? = noteRaw.isEmpty ? nil : noteRaw

            let tagsRaw = unescaped(fields[safe: 3] ?? "")
            let tags = tagsRaw.isEmpty ? [] : tagsRaw.components(separatedBy: "|")

            let card = WordCard(
                collectionId: collectionId,
                japanese: japanese,
                english: english,
                note: note,
                tags: tags
            )
            cards.append(card)
        }

        return cards
    }

    // MARK: - Private Helpers

    /// RFC 4180 準拠の CSV フィールドをエスケープ
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

    /// CSV の 1 行をフィールド配列にパース（クォート対応）
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

// MARK: - Array safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - エラー定義

enum CSVError: LocalizedError {
    case emptyFile
    case invalidFormat(line: Int)

    var errorDescription: String? {
        switch self {
        case .emptyFile:
            return "CSVファイルにデータがありません"
        case .invalidFormat(let line):
            return "\(line)行目のフォーマットが正しくありません（最低4列必要です: id, collectionId, japanese, english）"
        }
    }
}
