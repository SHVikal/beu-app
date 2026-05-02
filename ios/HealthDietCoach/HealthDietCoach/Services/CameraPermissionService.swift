import AVFoundation
import UIKit

@MainActor
enum CameraAccessResult {
    case authorized
    case denied
    case restricted
    case unavailable
}

@MainActor
struct CameraPermissionService {
    func currentAccessResult() -> CameraAccessResult {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            return .unavailable
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .restricted
        @unknown default:
            return .restricted
        }
    }

    func requestAccess() async -> CameraAccessResult {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            return .unavailable
        }

        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            let granted = await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .video) { isGranted in
                    continuation.resume(returning: isGranted)
                }
            }
            return granted ? .authorized : .denied
        @unknown default:
            return .restricted
        }
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
