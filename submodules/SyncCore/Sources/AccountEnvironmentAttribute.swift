import Foundation
import Postbox

public enum AccountEnvironment: Int32 {
    case production = 0
    case test = 1
}

public final class AccountEnvironmentAttribute: AccountRecordAttribute {
    public let environment: AccountEnvironment
    public let isSupportAccount: Bool
    
    public init(environment: AccountEnvironment, isSupportAccount: Bool) {
        self.environment = environment
        self.isSupportAccount = isSupportAccount
    }
    
    public init(decoder: PostboxDecoder) {
        self.environment = AccountEnvironment(rawValue: decoder.decodeInt32ForKey("environment", orElse: 0)) ?? .production
        self.isSupportAccount = Bool(decoder.decodeBoolForKey("isSupportAccount", orElse: false))
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.environment.rawValue, forKey: "environment")
        encoder.encodeBool(self.isSupportAccount, forKey: "isSupportAccount")
    }
    
    public func isEqual(to: AccountRecordAttribute) -> Bool {
        guard let to = to as? AccountEnvironmentAttribute else {
            return false
        }
        if self.environment != to.environment {
            return false
        }
        if self.isSupportAccount != to.isSupportAccount {
            return false
        }
        return true
    }
}
