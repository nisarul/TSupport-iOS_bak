import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import DeviceAccess
import AccountContext

public enum PermissionKind: Int32 {
    case contacts
    case notifications
    case siri
    case cellularData
    case nearbyLocation
}

public enum PermissionRequestStatus {
    case requestable
    case denied
    case unreachable
    case allowed
    
    public init(accessType: AccessType) {
        switch accessType {
            case .notDetermined:
                self = .requestable
            case .denied, .restricted:
                self = .denied
            case .unreachable:
                self = .unreachable
            case .allowed:
                self = .allowed
        }
    }
}

public enum PermissionState: Equatable {
    case contacts(status: PermissionRequestStatus)
    case notifications(status: PermissionRequestStatus)
    case siri(status: PermissionRequestStatus)
    case cellularData(status: PermissionRequestStatus)
    case nearbyLocation(status: PermissionRequestStatus)
    
    public var kind: PermissionKind {
        switch self {
            case .contacts:
                return .contacts
            case .notifications:
                return .notifications
            case .siri:
                return .siri
            case .cellularData:
                return .cellularData
            case .nearbyLocation:
                return .nearbyLocation
        }
    }
    
    public var status: PermissionRequestStatus {
        switch self {
            case let .contacts(status):
                return status
            case let .notifications(status):
                return status
            case let .siri(status):
                return status
            case let .cellularData(status):
                return status
            case let .nearbyLocation(status):
                return status
        }
    }
}

public func requiredPermissions(context: AccountContext) -> Signal<(contacts: PermissionState, notifications: PermissionState, cellularData: PermissionState, siri: PermissionState), NoError> {
    return combineLatest(DeviceAccess.authorizationStatus(subject: .contacts, isSupportAccount: context.account.isSupportAccount), DeviceAccess.authorizationStatus(applicationInForeground: context.sharedContext.applicationBindings.applicationInForeground, subject: .notifications, isSupportAccount: context.account.isSupportAccount), DeviceAccess.authorizationStatus(siriAuthorization: {
        return context.sharedContext.applicationBindings.siriAuthorization()
    }, subject: .cellularData, isSupportAccount: context.account.isSupportAccount), DeviceAccess.authorizationStatus(siriAuthorization: {
        return context.sharedContext.applicationBindings.siriAuthorization()
    }, subject: .siri, isSupportAccount: context.account.isSupportAccount))
    |> map { contactsStatus, notificationsStatus, cellularDataStatus, siriStatus in
        return (.contacts(status: PermissionRequestStatus(accessType: contactsStatus)), .notifications(status: PermissionRequestStatus(accessType: notificationsStatus)), .cellularData(status: PermissionRequestStatus(accessType: cellularDataStatus)), .siri(status: PermissionRequestStatus(accessType: siriStatus)))
    }
}
