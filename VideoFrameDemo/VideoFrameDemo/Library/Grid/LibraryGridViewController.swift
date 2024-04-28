import Combine
import Photos
import Utility
import UIKit

protocol LibraryGridViewControllerDelegate: AnyObject {
    func controller(_ controller: LibraryGridViewController, didSelectAsset asset: PHAsset, previewImage: UIImage?)
}

final class LibraryGridViewController: UICollectionViewController {
        
    weak var delegate: LibraryGridViewControllerDelegate?
    
    private let dataSource: LibraryDataSource
    private lazy var emptyView = LibraryEmptyView()
    private lazy var durationFormatter = VideoDurationFormatter()
    private var bindings = Set<AnyCancellable>()
    
    static let contentModeAnimationDuration: TimeInterval = 0.15
    static let contextMenuActionDelay: TimeInterval = 0.2
    
    init?(dataSource: LibraryDataSource, coder: NSCoder) {
        self.dataSource = dataSource
        super.init(coder: coder)
    }
        
    required init?(coder: NSCoder) {
        fatalError("A data source is required.")
    }
        
    override func viewDidLoad() {
        super.viewDidLoad()
        configureViews()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        DispatchQueue.main.async {
            self.collectionView.reloadData()
        }
    }

    // MARK: - Collection View Data Source & Delegate
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        dataSource.numberOfAssets
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: LibraryGridCell.className, for: indexPath) as? LibraryGridCell else { fatalError("Wrong cell identifier or type.") }
        guard let asset = dataSource.asset(at: indexPath) else { return cell }
        
        configure(cell: cell, for: asset)
        
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let asset = dataSource.asset(at: indexPath) else { return }
        let thumbnail = videoCell(at: indexPath)?.imageView.image
//        delegate?.controller(self, didSelectAsset: asset, previewImage: thumbnail)
    }

    override func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        (cell as? LibraryGridCell)?.imageRequest = nil
    }

    override func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let asset = dataSource.asset(at: indexPath) else { return nil}
        let thumbnail = videoCell(at: indexPath)?.imageView.image

        return LibraryGridMenu.configuration(
            for: asset,
            initialPreviewImage: thumbnail
        ) { [weak self] selection in
            let delay = LibraryGridViewController.contextMenuActionDelay

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self?.handleCellContextMenuSelection(selection, for: asset)
            }
        }
    }
    
    private func handleCellContextMenuSelection(_ selection: LibraryGridMenu.Selection, for asset: PHAsset) {
        guard let asset = dataSource.currentAsset(for: asset) else { return }
        
        switch selection {
        case .favorite:
            dataSource.toggleFavorite(for: asset)
        case .delete:
            dataSource.delete(asset)
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard view.window != nil,
              let asset = configuration.identifier as? PHAsset,
              let indexPath = dataSource.indexPath(of: asset),
              let cell = videoCell(at: indexPath) else { return nil }

        return UITargetedPreview(view: cell.imageContainer)
    }

    override func collectionView(_ collectionView: UICollectionView, previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        self.collectionView(collectionView, previewForHighlightingContextMenuWithConfiguration: configuration)
    }

    override func collectionView(_ collectionView: UICollectionView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        // Asset might've been deleted or changed during preview.
              guard let asset = configuration.identifier as? PHAsset,
              let updatedAsset = dataSource.currentAsset(for: asset),
              let indexPath = dataSource.indexPath(of: updatedAsset) else { return }

        animator.addAnimations {
            let thumbnail = self.videoCell(at: indexPath)?.imageView.image
//            self.delegate?.controller(self, didSelectAsset: updatedAsset, previewImage: thumbnail)
        }
    }
    
    // MARK: - Configuring
    
    private func configureViews() {
        collectionView.isPrefetchingEnabled = true
        collectionView.backgroundView = emptyView
        collectionView.collectionViewLayout = LibraryGridLayout()
        collectionView.collectionViewLayout.invalidateLayout()
        collectionView.verticalScrollIndicatorInsets = .zero

        configureBindings()
        updateViews()
    }

    private func updateViews() {
        emptyView.isHidden = !dataSource.isEmpty || dataSource.isUpdating
        emptyView.configure(with: dataSource.filter)
    }
    
    private func configureBindings() {
        dataSource.$album
            .combineLatest(
                dataSource.$isUpdating.removeDuplicates(),
                dataSource.$assets
            )
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateViews()
            }.store(in: &bindings)

        dataSource.$assets
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.collectionView.reloadData(animated: true)
            }.store(in: &bindings)
        
        dataSource.$gridMode
            .sink { [weak self] mode in
                self?.setGridMode(mode, animated: true)
            }.store(in: &bindings)
    }
    
    // MARK: Cell Handling
    
    private func videoCell(at indexPath: IndexPath) -> LibraryGridCell? {
        collectionView.cellForItem(at: indexPath) as? LibraryGridCell
    }

    private func configure(cell: LibraryGridCell, for asset: PHAsset) {
        cell.durationLabel.text = durationFormatter.string(from: asset.duration)
        cell.durationLabel.isHidden = asset.isLivePhoto
        cell.livePhotoImageView.isHidden = !asset.isLivePhoto
        cell.favoritedImageView.isHidden = !asset.isFavorite
        cell.setGridMode(dataSource.gridMode, forAspectRatio: asset.dimensions)
        
        loadThumbnail(for: cell, asset: asset)
    }

    private func loadThumbnail(for cell: LibraryGridCell, asset: PHAsset) {
        cell.identifier = asset.localIdentifier
        let size = cell.imageView.bounds.size.scaledToScreen
        
        cell.imageRequest = dataSource.thumbnail(for: asset, options: .init(size: size)) {
            (image, _) in
            
            guard cell.identifier == asset.localIdentifier,
                  let image = image else { return }

            cell.imageView.image = image
        }
    }
    
    // MARK: - Grid Mode

    private func setGridMode(_ mode: LibraryGridMode, animated: Bool) {
        if !animated {
            collectionView.reloadData()
            return
        }

        UIView.animate(
            withDuration: LibraryGridViewController.contentModeAnimationDuration,
            delay: 0,
            options: [.beginFromCurrentState, .curveEaseInOut],
            animations: {
                self.setGridModeForVisibleCells(mode)
            },
            completion: { _ in
                self.collectionView.reloadData()  // Update already configured, off-screen cells.
            }
        )
    }
    
    private func setGridModeForVisibleCells(_ mode: LibraryGridMode) {
        collectionView.indexPathsForVisibleItems.forEach { indexPath in
            guard let cell = videoCell(at: indexPath),
                  let asset = dataSource.asset(at: indexPath) else { return }
            
            cell.setGridMode(mode, forAspectRatio: asset.dimensions)
        }
    }
}
