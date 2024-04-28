import AVFoundation
import Combine
import UIKit

@MainActor protocol EditorViewControllerDelegate: AnyObject {
    func controller(_ controller: EditorViewController, handleSlideToPopGesture gesture: UIPanGestureRecognizer)
}

class EditorViewController: UIViewController{
    
    weak var delegate: EditorViewControllerDelegate?
    var asset:URL?
    let videoController: VideoController
    let playbackController: PlaybackController
    var toolbarController: EditorToolbarController!
    let settings: UserDefaults
    
    init?(
        videoController: VideoController,
        playbackController: PlaybackController = .init(),
        settings: UserDefaults = .standard,
        delegate: EditorViewControllerDelegate? = nil,
        coder: NSCoder
    ) {
        self.videoController = videoController
        self.playbackController = playbackController
        self.settings = settings
        self.delegate = delegate
        
        super.init(coder: coder)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Dependencies must be injected")
    }
    
    @IBOutlet private(set) var zoomingPlayerView: ZoomingPlayerView!
    @IBOutlet private(set)  var progressView: ProgressView!
    private lazy var activityFeedbackGenerator = UINotificationFeedbackGenerator()
    private lazy var bindings = Set<AnyCancellable>()

    // MARK: Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = .white
        
        configureViews()
        loadPreviewImage()
        loadVideo()
        
        print("=====\(asset)====")
        
//        showSettingsAndMetadata(UIBarButtonItem())
        if #available(iOS 16.0, *) {
            self.navigationItem.rightBarButtonItem?.isHidden = true
        } else {
            // Fallback on earlier versions
        }
        showSettingsAndMetadata(self.navigationItem.rightBarButtonItem!)
        self.title = "Choose Imagse"
        
        self.zoomingPlayerView.backgroundColor = .black
//        self.navigationController?.navigationBar.isHidden = true
        self.view.backgroundColor = .red
        toolbarController.asset = self.asset
        
