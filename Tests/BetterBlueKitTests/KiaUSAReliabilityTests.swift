//
//  KiaUSAReliabilityTests.swift
//  BetterBlueKit
//
//  Tests for Kia USA authentication reliability improvements
//

import Foundation
import Testing
@testable import BetterBlueKit

@Suite("Kia USA Reliability Tests")
struct KiaUSAReliabilityTests {

    // MARK: - Device ID Generation Tests

    @Test("Kia USA device ID follows official KIAPrimo hex format")
    @MainActor func testKiaDeviceIdFormat() {
        let deviceId = KiaUSAAPIClient.generateKiaDeviceId()
        let regexPattern = #"^[0-9a-f]{22}:[0-9a-f]{9}_[0-9a-f]{10}-[0-9a-f]{5}_[0-9a-f]{22}_[0-9a-f]{8}-[0-9a-f]{18}-_[0-9a-f]{22}_[0-9a-f]{17}$"#
        let matches = deviceId.range(of: regexPattern, options: .regularExpression) != nil

        #expect(matches, "Device ID should match official format: \(deviceId)")
        #expect(deviceId.contains(":"))
        #expect(deviceId.contains("_"))
        #expect(deviceId.contains("-"))
    }

    @Test("Kia USA registerDevice updates deviceId and configuration")
    @MainActor func testKiaRegisterDevice() async throws {
        let config = APIClientConfiguration(
            region: .usa,
            brand: .kia,
            username: "test@example.com",
            password: "password123",
            pin: "0000",
            accountId: UUID()
        )
        let client = KiaUSAAPIClient(configuration: config)
        let initialDeviceId = client.deviceId

        let registered = try await client.registerDevice()
        #expect(registered != nil)
        #expect(client.deviceId == registered)
        #expect(client.configuration.deviceId == registered)
        #expect(client.deviceId != initialDeviceId)
    }

    // MARK: - Header Casing Tests

    @Test("Kia USA headers use expected casing for gateway")
    @MainActor func testKiaHeadersCasing() {
        let config = APIClientConfiguration(
            region: .usa,
            brand: .kia,
            username: "test@example.com",
            password: "password123",
            pin: "0000",
            accountId: UUID(),
            deviceId: "custom-device-id"
        )
        let client = KiaUSAAPIClient(configuration: config)
        let headers = client.headers()

        #expect(headers["deviceId"] == "custom-device-id")
        #expect(headers["clientId"] == "SPACL716-APL")
        #expect(headers["appType"] == "L")
        #expect(headers["appVersion"] == "7.22.0")
        #expect(headers["osType"] == "iOS")
        #expect(headers["osVersion"] == "15.8.5")
        #expect(headers["secretKey"] == "sydnat-9kykci-Kuhtep-h5nK")
        #expect(headers["User-Agent"] == "KIAPrimo_iOS/37 CFNetwork/1335.0.3.4 Darwin/21.6.0")
        #expect(headers["accept"] == "application/json, text/plain, */*")
    }

    // MARK: - Session Expiration Error Detection Tests

    @Test("APIError isSessionExpired detects invalidVehicleSession")
    func testIsSessionExpiredForInvalidVehicleSession() {
        let error = APIError.invalidVehicleSession("Session Key is invalid or expired")
        #expect(error.isSessionExpired == true)
    }

    @Test("APIError isSessionExpired detects 401 token/session expiration")
    func testIsSessionExpiredFor401ExpiredText() {
        let error1 = APIError(message: "401 Unauthorized - session expired", code: 401, errorType: .invalidCredentials)
        #expect(error1.isSessionExpired == true)

        let error2 = APIError(message: "token expired", code: 401, errorType: .invalidCredentials)
        #expect(error2.isSessionExpired == true)
    }

    @Test("APIError isSessionExpired returns false for other errors")
    func testIsSessionExpiredReturnsFalseForOtherErrors() {
        let badPassword = APIError.invalidCredentials("Invalid username or password")
        #expect(badPassword.isSessionExpired == false)

        let serverErr = APIError.serverError("Internal Server Error")
        #expect(serverErr.isSessionExpired == false)
    }

    // MARK: - Configuration Callback Preservation Tests

    @Test("APIClientConfiguration with() preserves onAuthTokenRefreshed callback")
    @MainActor func testConfigurationWithPreservesAuthTokenRefreshed() {
        var refreshedCount = 0
        let config = APIClientConfiguration(
            region: .usa,
            brand: .kia,
            username: "test@example.com",
            password: "password",
            pin: "1234",
            accountId: UUID(),
            onAuthTokenRefreshed: { _ in
                refreshedCount += 1
            }
        )

        let updated = config.with(rememberMeToken: "new-token")
        #expect(updated.rememberMeToken == "new-token")
        #expect(updated.onAuthTokenRefreshed != nil)

        // Verify the callback is callable and still references the same logic
        let dummyToken = AuthToken(accessToken: "sid", refreshToken: "dummy-refresh", expiresAt: Date().addingTimeInterval(3600))
        updated.onAuthTokenRefreshed?(dummyToken)
        #expect(refreshedCount == 1)
    }
}
