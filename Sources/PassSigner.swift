import Foundation
import Crypto
import _CryptoExtras
import PassCore
@_spi(CMS) import X509
import ZipArchive

struct PassSigner {
    let wwdrCertificate: Certificate
    let passCertificate: Certificate
    let privateKey: _RSA.Signing.PrivateKey
    let assetsDirectoryURL: URL

    init(
        pemWWDRCertificate: String,
        pemCertificate: String,
        pemPrivateKey: String,
        assetsDirectoryURL: URL
    ) throws {
        self.wwdrCertificate = try Certificate(pemEncoded: pemWWDRCertificate)
        self.passCertificate = try Certificate(pemEncoded: pemCertificate)
        self.privateKey = try _RSA.Signing.PrivateKey(pemRepresentation: pemPrivateKey)
        self.assetsDirectoryURL = assetsDirectoryURL
    }

    func sign(pass: Pass) async throws -> Data {
        // Encode pass.json once
        let passData = try JSONEncoder.passKit.encode(pass)

        // Load asset files
        let assetFiles = try loadAssetFiles()

        // Create manifest with the same passData and assets
        let manifestData = try createManifest(passData: passData, assetFiles: assetFiles)

        // Sign the manifest
        let signatureData = try signManifest(manifestData)

        // Create the pass bundle
        return try createPassBundle(
            passData: passData,
            assetFiles: assetFiles,
            manifestData: manifestData,
            signatureData: signatureData
        )
    }

    private func loadAssetFiles() throws -> [String: Data] {
        var assets: [String: Data] = [:]
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: assetsDirectoryURL.path) else {
            return assets
        }

        let files = try fileManager.contentsOfDirectory(at: assetsDirectoryURL, includingPropertiesForKeys: nil)
        for fileURL in files where fileURL.pathExtension == "png" {
            let data = try Data(contentsOf: fileURL)
            assets[fileURL.lastPathComponent] = data
        }

        return assets
    }

    private func createManifest(passData: Data, assetFiles: [String: Data]) throws -> Data {
        var manifest = Manifest()
        manifest.addHash(name: "pass.json", data: passData)

        // Add hashes for all asset files
        for (filename, data) in assetFiles {
            manifest.addHash(name: filename, data: data)
        }

        return try manifest.makeData()
    }

    private func signManifest(_ manifestData: Data) throws -> Data {
        // Create CMS signature using the same approach as Apple's CMSEncodeContent
        // with kCMSAttrSigningTime and detached = true
        let signature = try CMS.sign(
            manifestData,
            signatureAlgorithm: .sha256WithRSAEncryption,
            additionalIntermediateCertificates: [wwdrCertificate],
            certificate: passCertificate,
            privateKey: Certificate.PrivateKey(pemEncoded: privateKey.pemRepresentation),
            signingTime: Date(),
            detached: true
        )

        return Data(signature)
    }

    private func createPassBundle(
        passData: Data,
        assetFiles: [String: Data],
        manifestData: Data,
        signatureData: Data
    ) throws -> Data {
        let archive = ZipArchiveWriter<ZipMemoryStorage<[UInt8]>>()

        // Add pass.json (use the same data that was hashed)
        try archive.writeFile(filename: "pass.json", contents: Array(passData))

        // Add all asset files (icons, logos, etc.)
        for (filename, data) in assetFiles {
            try archive.writeFile(filename: filename, contents: Array(data))
        }

        // Add manifest.json
        try archive.writeFile(filename: "manifest.json", contents: Array(manifestData))

        // Add signature
        try archive.writeFile(filename: "signature", contents: Array(signatureData))

        // Finalize and return
        let buffer = try archive.finalizeBuffer()
        return Data(buffer)
    }
}

// Manifest structure matching Apple's implementation
struct Manifest {
    private var hashes: [String: String] = [:]

    mutating func addHash(name: String, data: Data) {
        let hash = sha1Hash(data: data)
        hashes[name] = hash
    }

    func makeData() throws -> Data {
        try JSONSerialization.data(withJSONObject: hashes, options: .prettyPrinted)
    }

    private func sha1Hash(data: Data) -> String {
        let digest = Insecure.SHA1.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