//        let backButton = UIBarButtonItem(image: UIImage(named: "backIcon"), style: .plain, target: self, action: #selector(backButtonTapped))
//        backButton.title = "Back"
//        backButton.tintColor = UIColor.black
//        navigationItem.leftBarButtonItem = backButton
        
        let customView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
        let imageView = UIImageView(image: UIImage(named: "backIcon"))
        imageView.contentMode = .scaleAspectFit
        imageView.frame = CGRect(x: 0, y: 11, width: 20, height: 18)
        let label = UILabel(frame: CGRect(x: 22, y: 0, width: 70, height: 40))
        label.text = "Back"
        label.font = UIFont.systemFont(ofSize: 20)
        
        customView.addSubview(imageView)
        customView.addSubview(label)
        
        // Create a bar button item with the custom view
        let backButton = UIBarButtonItem(customView: customView)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(backButtonTapped))
        customView.addGestureRecognizer(tapGesture)
        navigationItem.leftBarButtonItem = backButton

    }
    
    @objc func backButtonTapped() {
        // Handle back button tapped event
        navigationController?.popViewController(animated: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        //configureNavigationBar()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        videoController.cancelFrameExport()
    }
    
    @IBSegueAction private func makeToolbarController(_ coder: NSCoder) -> EditorToolbarController? {
        self.toolbarController = EditorToolbarController(
            playbackController: playbackController,
            delegate: self,
            coder: coder
        )
        toolbarController.placeholderImage = videoController.previewImage
        toolbarController.timeFormat = settings.timeFormat
        toolbarController.exportAction = settings.exportAction
        return toolbarController
    }

    // MARK: - Configuring

    private func configureViews() {
        zoomingPlayerView.clipsToBounds = false
        zoomingPlayerView.player = playbackController.player
        zoomingPlayerView.posterImage = videoController.previewImage

        navigationItem.rightBarButtonItem?.isEnabled = false
        
        configureNavigationBar()
        configureGestures()
        configureBindings()
    }

    private func configureNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
//        appearance.backgroundColor = .editorBars
        appearance.shadowColor = nil
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
//        navigationController?.navigationBar.configureWithBarShadow()
    }

    private func configureGestures() {
        let slideToPopRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handleSlideToPopPan))
        zoomingPlayerView.addGestureRecognizer(slideToPopRecognizer)

        if let defaultPopRecognizer = navigationController?.interactivePopGestureRecognizer {
            slideToPopRecognizer.require(toFail: defaultPopRecognizer)
        }
    }

    @objc private func handleSlideToPopPan(_ gesture: UIPanGestureRecognizer) {
        let canSlide = zoomingPlayerView.playerView.bounds.size != .zero

        guard !toolbarController.isScrubbing,
              canSlide else { return }

        delegate?.controller(self, handleSlideToPopGesture: gesture)
    }

    private func presentOnTop(_ viewController: UIViewController, animated: Bool = true) {
        let presenter = navigationController ?? presentedViewController ?? self
        presenter.present(viewController, animated: animated)
    }

    private func configureBindings() {
        playbackController
            .$status
            .filter { $0 == .failed }
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.presentOnTop(UIAlertController.playbackFailed())
            }
            .store(in: &bindings)
    }

    // MARK: Loading Videos

    private func loadPreviewImage() {
        let size = zoomingPlayerView.bounds.size.scaledToScreen

        videoController.loadPreviewImage(with: size) { [weak self] image in
            guard let image else { return }
            self?.zoomingPlayerView.posterImage = image
            self?.toolbarController.placeholderImage = image
        }
    }

    private func loadVideo() {
        showProgress(true, forActivity: .load, value: .determinate(0))

        videoController.loadVideo(progressHandler: { [weak self] progress in
            self?.progressView.setProgress(.determinate(Float(progress)), animated: true)
        }, completionHandler: { [weak self] result in
            self?.showProgress(false, forActivity: .load, value: .determinate(1))
            self?.handleVideoLoadingResult(result)
        })
    }

    private func handleVideoLoadingResult(_ result: VideoController.VideoResult) {
        switch result {

        case .failure(let error):
            guard !error.isCocoaCancelledError else { return }
            presentOnTop(UIAlertController.videoLoadingFailed())

        case .success(let video):
            playbackController.asset = video
            startPlaying(from: videoController.source)
            navigationItem.rightBarButtonItem?.isEnabled = true
        }
    }
    
    // TODO: Fix this hack. This shouldn't be the the editor's responsibility.
    //
    // When the camera is dismissed, it disables all active video playback after a delay for some
    // reason :( However, we don't want to open the editor only after the camera is dismissed, we
    // want it to be ready right away. Just delay the playback for now.
    private func startPlaying(from source: VideoSource) {
        if case .camera = videoController.source {
            let delay = 0.5
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
//                self.playbackController.play()
            }
        } else {
//            playbackController.play()
        }
    }

    // MARK: Generating Images

    private func generateFramesAndShare(for times: [CMTime]) {
        let activity = Activity(exportAction: settings.exportAction)
        showProgress(true, forActivity: activity, value: .indeterminate)

        videoController.generateAndExportFrames(for: times) { [weak self] status in
            self?.showProgress(false, forActivity: activity) {
                self?.handleFrameGenerationResult(status)
            }
        }
    }

    private func handleFrameGenerationResult(_ status: FrameExport.Status) {
        switch status {
        
        case .progressed:
            break
            
        case .cancelled:
            activityFeedbackGenerator.notificationOccurred(.warning)
            
        case .failed:
            activityFeedbackGenerator.notificationOccurred(.error)
            presentOnTop(UIAlertController.frameExportFailed())
            
        case .succeeded(let urls):
            share(urls: urls, using: settings.exportAction)
        }
    }

    // todo: clean this up.
    private func share(urls: [URL], using action: ExportAction) {
        switch action {
                
        case .showShareSheet:
            activityFeedbackGenerator.notificationOccurred(.success)
            
            let shareController = UIActivityViewController(activityItems: urls, applicationActivities: nil)
            let shareButton = toolbarController.toolbar.shareButton
            shareController.popoverPresentationController?.sourceView = shareButton

            shareController.completionWithItemsHandler = { [weak self] activity, completed, _, _ in
                guard self?.shouldDeleteFrames(after: activity, completed: completed) == true  else { return }
                try? self?.videoController.deleteExportedFrames()
            }

            presentOnTop(shareController)

        case .saveToPhotos:
            SaveToPhotosAction().save(urls.map { .image($0) }, addingToAlbums: [.appAlbum]) {
                [weak self] ok, _ in
                if ok {
                    self?.activityFeedbackGenerator.notificationOccurred(.success)
                } else {
                    self?.activityFeedbackGenerator.notificationOccurred(.error)
                    self?.presentOnTop(UIAlertController.savingToPhotosFailed())
                }
                
                try? self?.videoController.deleteExportedFrames()
            }
        }
    }

    private func shouldDeleteFrames(after shareActivity: UIActivity.ActivityType?, completed: Bool) -> Bool {
        let wasDismissed = (shareActivity == nil) && !completed
        let didFinish = (shareActivity != nil) && completed
        return wasDismissed || didFinish
    }

    // MARK: Showing Progress

    private enum Activity {
        case load
        case exportToShareSheet
        case exportToPhotos
        
        init(exportAction: ExportAction) {
            switch exportAction {
            case .saveToPhotos: self = .exportToPhotos
            case .showShareSheet: self = .exportToShareSheet
            }
        }

        var title: String {
            switch self {
            case .load: return Localized.editorVideoLoadProgress
            case .exportToShareSheet: return Localized.editorExportShareSheetProgress
            case .exportToPhotos: return Localized.editorExportToPhotosProgress
            }
        }

        var delay: TimeInterval {
            switch self {
            case .load: return 0.25
            case .exportToShareSheet, .exportToPhotos: return 0.05
            }
        }
    }

    private func showProgress(_ show: Bool, forActivity activity: Activity, value: ProgressView.Progress? = nil, animated: Bool = true, completion: (() -> ())? = nil) {
        view.isUserInteractionEnabled = !show 

        progressView.showDelay = activity.delay
        progressView.titleLabel.text = activity.title
        
        if show {
            progressView.show(in: zoomingPlayerView, animated: animated, completion: completion)
        } else {
            progressView.hide(animated: animated, completion: completion)
        }

        if let value {
            progressView.setProgress(value, animated: animated)
        }
    }
}

// MARK: - EditorToolbarControllerDelegate

extension EditorViewController: EditorToolbarControllerDelegate {
 
    func controller(_ controller: EditorToolbarController, didSelectShareFrameAt time: CMTime) {
        generateFramesAndShare(for: [time])
    }
}

extension EditorViewController{
        @IBAction func showSettingsAndMetadata(_ sender: UIBarButtonItem) {
           
        }
}
