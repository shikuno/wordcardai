//
//  CreateCollectionView.swift
//  WordCardAI
//
//  Created by YuyaFuruichi on 2025/11/23.
//

import SwiftUI

struct CreateCollectionView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: CollectionsViewModel
    @State private var title: String = ""
    @FocusState private var isTitleFocused: Bool
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("カード集の名前", text: $title)
                        .focused($isTitleFocused)
                } header: {
                    Text("カード集名")
                }
                
                Section {
                    Text("例: 日常会話、ビジネス英語、旅行フレーズ")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("新しいカード集")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("作成") {
                        createCollection()
                    }
                    .disabled(title.trimmed.isEmpty)
                }
            }
            .onAppear {
                isTitleFocused = true
            }
        }
    }
    
    private func createCollection() {
        viewModel.createCollection(title: title.trimmed)
        dismiss()
    }
}

#Preview {
    CreateCollectionView(viewModel: CollectionsViewModel(storage: UserDefaultsStorage()))
}
