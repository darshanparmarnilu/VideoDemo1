import UIKit
import UniformTypeIdentifiers
import Utility

/// Static factory for view controllers.
@MainActor struct ViewControllerFactory {
    static func makeEditor(
        with source: VideoSource,
        previewImage: UIImage?,
        delegate: EditorViewControllerDelegate?
    ) -> EditorViewController {
        
        let storyboard = UIStoryboard(name: "Editor", bundle: nil)
        let videoController = VideoController(source: source, previewImage: previewImage)
        
        guard let controller = storyboard.instantiateInitialViewController(creator: {
            EditorViewController(videoController: videoController, delegate: delegate, coder: $0)
        }) else { fatalError("Could not instantiate controller.") }
        controller.asset = source.url
        return controller
    }
}
