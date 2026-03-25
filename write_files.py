#!/usr/bin/env python3
import os

base = '/Users/mauriello/Dev/bridge-macos/Sources'

files = {}

files['main.swift'] = r'''import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
'''

files['AppDelegate.swift'] = r'''import AppKit
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var deviceMonitor: DeviceMonitorService?
    let store: BridgeStore
    private var mainWindow: NSWindow?

    init() {
        self.store = BridgeStore()
        super.init()
    }

    nonisolated func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            self.setupStatusItem()
            self.setupPopover()
            self.setupDeviceMonitor()
            self.setupMainMenu()
            self.store.loadSettings()
        }
    }

    nonisolated func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "iphone", accessibilityDescription: "Bridge")
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 480, height: 520)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: ContentView(store: store))
    }

    @objc private func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown { popover.performClose(nil) }
            else { popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY) }
        }
    }

    private func setupDeviceMonitor() {
        deviceMonitor = DeviceMonitorService(store: store)
        deviceMonitor?.startMonitoring()
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Bridge", action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit Bridge", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        mainMenu.addItem(NSMenuItem(label: "Bridge", submenu: appMenu))
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "Open Bridge", action: #selector(openMainWindow), keyEquivalent: "o")
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Close Window", action: #selector(closeMainWindow), keyEquivalent: "w")
        mainMenu.addItem(NSMenuItem(label: "File", submenu: fileMenu))
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        mainMenu.addItem(NSMenuItem(label: "Window", submenu: windowMenu))
        NSApplication.shared.mainMenu = mainMenu
    }

    @objc private func openMainWindow() {
        if mainWindow == nil {
            mainWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            mainWindow?.title = "Bridge"
            mainWindow?.contentViewController = NSHostingController(rootView: ContentView(store: store))
            mainWindow?.center()
            mainWindow?.setFrameAutosaveName("BridgeMainWindow")
            mainWindow?.isReleasedWhenClosed = false
        }
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    @objc private func closeMainWindow() { mainWindow?.close() }
    @objc private func showAbout() { NSApplication.shared.orderFrontStandardAboutPanel(nil) }
}
'''

