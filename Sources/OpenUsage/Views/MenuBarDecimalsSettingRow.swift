import SwiftUI

/// The menu-bar precision control, using the same row spacing and switch style as Settings.
struct MenuBarDecimalsSettingRow: View {
    @Binding var hideDecimals: Bool
    @AppStorage(DensitySetting.key) private var density = DensitySetting.regular

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text("Hide Menu Bar Decimals")
                Spacer(minLength: 8)
                Toggle("Hide Menu Bar Decimals", isOn: $hideDecimals)
                    .settingsSwitchStyle()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, density.controlRowPadding)
            Text("Truncate values in the menu bar: ¥7.99 → ¥7.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
