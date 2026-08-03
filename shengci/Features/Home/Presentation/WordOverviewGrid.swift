import SwiftUI

struct WordOverviewGrid: View {
    let items: [WordOverviewItem]
    @Binding var currentWordID: UUID?
    let namespace: Namespace.ID
    let savedWordKeys: Set<String>
    let onSelectWord: (UUID) -> Void

    @State private var visibleIndex: Int
    @State private var lastScrubbedIndex: Int?
    @State private var lastScrubTimestamp = 0.0
    @State private var lastVisibleUpdateTimestamp = 0.0

    // ponytail: cap scrubber state updates at 30 Hz; exact word jumps stay available.
    private let visibleUpdateInterval = 1.0 / 30.0
    private let columns = [
        GridItem(.adaptive(minimum: 95, maximum: 125), spacing: 12),
    ]
    private let indexByID: [UUID: Int]

    init(
        items: [WordOverviewItem],
        currentWordID: Binding<UUID?>,
        namespace: Namespace.ID,
        savedWordKeys: Set<String>,
        onSelectWord: @escaping (UUID) -> Void
    ) {
        let indexByID = Dictionary(
            uniqueKeysWithValues: items.enumerated().map { ($1.id, $0) }
        )
        let initialID = currentWordID.wrappedValue

        self.items = items
        self._currentWordID = currentWordID
        self.namespace = namespace
        self.savedWordKeys = savedWordKeys
        self.onSelectWord = onSelectWord
        self.indexByID = indexByID
        self._visibleIndex = State(
            initialValue: initialID.flatMap { indexByID[$0] } ?? 0
        )
    }

    var body: some View {
        ScrollViewReader { proxy in
            GeometryReader { viewport in
                ZStack(alignment: .trailing) {
                    trackedScrollView(viewportHeight: viewport.size.height)

                    PersistentScrollScrubber(
                        progress: scrollProgress,
                        previewCharacter: visibleItem?.simplified ?? "",
                        position: visibleIndex + 1,
                        total: items.count,
                        onScrub: { progress, isFinal in
                            scrub(to: progress, isFinal: isFinal, proxy: proxy)
                        }
                    )
                    .padding(.top, 56)
                    .padding(.bottom, 40)
                    .padding(.trailing, 2)
                }
                .onAppear {
                    if let currentWordID {
                        proxy.scrollTo(currentWordID, anchor: .center)
                    }
                }
                .onChange(of: currentWordID) { _, newID in
                    guard let newID else { return }
                    proxy.scrollTo(newID, anchor: .center)
                }
            }
        }
    }

    private var scrollProgress: Double {
        guard items.count > 1 else { return 0 }
        return Double(visibleIndex) / Double(items.count - 1)
    }

    private var visibleItem: WordOverviewItem? {
        guard items.indices.contains(visibleIndex) else { return nil }
        return items[visibleIndex]
    }

    @ViewBuilder
    private func trackedScrollView(viewportHeight: Double) -> some View {
        if #available(iOS 18.0, *) {
            overviewScrollView
                .onScrollGeometryChange(for: Double.self) { geometry in
                    let contentHeight = geometry.contentSize.height
                        + geometry.contentInsets.top
                        + geometry.contentInsets.bottom
                    let maximumOffset = max(
                        contentHeight - geometry.containerSize.height,
                        1
                    )
                    let offset = geometry.contentOffset.y
                        + geometry.contentInsets.top

                    return min(max(offset / maximumOffset, 0), 1)
                } action: { _, progress in
                    updateVisibleIndex(from: progress)
                }
        } else {
            overviewScrollView
                .onPreferenceChange(
                    ScrollMetricsPreferenceKey.self
                ) { metrics in
                    updateVisibleIndex(
                        from: metrics,
                        viewportHeight: viewportHeight
                    )
                }
        }
    }

    private var overviewScrollView: some View {
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
                    .equatable()
                    .id(item.id)
                }
            }
            .padding(.leading, 20)
            .padding(.trailing, 56)
            .padding(.top, 56)
            .padding(.bottom, 40)
            .background {
                GeometryReader { content in
                    Color.clear.preference(
                        key: ScrollMetricsPreferenceKey.self,
                        value: ScrollMetrics(
                            minimumY: content.frame(
                                in: .named("word-overview-scroll")
                            ).minY,
                            contentHeight: content.size.height
                        )
                    )
                }
            }
        }
        .coordinateSpace(name: "word-overview-scroll")
        .scrollIndicators(.hidden)
    }

    private func scrub(
        to progress: Double,
        isFinal: Bool,
        proxy: ScrollViewProxy
    ) {
        guard !items.isEmpty else { return }

        let targetIndex = min(
            max(Int((Double(items.count - 1) * progress).rounded()), 0),
            items.count - 1
        )
        let now = Date.timeIntervalSinceReferenceDate
        let hasWaitedForNextFrame = now - lastScrubTimestamp >= 1.0 / 30.0

        guard
            isFinal
                || (targetIndex != lastScrubbedIndex && hasWaitedForNextFrame)
        else {
            return
        }

        lastScrubbedIndex = targetIndex
        lastScrubTimestamp = now
        visibleIndex = targetIndex

        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            proxy.scrollTo(items[targetIndex].id, anchor: .top)
        }
    }

    private func updateVisibleIndex(
        from metrics: ScrollMetrics,
        viewportHeight: Double
    ) {
        guard !items.isEmpty else { return }

        let maximumOffset = max(metrics.contentHeight - viewportHeight, 1)
        let progress = min(max(-metrics.minimumY / maximumOffset, 0), 1)
        updateVisibleIndex(from: progress)
    }

    private func updateVisibleIndex(from progress: Double) {
        guard !items.isEmpty else { return }

        let index = Int(
            (progress * Double(items.count - 1)).rounded()
        )

        guard index != visibleIndex else { return }

        let now = Date.timeIntervalSinceReferenceDate
        guard
            now - lastVisibleUpdateTimestamp >= visibleUpdateInterval
                || progress <= 0
                || progress >= 1
        else { return }

        lastVisibleUpdateTimestamp = now
        visibleIndex = index
    }
}
