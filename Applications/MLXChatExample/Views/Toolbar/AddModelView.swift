//
//  AddModelView.swift
//  MLXChatExample
//

import SwiftUI

/// Sheet for adding a Hugging Face model repo by id or URL, and managing previously added ones.
struct AddModelView: View {
    @Bindable var vm: ChatViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var input = ""
    @State private var typeChoice: CustomModelStore.ModelTypeChoice = .auto
    @State private var isAdding = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("org/model-name or huggingface.co URL", text: $input)
                        #if os(iOS)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                        #endif
                        .autocorrectionDisabled()
                        .onSubmit(addModel)

                    Picker("Type", selection: $typeChoice) {
                        Text("Auto-detect").tag(CustomModelStore.ModelTypeChoice.auto)
                        Text("Text (LLM)").tag(CustomModelStore.ModelTypeChoice.llm)
                        Text("Vision (VLM)").tag(CustomModelStore.ModelTypeChoice.vlm)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }

                    Button {
                        addModel()
                    } label: {
                        if isAdding {
                            ProgressView()
                        } else {
                            Text("Add")
                        }
                    }
                    .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || isAdding)
                }

                if !vm.customModels.entries.isEmpty {
                    Section("Your models") {
                        ForEach(vm.customModels.entries, id: \.self) { entry in
                            Text(entry.id)
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                vm.removeCustomModel(vm.customModels.entries[index])
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Model")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func addModel() {
        errorMessage = nil
        isAdding = true

        Task {
            do {
                try await vm.customModels.add(input, forcing: typeChoice)
                input = ""
                typeChoice = .auto
            } catch {
                errorMessage = error.localizedDescription
            }
            isAdding = false
        }
    }
}

#Preview {
    AddModelView(vm: ChatViewModel(mlxService: MLXService()))
}
