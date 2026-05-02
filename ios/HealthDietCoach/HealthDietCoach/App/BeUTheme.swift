import SwiftUI
import UIKit

// All new UI must use BeUTheme tokens. Do not hardcode colors directly in views.
enum BeUTheme {
    static let bg = Color(hex: "#FADADD")
    static let card = Color.white
    static let cardAlt = Color(hex: "#FCF4F3")
    static let accent2 = Color(hex: "#F5C6CE")
    static let ink = Color.black
    static let ink2 = Color(hex: "#333333")
    static let ink3 = Color(hex: "#555555")
    static let hairline = Color.black.opacity(0.06)
    static let ok = Color(hex: "#7FA89A")
    static let warn = Color(hex: "#C9A86A")
    static let alert = Color(hex: "#D08F8F")

    static let background = Color(hex: "#FADADD")
    static let backgroundGlow = Color(hex: "#FDE9EC")
    static let surface = Color(hex: "#FFF5F7")
    static let cardBackground = Color.white
    static let cardAltBackground = surface
    static let primaryText = Color.black
    static let secondaryText = Color(hex: "#333333")
    static let tertiaryText = Color(hex: "#555555")
    static let mutedText = Color(hex: "#555555")
    static let helperText = Color(hex: "#555555")
    static let placeholderText = Color(hex: "#777777")
    static let inputBackground = Color.white
    static let inputText = Color.black
    static let inputPlaceholder = Color(hex: "#777777")
    static let inputBorder = Color.black.opacity(0.12)
    static let accentPink = Color(hex: "#FF8FAB")
    static let accent = accentPink
    static let accentSoft = Color(hex: "#F5C6CE")
    static let macroCarb = Color(hex: "#C9A86A")
    static let macroFat = Color(hex: "#7FA89A")
    static let buttonBackground = Color.black
    static let buttonText = Color.white
    static let highStatus = Color(hex: "#7FA89A")
    static let moderateStatus = Color(hex: "#C9A86A")
    static let lowStatus = Color(hex: "#D08F8F")
    static let border = inputBorder
    static let divider = Color.black.opacity(0.1)
    static let cardBorder = Color.black.opacity(0.06)
    static let shadow = Color(red: 190 / 255, green: 100 / 255, blue: 130 / 255).opacity(0.04)
    static let glassBackground = Color.white.opacity(0.52)
    static let glassStroke = Color.white.opacity(0.75)
    static let neutralStub = Color.black.opacity(0.08)
    static let neutralTrack = Color.black.opacity(0.12)

    static let titleFont = Font.system(size: 28, weight: .bold)
    static let sectionTitleFont = Font.system(size: 17, weight: .semibold)
    static let bodyFont = Font.system(size: 15, weight: .regular)
    static let helperFont = Font.system(size: 13, weight: .regular)
    static let buttonFont = Font.system(size: 16, weight: .semibold)
    static let kickerFont = Font.system(size: 10.5, weight: .semibold)
    static let bigNumberFont = Font.system(size: 40, weight: .light, design: .rounded)

    static var greetingHeroFont: Font {
        if UIFont(name: "InstrumentSerif-Italic", size: 30) != nil {
            return .custom("InstrumentSerif-Italic", size: 30)
        }
        if UIFont(name: "Instrument Serif Italic", size: 30) != nil {
            return .custom("Instrument Serif Italic", size: 30)
        }
        return .system(size: 30, weight: .light, design: .serif).italic()
    }

    static func bigNumber(size: CGFloat) -> Font {
        .system(size: size, weight: .light, design: .rounded)
    }
}

struct BeUPrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(BeUPrimaryButtonStyle())
    }
}

struct BeUSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(BeUTheme.sectionTitleFont)
            .foregroundColor(BeUTheme.primaryText)
    }
}