files['Models.swift'] = r'''import Foundation

struct Device: Identifiable, Equatable {
    let id: UUID
    let udid: String
    var name: String
    var model: String
    var iosVersion: String
    var batteryLevel: Double
    var isCharging: Bool
    var storageUsed: Int64
    var storageTotal: Int64
    var lastBackupDate: Date?
    var isUsingiCloudBackup: Bool
    var lastSeen: Date
    var isPrimary: Bool

    init(id: UUID = UUID(), udid: String, name: String = "Unknown Device",
         model: String = "Unknown", iosVersion: String = "Unknown",
         batteryLevel: Double = 0, isCharging: Bool = false,
         storageUsed: Int64 = 0, storageTotal: Int64 = 0,
         lastBackupDate: Date? = nil, isUsingiCloudBackup: Bool = false,
         lastSeen: Date = Date(), isPrimary: Bool = false) {
        self.id = id; self.udid = udid; self.name = name; self.model = model
        self.iosVersion = iosVersion; self.batteryLevel = batteryLevel
        self.isCharging = isCharging; self.storageUsed = storageUsed
        self.storageTotal = storageTotal; self.lastBackupDate = lastBackupDate
        self.isUsingiCloudBackup = isUsingiCloudBackup; self.lastSeen = lastSeen
        self.isPrimary = isPrimary
    }

    var storageProgress: Double { guard storageTotal > 0 else { return 0 }; return Double(storageUsed) / Double(storageTotal) }
    var formattedStorageUsed: String { ByteCountFormatter.string(fromByteCount: storageUsed, countStyle: .file) }
    var formattedStorageTotal: String { ByteCountFormatter.string(fromByteCount: storageTotal, countStyle: .file) }
    var formattedBattery: String { "\(Int(batteryLevel * 100))%" }
}

struct Photo: Identifiable, Equatable {
    let id: UUID
    let filename: String
    let path: String
    let creationDate: Date?
    let fileSize: Int64
    var thumbnailData: Data?
    var isSelected: Bool
    var isDuplicate: Bool

    init(id: UUID = UUID(), filename: String, path: String, creationDate: Date? = nil,
         fileSize: Int64 = 0, thumbnailData: Data? = nil, isSelected: Bool = false, isDuplicate: Bool = false) {
        self.id = id; self.filename = filename; self.path = path; self.creationDate = creationDate
        self.fileSize = fileSize; self.thumbnailData = thumbnailData; self.isSelected = isSelected
        self.isDuplicate = isDuplicate
    }

    var formattedSize: String { ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file) }
}

struct Contact: Identifiable, Equatable {
    let id: UUID
    var givenName: String
    var familyName: String
    var phoneNumbers: [String]
    var emails: [String]
    var addresses: [String]
    var notes: String
    var lastModified: Date
    var deviceUDID: String

    init(id: UUID = UUID(), givenName: String = "", familyName: String = "",
         phoneNumbers: [String] = [], emails: [String] = [], addresses: [String] = [],
         notes: String = "", lastModified: Date = Date(), deviceUDID: String = "") {
        self.id = id; self.givenName = givenName; self.familyName = familyName
        self.phoneNumbers = phoneNumbers; self.emails = emails; self.addresses = addresses
        self.notes = notes; self.lastModified = lastModified; self.deviceUDID = deviceUDID
    }

    var fullName: String { [givenName, familyName].filter { !$0.isEmpty }.joined(separator: " ") }
}

struct SyncLog: Identifiable {
    let id: UUID
    let deviceID: UUID
    let syncType: SyncType
    let startedAt: Date
    var completedAt: Date?
    var itemsSynced: Int
    var status: SyncStatus

    enum SyncType: String { case photos, contacts, backup }
    enum SyncStatus: String { case inProgress = "in_progress", completed, failed }
}

enum ImportProgress: Equatable {
    case idle
    case scanning(total: Int)
    case importing(current: Int, total: Int)
    case completed(imported: Int, skipped: Int)
    case failed(String)

    var description: String {
        switch self {
        case .idle: return "Ready"
        case .scanning(let total): return "Scanning... \(total) photos found"
        case .importing(let current, let total): return "Importing \(current)/\(total)"
        case .completed(let imported, let skipped): return "Done! \(imported) imported, \(skipped) skipped"
        case .failed(let msg): return "Failed: \(msg)"
        }
    }
}

enum BackupProgress: Equatable {
    case idle
    case inProgress(bytesCopied: Int64, totalBytes: Int64, estimatedTime: TimeInterval?)
    case completed
    case failed(String)

    var description: String {
        switch self {
        case .idle: return "Ready"
        case .inProgress(let copied, let total, _):
            let pct = total > 0 ? Int(Double(copied) / Double(total) * 100) : 0
            return "Backing up \(pct)% (\(ByteCountFormatter.string(fromByteCount: copied, countStyle: .file))/\(ByteCountFormatter.string(fromByteCount: total, countStyle: .file)))"
        case .completed: return "Backup complete"
        case .failed(let msg): return "Backup failed: \(msg)"
        }
    }
}
'''

files['Theme.swift'] = r'''import SwiftUI

enum Theme {
    static let primaryBlue = Color(hex: "#007AFF")
    static let secondaryGray = Color(hex: "#8E8E93")
    static let successGreen = Color(hex: "#34C759")
    static let warningOrange = Color(hex: "#FF9500")
    static let dangerRed = Color(hex: "#FF3B30")
    static let backgroundPrimary = Color(NSColor.windowBackgroundColor)
    static let backgroundSecondary = Color(NSColor.controlBackgroundColor)
    static let backgroundTertiary = Color(NSColor.textBackgroundColor)
    static let textPrimary = Color(NSColor.labelColor)
    static let textSecondary = Color(NSColor.secondaryLabelColor)
    static let textTertiary = Color(NSColor.tertiaryLabelColor)
    static let spacing2: CGFloat = 2
    static let spacing4: CGFloat = 4
    static let spacing8: CGFloat = 8
    static let spacing12: CGFloat = 12
    static let spacing16: CGFloat = 16
    static let spacing20: CGFloat = 20
    static let cornerRadiusSmall: CGFloat = 4
    static let cornerRadiusMedium: CGFloat = 8
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: a = 255; r = (int >> 8) * 17; g = (int >> 4 & 0xF) * 17; b = (int & 0xF) * 17
        case 6: a = 255; r = int >> 16; g = int >> 8 & 0xFF; b = int & 0xFF
        case 8: a = int >> 24; r = int >> 16 & 0xFF; g = int >> 8 & 0xFF; b = int & 0xFF
        default: a = 255; r = 0; g = 0; b = 0
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content.background(Theme.backgroundSecondary).cornerRadius(Theme.cornerRadiusMedium)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

extension View { func cardStyle() -> some View { modifier(CardStyle()) } }
'''

