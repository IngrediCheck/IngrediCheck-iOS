import SwiftUI
import Foundation
import Supabase
import CryptoKit

struct FileCacheEntry: Codable {
    let localFileUrl: URL
    let fileSizeOnDisk: Int64
    var lastAccessed: Date
}

struct SupabaseFile: Codable, Hashable {
    let bucket: String
    let name: String
}

enum FileLocation: Codable, Hashable {
    case url(URL)
    case supabase(SupabaseFile)
}

protocol FileStore {
    func fetchFile(fileLocation: FileLocation) async throws -> Data
}

struct ImageFileStore: FileStore {
    
    let resize: CGSize?

    func fetchFile(fileLocation: FileLocation) async throws -> Data {
        switch fileLocation {
        case .url(let url):
            return try await downloadImageFrom(url: url)
        case .supabase(let supabaseFile):
            return try await downloadImageFrom(supabaseFile: supabaseFile)
        }
    }
    
    private func downloadImageFrom(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse

        guard httpResponse.statusCode == 200 else {
            print("Bad response from server: \(httpResponse.statusCode)")
            throw NetworkError.invalidResponse(httpResponse.statusCode)
        }
        
        return await resizeIfNeeded(data)
    }
    
    private func downloadImageFrom(supabaseFile: SupabaseFile) async throws -> Data {
        let data = try await supabaseClient.storage
            .from(supabaseFile.bucket)
            .download(path: supabaseFile.name) //, options: TransformOptions(width: 0, height: 0))
        return await resizeIfNeeded(data)
    }
    
    private func resizeIfNeeded(_ data: Data) async -> Data {
        guard let resize else {
            return data
        }
        
        guard let uiImage = UIImage(data: data) else {
            return data
        }
        
        let resizedImage = await withCheckedContinuation { continuation in
            uiImage.prepareThumbnail(of: resize) { thumbnail in
                continuation.resume(returning: thumbnail)
            }
        }
        
        guard let resizedImage = resizedImage else {
            return data
        }
        
        // Check if the original image has transparency (alpha channel)
        // If it does, preserve PNG format; otherwise use JPEG for smaller size
        if let cgImage = uiImage.cgImage,
           cgImage.alphaInfo != .none && 
           cgImage.alphaInfo != .noneSkipFirst && 
           cgImage.alphaInfo != .noneSkipLast {
            // Has transparency - preserve as PNG
            if let pngData = resizedImage.pngData() {
                return pngData
            }
        }
        
        // No transparency or PNG conversion failed - use JPEG for smaller file size
        if let jpegData = resizedImage.jpegData(compressionQuality: 1.0) {
            return jpegData
        }
        
        // Fallback: return original data if both conversions fail
        return data
    }
}

