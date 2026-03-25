import SwiftUI

struct SkeletonView: View {
    @State private var isAnimating = false
    
    let width: CGFloat?
    let height: CGFloat
    
    init(width: CGFloat? = nil, height: CGFloat = 20) {
        self.width = width
        self.height = height
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.gray.opacity(0.2),
                        Color.gray.opacity(0.3),
                        Color.gray.opacity(0.2)
                    ]),
                    startPoint: isAnimating ? .leading : .trailing,
                    endPoint: isAnimating ? .trailing : .leading
                )
            )
            .frame(width: width, height: height)
            .onAppear {
                withAnimation(
                    Animation.linear(duration: 1.5)
                        .repeatForever(autoreverses: false)
                ) {
                    isAnimating = true
                }
            }
    }
}

struct SkeletonRowView: View {
    var body: some View {
        HStack(spacing: 12) {
            SkeletonView(width: 50, height: 50)
            
            VStack(alignment: .leading, spacing: 8) {
                SkeletonView(width: 150, height: 14)
                SkeletonView(width: 100, height: 12)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

struct SkeletonListView: View {
    let count: Int
    
    init(count: Int = 5) {
        self.count = count
    }
    
    var body: some View {
        ForEach(0..<count, id: \.self) { _ in
            SkeletonRowView()
        }
    }
}

// MARK: - Pull to Refresh

struct PullToRefresh: ViewModifier {
    let action: () -> Void
    
    func body(content: Content) -> some View {
        content
            .refreshable {
                action()
            }
    }
}

extension View {
    func pullToRefresh(action: @escaping () -> Void) -> some View {
        modifier(PullToRefresh(action: action))
    }
}

// MARK: - Context Menu

struct ContextMenuItem: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let action: () -> Void
}

struct ContextMenuView: View {
    let items: [ContextMenuItem]
    
    var body: some View {
        ForEach(items) { item in
            Button(action: item.action) {
                Label(item.title, systemImage: item.systemImage)
            }
        }
    }
}
