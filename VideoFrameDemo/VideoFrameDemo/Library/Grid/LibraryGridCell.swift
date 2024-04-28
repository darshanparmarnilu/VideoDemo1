import UIKit
import Combine

class LibraryGridCell: UICollectionViewCell {
    
    var identifier: String?
    var imageRequest: Cancellable?

    @IBOutlet var imageView: UIImageView!
    @IBOutlet var durationLabel: UILabel!
    @IBOutlet var favoritedImageView: UIImageView!
    @IBOutlet var livePhotoImageView: UIImageView!
    @IBOutlet var gradientView: GradientView!

    @IBOutlet var imageContainer: UIView!
    @IBOutlet var imageContainerWidthConstraint: NSLayoutConstraint!
    @IBOutlet var imageContainerHeightConstraint: NSLayoutConstraint!
    
    static let fadeOverlaysAnimationDuration: TimeInterval = 0.2

    override func awakeFromNib() {
        super.awakeFromNib()
        configureViews()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        isHidden = false
        identifier = nil
        imageRequest = nil
        imageView.image = nil
        durationLabel.text = nil
        favoritedImageView.isHidden = true
        livePhotoImageView.isHidden = true
        imageContainerWidthConstraint.constant = bounds.width
        imageContainerHeightConstraint.constant = bounds.height
    }

    private func configureViews() {
//        gradientView.colors = UIColor.videoCellGradient
        imageView.contentMode = .scaleAspectFill
        prepareForReuse()
    }

    func fadeInOverlays() {
        gradientView.alpha = 0

        UIView.animate(withDuration: LibraryGridCell.fadeOverlaysAnimationDuration) {
            self.gradientView.alpha = 1
        }
    }

    func setGridMode(_ mode: LibraryGridMode, forAspectRatio aspectRatio: CGSize) {
        let targetSize = mode.thumbnailSize(for: aspectRatio, in: bounds.size)
        imageContainerWidthConstraint.constant = targetSize.width
        imageContainerHeightConstraint.constant = targetSize.height
        imageContainer.layoutIfNeeded()
    }
}
