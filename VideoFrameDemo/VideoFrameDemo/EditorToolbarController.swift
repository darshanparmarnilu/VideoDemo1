import AVFoundation
import Combine
import ThumbnailSlider
import UIKit

protocol EditorToolbarControllerDelegate: AnyObject {
    func controller(_ controller: EditorToolbarController, didSelectShareFrameAt time: CMTime)
}

class EditorToolbarController: UIViewController {
    
    weak var delegate: EditorToolbarControllerDelegate?
    var asset : URL?
    var time : CMTime?
    @IBOutlet weak var btnDone: UIButton!
    let playbackController: PlaybackController
    var placeholderImage: UIImage? {
        didSet { updateViews() }
    }
    
    var timeFormat: TimeFormat = .minutesSecondsMilliseconds {
        didSet { updateViews()  }
    }
    
    var exportAction: ExportAction = .showShareSheet {
        didSet { updateViews() }
    }
    
    var isScrubbing: Bool {
        toolbar.timeSlider.isTracking
    }
    
    @IBOutlet private(set) var toolbar: EditorToolbar!
    
    private lazy var timeFormatter = VideoTimeFormatter()
    private var sliderDataSource: AVAssetThumbnailSliderDataSource?
    private lazy var feedbackGenerator = UISelectionFeedbackGenerator()
    private lazy var bindings = Set<AnyCancellable>()
    
