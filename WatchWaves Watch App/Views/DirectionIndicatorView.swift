import SwiftUI

struct DirectionIndicatorView: View {
    let degrees: Double
    var size: CGFloat = 24

    var body: some View {
        Image(systemName: "arrow.up")
            .font(.system(size: size, weight: .bold))
            .rotationEffect(.degrees(degrees + 180))
            .foregroundStyle(.cyan)
    }
}

#Preview {
    DirectionIndicatorView(degrees: 225, size: 40)
}
