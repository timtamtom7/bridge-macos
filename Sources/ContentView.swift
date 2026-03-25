import SwiftUI

struct ContentView: View {
    @ObservedObject var store: BridgeStore
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            headerView; Divider(); tabBar; Divider()
            TabView(selection: $selectedTab) {
                deviceInfoView.tag(0); photosView.tag(1); contactsView.tag(2); backupView.tag(3)
            }.tabViewStyle(.automatic)
            statusBar
        }.frame(width: 480, height: 520).background(Theme.backgroundPrimary)
    }

    private var headerView: some View {
        HStack(spacing: Theme.spacing12) {
            Image(systemName: "iphone").font(.title2).foregroundColor(store.isDeviceConnected ? Theme.primaryBlue : Theme.secondaryGray)
            VStack(alignment: .leading, spacing: 2) {
                if let device = store.connectedDevice {
                    Text(device.name).font(.headline).foregroundColor(Theme.textPrimary)
                    Text("iOS \(device.iosVersion) - \(device.model)").font(.caption).foregroundColor(Theme.textSecondary)
                } else {
                    Text("No Device Connected").font(.headline).foregroundColor(Theme.textSecondary)
                    Text("Connect an iOS device via USB").font(.caption).foregroundColor(Theme.textTertiary)
                }
            }
            Spacer()
            Button(action: { Task { await store.refreshDevices() } }) { Image(systemName: "arrow.clockwise").font(.body) }.buttonStyle(.borderless).disabled(store.isScanning)
        }.padding(Theme.spacing16).background(Theme.backgroundSecondary)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(title: "Device", icon: "iphone", tag: 0)
            tabButton(title: "Photos", icon: "photo.on.rectangle", tag: 1)
            tabButton(title: "Contacts", icon: "person.2", tag: 2)
            tabButton(title: "Backup", icon: "externaldrive.badge.timemachine", tag: 3)
        }.padding(.horizontal, Theme.spacing8).padding(.vertical, Theme.spacing4)
    }

    private func tabButton(title: String, icon: String, tag: Int) -> some View {
        Button(action: { selectedTab = tag }) {
            VStack(spacing: 4) { Image(systemName: icon).font(.body); Text(title).font(.caption2) }
                .foregroundColor(selectedTab == tag ? Theme.primaryBlue : Theme.textSecondary)
                .padding(.horizontal, Theme.spacing12).padding(.vertical, Theme.spacing4)
                .background(selectedTab == tag ? Theme.primaryBlue.opacity(0.1) : Color.clear)
                .cornerRadius(Theme.cornerRadiusSmall)
        }.buttonStyle(.borderless)
    }

    private var deviceInfoView: some View {
        ScrollView { VStack(alignment: .leading, spacing: Theme.spacing16) {
            if let device = store.connectedDevice { deviceCard(device) }
            else { emptyStateView(icon: "iphone.slash", title: "No Device", message: "Connect an iOS device to get started") }
        }.padding(Theme.spacing16) }
    }

    private func deviceCard(_ device: Device) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing16) {
            VStack(alignment: .leading, spacing: Theme.spacing4) {
                HStack { Image(systemName: batteryIcon(device)).foregroundColor(batteryColor(device)); Text(device.formattedBattery).font(.headline); Text(device.isCharging ? "Charging" : "On Battery").font(.caption).foregroundColor(Theme.textSecondary); Spacer() }
                ProgressView(value: device.batteryLevel).tint(batteryColor(device))
            }
            Divider()
            VStack(alignment: .leading, spacing: Theme.spacing4) {
                Text("Storage").font(.subheadline).foregroundColor(Theme.textSecondary)
                HStack { ProgressView(value: device.storageProgress).tint(storageColor(device.storageProgress)); Spacer(); Text("\\(device.formattedStorageUsed) / \(device.formattedStorageTotal)").font(.caption).foregroundColor(Theme.textSecondary) }
            }
            Divider()
            VStack(alignment: .leading, spacing: Theme.spacing4) {
                HStack { Image(systemName: device.isUsingiCloudBackup ? "icloud.fill" : "externaldrive").foregroundColor(Theme.primaryBlue); Text(device.isUsingiCloudBackup ? "iCloud Backup" : "Local Backup").font(.subheadline); Spacer() }
                if let lastBackup = device.lastBackupDate { Text("Last backup: \(lastBackup.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundColor(Theme.textSecondary) }
            }
        }.padding(Theme.spacing16).cardStyle()
    }

    private func batteryIcon(_ device: Device) -> String {
        if device.isCharging { return "battery.100.bolt" }
        if device.batteryLevel > 0.75 { return "battery.100" }
        if device.batteryLevel > 0.5 { return "battery.75" }
        if device.batteryLevel > 0.25 { return "battery.50" }
        return "battery.25"
    }

    private func batteryColor(_ device: Device) -> Color {
        if device.isCharging { return Theme.successGreen }
        if device.batteryLevel > 0.5 { return Theme.successGreen }
        if device.batteryLevel > 0.2 { return Theme.warningOrange }
        return Theme.dangerRed
    }

    private func storageColor(_ progress: Double) -> Color {
        if progress > 0.9 { return Theme.dangerRed }
        if progress > 0.75 { return Theme.warningOrange }
        return Theme.primaryBlue
    }

    private var photosView: some View {
        VStack(spacing: Theme.spacing8) {
            HStack {
                Text("\(store.photos.count) photos").font(.subheadline).foregroundColor(Theme.textSecondary); Spacer()
                Button("Select All") { store.selectAllPhotos() }.buttonStyle(.borderless).disabled(store.photos.isEmpty)
                Button("Deselect") { store.deselectAllPhotos() }.buttonStyle(.borderless).disabled(store.selectedPhotos.isEmpty)
                Button("Scan") { Task { await store.scanPhotos() } }.buttonStyle(.borderless).disabled(store.isScanning || store.connectedDevice == nil)
                Button("Import") { Task { await store.importSelectedPhotos() } }.buttonStyle(.borderedProminent).disabled(store.selectedPhotos.isEmpty || store.isImporting)
            }.padding(.horizontal, Theme.spacing16).padding(.top, Theme.spacing8)
            if store.photos.isEmpty { emptyStateView(icon: "photo.on.rectangle.angled", title: "No Photos", message: "Scan to discover photos on your device") }
            else { ScrollView { LazyVGrid(columns: [GridItem(.adaptive(minimum: 80, maximum: 100), spacing: 4)], spacing: 4) { ForEach(store.photos) { photo in PhotoThumbnailView(photo: photo, isSelected: store.selectedPhotos.contains(photo.id), onTap: { store.togglePhotoSelection(photo) }) } }.padding(Theme.spacing8) } }
            if store.isImporting || store.importProgress != .idle { VStack(spacing: 4) { ProgressView().scaleEffect(0.8); Text(store.importProgress.description).font(.caption).foregroundColor(Theme.textSecondary) }.padding(Theme.spacing8) }
        }
    }

    private var contactsView: some View {
        VStack(spacing: Theme.spacing8) {
            HStack { Text("\(store.contacts.count) contacts").font(.subheadline).foregroundColor(Theme.textSecondary); Spacer(); Button("Sync Contacts") { Task { await store.syncContacts() } }.buttonStyle(.borderedProminent).disabled(store.isSyncingContacts || store.connectedDevice == nil) }.padding(.horizontal, Theme.spacing16).padding(.top, Theme.spacing8)
            if store.contacts.isEmpty { emptyStateView(icon: "person.2.slash", title: "No Contacts", message: "Sync to import contacts from your device") }
            else { List(store.contacts) { contact in HStack { Image(systemName: "person.circle.fill").foregroundColor(Theme.secondaryGray); VStack(alignment: .leading) { Text(contact.fullName).font(.subheadline); if !contact.phoneNumbers.isEmpty { Text(contact.phoneNumbers.first ?? "").font(.caption).foregroundColor(Theme.textSecondary) } }; Spacer() } } }
        }
    }

    private var backupView: some View {
        VStack(spacing: Theme.spacing16) {
            if let device = store.connectedDevice {
                VStack(alignment: .leading, spacing: Theme.spacing8) {
                    Text("Backup Status").font(.headline)
                    HStack { Image(systemName: device.isUsingiCloudBackup ? "icloud.fill" : "externaldrive").font(.title2).foregroundColor(Theme.primaryBlue); VStack(alignment: .leading) { Text(device.isUsingiCloudBackup ? "iCloud Backup" : "Local Backup").font(.subheadline); if let lastBackup = device.lastBackupDate { Text("Last: \(lastBackup.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundColor(Theme.textSecondary) } else { Text("No backup yet").font(.caption).foregroundColor(Theme.textSecondary) } }; Spacer() }.padding(Theme.spacing12).cardStyle()
                }
                Button(action: { Task { await store.backupNow() } }) { HStack { Image(systemName: "arrow.triangle.2.circlepath"); Text("Backup Now") }.frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).disabled(store.isBackingUp || store.connectedDevice == nil)
                if store.isBackingUp || store.backupProgress != .idle { VStack(spacing: 4) { ProgressView(); Text(store.backupProgress.description).font(.caption).foregroundColor(Theme.textSecondary) } }
            } else { emptyStateView(icon: "externaldrive.badge.xmark", title: "No Device", message: "Connect a device to back up") }
            Spacer()
        }.padding(Theme.spacing16)
    }

    private var statusBar: some View {
        HStack { if let device = store.connectedDevice { Text(String(device.udid.prefix(8)) + "...").font(.caption2).foregroundColor(Theme.textTertiary) }; Spacer(); if let error = store.errorMessage { Text(error).font(.caption2).foregroundColor(Theme.dangerRed) } }.padding(.horizontal, Theme.spacing16).padding(.vertical, Theme.spacing4).background(Theme.backgroundSecondary)
    }

    private func emptyStateView(icon: String, title: String, message: String) -> some View {
        VStack(spacing: Theme.spacing12) { Spacer(); Image(systemName: icon).font(.system(size: 48)).foregroundColor(Theme.secondaryGray); Text(title).font(.headline).foregroundColor(Theme.textSecondary); Text(message).font(.caption).foregroundColor(Theme.textTertiary); Spacer() }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PhotoThumbnailView: View {
    let photo: Photo; let isSelected: Bool; let onTap: () -> Void
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Rectangle().fill(Theme.backgroundTertiary).frame(width: 80, height: 80).overlay(Image(systemName: "photo").foregroundColor(Theme.secondaryGray))
            if isSelected { Circle().fill(Theme.primaryBlue).frame(width: 20, height: 20).overlay(Image(systemName: "checkmark").font(.caption2.bold()).foregroundColor(.white)).padding(4) }
            if photo.isDuplicate { Circle().fill(Theme.warningOrange).frame(width: 16, height: 16).overlay(Image(systemName: "exclamationmark").font(.system(size: 8).bold()).foregroundColor(.white)).padding(4).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading) }
        }.cornerRadius(Theme.cornerRadiusSmall).overlay(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall).stroke(isSelected ? Theme.primaryBlue : Color.clear, lineWidth: 2)).onTapGesture(perform: onTap)
    }
}
