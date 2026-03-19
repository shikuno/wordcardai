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
            }
            .onDelete(perform: deleteCollections)
        }
        .listStyle(.plain)
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
    
    private func deleteCollections(at offsets: IndexSet) {
        for index in offsets {
            let collection = viewModel.collections[index]
            cardsViewModel.deleteCards(for: collection.id)
            viewModel.deleteCollection(collection)
        }
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
