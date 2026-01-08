import SwiftUI

struct ProfileSetupView: View {
    @Binding var displayName: String
    let onContinue: () -> Void
    let onBack: () -> Void

    @FocusState private var isTextFieldFocused: Bool

    private var canContinue: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with Back Button and Icon
            VStack(spacing: 24) {
                // Top Bar
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundColor(BrandColors.primary)
                    }
                    Spacer()
                }
                .padding(.bottom, 8)

                // Icon
                ZStack {
                    Circle()
                        .fill(BrandColors.primary.opacity(0.1))
                        .frame(width: 80, height: 80)

                    Image(systemName: "person.fill")
                        .font(.system(size: 36))
                        .foregroundColor(BrandColors.primary)
                }
                .padding(.bottom, 8)

                // Title
                VStack(spacing: 12) {
                    Text("What's your name?")
                        .font(.largeTitle.weight(.bold))
                        .multilineTextAlignment(.center)
                        .tracking(-0.5)

                    Text("This is how you'll appear in the app")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer()
                .frame(height: 40)

            // Form field
            VStack(alignment: .leading, spacing: 8) {
                Text("Display Name")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)

                TextField("Your name", text: $displayName)
                    .font(.body)
                    .padding()
                    .frame(height: 54)
                    .background(Color(.systemGray6))
                    .cornerRadius(14)
                    .focused($isTextFieldFocused)
                    .autocapitalization(.words)
                    .disableAutocorrection(true)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                    )
            }
            .padding(.horizontal, 24)

            Spacer()

            // Continue Button
            Button(action: onContinue) {
                HStack {
                    Text("Continue")
                        .font(.headline.weight(.semibold))
                    Image(systemName: "arrow.right")
                        .font(.headline.weight(.bold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(canContinue ? BrandColors.primary : Color(.systemGray5))
                .foregroundColor(canContinue ? .white : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!canContinue)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .onAppear {
            isTextFieldFocused = true
        }
    }
}

#Preview {
    ProfileSetupView(
        displayName: .constant(""),
        onContinue: {},
        onBack: {}
    )
}
