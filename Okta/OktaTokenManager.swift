/*
 * Copyright (c) 2017, Okta, Inc. and/or its affiliates. All rights reserved.
 * The Okta software accompanied by this notice is provided pursuant to the Apache License, Version 2.0 (the "License.")
 *
 * You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0.
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *
 * See the License for the specific language governing permissions and limitations under the License.
 */

import AppAuth
import Vinculum

open class OktaTokenManager: NSObject, NSCoding {

    open var authState: OIDAuthState
    open var config: [String: String]
    open var accessibility: CFString
    open var validationOptions: [String: Any]

    open var accessToken: String? {
        // Return the known accessToken if it hasn't expired
        get {
            guard let tokenResponse = self.authState.lastTokenResponse,
                  let token = tokenResponse.accessToken,
                  let tokenExp = tokenResponse.accessTokenExpirationDate,
                  tokenExp.timeIntervalSince1970 > Date().timeIntervalSince1970 else {
                    return nil
            }
            return token
        }
    }

    open var idToken: String? {
        // Return the known idToken if it is valid
        get {
            guard let tokenResponse = self.authState.lastTokenResponse,
                let token = tokenResponse.idToken else {
                    return nil
            }
            do {
                // Attempt to validate the token
                let valid = try isValidToken(idToken: token)
                return valid ? token : nil
            } catch let error {
                // Capture the error here since we aren't throwing
                print(error)
                return nil
            }
        }
    }

    open var refreshToken: String? {
        // Return the known refreshToken
        get {
            guard let token = self.authState.refreshToken else { return nil }
            return token
        }
    }

    public init(authState: OIDAuthState, config: [String: String], accessibility: CFString = kSecAttrAccessibleWhenUnlockedThisDeviceOnly, validationOptions: [String: Any]?) throws {
        self.authState = authState
        self.config = config
        self.accessibility = accessibility

        if validationOptions != nil {
            // Override config options
            self.validationOptions = validationOptions!
        } else {
            // Opinionated validation options
            self.validationOptions = [
                "issuer": config["issuer"] as Any,
                "audience": config["clientId"] as Any,
                "exp": true,
                "iat": true,
                "nonce": authState.lastTokenResponse?.request.additionalParameters?["nonce"] as Any
            ] as [String: Any]
        }

        super.init()

        // Store the current configuration
        OktaAuth.configuration = config
    }

    required public convenience init?(coder decoder: NSCoder) {
        try? self.init(
                    authState: decoder.decodeObject(forKey: "authState") as! OIDAuthState,
                       config: decoder.decodeObject(forKey: "config") as! [String: String],
                accessibility: (decoder.decodeObject(forKey: "accessibility") as! CFString),
            validationOptions: (decoder.decodeObject(forKey: "validationOptions") as! [String: Any])
        )
    }

    public func encode(with coder: NSCoder) {
        coder.encode(self.authState, forKey: "authState")
        coder.encode(self.config, forKey: "config")
        coder.encode(self.accessibility, forKey: "accessibility")
        coder.encode(self.validationOptions, forKey: "validationOptions")
    }

    public func isValidToken(idToken: String?) throws -> Bool {
        guard let token = idToken else { return false }
        do {
            let isValid = try Introspect().validate(jwt: token, options: self.validationOptions)
            if isValid {
                return true
            }
        } catch let error {
            throw error
        }
        return false
    }

    public func clear() {
        Vinculum.removeAll()
        OktaAuth.tokens = nil
    }
}
