import SwiftUI
import PhotosUI
import UIKit

@MainActor
final class MealLoggingViewModel: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var isShowingCamera = false
    @Published var isShowingGallery = false
    @Published var cameraPermissionDenied = false
    @Published var errorMessage: String?

    private let cameraPermissionService: CameraPermissionService

    init(cameraPermissionService: CameraPermissionService? = nil) {
        self.cameraPermissionService = cameraPermissionService ?? CameraPermissionService()
    }

    func takePhotoTapped() {
        errorMessage = nil
        cameraPermissionDenied = false

        #if targetEnvironment(simulator)
        errorMessage = "Camera capture requires a physical device. Use upload from gallery on simulator."
        return
        #else
        Task {
            let result = await cameraPermissionService.requestAccess()
            switch result {
            case .authorized:
                isShowingCamera = true
            case .denied, .restricted:
                cameraPermissionDenied = true
            case .unavailable:
                errorMessage = "Camera is not available on this device. Please upload a photo instead."
            }
        }
        #endif
    }

    func uploadFromGalleryTapped() {
        errorMessage = nil
        cameraPermissionDenied = false
        isShowingGallery = true
    }

    func setSelectedImage(_ image: UIImage) {
        selectedImage = image
        isShowingCamera = false
        isShowingGallery = false
        cameraPermissionDenied = false
        errorMessage = nil
    }

    func clearSelectedImage() {
        selectedImage = nil
        isShowingCamera = false
        isShowingGallery = false
        cameraPermissionDenied = false
        errorMessage = nil
    }

    func analyzeSelectedImage<T>(_ analysisBlock: (UIImage) async throws -> T) async throws -> T {
        guard let selectedImage else {
            throw APIError.server("Select a meal photo before analyzing.")
        }
        return try await analysisBlock(selectedImage)
    }

    func openSettings() {
        cameraPermissionService.openSettings()
    }
}
