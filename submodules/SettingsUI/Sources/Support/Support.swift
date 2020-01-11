import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import LegacyComponents
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext
import OpenInExternalAppUI

private final class SupportControllerArguments {
    let toggleWorkmode: (Bool) -> Void

    init(toggleWorkmode: @escaping (Bool) -> Void) {
        self.toggleWorkmode = toggleWorkmode
    }
}

private enum SupportSection: Int32 {
    case basicSettings
}

enum SupportEntryTag: ItemListItemTag {
    case workmode

    func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? SupportEntryTag, self == other {
            return true
        } else {
            return false
        }
    }
}

private enum SupportEntry: ItemListNodeEntry {
    case basicSettingsHeader(PresentationTheme, String)
    case workmode(PresentationTheme, String, Bool)

    var section: ItemListSectionId {
        switch self {
            case .basicSettingsHeader, .workmode:
                return SupportSection.basicSettings.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
            case .basicSettingsHeader:
                return 0
            case .workmode:
                return 1
        }
    }

    static func ==(lhs: SupportEntry, rhs: SupportEntry) -> Bool {
        switch lhs {
            case let .basicSettingsHeader(lhsTheme, lhsText):
                if case let .basicSettingsHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .workmode(lhsTheme, lhsText, lhsValue):
                if case let .workmode(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
        }
    }

    static func <(lhs: SupportEntry, rhs: SupportEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! SupportControllerArguments
        switch self {
            case let .basicSettingsHeader(theme, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .workmode(theme, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleWorkmode(value)
                }, tag: SupportEntryTag.workmode)
        }
    }
}

private struct SupportControllerState: Equatable {
    static func ==(lhs: SupportControllerState, rhs: SupportControllerState) -> Bool {
        return true
    }
}

private struct SupportData: Equatable {
    let supportSettings: SupportSettings

    init(supportSettings: SupportSettings) {
        self.supportSettings = supportSettings
    }

    static func ==(lhs: SupportData, rhs: SupportData) -> Bool {
        return lhs.supportSettings == rhs.supportSettings
    }
}

private func supportControllerEntries(state: SupportControllerState, data: SupportData, presentationData: PresentationData) -> [SupportEntry] {
    var entries: [SupportEntry] = []
    entries.append(.basicSettingsHeader(presentationData.theme, presentationData.strings.SupportSettings_BasicSettingsTitle.uppercased()))
    entries.append(.workmode(presentationData.theme, presentationData.strings.SupportSettings_Workmode, data.supportSettings.workmode))
    return entries
}

func supportController(context: AccountContext, focusOnItemTag: SupportEntryTag? = nil) -> ViewController {
    let initialState = SupportControllerState()
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)

    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?

    let actionsDisposable = DisposableSet()

    let cacheUsagePromise = Promise<CacheUsageStatsResult?>()
    cacheUsagePromise.set(cacheUsageStats(context: context))

    let supportDataPromise = Promise<SupportData>()
    supportDataPromise.set(context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.supportSettings])
    |> map { sharedData -> SupportData in
        var supportSettings: SupportSettings
        if let value = sharedData.entries[ApplicationSpecificSharedDataKeys.supportSettings] as? SupportSettings {
            supportSettings = value
        } else {
            supportSettings = .defaultSettings
        }
        return SupportData(supportSettings: supportSettings)
    })

    let arguments = SupportControllerArguments(toggleWorkmode: { value in
        let _ = updateSupportSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
            return current.withUpdatedWorkmode(value)
        }).start()
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        statePromise.get(),
        supportDataPromise.get()
    )
    |> map { presentationData, state, supportData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.SupportSettings_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: supportControllerEntries(state: state, data: supportData, presentationData: presentationData), style: .blocks, ensureVisibleItemTag: focusOnItemTag, emptyStateItem: nil, animateChanges: false)

        return (controllerState, (listState, arguments))
    } |> afterDisposed {
        actionsDisposable.dispose()
    }

    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        if let controller = controller {
            (controller.navigationController as? NavigationController)?.pushViewController(c)
        }
    }
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }

    return controller
}
