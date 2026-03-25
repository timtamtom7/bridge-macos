import SwiftUI

struct ContentView: View {
    @ObservedObject var bridgeStore: BridgeStore
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "bridge.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("Bridge")
                    .font(.title2.bold())
                Spacer()
                Button("Open") {
                    NSApp.sendAction(#selector(AppDelegate.openMainWindow), to: nil, from: nil)
                }
                .buttonStyle(.borderless)
            }
            .padding()

            Divider()

            Picker("", selection: $selectedTab) {
                Image(systemName: "iphone").tag(0)
                Image(systemName: "photo").tag(1)
                Image(systemName: "person.2").tag(2)
                Image(systemName: "externaldrive").tag(3)
            }
            .pickerStyle(.segmented)
            .padding()

            TabView(selection: $selectedTab) {
                DeviceTab(bridgeStore: bridgeStore).tag(0)
                PhotosTab(bridgeStore: bridgeStore).tag(1)
                ContactsTab(bridgeStore: bridgeStore).tag(2)
                BackupTab(bridgeStore: bridgeStore).tag(3)
            }
            .tabViewStyle(.automatic)
        }
        .frame(width: 480, height: 520)
    }
}

struct DeviceTab: View {
    @ObservedObject var bridgeStore: BridgeStore

    var body: some View {
        VStack(spacing: 16) {
            if let d = bridgeStore.connectedDevice {
                DeviceCard(device: d)
            } else {
                VStack {
                    Image(systemName: "iphone.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No Device Connected")
                        .font(.headline)
                    Text("Connect your iOS device")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding()
    }
}

struct DeviceCard: View {
    let device: DeviceInfo

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "iphone")
                    .font(.system(size: 36))
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading) {
                    Text(device.name).font(.headline)
                    Text(device.model).font(.caption).foregroundColor(.secondary)
                    Text("iOS \(device.iosVersion)").font(.caption2).foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    HStack {
                        Image(systemName: device.isCharging ? "bolt.fill" : "battery.100")
                            .foregroundColor(device.isCharging ? .green : .primary)
                        Text("\(device.batteryLevel)%").font(.caption.monospacedDigit())
                    }
                    if device.isCharging {
                        Text("Charging").font(.caption2).foregroundColor(.green)
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Storage").font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Text("\(ByteCountFormatter.string(fromByteCount: device.storageUsed, countStyle: .file)) / \(ByteCountFormatter.string(fromByteCount: device.storageTotal, countStyle: .file))")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                ProgressView(value: Double(device.storageUsed), total: Double(device.storageTotal))
                    .progressViewStyle(.linear)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct PhotosTab: View {
    @ObservedObject var bridgeStore: BridgeStore

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("\(bridgeStore.devicePhotos.count) photos")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: { Task { await bridgeStore.refreshPhotos() } }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }

            if bridgeStore.devicePhotos.isEmpty {
                VStack {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No photos found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 4) {
                        ForEach(bridgeStore.devicePhotos.prefix(20), id: \.id) { _ in
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .aspectRatio(1, contentMode: .fit)
                                .cornerRadius(4)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                )
                        }
                    }
                }
            }

            if bridgeStore.isImportingPhotos {
                HStack {
                    ProgressView()
                    Text("Importing... \(Int(bridgeStore.importProgress * 100))%")
                }
            }
        }
    }
}

struct ContactsTab: View {
    @ObservedObject var bridgeStore: BridgeStore

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("\(bridgeStore.deviceContacts.count) contacts")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: { Task { await bridgeStore.syncContacts() } }) {
                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .disabled(bridgeStore.connectedDevice == nil)
            }

            if bridgeStore.deviceContacts.isEmpty {
                VStack {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No contacts found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(bridgeStore.deviceContacts.prefix(10), id: \.id) { c in
                    VStack(alignment: .leading) {
                        Text(c.displayName)
                            .font(.caption)
                            .lineLimit(1)
                        if let e = c.emails.first {
                            Text(e)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

struct BackupTab: View {
    @ObservedObject var bridgeStore: BridgeStore

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading) {
                Label("Last Backup", systemImage: "clock.arrow.circlepath")
                    .font(.caption.bold())

                if let lb = bridgeStore.lastBackupDate {
                    Text(lb, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Never")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if bridgeStore.isBackingUp {
                    VStack(spacing: 4) {
                        ProgressView(value: bridgeStore.backupProgress)
                            .progressViewStyle(.linear)
                        Text("\(Int(bridgeStore.backupProgress * 100))% complete")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)

            HStack {
                Image(systemName: bridgeStore.iCloudBackupEnabled ? "checkmark.icloud" : "xmark.icloud")
                    .foregroundColor(bridgeStore.iCloudBackupEnabled ? .green : .secondary)
                Text("iCloud: \(bridgeStore.iCloudBackupEnabled ? "Enabled" : "Disabled")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }

            Spacer()

            Button("Backup Now") {
                Task { await bridgeStore.backupNow() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(bridgeStore.connectedDevice == nil || bridgeStore.isBackingUp)
            .frame(maxWidth: .infinity)
        }
        .padding()
    }
}
