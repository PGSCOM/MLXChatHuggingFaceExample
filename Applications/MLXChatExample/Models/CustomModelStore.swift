//
//  CustomModelStore.swift
//  MLXChatExample
//

import Foundation
import MLXLMCommon

/// Persists user-added Hugging Face model repos and exposes them as `LMModel`s, so the
/// picker in `ChatToolbarView` can list them alongside `MLXService.availableModels`.
@Observable
@MainActor
final class CustomModelStore {
    /// A user-added model repo, identified by its Hugging Face id.
    struct Entry: Codable, Hashable {
        let id: String
        let isVision: Bool
    }

    /// How to classify a newly added repo.
    enum ModelTypeChoice: Hashable {
        case auto
        case llm
        case vlm
    }

    enum AddError: LocalizedError {
        case invalidId
        case alreadyAdded
        case notFound
        case notMLX

        var errorDescription: String? {
            switch self {
            case .invalidId:
                "Enter a repo id like \"org/model-name\" or a Hugging Face URL."
            case .alreadyAdded:
                "That model is already in your list."
            case .notFound:
                "That repo doesn't exist or is private."
            case .notMLX:
                "No .safetensors weights found. MLX Swift can't load GGUF repos directly."
            }
        }
    }

    private static let defaultsKey = "customModels"

    private(set) var entries: [Entry] {
        didSet { persist() }
    }

    init() {
        entries = Self.load()
    }

    /// The stored entries mapped to `LMModel`s ready for `MLXService`.
    var models: [LMModel] {
        entries.map {
            LMModel(
                name: $0.id,
                configuration: ModelConfiguration(id: $0.id),
                type: $0.isVision ? .vlm : .llm
            )
        }
    }

    /// Normalizes a pasted repo id or Hugging Face URL down to "org/model-name".
    static func normalize(_ input: String) -> String {
        var value = input.trimmingCharacters(in: .whitespacesAndNewlines)

        if let url = URL(string: value), let host = url.host, host.contains("huggingface.co") {
            value = url.path
        }

        // Drop leading/trailing slashes and any trailing path (e.g. "/tree/main", "/blob/...").
        let parts = value.split(separator: "/", omittingEmptySubsequences: true)
        return parts.prefix(2).joined(separator: "/")
    }

    /// Validates a repo against the Hugging Face API, classifies it, and adds it.
    func add(_ input: String, forcing choice: ModelTypeChoice = .auto) async throws {
        let id = Self.normalize(input)
        guard id.split(separator: "/").count == 2 else {
            throw AddError.invalidId
        }
        guard !entries.contains(where: { $0.id == id }) else {
            throw AddError.alreadyAdded
        }

        guard let url = URL(string: "https://huggingface.co/api/models/\(id)") else {
            throw AddError.invalidId
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AddError.notFound
        }

        let info = try? JSONDecoder().decode(HFModelInfo.self, from: data)
        let siblingNames = info?.siblings?.map(\.rfilename) ?? []
        guard siblingNames.contains(where: { $0.hasSuffix(".safetensors") }) else {
            throw AddError.notMLX
        }

        let isVision: Bool
        switch choice {
        case .llm:
            isVision = false
        case .vlm:
            isVision = true
        case .auto:
            // ponytail: heuristic on architectures/model_type; the manual override
            // (forcing: .llm/.vlm) is the escape hatch for whenever this guesses wrong.
            let signal = ((info?.config?.architectures ?? []) + [info?.config?.modelType ?? ""])
                .joined(separator: " ").lowercased()
            isVision = ["vl", "vision", "llava", "conditionalgeneration"].contains {
                signal.contains($0)
            }
        }

        entries.append(Entry(id: id, isVision: isVision))
    }

    func remove(_ entry: Entry) {
        entries.removeAll { $0 == entry }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
    }

    private static func load() -> [Entry] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
            let entries = try? JSONDecoder().decode([Entry].self, from: data)
        else { return [] }
        return entries
    }
}

/// Minimal subset of the Hugging Face model API response used for validation and classification.
private struct HFModelInfo: Decodable {
    struct Sibling: Decodable { let rfilename: String }
    struct Config: Decodable {
        let architectures: [String]?
        let modelType: String?

        enum CodingKeys: String, CodingKey {
            case architectures
            case modelType = "model_type"
        }
    }

    let siblings: [Sibling]?
    let config: Config?
}
