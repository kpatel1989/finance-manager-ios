import Foundation
import LocalAuthentication

@MainActor
final class AppLockManager: ObservableObject {
#if targetEnvironment(simulator)
    @Published var isLocked = false
#else
    @Published var isLocked = true
#endif
    @Published var isAuthenticating = false

    func lock() {
#if targetEnvironment(simulator)
        isLocked = false
#else
        isLocked = true
#endif
    }

    func unlockIfNeeded(isEnabled: Bool) async {
#if targetEnvironment(simulator)
        isLocked = false
        return
#else
        guard isEnabled else {
            isLocked = false
            return
        }

        guard isLocked, !isAuthenticating else { return }

        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // If no biometric/passcode is configured we fail open.
            isLocked = false
            return
        }

        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Unlock Portfolio to view financial data"
            )
            isLocked = !success
        } catch {
            isLocked = true
        }
#endif
    }
}