struct BeUPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BeUTheme.buttonFont)
            .foregroundColor(BeUTheme.buttonText)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(BeUTheme.buttonBackground.opacity(configuration.isPressed ? 0.85 : 1))
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct BeUSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BeUTheme.buttonFont)
            .foregroundColor(BeUTheme.primaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(BeUTheme.cardBackground.opacity(configuration.isPressed ? 0.82 : 1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(BeUTheme.divider, lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct BeUCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .foregroundColor(BeUTheme.primaryText)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(BeUTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(BeUTheme.cardBorder, lineWidth: 0.5)
                )
        )
        .shadow(color: BeUTheme.shadow, radius: 16, x: 0, y: 4)
    }
}

struct BeUSectionTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(BeUTheme.sectionTitleFont)
            .foregroundColor(BeUTheme.primaryText)
    }
}

struct BeUFormLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(BeUTheme.kickerFont)
            .foregroundColor(BeUTheme.secondaryText)
    }
}

struct BeUFormCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(BeUTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(BeUTheme.inputBorder, lineWidth: 1)
                )
        )
    }
}

struct BeUTextField: View {
    let placeholder: String
    @Binding var text: String
    var autocapitalization: TextInputAutocapitalization = .sentences
    var disableAutocorrection = false

    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(BeUTheme.bodyFont)
                    .foregroundColor(BeUTheme.inputPlaceholder)
                    .padding(.horizontal, 12)
            }

            TextField("", text: $text)
                .font(BeUTheme.bodyFont)
                .foregroundColor(BeUTheme.inputText)
                .tint(BeUTheme.primaryText)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled(disableAutocorrection)
                .padding(.horizontal, 12)
        }
        .frame(height: 48)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(BeUTheme.inputBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(BeUTheme.inputBorder, lineWidth: 1)
                )
        )
    }
}

struct BeUNumberField: View {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .decimalPad

    var body: some View {
        BeUTextField(placeholder: placeholder, text: $text)
            .keyboardType(keyboardType)
    }
}

struct BeUTextArea: View {
    let placeholder: String
    @Binding var text: String
    var minHeight: CGFloat = 96

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(BeUTheme.inputBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(BeUTheme.inputBorder, lineWidth: 1)
                )

            if text.isEmpty {
                Text(placeholder)
                    .font(BeUTheme.bodyFont)
                    .foregroundColor(BeUTheme.inputPlaceholder)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
            }

            TextEditor(text: $text)
                .font(BeUTheme.bodyFont)
                .foregroundColor(BeUTheme.inputText)
                .tint(BeUTheme.primaryText)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .frame(minHeight: minHeight)
        }
    }
}

struct BeUToggleRow: View {
    let title: String
    let helper: String?
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(BeUTheme.bodyFont.weight(.semibold))
                    .foregroundColor(BeUTheme.primaryText)
                if let helper {
                    Text(helper)
                        .font(BeUTheme.helperFont)
                        .foregroundColor(BeUTheme.mutedText)
                }
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(BeUTheme.accent)
        }
    }
}

private struct BeUInputFieldStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(BeUTheme.bodyFont)
            .foregroundColor(BeUTheme.inputText)
            .tint(BeUTheme.primaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(BeUTheme.inputBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(BeUTheme.border, lineWidth: 1)
                    )
            )
    }
}

private struct BeUSegmentedControlStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .pickerStyle(.segmented)
            .tint(BeUTheme.accent)
            .environment(\.colorScheme, .light)
            .foregroundColor(BeUTheme.primaryText)
    }
}

private struct BeUMenuPickerStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .pickerStyle(.menu)
            .tint(BeUTheme.primaryText)
            .foregroundColor(BeUTheme.primaryText)
    }
}

extension View {
    func beuInputFieldStyle() -> some View {
        modifier(BeUInputFieldStyleModifier())
    }

    func beuSegmentedControlStyle() -> some View {
        modifier(BeUSegmentedControlStyleModifier())
    }

    func beuMenuPickerStyle() -> some View {
        modifier(BeUMenuPickerStyleModifier())
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }

    init(hex: String, alpha: Double = 1) {
        let sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        let value = UInt(sanitized, radix: 16) ?? 0
        self.init(hex: value, alpha: alpha)
    }
}
