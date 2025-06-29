import XCTest
import Foundation

/// Tests for universal binary functionality to ensure app compatibility
final class UniversalBinaryTests: XCTestCase {
    
    /// Test that verifies the CLI binary is a universal binary containing both architectures
    func testCLIUniversalBinary() throws {
        let binaryPath = ".build/release/transcriber"
        let binaryURL = URL(fileURLWithPath: binaryPath)
        
        // Check if binary exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: binaryPath), 
                     "CLI binary should exist at \(binaryPath)")
        
        // Use lipo to check architectures
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/lipo")
        process.arguments = ["-info", binaryPath]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            // Verify it's a universal binary with both architectures
            XCTAssertTrue(output.contains("x86_64"), "Binary should contain x86_64 architecture")
            XCTAssertTrue(output.contains("arm64"), "Binary should contain arm64 architecture")
            XCTAssertTrue(output.contains("Architectures in the fat file") || output.contains("2 architectures"), 
                         "Binary should be a universal binary")
            
        } catch {
            XCTFail("Failed to run lipo command: \(error)")
        }
    }
    
    /// Test that verifies the GUI app binary is a universal binary containing both architectures
    func testAppUniversalBinary() throws {
        let binaryPath = ".build/release/TranscriberApp"
        let binaryURL = URL(fileURLWithPath: binaryPath)
        
        // Check if binary exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: binaryPath), 
                     "App binary should exist at \(binaryPath)")
        
        // Use lipo to check architectures
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/lipo")
        process.arguments = ["-info", binaryPath]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            // Verify it's a universal binary with both architectures
            XCTAssertTrue(output.contains("x86_64"), "App binary should contain x86_64 architecture")
            XCTAssertTrue(output.contains("arm64"), "App binary should contain arm64 architecture")
            XCTAssertTrue(output.contains("Architectures in the fat file") || output.contains("2 architectures"), 
                         "App binary should be a universal binary")
            
        } catch {
            XCTFail("Failed to run lipo command: \(error)")
        }
    }
    
    /// Test that verifies app bundle contains universal binary
    func testAppBundleUniversalBinary() throws {
        let appBundlePath = "installer/build/Transcriber.app/Contents/MacOS/TranscriberApp"
        
        // Skip test if app bundle doesn't exist (not built yet)
        guard FileManager.default.fileExists(atPath: appBundlePath) else {
            throw XCTSkip("App bundle not found at \(appBundlePath) - run build-app-bundle.sh first")
        }
        
        // Use lipo to check architectures
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/lipo")
        process.arguments = ["-info", appBundlePath]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            // Verify it's a universal binary with both architectures
            XCTAssertTrue(output.contains("x86_64"), "App bundle binary should contain x86_64 architecture")
            XCTAssertTrue(output.contains("arm64"), "App bundle binary should contain arm64 architecture")
            XCTAssertTrue(output.contains("Architectures in the fat file") || output.contains("2 architectures"), 
                         "App bundle binary should be a universal binary")
            
        } catch {
            XCTFail("Failed to run lipo command: \(error)")
        }
    }
    
    /// Test that verifies code signing is applied to universal binaries
    func testUniversalBinaryCodeSigning() throws {
        let cliPath = ".build/release/transcriber"
        let appPath = ".build/release/TranscriberApp"
        
        // Test CLI binary code signing
        if FileManager.default.fileExists(atPath: cliPath) {
            let cliResult = try runCodeSignVerification(for: cliPath)
            XCTAssertTrue(cliResult, "CLI universal binary should be properly code signed")
        }
        
        // Test App binary code signing
        if FileManager.default.fileExists(atPath: appPath) {
            let appResult = try runCodeSignVerification(for: appPath)
            XCTAssertTrue(appResult, "App universal binary should be properly code signed")
        }
    }
    
    /// Helper method to verify code signing
    private func runCodeSignVerification(for binaryPath: String) throws -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["-v", binaryPath]
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            throw error
        }
    }
}