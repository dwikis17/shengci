import SwiftUI

struct WordOverviewGrid: View {
    let items: [WordOverviewItem]
    @Binding var currentWordID: UUID?
    let namespace: Namespace.ID
    let savedWordKeys: Set<String>
    let onSelectWord: (UUID) -> Void

    @State private var indicatorFlashTrigger = false

    private let columns = [
        GridItem(.adaptive(minimum: 95, maximum: 125), spacing: 12),
    ]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(items) { item in
                        WordOverviewTile(
                            item: item,
                            isSelected: item.id == currentWordID,
                            isSaved: savedWordKeys.contains(item.simplified),
                            namespace: namespace,
                            onSelect: {
                                onSelectWord(item.id)
                            }
                        )
                        .id(item.id)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.visible)
            .scrollIndicatorsFlash(trigger: indicatorFlashTrigger)
            .onAppear {
                if let currentWordID {
                    proxy.scrollTo(currentWordID, anchor: .center)
                }
                indicatorFlashTrigger.toggle()
            }
            .onChange(of: currentWordID) { _, newID in
                guard let newID else { return }
                proxy.scrollTo(newID, anchor: .center)
            }
        }
    }
}
