import Foundation
import Postbox
import SwiftSignalKit

public struct SupportSettings: PreferencesEntry, Equatable {
    public var workmode: Bool

    public static var defaultSettings: SupportSettings {
        return SupportSettings(workmode: false)
    }

    public init(workmode: Bool) {
        self.workmode = workmode
    }

    public init(decoder: PostboxDecoder) {
        self.workmode = decoder.decodeInt32ForKey("wm", orElse: 0) != 0
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.workmode ? 1 : 0, forKey: "wm")
    }

    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? SupportSettings {
            return self == to
        } else {
            return false
        }
    }

    public static func ==(lhs: SupportSettings, rhs: SupportSettings) -> Bool {
        return lhs.workmode == rhs.workmode
    }

    public func withUpdatedWorkmode(_ workmode: Bool) -> SupportSettings {
        return SupportSettings(workmode: workmode)
    }
}

public func updateSupportSettingsInteractively(accountManager: AccountManager, _ f: @escaping (SupportSettings) -> SupportSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.supportSettings, { entry in
            let currentSettings: SupportSettings
            if let entry = entry as? SupportSettings {
                currentSettings = entry
            } else {
                currentSettings = SupportSettings.defaultSettings
            }
            return f(currentSettings)
        })
    }
}
