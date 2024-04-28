//
//  ViewController.swift
//  VideoFrameDemo
//
//  Created by MacBookAir_36 on 24/04/24.
//

import UIKit
import MobileCoreServices
import Photos
import Combine


class ViewController: UIViewController, UIImagePickerControllerDelegate, EditorViewControllerDelegate, UINavigationControllerDelegate {
    
    func controller(_ controller: EditorViewController, handleSlideToPopGesture gesture: UIPanGestureRecognizer) {
        print("Data call")
    }
    
    private var asset: AVAsset!
    var zoomingPlayerView: ZoomingPlayerView!
    weak var dataSource : LibraryDataSource?
    var coordinator: Coordinator?
    var imageRequest: Cancellable?
    let imageManager: PHImageManager? = nil
    var previewImage: UIImage?
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }

    @IBAction func btnStart(_ sender: Any) {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = .photoLibrary
        imagePicker.mediaTypes = [kUTTypeMovie as String, kUTTypeVideo as String]
        self.present(imagePicker, animated: true, completion: nil)
        
    }
    
    func saveVideoAndRetrieveAsset(videoURL : URL?) {
            guard let videoURL = videoURL else {
                print("Video file not found.")
                return
            }
        
        let editor = ViewControllerFactory.makeEditor(
            with: .url(videoURL),
            previewImage: UIImage(named: "sampleimage"),
            delegate: self
        )
        self.navigationController?.pushViewController(editor, animated: true)
        
//            PHPhotoLibrary.shared().performChanges({
//                let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
//                guard let localIdentifier = request?.placeholderForCreatedAsset?.localIdentifier else {
//                    print("Failed to get local identifier for the created asset.")
//                    return
//                }
//                UserDefaults.standard.set(localIdentifier, forKey: "savedVideoLocalIdentifier")
//            }) { (success, error) in
//                if success {
//                    print("Video saved successfully.")
//                    if let localIdentifier = UserDefaults.standard.string(forKey: "savedVideoLocalIdentifier") {
//                        PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil).enumerateObjects { (asset, _, _) in
//                            print("PHAsset for the video: \(asset)")
//                            let size = CGSize(width: 1170, height: 1608)
//                            let options = PHImageManager.ImageOptions(
//                                size: size,
//                                mode: .aspectFit,
//                                requestOptions: .default()
//                            )
//                            self.imageRequest = self.imageManager?.requestImage(for: asset, options: options) {
//                                [weak self] image, info in
//                                
//                                self?.previewImage = image ?? self?.previewImage
//                                self?.imageRequest = nil
//                            }
//                            
//                            DispatchQueue.main.async {
//                                let editor = ViewControllerFactory.makeEditor(
//                                    with: .photoLibrary(asset),
//                                    previewImage: self.previewImage,
//                                    delegate: self
//                                )
//                                self.navigationController?.setViewControllers([editor], animated: true)
//                            }
//                        }
//                    } else {
//                        print("Local identifier not found.")
//                    }
//                } else {
//                    print("Error saving video: \(error?.localizedDescription ?? "")")
//                }
//            }
        }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let videoUrl = info[.mediaURL] as? URL {
            self.saveVideoAndRetrieveAsset(videoURL:videoUrl)
        }
        self.dismiss(animated: true)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
}




//func saveVideoAndRetrieveAsset() {
//        guard let videoURL = Bundle.main.url(forResource: "sampleVideo", withExtension: "mp4") else {
//            print("Video file not found.")
//            return
//        }
//        PHPhotoLibrary.shared().performChanges({
//            let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
//            guard let localIdentifier = request?.placeholderForCreatedAsset?.localIdentifier else {
//                print("Failed to get local identifier for the created asset.")
//                return
//            }
//            // Store the local identifier for later retrieval
//            UserDefaults.standard.set(localIdentifier, forKey: "savedVideoLocalIdentifier")
//        }) { (success, error) in
//            if success {
//                print("Video saved successfully.")
//                if let localIdentifier = UserDefaults.standard.string(forKey: "savedVideoLocalIdentifier") {
//                    PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil).enumerateObjects { (asset, _, _) in
//                        print("PHAsset for the video: \(asset)")
//                        DispatchQueue.main.async {
//                            let editor = ViewControllerFactory.makeEditor(
//                                with: .photoLibrary(asset),
//                                previewImage: UIImage(named: "sampleimage"),
//                                delegate: self
//                            )
//                            self.navigationController?.setViewControllers([editor], animated: true)
//                        }
//                    }
//                } else {
//                    print("Local identifier not found.")
//                }
//            } else {
//                print("Error saving video: \(error?.localizedDescription ?? "")")
//            }
//        }
//    }
