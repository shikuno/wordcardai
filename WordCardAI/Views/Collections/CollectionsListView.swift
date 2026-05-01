//
//  CollectionsListView.swift
//  WordCardAI
//
//  Created by YuyaFuruichi on 2025/11/23.
//

import SwiftUI

struct CollectionsListView: View {
    @StateObject private var viewModel: CollectionsViewModel
    @ObservedObject var cardsViewModel: CardsViewModel
    @State private var showingCreateSheet = false
    @State private var showingSettings = false
    @State private var editingCollection: CardCollection?
    @State private var pendingDeleteCollections: [CardCollection] = []
    @State private var showDeleteConfirmation = false
    
    init(storage: StorageProtocol, cardsViewModel: CardsViewModel) {
        _viewModel = StateObject(wrappedValue: CollectionsViewModel(storage: storage))
        self.cardsViewModel = cardsViewModel
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.collections.isEmpty {
                    emptyStateView
                } else {
                    collectionsList
                }
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { showingCreateSheet = true }) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .padding()
                    }
                }
            }
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                }
                #endif
            }
            .sheet(isPresented: $showingCreateSheet) {
                CreateCollectionView(viewModel: viewModel)
            }
            .sheet(item: $editingCollection) { collection in
                EditCollectionView(collection: collection, viewModel: viewModel)
            }
            .sheet(isPresented: $showingSettings) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
    }
    
    private var collectionsList: some View {
        List {
            ForEach(viewModel.collections) { collection in
                NavigationLink(destination: CollectionCardView(
                    collection: collection,
                    cardsViewModel: cardsViewModel,
                    collectionsViewModel: viewModel
                )) {
                    CollectionRow(
                        collection: collection,
                        cardCount: cardsViewModel.cardCount(for: collection.id)
                    )
                }
                .contextMenu {
                    Button {
                        editingCollection = collection
                    } label: {
                        Label("名前を編集", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        pendingDeleteCollections = [collection]
                        showDeleteConfirmation = true
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button {
                        editingCollection = collection
                    } label: {
                        Label("編集", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
            }
            .onDelete(perform: confirmDeleteCollections)
        }
        .listStyle(.plain)
        .confirmationDialog(
            "このデッキを削除しますか？",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("削除する", role: .destructive) {
                deletePendingCollections()
            }
            Button("キャンセル", role: .cancel) {
                pendingDeleteCollections = []
            }
        } message: {
            Text(deleteConfirmationMessage)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("デッキがありません")
                .font(.headline)
            
            Text("+ ボタンで新しいデッキを作成しましょう")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    private var deleteConfirmationMessage: String {
        if pendingDeleteCollections.count == 1, let collection = pendingDeleteCollections.first {
            return "「\(collection.title)」を削除します。デッキ内のカードもすべて削除され、この操作は元に戻せません。"
        }
        return "\(pendingDeleteCollections.count) 個のデッキを削除します。デッキ内のカードもすべて削除され、この操作は元に戻せません。"
    }

    private func confirmDeleteCollections(at offsets: IndexSet) {
        pendingDeleteCollections = offsets.map { viewModel.collections[$0] }
        showDeleteConfirmation = !pendingDeleteCollections.isEmpty
    }

    private func deletePendingCollections() {
        for collection in pendingDeleteCollections {
            cardsViewModel.deleteCards(for: collection.id)
            viewModel.deleteCollection(collection)
        }
        pendingDeleteCollections = []
    }
}

struct CollectionRow: View {
    let collection: CardCollection
    let cardCount: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.stack.fill")
                    .font(.title3)
                    .foregroundStyle(Color.appAccent)
                    .frame(width: 28, height: 28)
                    .background(Color.appAccent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(collection.title)
                    .font(.headline)
            }
            
            HStack {
                Text("\(cardCount) 枚のカード")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("更新: \(collection.updatedAt.shortDateTimeFormatted())")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    CollectionsListView(
        storage: UserDefaultsStorage(),
        cardsViewModel: CardsViewModel(storage: UserDefaultsStorage())
    )
}
