import Foundation
import SwiftSignalKit
import Display
import TelegramCore
import Postbox

public final class PeerSelectionController: ViewController {
    private let account: Account
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    var peerSelected: ((PeerId) -> Void)?
    private let filter: ChatListNodePeersFilter
    
    var inProgress: Bool = false {
        didSet {
            if self.inProgress != oldValue {
                if self.isNodeLoaded {
                    self.peerSelectionNode.inProgress = self.inProgress
                }
                
                if self.inProgress {
                    self.navigationItem.rightBarButtonItem = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(theme: self.presentationData.theme))
                } else {
                    self.navigationItem.rightBarButtonItem = nil
                }
            }
        }
    }
    
    private var peerSelectionNode: PeerSelectionControllerNode {
        return super.displayNode as! PeerSelectionControllerNode
    }
    
    let openMessageFromSearchDisposable: MetaDisposable = MetaDisposable()
    
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    public init(account: Account, filter: ChatListNodePeersFilter = [.onlyWriteable]) {
        self.account = account
        self.filter = filter
        
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        
        self.title = self.presentationData.strings.Conversation_ForwardTitle
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed))
        
        self.scrollToTop = { [weak self] in
            if let strongSelf = self {
                strongSelf.peerSelectionNode.scrollToTop()
            }
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.openMessageFromSearchDisposable.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = PeerSelectionControllerNode(account: self.account, filter: self.filter, dismiss: { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        })
        self.displayNode.backgroundColor = .white
        
        self.peerSelectionNode.navigationBar = self.navigationBar
        
        self.peerSelectionNode.requestDeactivateSearch = { [weak self] in
            self?.deactivateSearch()
        }
        
        self.peerSelectionNode.requestActivateSearch = { [weak self] in
            self?.activateSearch()
        }
        
        self.peerSelectionNode.requestOpenPeer = { [weak self] peerId in
            if let strongSelf = self, let peerSelected = strongSelf.peerSelected {
                peerSelected(peerId)
            }
        }
        
        self.peerSelectionNode.requestOpenPeerFromSearch = { [weak self] peer in
            if let strongSelf = self {
                let storedPeer = strongSelf.account.postbox.transaction { transaction -> Void in
                    if transaction.getPeer(peer.id) == nil {
                        updatePeers(transaction: transaction, peers: [peer], update: { previousPeer, updatedPeer in
                            return updatedPeer
                        })
                    }
                }
                strongSelf.openMessageFromSearchDisposable.set((storedPeer |> deliverOnMainQueue).start(completed: { [weak strongSelf] in
                    if let strongSelf = strongSelf, let peerSelected = strongSelf.peerSelected {
                        peerSelected(peer.id)
                    }
                }))
            }
        }
        
        self.displayNodeDidLoad()
        
        self._ready.set(self.peerSelectionNode.ready)
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.peerSelectionNode.animateIn()
    }
    
    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.peerSelectionNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
    
    @objc func cancelPressed() {
        self.dismiss()
    }
    
    private func activateSearch() {
        if self.displayNavigationBar {
            if let scrollToTop = self.scrollToTop {
                scrollToTop()
            }
            self.peerSelectionNode.activateSearch()
            self.setDisplayNavigationBar(false, transition: .animated(duration: 0.5, curve: .spring))
        }
    }
    
    private func deactivateSearch() {
        if !self.displayNavigationBar {
            self.setDisplayNavigationBar(true, transition: .animated(duration: 0.5, curve: .spring))
            self.peerSelectionNode.deactivateSearch()
        }
    }
    
    override open func dismiss(completion: (() -> Void)? = nil) {
        self.peerSelectionNode.view.endEditing(true)
        self.peerSelectionNode.animateOut(completion: completion)
    }
}
