import ContactsUI
import SwiftUI

/// The system Contacts picker. It runs out of process and hands back only the contact picked, so Curbside never asks
/// for Contacts access. It's presented from an empty host controller because it won't render inside a SwiftUI sheet.
struct ContactPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let picked: (CNContact) -> Void

    func makeUIViewController(context: Context) -> UIViewController { UIViewController() }

    func updateUIViewController(_ host: UIViewController, context: Context) {
        context.coordinator.parent = self
        guard isPresented, host.presentedViewController == nil else { return }
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        host.present(picker, animated: true)
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    // ContactsUI predates Sendable annotations; UIKit calls the delegate on the main thread, which `@preconcurrency` checks.
    @MainActor final class Coordinator: NSObject, @preconcurrency CNContactPickerDelegate {
        var parent: ContactPicker

        init(parent: ContactPicker) {
            self.parent = parent
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            parent.isPresented = false
            parent.picked(contact)
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            parent.isPresented = false
        }
    }
}