    init?(
        playbackController: PlaybackController,
        delegate: EditorToolbarControllerDelegate? = nil,
        coder: NSCoder
    ) {
        self.playbackController = playbackController
        self.delegate = delegate
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .green
        view.translatesAutoresizingMaskIntoConstraints = false
        configureViews()
        
        let doneButton = UIButton(type: .system)
        doneButton.setTitle("Done", for: .normal)
        doneButton.setTitleColor(UIColor.white, for: .normal)
        doneButton.addTarget(self, action: #selector(doneButtonTapped), for: .touchUpInside)
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        doneButton.backgroundColor = UIColor.lightGray
        doneButton.titleLabel?.font = UIFont.systemFont(ofSize: 20)
        doneButton.layer.cornerRadius = 8

        view.addSubview(doneButton)
        NSLayoutConstraint.activate([
            doneButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            doneButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 0),
            doneButton.widthAnchor.constraint(equalToConstant: 120),
            doneButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        
//        self.toolbar.backgroundColor = .black
    }
    
    @objc func doneButtonTapped() {
        print("Hello")
        captureFrame(atTime: time ?? CMTime()) { image in
            if let image = image {
                // Do something with the captured frame (e.g., display it)
                print("Captured frame: \(image)")
            } else {
                print("Failed to capture frame.")
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateExpandedPreferredContentSize()
    }
    
    // MARK: - Actions
    
    @IBAction func btnDone(_ sender: UIButton) {
        print("Hello")
        captureFrame(atTime: time ?? CMTime()) { image in
            if let image = image {
                // Do something with the captured frame (e.g., display it)
                print("Captured frame: \(image)")
            } else {
                print("Failed to capture frame.")
            }
        }
        playbackController.pause()
    }
    
    
    @IBAction func playOrPause() {
        guard !isScrubbing else { return }
        playFeedback()
        playbackController.playOrPause()
    }

    @IBAction func stepBackward() {
        guard !isScrubbing else { return }
        playFeedback()
        playbackController.step(byCount: -1)
    }

    @IBAction func stepForward() {
        guard !isScrubbing else { return }
        playFeedback()
        playbackController.step(byCount: 1)
    }

    @IBAction func shareFrames() {
        guard !isScrubbing else { return }

        playFeedback()
        playbackController.pause()
        
        let time = playbackController.currentSampleTime ?? playbackController.currentPlaybackTime
        delegate?.controller(self, didSelectShareFrameAt: time)
    }

    @IBAction func scrub(_ sender: ScrubbingThumbnailSlider) {
        playbackController.smoothlySeek(to: sender.time)
        self.time = sender.time
//        print(time)
    }
    
    private func playFeedback() {
        feedbackGenerator.selectionChanged()
        feedbackGenerator.prepare()
    }
    
    // MARK: - Configuring
    
    private func configureViews() {
        sliderDataSource = AVAssetThumbnailSliderDataSource(
            slider: toolbar.timeSlider,
            asset: nil,  // Set in binding, avoid triggering work twice.
            placeholderImage: placeholderImage
        )
        
//        toolbar.backgroundColor = .editorBars
//        toolbar.configureWithBarShadow()
        toolbar.timeSlider.scrubbingSpeeds = [EditorSpeedMenu.defaultSpeed.scrubbingSpeed]
        toolbar.speedButton.showsMenuAsPrimaryAction = true
        updateSpeedButton()
        
        configureBindings()
        updateViews()
    }
    
    func updateViews() {
        guard isViewLoaded else { return }
        
        sliderDataSource?.placeholderImage = placeholderImage
        toolbar.shareButton.setImage(exportAction.icon, for: .normal)
        
        let time = playbackController.currentSampleTime ?? playbackController.currentPlaybackTime
        updateTimeLabel(withTime: time)
    }
    
    func configureBindings() {
        playbackController
            .$asset
            .assignWeak(to: \.asset, on: sliderDataSource)
            .store(in: &bindings)
        
        playbackController
            .$status
            .map { $0 == .readyToPlay }
            .sink { [weak self] in
                self?.toolbar.setEnabled($0)
                self?.navigationItem.rightBarButtonItem?.isEnabled = $0
            }
            .store(in: &bindings)

        playbackController
            .$duration
            .assignWeak(to: \.duration, on: toolbar.timeSlider)
            .store(in: &bindings)

        playbackController
            .$currentPlaybackTime
            .sink { [weak self] time in
                guard self?.isScrubbing == false else { return }
                self?.toolbar.timeSlider.setTime(time, animated: false)
                self?.time = time
            }
            .store(in: &bindings)
        
        playbackController
            .$currentSampleTime
            .sink { [weak self] time in
                let time = time ?? self?.playbackController.currentPlaybackTime ?? .zero
                self?.updateTimeLabel(withTime: time)
                self?.time = time
            }
            .store(in: &bindings)

        playbackController
            .$timeControlStatus
            .sink { [weak self] in
                self?.toolbar.playButton.setTimeControlStatus($0)
            }
            .store(in: &bindings)
    }
    
    func updateSpeedButton() {
//        let currentSelection = EditorSpeedMenu.Selection(toolbar.timeSlider.currentScrubbingSpeed)
//        let hasCustomSelection = currentSelection != EditorSpeedMenu.defaultSpeed
//                
//        toolbar.speedButton.tintColor = hasCustomSelection ? .systemOrange : .label
//
//        toolbar.speedButton.menu = EditorSpeedMenu.menu(with: currentSelection) { [weak self] selection in
//            self?.playbackController.defaultRate = selection.scrubbingSpeed.speed
//            self?.toolbar.timeSlider.scrubbingSpeeds = [selection.scrubbingSpeed]
//            self?.updateSpeedButton()
//        }
    }
    
    // TODO: Clean this up.
    func updateTimeLabel(withTime time: CMTime) {
        // Loading or playing.
        guard !playbackController.isPlaying && (playbackController.status == .readyToPlay) else {
            toolbar.timeSpinner.isHidden = true
            toolbar.timeLabel.text = timeFormatter.string(from: time)
            return
        }
        
        switch timeFormat {
        
        case .minutesSecondsMilliseconds:
            toolbar.timeLabel.text = timeFormatter.string(from: time, includeMilliseconds: true)
        
        case .minutesSecondsFrameNumber:
            // Succeeded indexing.
            if let frameNumber = playbackController.relativeFrameNumber(for: time) {
                toolbar.timeSpinner.isHidden = true
                toolbar.timeLabel.text = timeFormatter.string(from: time, frameNumber: frameNumber)
            // Still indexing.
            } else if playbackController._isIndexingSampleTimes {
                toolbar.timeSpinner.isHidden = false
                toolbar.timeLabel.text = timeFormatter.string(from: time) + "."
            // Failed indexing.
            } else {
                toolbar.timeSpinner.isHidden = true
                toolbar.timeLabel.text = timeFormatter.string(from: time)
            }
        }
    }
    
    func captureFrame(atTime time: CMTime, completion: @escaping (UIImage?) -> Void) {
        let asset = AVURLAsset(url: asset!)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        
        generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { requestedTime, cgImage, _, _, error in
            if let error = error {
                print("Error capturing frame: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let cgImage = cgImage else {
                print("Error: No CGImage found.")
                completion(nil)
                return
            }
            
            let image = UIImage(cgImage: cgImage)
            completion(image)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