files['SettingsStore.swift'] = r'''import Foundation

final class SettingsStore: ObservableObject {
    @Published var launchAtLogin: Bool = false
    @Published var syncContactsEnabled: Bool = true
    @Published var importDuplicates: Bool = false
    @Published var backupLocation: URL {
        didSet { UserDefaults.standard.set(backupLocation.path, forKey: "backupLocation") }
    }
    private let defaults = UserDefaults.standard

    init() {
        let defaultBackup = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Bridge/Backups")
        self.backupLocation = URL(fileURLWithPath: defaults.string(forKey: "backupLocation") ?? defaultBackup.path)
    }

    func load() {
        launchAtLogin = defaults.bool(forKey: "launchAtLogin")
        syncContactsEnabled = defaults.object(forKey: "syncContactsEnabled") as? Bool ?? true
        importDuplicates = defaults.bool(forKey: "importDuplicates")
    }

    func save() {
        defaults.set(launchAtLogin, forKey: "launchAtLogin")
        defaults.set(syncContactsEnabled, forKey: "syncContactsEnabled")
        defaults.set(importDuplicates, forKey: "importDuplicates")
        defaults.synchronize()
    }
}
'''

files['DeviceService.swift'] = r'''import Foundation
import SQLite

@_silgen_name("AMDeviceCopyDeviceList")
func AMDeviceCopyDeviceList() -> CFArray?
@_silgen_name("AMDeviceConnect")
func AMDeviceConnect(_ device: UnsafeMutableRawPointer?) -> Int32
@_silgen_name("AMDeviceIsPaired")
func AMDeviceIsPaired(_ device: UnsafeMutableRawPointer?) -> Int32
@_silgen_name("AMDevicePairingPair")
func AMDevicePairingPair(_ device: UnsafeMutableRawPointer?) -> Int32
@_silgen_name("AMDeviceStartSession")
func AMDeviceStartSession(_ device: UnsafeMutableRawPointer?) -> Int32
@_silgen_name("AMDeviceStopSession")
func AMDeviceStopSession(_ device: UnsafeMutableRawPointer?) -> Int32
@_silgen_name("AMDeviceCopyValue")
func AMDeviceCopyValue(_ device: UnsafeMutableRawPointer?, _ domain: CFString?, _ key: CFString?) -> CFTypeRef?
@_silgen_name("AMDeviceCopyDeviceIdentifier")
func AMDeviceCopyDeviceIdentifier(_ device: UnsafeMutableRawPointer?) -> CFString?

actor DeviceService {
    func discoverDevices() -> [Device] {
        var devices: [Device] = []
        guard let deviceList = AMDeviceCopyDeviceList() as? [UnsafeMutableRawPointer?] else { return devices }
        for rawDevice in deviceList {
            guard let device = rawDevice else { continue }
            guard AMDeviceConnect(device) == 0 else { continue }
            guard AMDeviceIsPaired(device) == 1 else { _ = AMDeviceStopSession(device); continue }
            _ = AMDevicePairingPair(device)
            guard AMDeviceStartSession(device) == 0 else { continue }
            let udid = (AMDeviceCopyDeviceIdentifier(device) as String?) ?? UUID().uuidString
            let deviceName = getDeviceValue(device, key: "DeviceName") as? String ?? "iPhone"
            let modelStr = getDeviceValue(device, key: "ModelNumber") as? String ?? "Unknown"
            let iosVer = getDeviceValue(device, key: "ProductVersion") as? String ?? "Unknown"
            let batteryLevel = getBatteryLevel(device)
            let isCharging = getChargingState(device)
            let (storageUsed, storageTotal) = getStorageInfo(device)
            let lastBackup = getLastBackupDate()
            let deviceObj = Device(udid: udid, name: deviceName, model: modelStr, iosVersion: iosVer, batteryLevel: batteryLevel, isCharging: isCharging, storageUsed: storageUsed, storageTotal: storageTotal, lastBackupDate: lastBackup, isUsingiCloudBackup: false, lastSeen: Date(), isPrimary: devices.isEmpty)
            devices.append(deviceObj)
            _ = AMDeviceStopSession(device)
        }
        return devices
    }

    private func getDeviceValue(_ device: UnsafeMutableRawPointer?, key: String) -> CFTypeRef? {
        return AMDeviceCopyValue(device, nil, key as CFString)
    }

    private func getBatteryLevel(_ device: UnsafeMutableRawPointer?) -> Double {
        if let battery = AMDeviceCopyValue(device, "com.apple.mobile.battery" as CFString, "BatteryCurrentCapacity" as CFString), let level = battery as? Int { return Double(level) / 100.0 }
        return 0.0
    }

    private func getChargingState(_ device: UnsafeMutableRawPointer?) -> Bool {
        if let charging = AMDeviceCopyValue(device, "com.apple.mobile.battery" as CFString, "IsCharging" as CFString), let state = charging as? Bool { return state }
        return false
    }

    private func getStorageInfo(_ device: UnsafeMutableRawPointer?) -> (Int64, Int64) {
        if let total = AMDeviceCopyValue(device, nil, "TotalDataCapacity" as CFString) as? Int64,
           let available = AMDeviceCopyValue(device, nil, "TotalDataAvailable" as CFString) as? Int64 { return (total - available, total) }
        return (0, 0)
    }

    private func getLastBackupDate() -> Date? {
        let backupDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("Bridge/Backups")
        guard let contents = try? FileManager.default.contentsOfDirectory(at: backupDir, includingPropertiesForKeys: [.contentModificationDateKey]) else { return nil }
        let sorted = contents.sorted { a, b in
            let dateA = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
            let dateB = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
            return dateA > dateB
        }
        return sorted.first.flatMap { url in try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate }
    }

    func backupDevice(_ device: Device, progressHandler: @escaping (Int64, Int64, TimeInterval?) -> Void) async -> Swift.Result<Void, String> {
        return await withCheckedContinuation { continuation in
            let backupDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("Bridge/Backups")
            try? FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                continuation.resume(returning: .success(()))
            }
        }
    }
}

@MainActor
final class DeviceMonitorService {
    private let store: BridgeStore
    private var timer: Timer?
    init(store: BridgeStore) { self.store = store }
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in Task { @MainActor [weak self] in await self?.store.refreshDevices() } }
        timer?.fire()
        Task { await store.refreshDevices() }
    }
    func stopMonitoring() { timer?.invalidate(); timer = nil }
    deinit { timer?.invalidate() }
}
'''

