import SwiftUI

struct WordOverviewTile: View {
    let item: WordOverviewItem
    let isSelected: Bool
    let isSaved: Bool
    let namespace: Namespace.ID
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 4) {
                HStack {
                    Spacer()

                    if isSaved {
                        Image(systemName: "bookmark.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.roseAccent)
                    }
                }
                .frame(height: 10)

                Text(item.simplified)
                    .font(.title2.bold())
                    .fontDesign(.serif)
                    .foregroundStyle(Color.darkForeground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .homeMatchedGeometryEffect(
                        id: "overview-char-\(item.id)",
                        in: namespace,
                        isEnabled: isSelected
                    )

                if !item.pinyin.isEmpty {
                    Text(item.pinyin)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(
                            isSelected
                                ? Color.royalBlueAccent
                                : Color.darkForeground.opacity(0.7)
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        isSelected
                            ? Color.royalBlueAccent.opacity(0.12)
                            : Color.warmIvoryCard
                    )
                    .homeMatchedGeometryEffect(
                        id: "overview-tile-\(item.id)",
                        in: namespace,
                        isEnabled: isSelected
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected
                            ? Color.royalBlueAccent
                            : Color.black.opacity(0.06),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
            .shadow(
                color: isSelected
                    ? Color.royalBlueAccent.opacity(0.15)
                    : .clear,
                radius: isSelected ? 6 : 0,
                y: isSelected ? 2 : 0
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(item.simplified), \(item.pinyin)\(isSaved ? ", Bookmarked" : "")"
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("Double tap to jump to this word")
    }
}

extension WordOverviewTile: Equatable {
    static func == (lhs: WordOverviewTile, rhs: WordOverviewTile) -> Bool {
        lhs.item.id == rhs.item.id
            && lhs.item.simplified == rhs.item.simplified
            && lhs.item.pinyin == rhs.item.pinyin
            && lhs.isSelected == rhs.isSelected
            && lhs.isSaved == rhs.isSaved
    }
}
