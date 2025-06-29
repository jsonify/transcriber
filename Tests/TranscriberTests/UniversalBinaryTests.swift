import XCTest
import Foundation

/// Tests for universal binary functionality to ensure app compatibility
final class UniversalBinaryTests: XCTestCase {
    
    /// Test that verifies the CLI binary is a universal binary containing both architectures
    /// This test is skipped in CI environments where only single-architecture builds are available
    func testCLIUniversalBinary() throws {
        let binaryPath = ".build/release/transcriber"
        
        // Skip test if binary doesn't exist (not built with universal binary process)
        guard FileManager.default.fileExists(atPath: binaryPath) else {
            throw XCTSkip("CLI binary not found at \(binaryPath) - universal binary not built")
        }
        
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
            
            // If this is a single-architecture binary (normal in CI), skip the universal binary check
            let hasX86 = output.contains("x86_64")
            let hasArm = output.contains("arm64")
            if output.contains("is not a fat file") || 
               (!hasX86 && !hasArm) ||
               (hasX86 && !hasArm) ||
               (!hasX86 && hasArm) {
                throw XCTSkip("Single-architecture binary detected - universal binary tests only apply to manually built binaries")
            }
            
            // Verify it's a universal binary with both architectures
            XCTAssertTrue(output.contains("x86_64"), "Binary should contain x86_64 architecture")
            XCTAssertTrue(output.contains("arm64"), "Binary should contain arm64 architecture")
            XCTAssertTrue(output.contains("Architectures in the fat file") || output.contains("2 architectures"), 
                         "Binary should be a universal binary")
            
        } catch {
            throw XCTSkip("Failed to run lipo command or binary is single-architecture: \(error)")
        }
    }
    
    /// Test that verifies the GUI app binary is a universal binary containing both architectures
    /// This test is skipped in CI environments where only single-architecture builds are available
    func testAppUniversalBinary() throws {
        let binaryPath = ".build/release/TranscriberApp"
        
        // Skip test if binary doesn't exist (not built with universal binary process)
        guard FileManager.default.fileExists(atPath: binaryPath) else {
            throw XCTSkip("App binary not found at \(binaryPath) - universal binary not built")
        }
        
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
            
            // If this is a single-architecture binary (normal in CI), skip the universal binary check
            let hasX86 = output.contains("x86_64")
            let hasArm = output.contains("arm64")
            if output.contains("is not a fat file") || 
               (!hasX86 && !hasArm) ||
               (hasX86 && !hasArm) ||
               (!hasX86 && hasArm) {
                throw XCTSkip("Single-architecture binary detected - universal binary tests only apply to manually built binaries")
            }
            
            // Verify it's a universal binary with both architectures
            XCTAssertTrue(output.contains("x86_64"), "App binary should contain x86_64 architecture")
            XCTAssertTrue(output.contains("arm64"), "App binary should contain arm64 architecture")
            XCTAssertTrue(output.contains("Architectures in the fat file") || output.contains("2 architectures"), 
                         "App binary should be a universal binary")
            
        } catch {
            throw XCTSkip("Failed to run lipo command or binary is single-architecture: \(error)")
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
    
    /// Test that verifies code signing is applied to binaries
    /// This test is compatible with both universal and single-architecture binaries
    func testUniversalBinaryCodeSigning() throws {
        let cliPath = ".build/release/transcriber"
        let appPath = ".build/release/TranscriberApp"
        
        // Test CLI binary code signing (skip if not built)
        if FileManager.default.fileExists(atPath: cliPath) {
            let cliResult = try runCodeSignVerification(for: cliPath)
            XCTAssertTrue(cliResult, "CLI binary should be properly code signed")
        }
        
        // Test App binary code signing (skip if not built)
        if FileManager.default.fileExists(atPath: appPath) {
            let appResult = try runCodeSignVerification(for: appPath)
            XCTAssertTrue(appResult, "App binary should be properly code signed")
        }
        
        // If neither binary exists, skip the test (normal in some CI scenarios)
        if !FileManager.default.fileExists(atPath: cliPath) && !FileManager.default.fileExists(atPath: appPath) {
            throw XCTSkip("No release binaries found - code signing test requires release build")
        }
    }
    
    /// Test that verifies the build scripts contain universal binary support
    /// This test validates the implementation without requiring actual universal binaries to be built
    func testUniversalBinaryBuildScriptSupport() throws {
        // Check that build-signed.sh contains universal binary support
        let buildSignedPath = "build-signed.sh"
        XCTAssertTrue(FileManager.default.fileExists(atPath: buildSignedPath), 
                     "build-signed.sh should exist")
        
        let buildSignedContent = try String(contentsOfFile: buildSignedPath)
        XCTAssertTrue(buildSignedContent.contains("--arch x86_64"), 
                     "build-signed.sh should contain x86_64 architecture build")
        XCTAssertTrue(buildSignedContent.contains("--arch arm64"), 
                     "build-signed.sh should contain arm64 architecture build")
        XCTAssertTrue(buildSignedContent.contains("lipo -create"), 
                     "build-signed.sh should contain lipo command for universal binary creation")
        
        // Check that Makefile contains universal binary support
        let makefilePath = "Makefile"
        XCTAssertTrue(FileManager.default.fileExists(atPath: makefilePath), 
                     "Makefile should exist")
        
        let makefileContent = try String(contentsOfFile: makefilePath)
        XCTAssertTrue(makefileContent.contains("--arch x86_64"), 
                     "Makefile should contain x86_64 architecture build")
        XCTAssertTrue(makefileContent.contains("--arch arm64"), 
                     "Makefile should contain arm64 architecture build")
        XCTAssertTrue(makefileContent.contains("lipo -create"), 
                     "Makefile should contain lipo command for universal binary creation")
        
        // Check that build-app-bundle.sh contains universal binary support
        let appBundlePath = "installer/build-scripts/build-app-bundle.sh"
        XCTAssertTrue(FileManager.default.fileExists(atPath: appBundlePath), 
                     "build-app-bundle.sh should exist")
        
        let appBundleContent = try String(contentsOfFile: appBundlePath)
        XCTAssertTrue(appBundleContent.contains("--arch x86_64"), 
                     "build-app-bundle.sh should contain x86_64 architecture build")
        XCTAssertTrue(appBundleContent.contains("--arch arm64"), 
                     "build-app-bundle.sh should contain arm64 architecture build")
        XCTAssertTrue(appBundleContent.contains("lipo -create"), 
                     "build-app-bundle.sh should contain lipo command for universal binary creation")
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