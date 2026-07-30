import Foundation
import Network
import TestStepHUDProtocol

struct AppLaunchConfiguration {
    let port: NWEndpoint.Port
    let token: String

    init?(environment: [String: String]) {
        guard
            let portValue = environment[TestStepHUDProtocolConstants.portEnvironmentKey],
            let rawPort = UInt16(portValue),
            rawPort > 0,
            let port = NWEndpoint.Port(rawValue: rawPort),
            let token = environment[TestStepHUDProtocolConstants.tokenEnvironmentKey],
            !token.isEmpty,
            let versionValue = environment[TestStepHUDProtocolConstants.versionEnvironmentKey],
            let declaredProtocolVersion = Int(versionValue),
            declaredProtocolVersion > 0
        else {
            return nil
        }

        self.port = port
        self.token = token
    }
}
