import SwiftUI
import GlutenFreeCore

struct PreferencesView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var cuisineInput = ""
    @State private var ingredientInput = ""
    @State private var dislikeInput = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                AppCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Taste profile")
                            .font(.system(.title, design: .rounded, weight: .bold))
                        Text("Preferences shape ranking and filtering only. They never override safety warnings.")
                            .foregroundStyle(.secondary)
                        Toggle("Conservative safety mode", isOn: Binding(
                            get: { appModel.profile.conservativeMode },
                            set: { value in
                                var updated = appModel.profile
                                updated.conservativeMode = value
                                appModel.updateProfile(updated)
                            }
                        ))
                        .tint(AppPalette.accent)
                    }
                }

                preferenceEditor(
                    title: "Liked cuisines",
                    input: $cuisineInput,
                    values: appModel.profile.likedCuisines,
                    placeholder: "Add cuisine"
                ) { newValue in
                    var profile = appModel.profile
                    profile.likedCuisines.append(newValue)
                    profile.likedCuisines = Array(Set(profile.likedCuisines)).sorted()
                    appModel.updateProfile(profile)
                } onRemove: { value in
                    var profile = appModel.profile
                    profile.likedCuisines.removeAll { $0 == value }
                    appModel.updateProfile(profile)
                }

                preferenceEditor(
                    title: "Liked ingredients",
                    input: $ingredientInput,
                    values: appModel.profile.likedIngredients,
                    placeholder: "Add ingredient"
                ) { newValue in
                    var profile = appModel.profile
                    profile.likedIngredients.append(newValue)
                    profile.likedIngredients = Array(Set(profile.likedIngredients)).sorted()
                    appModel.updateProfile(profile)
                } onRemove: { value in
                    var profile = appModel.profile
                    profile.likedIngredients.removeAll { $0 == value }
                    appModel.updateProfile(profile)
                }

                preferenceEditor(
                    title: "Disliked ingredients",
                    input: $dislikeInput,
                    values: appModel.profile.dislikedIngredients,
                    placeholder: "Add ingredient to avoid"
                ) { newValue in
                    var profile = appModel.profile
                    profile.dislikedIngredients.append(newValue)
                    profile.dislikedIngredients = Array(Set(profile.dislikedIngredients)).sorted()
                    appModel.updateProfile(profile)
                } onRemove: { value in
                    var profile = appModel.profile
                    profile.dislikedIngredients.removeAll { $0 == value }
                    appModel.updateProfile(profile)
                }
            }
            .padding(20)
        }
        .background(AppPalette.canvas.ignoresSafeArea())
        .navigationTitle("Preferences")
    }

    private func preferenceEditor(
        title: String,
        input: Binding<String>,
        values: [String],
        placeholder: String,
        onAdd: @escaping (String) -> Void,
        onRemove: @escaping (String) -> Void
    ) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.headline)
                HStack {
                    TextField(placeholder, text: input)
                    Button("Add") {
                        let trimmed = input.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        onAdd(trimmed)
                        input.wrappedValue = ""
                    }
                    .font(.footnote.weight(.bold))
                    .disabled(input.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityHint("Adds this preference to your saved profile.")
                }
                .padding(12)
                .background(Color.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .animation(.spring(response: 0.28, dampingFraction: 0.85), value: values.count)

                FlowLayout(values, onRemove: onRemove)
            }
        }
    }
}

private struct FlowLayout: View {
    let values: [String]
    let onRemove: (String) -> Void

    init(_ values: [String], onRemove: @escaping (String) -> Void) {
        self.values = values
        self.onRemove = onRemove
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(values, id: \.self) { value in
                HStack {
                    PreferenceChip(title: value)
                    Spacer()
                    Button(role: .destructive) {
                        onRemove(value)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                    }
                    .accessibilityLabel("Remove \(value)")
                }
            }
        }
    }
}