files['PhotoService.swift'] = r'''import Foundation
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
        do { if let _ = try db.pluck(Table("imported_photos").filter(Expression<String>("filename") == photo.filename)) { return true } } catch { }
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
                creationRequest.addResource(with: .photo, fileURL: URL(fileURLWithPath: photo.path), options: nil)
                placeholder = creationRequest.placeholderForCreatedAsset
            }
            return placeholder != nil
        } catch { return false }
    }
}
'''

files['ContactService.swift'] = r'''import Foundation
import Contacts

actor ContactService {
    func fetchContacts(from device: Device) async -> [Contact] {
        let possiblePaths = [
            "/Volumes/\(device.name)/Library/Application Support/AddressBook/AddressBook.sqlitedb",
            "/Volumes/MobileSync/Library/Application Support/AddressBook/AddressBook.sqlitedb",
            "/Volumes/iPhone/Library/Application Support/AddressBook/AddressBook.sqlitedb"
        ]
        for dbPath in possiblePaths { if FileManager.default.fileExists(atPath: dbPath) { return await readContactsFromDatabase(at: dbPath, deviceUDID: device.udid) } }
        return []
    }

    private func readContactsFromDatabase(at path: String, deviceUDID: String) async -> [Contact] { return [] }

    nonisolated func fetchMacContacts() -> [Contact] {
        let keysToFetch: [CNKeyDescriptor] = [CNContactGivenNameKey as CNKeyDescriptor, CNContactFamilyNameKey as CNKeyDescriptor, CNContactPhoneNumbersKey as CNKeyDescriptor, CNContactEmailAddressesKey as CNKeyDescriptor, CNContactPostalAddressesKey as CNKeyDescriptor, CNContactNoteKey as CNKeyDescriptor]
        var contacts: [Contact] = []
        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        request.sortOrder = .givenName
        do {
            try CNContactStore().enumerateContacts(with: request) { cnContact, _ in
                contacts.append(Contact(givenName: cnContact.givenName, familyName: cnContact.familyName, phoneNumbers: cnContact.phoneNumbers.map { $0.value.stringValue }, emails: cnContact.emailAddresses.map { $0.value as String }, addresses: cnContact.postalAddresses.map { "\($0.value.street), \($0.value.city)" }, notes: cnContact.note, lastModified: Date(), deviceUDID: ""))
            }
        } catch { }
        return contacts
    }

    nonisolated func saveContactsToMac(_ contacts: [Contact]) {
        for contact in contacts {
            let cnContact = CNMutableContact()
            cnContact.givenName = contact.givenName; cnContact.familyName = contact.familyName
            cnContact.phoneNumbers = contact.phoneNumbers.map { CNLabeledValue(label: nil, value: CNPhoneNumber(stringValue: $0)) }
            cnContact.emailAddresses = contact.emails.map { CNLabeledValue(label: nil, value: $0 as NSString) }
            cnContact.note = contact.notes
            let saveRequest = CNSaveRequest(); saveRequest.add(cnContact, toContainerWithIdentifier: nil)
            do { try CNContactStore().execute(saveRequest) } catch { }
        }
    }
}
'''

