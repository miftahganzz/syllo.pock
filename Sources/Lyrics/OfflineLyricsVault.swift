//
//  OfflineLyricsVault.swift
//  lirik
//
//  Created by RidhaAF on 2024.
//  Enhanced & Recoded by Miftah on 2026.
//  Licensed under MIT License.
//

import Foundation

private struct VaultPayload: Codable {
    var lyrics: [String: CachedLyrics]
    var offsets: [String: Double]
}

final class OfflineLyricsVault {

    static let shared = OfflineLyricsVault()

    private let fileManager = FileManager.default
    private let vaultURL: URL
    private var inMemoryVault: [String: CachedLyrics] = [:]
    private var inMemoryOffsets: [String: Double] = [:]
    private let lock = NSLock()

    init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let pockDir = appSupport.appendingPathComponent("Pock/Widgets", isDirectory: true)

        try? fileManager.createDirectory(at: pockDir, withIntermediateDirectories: true)
        self.vaultURL = pockDir.appendingPathComponent("syllo_vault.json")

        // Auto-migrate existing lirik_vault.json if syllo_vault.json is not yet created
        let legacyURL = pockDir.appendingPathComponent("lirik_vault.json")
        if !fileManager.fileExists(atPath: vaultURL.path) && fileManager.fileExists(atPath: legacyURL.path) {
            try? fileManager.copyItem(at: legacyURL, to: vaultURL)
        }

        loadVaultFromDisk()
    }

    // MARK: - Vault Persistence

    private func loadVaultFromDisk() {
        guard fileManager.fileExists(atPath: vaultURL.path) else { return }
        lock.lock()
        defer { lock.unlock() }

        do {
            let data = try Data(contentsOf: vaultURL)
            if let payload = try? JSONDecoder().decode(VaultPayload.self, from: data) {
                self.inMemoryVault = payload.lyrics
                self.inMemoryOffsets = payload.offsets
                NSLog("[OfflineLyricsVault] Loaded \(payload.lyrics.count) songs & \(payload.offsets.count) offsets.")
            } else if let legacy = try? JSONDecoder().decode([String: CachedLyrics].self, from: data) {
                self.inMemoryVault = legacy
                self.inMemoryOffsets = [:]
                NSLog("[OfflineLyricsVault] Loaded \(legacy.count) legacy songs from offline vault.")
            }
        } catch {
            NSLog("[OfflineLyricsVault] Failed to load offline vault: \(error.localizedDescription)")
        }
    }

    private func saveVaultToDisk() {
        lock.lock()
        let payload = VaultPayload(lyrics: inMemoryVault, offsets: inMemoryOffsets)
        lock.unlock()

        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self else { return }
            do {
                let data = try JSONEncoder().encode(payload)
                try data.write(to: self.vaultURL, options: .atomic)
            } catch {
                NSLog("[OfflineLyricsVault] Failed to write vault to disk: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Lyrics Vault Access

    func get(byKey key: String) -> CachedLyrics? {
        lock.lock()
        defer { lock.unlock() }
        return inMemoryVault[key]
    }

    func save(_ entry: CachedLyrics) {
        lock.lock()
        inMemoryVault[entry.trackKey] = entry
        lock.unlock()
        saveVaultToDisk()
    }

    var totalSongsInVault: Int {
        lock.lock()
        defer { lock.unlock() }
        return inMemoryVault.count
    }

    func clearVault() {
        lock.lock()
        inMemoryVault.removeAll()
        inMemoryOffsets.removeAll()
        lock.unlock()
        try? fileManager.removeItem(at: vaultURL)
    }

    // MARK: - Timing Offset Calibrator (Feature 2)

    func getOffset(for trackKey: String) -> Double {
        lock.lock()
        defer { lock.unlock() }
        return inMemoryOffsets[trackKey] ?? 0.0
    }

    func setOffset(_ offset: Double, for trackKey: String) {
        lock.lock()
        inMemoryOffsets[trackKey] = offset
        lock.unlock()
        saveVaultToDisk()
    }

    @discardableResult
    func adjustOffset(by delta: Double, for trackKey: String) -> Double {
        lock.lock()
        let current = inMemoryOffsets[trackKey] ?? 0.0
        let updated = ((current + delta) * 100).rounded() / 100
        inMemoryOffsets[trackKey] = updated
        lock.unlock()
        saveVaultToDisk()
        return updated
    }

    // MARK: - Local .lrc File Auto-Scanner & Importer

    /// Searches ~/Music, ~/Downloads, and ~/Documents for a matching .lrc file.
    func findLocalLRC(title: String, artist: String) -> String? {
        let cleanTitle = sanitizeFilename(title)
        let cleanArtist = sanitizeFilename(artist)

        let targetFilenames = [
            "\(cleanTitle).lrc",
            "\(cleanArtist) - \(cleanTitle).lrc",
            "\(cleanTitle) - \(cleanArtist).lrc",
            "\(title).lrc",
            "\(artist) - \(title).lrc"
        ]

        let searchDirectories = [
            fileManager.urls(for: .musicDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        ].compactMap { $0 }

        for dir in searchDirectories {
            for filename in targetFilenames {
                let fileURL = dir.appendingPathComponent(filename)
                if fileManager.fileExists(atPath: fileURL.path),
                   let content = try? String(contentsOf: fileURL, encoding: .utf8),
                   !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    NSLog("[OfflineLyricsVault] Found matching local .lrc: \(fileURL.path)")
                    return content
                }
            }

            // Also check subdirectories in ~/Music/ (e.g. ~/Music/Artist/Album/Title.lrc)
            if let enumerator = fileManager.enumerator(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
                var depth = 0
                for case let fileURL as URL in enumerator {
                    if fileURL.pathExtension.lowercased() == "lrc" {
                        let name = fileURL.deletingPathExtension().lastPathComponent.lowercased()
                        if name.contains(cleanTitle.lowercased()) {
                            if let content = try? String(contentsOf: fileURL, encoding: .utf8),
                               !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                NSLog("[OfflineLyricsVault] Found nested local .lrc: \(fileURL.path)")
                                return content
                            }
                        }
                    }
                    depth += 1
                    if depth > 200 { break }
                }
            }
        }

        return nil
    }

    private func sanitizeFilename(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "\\/:*?\"<>|")
        return name.components(separatedBy: invalid).joined(separator: "")
    }
}
