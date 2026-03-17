// ChatMessage.swift
import Foundation

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let text: String
    let createdAt: Date = .now

    enum Role { case user, assistant }
}