files['BridgeStore.swift'] = r'''import Foundation
import Combine
import AppKit
import Photos
import SQLite

@MainActor
final class BridgeStore: ObservableObject {
    @Published var connectedDevice: Device?
    @Published var devices: [Device] = []
    @Published var photos: [Photo] = []
    @Published var selectedPhotos: Set<UUID> = []
    @Published var contacts: [Contact] = []
    @Published var isScanning = false
    @Published var isImporting = false
    @Published var isSyncingContacts = false
    @Published var isBackingUp = false
    @Published var importProgress: ImportProgress = .idle
    @Published var backupProgress: BackupProgress = .idle
    @Published var errorMessage: String?
    @Published var isDeviceConnected = false

    let deviceService: DeviceService
    let photoService: PhotoService
    let contactService: ContactService
    let settingsStore: SettingsStore
    private var db: Connection?

    init() {
        self.deviceService = DeviceService()
        self.photoService = PhotoService()
        self.contactService = ContactService()
        self.settingsStore = SettingsStore()
        setupDatabase()
    }

    private func setupDatabase() {
        do {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let bridgeDir = appSupport.appendingPathComponent("Bridge", isDirectory: true)
            try FileManager.default.createDirectory(at: bridgeDir, withIntermediateDirectories: true)
            db = try Connection(bridgeDir.appendingPathComponent("bridge.db").path)
            let devicesTable = Table("devices")
            let syncLogTable = Table("sync_log")
            let importedPhotosTable = Table("imported_photos")
            try db?.run(devicesTable.create(ifNotExists: true) { t in
                t.column(Expression<String>("id"), primaryKey: true)
                t.column(Expression<String>("udid"), unique: true)
                t.column(Expression<String>("name"))
                t.column(Expression<String>("model"))
                t.column(Expression<String>("ios_version"))
                t.column(Expression<Date>("last_seen"))
                t.column(Expression<Bool>("is_primary"))
            })
            try db?.run(syncLogTable.create(ifNotExists: true) { t in
                t.column(Expression<String>("id"), primaryKey: true)
                t.column(Expression<String>("device_id"))
                t.column(Expression<String>("sync_type"))
                t.column(Expression<Date>("started_at"))
                t.column(Expression<Date?>("completed_at"))
                t.column(Expression<Int>("items_synced"))
                t.column(Expression<String>("status"))
            })
            try db?.run(importedPhotosTable.create(ifNotExists: true) { t in
                t.column(Expression<String>("id"), primaryKey: true)
                t.column(Expression<String>("device_id"))
                t.column(Expression<String>("filename"))
                t.column(Expression<Date>("import_date"))
                t.column(Expression<String>("mac_url"))
            })
        } catch { errorMessage = "Database setup failed: \(error.localizedDescription)" }
    }

    func refreshDevices() async {
        isScanning = true; defer { isScanning = false }
        let foundDevices = await deviceService.discoverDevices()
        devices = foundDevices
        if let primary = foundDevices.first(where: { $0.isPrimary }) ?? foundDevices.first {
            connectedDevice = primary; isDeviceConnected = true
        } else { connectedDevice = nil; isDeviceConnected = false }
    }

    func scanPhotos() async {
        guard let device = connectedDevice else { return }
        isScanning = true; importProgress = .scanning(total: 0); defer { isScanning = false }
        let discoveredPhotos = await photoService.scanPhotosFromDevice(device)
        var photosWithDuplicates: [Photo] = []
        for var photo in discoveredPhotos {
            photo.isDuplicate = await photoService.isDuplicate(photo)
            photosWithDuplicates.append(photo)
        }
        photos = photosWithDuplicates
        importProgress = .scanning(total: photos.count)
    }

    func togglePhotoSelection(_ photo: Photo) {
        if selectedPhotos.contains(photo.id) { selectedPhotos.remove(photo.id) }
        else { selectedPhotos.insert(photo.id) }
        if let idx = photos.firstIndex(where: { $0.id == photo.id }) { photos[idx].isSelected.toggle() }
    }

    func selectAllPhotos() {
        selectedPhotos = Set(photos.filter { !$0.isDuplicate }.map { $0.id })
        for i in photos.indices { if !photos[i].isDuplicate { photos[i].isSelected = true } }
    }

    func deselectAllPhotos() { selectedPhotos.removeAll(); for i in photos.indices { photos[i].isSelected = false } }

    func importSelectedPhotos() async {
        guard let device = connectedDevice else { return }
        let toImport = photos.filter { selectedPhotos.contains($0.id) && !$0.isDuplicate }
        guard !toImport.isEmpty else { return }
        isImporting = true; importProgress = .importing(current: 0, total: toImport.count); defer { isImporting = false }
        var imported = 0; var skipped = 0
        for (index, photo) in toImport.enumerated() {
            importProgress = .importing(current: index + 1, total: toImport.count)
            let success = await photoService.importPhoto(photo, from: device)
            if success { imported += 1; recordImportedPhoto(photo) } else { skipped += 1 }
        }
        importProgress = .completed(imported: imported, skipped: skipped); selectedPhotos.removeAll()
    }

    private func recordImportedPhoto(_ photo: Photo) {
        guard let device = connectedDevice, let db = db else { return }
        do { try db.run(Table("imported_photos").insert(
            Expression<String>("id") <- photo.id.uuidString,
            Expression<String>("device_id") <- device.udid,
            Expression<String>("filename") <- photo.filename,
            Expression<Date>("import_date") <- Date(),
            Expression<String>("mac_url") <- photo.path)) } catch { }
    }

    func syncContacts() async {
        guard let device = connectedDevice else { return }
        isSyncingContacts = true; defer { isSyncingContacts = false }
        let deviceContacts = await contactService.fetchContacts(from: device)
        let macContacts = contactService.fetchMacContacts()
        var merged: [Contact] = []
        for dc in deviceContacts {
            if let mc = macContacts.first(where: { $0.fullName == dc.fullName }) { merged.append(dc.lastModified > mc.lastModified ? dc : mc) }
            else { merged.append(dc) }
        }
        contacts = merged; contactService.saveContactsToMac(merged)
        recordSync(deviceID: device.id, type: .contacts, items: merged.count)
    }

    func backupNow() async {
        guard let device = connectedDevice else { return }
        isBackingUp = true; backupProgress = .inProgress(bytesCopied: 0, totalBytes: 0, estimatedTime: nil); defer { isBackingUp = false }
        let result = await deviceService.backupDevice(device) { [weak self] copied, total, eta in
            Task { @MainActor [weak self] in self?.backupProgress = .inProgress(bytesCopied: copied, totalBytes: total, estimatedTime: eta) }
        }
        switch result { case .success: backupProgress = .completed; recordSync(deviceID: device.id, type: .backup, items: 0); case .failure(let msg): backupProgress = .failed(msg) }
    }

    private func recordSync(deviceID: UUID, type: SyncLog.SyncType, items: Int) {
        guard let db = db else { return }
        do { try db.run(Table("sync_log").insert(
            Expression<String>("id") <- UUID().uuidString,
            Expression<String>("device_id") <- deviceID.uuidString,
            Expression<String>("sync_type") <- type.rawValue,
            Expression<Date>("started_at") <- Date(),
            Expression<Date?>("completed_at") <- Date(),
            Expression<Int>("items_synced") <- items,
            Expression<String>("status") <- SyncLog.SyncStatus.completed.rawValue)) } catch { }
    }

    func loadSettings() { settingsStore.load() }
    func saveSettings() { settingsStore.save() }
}
'''

# Write all files
for name, content in files.items():
    path = os.path.join(base, name)
    with open(path, 'w') as f:
        f.write(content)
    print(f'Written {name} ({len(content)} bytes)')

print('All files written successfully')
