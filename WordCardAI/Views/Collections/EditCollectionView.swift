import SwiftUI

struct EditCollectionView: View {
    @Environment(\.dismiss) private var dismiss

    let collection: CardCollection
    @ObservedObject var viewModel: CollectionsViewModel
    @State private var title: String
    @FocusState private var isTitleFocused: Bool

    init(collection: CardCollection, viewModel: CollectionsViewModel) {
        self.collection = collection
        self.viewModel = viewModel
        _title = State(initialValue: collection.title)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("デッキ名", text: $title)
                        .focused($isTitleFocused)
                } header: {
                    Text("デッキ名を編集")
                }
            }
            .navigationTitle("デッキ編集")
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
                    Button("保存") {
                        viewModel.renameCollection(collection, title: title)
                        dismiss()
                    }
                    .disabled(title.trimmed.isEmpty || title.trimmed == collection.title)
                }
            }
            .onAppear {
                isTitleFocused = true
            }
        }
    }
}

#Preview {
    EditCollectionView(
        collection: CardCollection(title: "日常会話"),
        viewModel: CollectionsViewModel(storage: UserDefaultsStorage())
    )
}
