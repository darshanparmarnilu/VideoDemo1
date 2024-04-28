import ThumbnailSlider
import UIKit

class EditorToolbar: UIView {

    @IBOutlet var timeSlider: ScrubbingThumbnailSlider!
    @IBOutlet var timeLabel: UILabel!
    @IBOutlet var timeSpinner: UIActivityIndicatorView!
    @IBOutlet var speedButton: UIButton!
    @IBOutlet var playButton: UIButton!
    @IBOutlet var previousButton: RepeatingButton!
    @IBOutlet var nextButton: RepeatingButton!
    @IBOutlet var shareButton: UIButton!
    
    private let spinnerScale: CGFloat = 0.75

    override func awakeFromNib() {
        super.awakeFromNib()
        configureViews()
        
        
    }
    
    func setEnabled(_ enabled: Bool) {
        timeSlider.isEnabled = enabled
        timeLabel.isEnabled = enabled
        speedButton.isEnabled = enabled
        shareButton.isEnabled = enabled
        playButton.isEnabled = enabled
        nextButton.isEnabled = enabled
        previousButton.isEnabled = enabled
    }

    private func configureViews() {
        
        configureTimeLabel()
        
        playButton.isUserInteractionEnabled = false
        shareButton.isUserInteractionEnabled = false
        nextButton.isUserInteractionEnabled = false
        previousButton.isUserInteractionEnabled = false
        
        playButton.alpha = 0.0
        shareButton.alpha = 0.0
        nextButton.alpha = 0.0
        previousButton.alpha = 0.0
    }
    
    private func configureTimeLabel() {
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        timeLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
                
        let handleConstraint = timeLabel.superview?.centerXAnchor.constraint(
            equalTo: timeSlider.handleLayoutGuide.centerXAnchor
        )
        
        handleConstraint?.priority = .defaultHigh
        handleConstraint?.isActive = true
        
        timeSpinner.transform = CGAffineTransform.identity
            .scaledBy(x: spinnerScale, y: spinnerScale)
    }
    
    
}

// MARK: - Play Button

import AVFoundation

extension UIButton {
    func setTimeControlStatus(_ status: AVPlayer.TimeControlStatus) {
        setImage((status == .paused) ? UIImage(systemName: "play.fill") : UIImage(systemName: "pause.fill"), for: .normal)
    }
}
