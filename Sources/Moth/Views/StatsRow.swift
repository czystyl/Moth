import SwiftUI

struct StatsRow: View {
    let category: ActivityCategory
    let seconds: Int
    let isActive: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(category.color)
                .frame(width: 10, height: 10)
                .overlay {
                    if isActive {
                        Circle()
                            .stroke(category.color, lineWidth: 2)
                            .frame(width: 16, height: 16)
                    }
                }

            Text(category.label)
                .font(.system(.body, design: .rounded))
                .fontWeight(isActive ? .semibold : .regular)

            Spacer()

            Text(TimeFormatter.format(seconds: seconds))
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
