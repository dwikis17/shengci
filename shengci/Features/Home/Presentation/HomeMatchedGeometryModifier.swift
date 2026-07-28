import SwiftUI

struct HomeMatchedGeometryModifier: ViewModifier {
    let id: String
    let namespace: Namespace.ID
    let isEnabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content.matchedGeometryEffect(id: id, in: namespace)
        } else {
            content
        }
    }
}

extension View {
    func homeMatchedGeometryEffect(
        id: String,
        in namespace: Namespace.ID,
        isEnabled: Bool
    ) -> some View {
        modifier(
            HomeMatchedGeometryModifier(
                id: id,
                namespace: namespace,
                isEnabled: isEnabled
            )
        )
    }
}