actor FileCache: FileStore {
    let cacheName: String
    let maxDiskUsageInBytes: Int64
    let fileStore: FileStore
    var inMemoryStore: [FileLocation: FileCacheEntry] = [:]
    
    var cacheHit: Int = 0
    var cacheMiss: Int = 0

    init(
        cacheName: String,
        maximumDiskUsage: Int64,
        fileStore: FileStore
    ) {
        self.cacheName = cacheName
        self.maxDiskUsageInBytes = maximumDiskUsage
        self.fileStore = fileStore
        Task {
            await loadPersistedInMemoryStore()
        }
    }
    
    private var cacheDirectory: URL? {
        let cacheDirectoryParent = try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let cacheDir = cacheDirectoryParent?.appendingPathComponent(self.cacheName)
        try! FileManager.default.createDirectory(at: cacheDir!, withIntermediateDirectories: true, attributes: nil)
        return cacheDir
    }
    
    var cacheDirectorySize: Int64 {

        guard let cacheDirectory = cacheDirectory else { return 0 }
        return directorySize(url: cacheDirectory) / (1 * 1024 * 1024)
        
        func directorySize(url: URL) -> Int64 {
            let contents: [URL]
            do {
                contents = try FileManager.default.contentsOfDirectory(
                    at: cacheDirectory,
                    includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey])
            } catch {
                return 0
            }
            
            var size: Int64 = 0
            
            for url in contents {
                let isDirectoryResourceValue: URLResourceValues
                do {
                    isDirectoryResourceValue = try url.resourceValues(forKeys: [.isDirectoryKey])
                } catch {
                    continue
                }
                
                if isDirectoryResourceValue.isDirectory == true {
                    size += directorySize(url: url)
                } else {
                    let fileSizeResourceValue: URLResourceValues
                    do {
                        fileSizeResourceValue = try url.resourceValues(forKeys: [.fileSizeKey])
                    } catch {
                        continue
                    }
                    
                    size += Int64(fileSizeResourceValue.fileSize ?? 0)
                }
            }
            return size
        }
    }
    
    private var dictionaryFileUrl: URL? {
        return self.cacheDirectory?.appendingPathComponent("dictionary.json")
    }

    private func copyFileToCache(_ sourceFileUrl: URL, _ fileHash: String) -> URL? {
        let destinationUrl = self.cacheDirectory?.appendingPathComponent(fileHash)

        do {
            if let destinationUrl = destinationUrl {
                try FileManager.default.copyItem(at: sourceFileUrl, to: destinationUrl)
                return destinationUrl
            }
        } catch {
            print("Copy file error: \(error)")
        }
        return nil
    }

    private func pruneCache() {
        var currentDiskUsage = inMemoryStore.values.reduce(0) { $0 + $1.fileSizeOnDisk }
        let sortedKeys = inMemoryStore.keys.sorted { inMemoryStore[$0]!.lastAccessed < inMemoryStore[$1]!.lastAccessed }
        
        for key in sortedKeys where currentDiskUsage > maxDiskUsageInBytes {
            if let cacheEntry = inMemoryStore[key] {
                do {
                    print("FileCache: Deleting file")
                    try FileManager.default.removeItem(at: cacheEntry.localFileUrl)
                    currentDiskUsage -= cacheEntry.fileSizeOnDisk
                    inMemoryStore.removeValue(forKey: key)
                    persistInMemoryStore()
                } catch {
                    print("Error deleting file: \(error)")
                }
            }
        }
    }
    
    private func fileName(from fileLocation: FileLocation) -> String {
        switch fileLocation {
        case .url(let url):
            let urlString = url.absoluteString
            guard let data = urlString.data(using: .utf8) else { return "" }
            let hash = SHA256.hash(data: data)
            return hash.compactMap { String(format: "%02x", $0) }.joined()
        case .supabase(let supabaseFile):
            return supabaseFile.name
        }
    }
    
    private func cacheFile(fileLocation: FileLocation) async throws -> Data {
        let localFileUrl = (self.cacheDirectory?.appendingPathComponent(fileName(from: fileLocation)))!
        let fileData = try await fileStore.fetchFile(fileLocation: fileLocation)
        // TODO: Do the writing to file part in background.
        try fileData.write(to: localFileUrl)
        let fileSize = Int64(fileData.count)
        inMemoryStore[fileLocation] = FileCacheEntry(localFileUrl: localFileUrl, fileSizeOnDisk: fileSize, lastAccessed: Date())
        pruneCache()
        persistInMemoryStore()
        return fileData
    }

    func fetchFile(fileLocation: FileLocation) async throws -> Data {
        if var cacheEntry = inMemoryStore[fileLocation] {
            if FileManager.default.fileExists(atPath: cacheEntry.localFileUrl.path) {
                cacheEntry.lastAccessed = Date()
                inMemoryStore[fileLocation] = cacheEntry
                persistInMemoryStore()
                do {
                    let data = try Data(contentsOf: cacheEntry.localFileUrl)
                    self.cacheHit += 1
                    return data
                } catch {
                    print("Error reading file: \(error)")
                    throw error
                }
            }
        }
        self.cacheMiss += 1
        return try await cacheFile(fileLocation: fileLocation)
    }

    private func persistInMemoryStore() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let dictionaryFile = self.dictionaryFileUrl,
           let encodedData = try? encoder.encode(inMemoryStore) {
            try? encodedData.write(to: dictionaryFile)
        }
    }

    private func loadPersistedInMemoryStore() {
        if let dictionaryFile = self.dictionaryFileUrl,
           let data = try? Data(contentsOf: dictionaryFile) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            inMemoryStore = (try? decoder.decode([FileLocation: FileCacheEntry].self, from: data)) ?? [:]
            print("FileCache: Loaded \(inMemoryStore.count) entries")
            
            // This bizarre behavior happens when deploying a debug build to my phone.
            // The dictionary file exists, but all other cache files have been deleted.
            // So, go and cleanup stale entries from dictionary file.

            var keysToDelete: [FileLocation] = []
            for (key, value) in inMemoryStore {
                if !FileManager.default.fileExists(atPath: value.localFileUrl.path) {
                    keysToDelete.append(key)
                }
            }
            for key in keysToDelete {
                inMemoryStore.removeValue(forKey: key)
            }
            persistInMemoryStore()
        }
    }
}
