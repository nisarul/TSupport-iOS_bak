import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import CheckNode
import PhotoResources

final class WebSearchItem: GridItem {
    var section: GridSection?
    
    let account: Account
    let theme: PresentationTheme
    let interfaceState: WebSearchInterfaceState
    let result: ChatContextResult
    let controllerInteraction: WebSearchControllerInteraction
    
    public init(account: Account, theme: PresentationTheme, interfaceState: WebSearchInterfaceState, result: ChatContextResult, controllerInteraction: WebSearchControllerInteraction) {
        self.account = account
        self.theme = theme
        self.result = result
        self.interfaceState = interfaceState
        self.controllerInteraction = controllerInteraction
    }
    
    func node(layout: GridNodeLayout, synchronousLoad: Bool) -> GridItemNode {
        let node = WebSearchItemNode()
        node.setup(item: self, synchronousLoad: synchronousLoad)
        return node
    }
    
    func update(node: GridItemNode) {
        guard let node = node as? WebSearchItemNode else {
            assertionFailure()
            return
        }
        node.setup(item: self, synchronousLoad: false)
    }
}

final class WebSearchItemNode: GridItemNode {
    private let imageNodeBackground: ASDisplayNode
    private let imageNode: TransformImageNode
    private var checkNode: CheckNode?
    
    private(set) var item: WebSearchItem?
    private var currentDimensions: CGSize?
    
    private let fetchStatusDisposable = MetaDisposable()
    private let fetchDisposable = MetaDisposable()
    private var resourceStatus: MediaResourceStatus?
    
    override init() {
        self.imageNodeBackground = ASDisplayNode()
        self.imageNodeBackground.isLayerBacked = true
        
        self.imageNode = TransformImageNode()
        self.imageNode.contentAnimations = [.subsequentUpdates]
        self.imageNode.displaysAsynchronously = false
        
        super.init()
        
        self.addSubnode(self.imageNodeBackground)
        self.addSubnode(self.imageNode)
    }
    
    deinit {
        self.fetchStatusDisposable.dispose()
        self.fetchDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.tapActionAtPoint = { _ in
            return .waitForSingleTap
        }
        self.imageNode.view.addGestureRecognizer(recognizer)
    }
    
    func setup(item: WebSearchItem, synchronousLoad: Bool) {
        if self.item !== item {
            var updateImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
            
            var thumbnailDimensions: CGSize?
            var thumbnailResource: TelegramMediaResource?
            var imageResource: TelegramMediaResource?
            var imageDimensions: CGSize?
            var immediateThumbnailData: Data?
            
            switch item.result {
                case let .externalReference(_, _, type, _, _, _, content, thumbnail, _):
                    if let content = content, type != "gif" {
                        imageResource = content.resource
                    } else if let thumbnail = thumbnail {
                        imageResource = thumbnail.resource
                    }
                    imageDimensions = content?.dimensions
                case let .internalReference(_, _, _, _, _, image, file, _):
                    if let image = image {
                        immediateThumbnailData = image.immediateThumbnailData
                        if let largestRepresentation = largestImageRepresentation(image.representations) {
                            imageDimensions = largestRepresentation.dimensions
                        }
                        imageResource = imageRepresentationLargerThan(image.representations, size: CGSize(width: 200.0, height: 100.0))?.resource
                        if let file = file {
                            if let thumbnailRepresentation = smallestImageRepresentation(file.previewRepresentations) {
                                thumbnailDimensions = thumbnailRepresentation.dimensions
                                thumbnailResource = thumbnailRepresentation.resource
                            }
                        } else {
                            if let thumbnailRepresentation = smallestImageRepresentation(image.representations) {
                                thumbnailDimensions = thumbnailRepresentation.dimensions
                                thumbnailResource = thumbnailRepresentation.resource
                            }
                        }
                    } else if let file = file {
                        immediateThumbnailData = file.immediateThumbnailData
                        if let dimensions = file.dimensions {
                            imageDimensions = dimensions
                        } else if let largestRepresentation = largestImageRepresentation(file.previewRepresentations) {
                            imageDimensions = largestRepresentation.dimensions
                        }
                        imageResource = smallestImageRepresentation(file.previewRepresentations)?.resource
                    }
            }
            
            var representations: [TelegramMediaImageRepresentation] = []
            if let thumbnailResource = thumbnailResource, let thumbnailDimensions = thumbnailDimensions {
                representations.append(TelegramMediaImageRepresentation(dimensions: thumbnailDimensions, resource: thumbnailResource))
            }
            if let imageResource = imageResource, let imageDimensions = imageDimensions {
                representations.append(TelegramMediaImageRepresentation(dimensions: imageDimensions, resource: imageResource))
            }
            if !representations.isEmpty {
                let tmpImage = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: representations, immediateThumbnailData: immediateThumbnailData, reference: nil, partialReference: nil)
                updateImageSignal =  mediaGridMessagePhoto(account: item.account, photoReference: .standalone(media: tmpImage))
            } else {
                updateImageSignal = .complete()
            }
            
            if let updateImageSignal = updateImageSignal {
                let editingContext = item.controllerInteraction.editingState
                let editableItem = LegacyWebSearchItem(result: item.result)
                let editedImageSignal = Signal<UIImage?, NoError> { subscriber in
                    if let signal = editingContext.thumbnailImageSignal(for: editableItem) {
                        let disposable = signal.start(next: { next in
                            if let image = next as? UIImage {
                                subscriber.putNext(image)
                            } else {
                                subscriber.putNext(nil)
                            }
                        }, error: { _ in
                        }, completed: nil)!
                        
                        return ActionDisposable {
                            disposable.dispose()
                        }
                    } else {
                        return EmptyDisposable
                    }
                }
                let editedSignal: Signal<((TransformImageArguments) -> DrawingContext?)?, NoError> = editedImageSignal
                |> map { image in
                    if let image = image {
                        return { arguments in
                            let context = DrawingContext(size: arguments.drawingSize, clear: true)
                            let drawingRect = arguments.drawingRect
                            let imageSize = image.size
                            let fittedSize = imageSize.aspectFilled(arguments.boundingSize).fitted(imageSize)
                            let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
                            
                            context.withFlippedContext { c in
                                c.setBlendMode(.copy)
                                if let cgImage = image.cgImage {
                                    drawImage(context: c, image: cgImage, orientation: .up, in: fittedRect)
                                }
                            }
                            return context
                        }
                    } else {
                        return nil
                    }
                }
                
                let imageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError> = editedSignal
                |> mapToSignal { result in
                    if result != nil {
                        return .single(result!)
                    } else {
                        return updateImageSignal
                    }
                }
                self.imageNode.setSignal(imageSignal)
            }
            
            self.currentDimensions = imageDimensions
            if let _ = imageDimensions {
                self.setNeedsLayout()
            }
            self.updateHiddenMedia()
        }
        
