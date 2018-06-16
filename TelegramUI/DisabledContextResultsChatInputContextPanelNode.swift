import Foundation
import TelegramCore
import AsyncDisplayKit
import Display

final class DisabledContextResultsChatInputContextPanelNode: ChatInputContextPanelNode {
    private let containerNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    private let textNode: ImmediateTextNode
    
    private var validLayout: (CGSize, CGFloat, CGFloat)?
    
    override init(account: Account, theme: PresentationTheme, strings: PresentationStrings) {
        self.containerNode = ASDisplayNode()
        self.separatorNode = ASDisplayNode()
        self.textNode = ImmediateTextNode()
        self.textNode.maximumNumberOfLines = 0
        self.textNode.textAlignment = .center
        
        super.init(account: account, theme: theme, strings: strings)
        
        self.isOpaque = false
        self.clipsToBounds = true
        
        self.containerNode.addSubnode(self.textNode)
        self.containerNode.addSubnode(self.separatorNode)
        self.addSubnode(self.containerNode)
    }
    
    override func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) {
        let firstLayout = self.validLayout == nil
        
        self.validLayout = (size, leftInset, rightInset)
        
        self.containerNode.backgroundColor = interfaceState.theme.list.plainBackgroundColor
        self.separatorNode.backgroundColor = interfaceState.theme.list.itemPlainSeparatorColor
        
        guard let bannedRights = (interfaceState.renderedPeer?.peer as? TelegramChannel)?.bannedRights else {
            return
        }
        let banDescription: String
        if bannedRights.untilDate != 0 && bannedRights.untilDate != Int32.max {
            banDescription = interfaceState.strings.Conversation_RestrictedInlineTimed(stringForFullDate(timestamp: bannedRights.untilDate, strings: interfaceState.strings, timeFormat: .regular)).0
        } else {
            banDescription = interfaceState.strings.Conversation_RestrictedInline
        }
        
        self.textNode.attributedText = NSAttributedString(string: banDescription, font: Font.regular(13.0), textColor: interfaceState.theme.chat.inputPanel.secondaryTextColor)
        
        let verticalInset: CGFloat = 8.0
        let textSize = self.textNode.updateLayout(CGSize(width: size.width - leftInset - rightInset - 8.0 * 2.0, height: CGFloat.greatestFiniteMagnitude))
        
        self.textNode.frame = CGRect(origin: CGPoint(x: leftInset + floor((size.width - leftInset - rightInset - textSize.width) / 2.0), y: verticalInset), size: textSize)
        
        let containerHeight = textSize.height + verticalInset * 2.0
        let containerFrame = CGRect(origin: CGPoint(x: 0.0, y: size.height - containerHeight), size: CGSize(width: size.width, height: containerHeight))
        transition.updateFrame(node: self.containerNode, frame: containerFrame)
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: UIScreenPixel)))
        
        if firstLayout {
            self.animateIn()
        }
    }
    
    func animateIn() {
        let position = self.containerNode.layer.position
        self.containerNode.layer.animatePosition(from: CGPoint(x: position.x, y: position.y + (self.containerNode.bounds.height)), to: position, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    override func animateOut(completion: @escaping () -> Void) {
        let position = self.containerNode.layer.position
        self.containerNode.layer.animatePosition(from: position, to: CGPoint(x: position.x, y: position.y + (self.containerNode.bounds.height)), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
            completion()
        })
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let containerFrame = self.containerNode.frame
        return self.containerNode.hitTest(CGPoint(x: point.x - containerFrame.minX, y: point.y - containerFrame.minY), with: event)
    }
}
