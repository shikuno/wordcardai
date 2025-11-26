//
//  CardsListView.swift
//  WordCardAI
//
//  Created by YuyaFuruichi on 2025/11/23.
//

import SwiftUI

struct CardsListView: View {
    let collection: CardCollection
    @ObservedObject var cardsViewModel: CardsViewModel
    @ObservedObject var collectionsViewModel: CollectionsViewModel
    @EnvironmentObject var settingsService: SettingsService
    
    @State private var showingCreateCard = false
    @State private var showingLearnMode = false
    @State private var editingCard: WordCard?
    
    var body: some View {
        ZStack {
            if cardsViewModel.filteredCards.isEmpty && cardsViewModel.searchText.isEmpty {
                emptyStateView
            } else {
                cardsList
            }
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { showingCreateCard = true }) {
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
        .navigationTitle(collection.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .searchable(text: $cardsViewModel.searchText, prompt: "カードを検索")
        .onAppear {
            cardsViewModel.loadCards(for: collection.id)
        }
        .sheet(isPresented: $showingCreateCard) {
            CreateEditCardView(
                collection: collection,
                cardsViewModel: cardsViewModel,
                settingsService: settingsService,
                card: nil
            )
        }
        .sheet(item: $editingCard) { card in
            CreateEditCardView(
                collection: collection,
                cardsViewModel: cardsViewModel,
                settingsService: settingsService,
                card: card
            )
        }
        .sheet(isPresented: $showingLearnMode) {
            LearnModeView(cards: cardsViewModel.cards)
        }
    }
    
    private var cardsList: some View {
        VStack(spacing: 0) {
            if !cardsViewModel.cards.isEmpty {
                Button(action: { showingLearnMode = true }) {
                    HStack {
                        Image(systemName: "graduationcap.fill")
                        Text("学習モード")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            
            List {
                ForEach(cardsViewModel.filteredCards) { card in
                    Button(action: { editingCard = card }) {
                        CardRow(card: card)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: deleteCards)
            }
            .listStyle(.plain)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("カードがありません")
                .font(.headline)
            
            Text("+ ボタンで新しいカードを作成しましょう")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    private func deleteCards(at offsets: IndexSet) {
        for index in offsets {
            let card = cardsViewModel.filteredCards[index]
            cardsViewModel.deleteCard(card)
        }
    }
}

struct CardRow: View {
    let card: WordCard
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(card.japanese)
                .font(.body)
                .foregroundColor(.primary)
            
            Text(card.english)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if !card.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(card.tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        CardsListView(
            collection: CardCollection(title: "日常会話"),
            cardsViewModel: CardsViewModel(storage: UserDefaultsStorage()),
            collectionsViewModel: CollectionsViewModel(storage: UserDefaultsStorage())
        )
        .environmentObject(SettingsService(storage: UserDefaultsStorage()))
    }
}
