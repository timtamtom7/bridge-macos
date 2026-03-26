import Foundation
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
                let addrParts = cnContact.postalAddresses.map { addr -> String in let v = addr.value; return "\(v.street), \(v.city)" }
                contacts.append(Contact(givenName: cnContact.givenName, familyName: cnContact.familyName, phoneNumbers: cnContact.phoneNumbers.map { $0.value.stringValue }, emails: cnContact.emailAddresses.map { $0.value as String }, addresses: addrParts, notes: cnContact.note, lastModified: Date(), deviceUDID: ""))
            }
        } catch {
            print("ContactService: Failed to fetch Mac contacts: \(error)")
        }
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
            do { try CNContactStore().execute(saveRequest) } catch {
                print("ContactService: Failed to save contact \(contact.fullName): \(error)")
            }
        }
    }
}
