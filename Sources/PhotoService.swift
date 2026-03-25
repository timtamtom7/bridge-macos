import Foundation
import AppKit
import Photos
import SQLite

actor PhotoService {
    func scanPhotosFromDevice(_ device: Device) async -> [Photo] {
        guard let mountPath = mountDevice(device) else { return [] }
        var photos: [Photo] = []
        let dcimPath = mountPath.appendingPathComponent("DCIM")
        guard let enumerator = FileManager.default.enumerator(at: dcimPath, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey], options: [.skipsHiddenFiles]) else { return [] }
        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            guard ["jpg", "jpeg", "png", "heic", "heif", "gif", "tiff", "bmp"].contains(ext) else { continue }
            let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
            photos.append(Photo(filename: fileURL.lastPathComponent, path: fileURL.path, creationDate: resourceValues?.creationDate, fileSize: Int64(resourceValues?.fileSize ?? 0)))
        }
        return photos
    }

    private func mountDevice(_ device: Device) -> URL? {
        let candidatePaths = ["/Volumes/\(device.name)/DCIM", "/Volumes/MobileSync/DCIM", "/Volumes/iPhone/DCIM"]
        for path in candidatePaths { if FileManager.default.fileExists(atPath: path) { return URL(fileURLWithPath: path) } }
        return nil
    }

    func isDuplicate(_ photo: Photo) async -> Bool {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dbPath = appSupport.appendingPathComponent("Bridge/bridge.db")
        guard let db = try? Connection(dbPath.path) else { return false }
        let table = Table("imported_photos")
        let query = table.filter(Expression<String>("filename") == photo.filename)
        do { if let _ = try db.pluck(query) { return true } } catch { }
        return false
    }

    func importPhoto(_ photo: Photo, from device: Device) async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return false }
        guard FileManager.default.fileExists(atPath: photo.path) else { return false }
        var placeholder: PHObjectPlaceholder?
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let creationRequest = PHAssetCreationRequest.forAsset()
                let url = URL(fileURLWithPath: photo.path)
                creationRequest.addResource(with: .photo, fileURL: url, options: nil)
                placeholder = creationRequest.placeholderForCreatedAsset
            }
            return placeholder != nil
        } catch { return false }
    }
}
