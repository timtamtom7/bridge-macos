import SwiftUI
extension View {
    func accessibilityDeviceLabel(name: String) -> some View {
        self.accessibilityLabel("Device \(name)")
    }
}