        self.item = item
        self.updateSelectionState(animated: false)
    }
    
    @objc func toggleSelection() {
        if let checkNode = self.checkNode, let item = self.item {
            checkNode.setIsChecked(!checkNode.isChecked, animated: true)
            item.controllerInteraction.toggleSelection(item.result, checkNode.isChecked)
        }
    }
    
    func updateSelectionState(animated: Bool) {
        if self.checkNode == nil, let item = self.item, let _ = item.controllerInteraction.selectionState {
            let checkNode = CheckNode(strokeColor: item.theme.list.itemCheckColors.strokeColor, fillColor: item.theme.list.itemCheckColors.fillColor, foregroundColor: item.theme.list.itemCheckColors.foregroundColor, style: .overlay)
            checkNode.addTarget(target: self, action: #selector(self.toggleSelection))
            self.addSubnode(checkNode)
            self.checkNode = checkNode
            self.setNeedsLayout()
        }
        
        if let item = self.item {
            if let selectionState = item.controllerInteraction.selectionState {
                let selected = selectionState.isIdentifierSelected(item.result.id)
                self.checkNode?.setIsChecked(selected, animated: animated)
            }
        }
    }
    
    func updateHiddenMedia() {
        if let item = self.item {
            let wasHidden = self.isHidden
            self.isHidden = item.controllerInteraction.hiddenMediaId == item.result.id
            if !self.isHidden && wasHidden {
                self.checkNode?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            }
        }
    }
    
    func transitionView() -> UIView {
        let view = self.imageNode.view.snapshotContentTree(unhide: true, keepTransform: true)!
        view.frame = self.convert(self.bounds, to: nil)
        return view
    }
    
    override func layout() {
        super.layout()
        
        let imageFrame = self.bounds
        self.imageNode.frame = imageFrame
        
        if let item = self.item, let dimensions = self.currentDimensions {
            let imageSize = dimensions.aspectFilled(imageFrame.size)
            self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageFrame.size, intrinsicInsets: UIEdgeInsets(), emptyColor: item.theme.list.mediaPlaceholderColor))()
        }
        
        let checkSize = CGSize(width: 32.0, height: 32.0)
        self.checkNode?.frame = CGRect(origin: CGPoint(x: imageFrame.width - checkSize.width, y: 0.0), size: checkSize)
    }
    
    @objc func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        guard let item = self.item else {
            return
        }

        switch recognizer.state {
            case .ended:
                if let (gesture, _) = recognizer.lastRecognizedGestureAndLocation {
                    switch gesture {
                        case .tap:
                            item.controllerInteraction.openResult(item.result)
                        default:
                            break
                    }
                }
            default:
                break
        }
    }
}

