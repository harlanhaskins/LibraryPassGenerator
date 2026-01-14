import Foundation
import Hummingbird
import PassCore

struct Secrets: Codable {
    let pemWWDRCertificate: String // Base64 encoded PEM WWDR certificate
    let pemCertificate: String // Base64 encoded PEM certificate
    let pemPrivateKey: String // Base64 encoded PEM private key
}

struct BarcodeInfo: Codable, Sendable {
    let format: String // "PKBarcodeFormatQR", "PKBarcodeFormatPDF417", "PKBarcodeFormatAztec", "PKBarcodeFormatCode128"
    let message: String
    let messageEncoding: String // "iso-8859-1", "utf-8", etc.
    let altText: String?

    func toPassBarcode() -> Pass.Barcode {
        let barcodeFormat: Pass.Barcode.BarcodeFormat
        switch format {
        case "PKBarcodeFormatQR":
            barcodeFormat = .qr
        case "PKBarcodeFormatPDF417":
            barcodeFormat = .pdf
        case "PKBarcodeFormatAztec":
            barcodeFormat = .aztec
        case "PKBarcodeFormatCode128":
            barcodeFormat = .code128
        default:
            barcodeFormat = .qr
        }

        let encoding: Pass.Barcode.CharacterEncoding
        switch messageEncoding.lowercased() {
        case "iso-8859-1", "iso88591":
            encoding = .iso88591
        case "utf-8", "utf8":
            encoding = .utf8
        default:
            encoding = .iso88591
        }

        return Pass.Barcode(
            altText: altText,
            format: barcodeFormat,
            message: message,
            messageEncoding: encoding
        )
    }
}

struct PassField: Codable, Sendable {
    let key: String
    let label: String?
    let value: String
    let textAlignment: String? // "PKTextAlignmentLeft", "PKTextAlignmentCenter", "PKTextAlignmentRight", "PKTextAlignmentNatural"

    func toPassFieldContent() -> PassFieldContent {
        let alignment: PassFieldContent.TextAlignment?
        switch textAlignment {
        case "PKTextAlignmentLeft":
            alignment = .left
        case "PKTextAlignmentCenter":
            alignment = .center
        case "PKTextAlignmentRight":
            alignment = .right
        case "PKTextAlignmentNatural":
            alignment = .natural
        default:
            alignment = nil
        }

        return PassFieldContent(
            key: key,
            label: label,
            textAlignment: alignment,
            value: .string(value)
        )
    }
}

struct PassStructureInfo: Codable, Sendable {
    let headerFields: [PassField]?
    let primaryFields: [PassField]?
    let secondaryFields: [PassField]?
    let auxiliaryFields: [PassField]?
    let backFields: [PassField]?
    let transitType: String? // For boarding passes: "PKTransitTypeAir", "PKTransitTypeBoat", etc.
}

enum PassType: Sendable {
    case generic
    case storeCard
    case eventTicket
    case coupon
    case boardingPass
}

struct SpecificPassContent: Sendable {
    let type: PassType
    let info: PassStructureInfo

    func toPassFields() -> PassFields {
        let transitType: PassFields.TransitType?
        if let transitTypeString = info.transitType {
            switch transitTypeString {
            case "PKTransitTypeAir":
                transitType = .air
            case "PKTransitTypeBoat":
                transitType = .boat
            case "PKTransitTypeBus":
                transitType = .bus
            case "PKTransitTypeTrain":
                transitType = .train
            case "PKTransitTypeGeneric":
                transitType = .generic
            default:
                transitType = .generic
            }
        } else {
            transitType = nil
        }

        return PassFields(
            auxiliaryFields: info.auxiliaryFields?.map { $0.toPassFieldContent() },
            backFields: info.backFields?.map { $0.toPassFieldContent() },
            headerFields: info.headerFields?.map { $0.toPassFieldContent() },
            primaryFields: info.primaryFields?.map { $0.toPassFieldContent() },
            secondaryFields: info.secondaryFields?.map { $0.toPassFieldContent() },
            transitType: transitType
        )
    }
}

extension SpecificPassContent: Decodable {
    enum CodingKeys: String, CodingKey {
        case generic
        case storeCard
        case eventTicket
        case coupon
        case boardingPass
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Try each pass type
        if let info = try container.decodeIfPresent(PassStructureInfo.self, forKey: .generic) {
            self.type = .generic
            self.info = info
        } else if let info = try container.decodeIfPresent(PassStructureInfo.self, forKey: .storeCard) {
            self.type = .storeCard
            self.info = info
        } else if let info = try container.decodeIfPresent(PassStructureInfo.self, forKey: .eventTicket) {
            self.type = .eventTicket
            self.info = info
        } else if let info = try container.decodeIfPresent(PassStructureInfo.self, forKey: .coupon) {
            self.type = .coupon
            self.info = info
        } else if let info = try container.decodeIfPresent(PassStructureInfo.self, forKey: .boardingPass) {
            self.type = .boardingPass
            self.info = info
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Must specify exactly one pass type: generic, storeCard, eventTicket, coupon, or boardingPass"
                )
            )
        }
    }
}

struct CreatePassRequest: Decodable, Sendable {
    let formatVersion: Int
    let passTypeIdentifier: String
    let serialNumber: String
    let teamIdentifier: String
    let organizationName: String
    let description: String
    let logoText: String?
    let foregroundColor: PassColor?
    let backgroundColor: PassColor?
    let labelColor: PassColor?
    let barcodes: [BarcodeInfo]?
    let passContent: SpecificPassContent

    enum CodingKeys: String, CodingKey {
        case formatVersion
        case passTypeIdentifier
        case serialNumber
        case teamIdentifier
        case organizationName
        case description
        case logoText
        case foregroundColor
        case backgroundColor
        case labelColor
        case barcodes
        case generic
        case storeCard
        case eventTicket
        case coupon
        case boardingPass
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        formatVersion = try container.decode(Int.self, forKey: .formatVersion)
        passTypeIdentifier = try container.decode(String.self, forKey: .passTypeIdentifier)
        serialNumber = try container.decode(String.self, forKey: .serialNumber)
        teamIdentifier = try container.decode(String.self, forKey: .teamIdentifier)
        organizationName = try container.decode(String.self, forKey: .organizationName)
        description = try container.decode(String.self, forKey: .description)
        logoText = try container.decodeIfPresent(String.self, forKey: .logoText)
        foregroundColor = try container.decodeIfPresent(PassColor.self, forKey: .foregroundColor)
        backgroundColor = try container.decodeIfPresent(PassColor.self, forKey: .backgroundColor)
        labelColor = try container.decodeIfPresent(PassColor.self, forKey: .labelColor)
        barcodes = try container.decodeIfPresent([BarcodeInfo].self, forKey: .barcodes)
        passContent = try SpecificPassContent(from: decoder)
    }
}

struct CreatePassResponse: ResponseCodable, Sendable {
    let passData: Data

    func response(from request: Request, context: some RequestContext) throws -> Response {
        var response = Response(status: .ok)
        response.headers[.contentType] = "application/vnd.apple.pkpass"
        response.headers[.contentDisposition] = "attachment; filename=\"library.pkpass\""
        response.body = .init(byteBuffer: ByteBuffer(data: passData))
        return response
    }
}


@main
struct Main {
    static func main() async throws {
        let projectRoot = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let webDir = projectRoot.appending(path: "Web")
        let secretsPath = projectRoot.appending(path: "secrets.json")

        // Load secrets
        let secretsData = try Data(contentsOf: secretsPath)
        let secrets = try JSONDecoder().decode(Secrets.self, from: secretsData)

        // Decode PEM certificates from base64
        guard let pemWWDR = String(data: Data(base64Encoded: secrets.pemWWDRCertificate) ?? Data(), encoding: .utf8) else {
            fatalError("Invalid PEM WWDR certificate")
        }
        guard let pemCert = String(data: Data(base64Encoded: secrets.pemCertificate) ?? Data(), encoding: .utf8) else {
            fatalError("Invalid PEM certificate")
        }
        guard let pemKey = String(data: Data(base64Encoded: secrets.pemPrivateKey) ?? Data(), encoding: .utf8) else {
            fatalError("Invalid PEM private key")
        }

        // Assets directory
        let assetsDir = projectRoot.appending(path: "PassAssets")

        // Initialize PassSigner
        let passSigner = try PassSigner(
            pemWWDRCertificate: pemWWDR,
            pemCertificate: pemCert,
            pemPrivateKey: pemKey,
            assetsDirectoryURL: assetsDir
        )

        let router = Router()
            .addMiddleware {
                RequestLoggerMiddleware()
                FileMiddleware(webDir.path, searchForIndexHtml: true)
                CORSMiddleware(
                    allowOrigin: .originBased,
                    allowHeaders: [.accept, .authorization, .contentType, .origin],
                    allowMethods: [.get, .options, .post]
                )
            }

        let apiRoutes = router.group("api")

        apiRoutes.on("/preview", method: .options) { _, _ in
            Response(status: .ok)
        }

        apiRoutes.post("/generate") { req, ctx in
            let request = try await req.decode(as: CreatePassRequest.self, context: ctx)

            // Convert barcodes
            let barcodes = request.barcodes?.map { $0.toPassBarcode() } ?? []

            // Convert pass content
            let passFields = request.passContent.toPassFields()

            // Create pass based on type
            var pass = Pass(
                description: request.description,
                organizationName: request.organizationName,
                passTypeIdentifier: request.passTypeIdentifier,
                serialNumber: request.serialNumber,
                teamIdentifier: request.teamIdentifier,
                backgroundColor: request.backgroundColor,
                barcodes: barcodes,
                foregroundColor: request.foregroundColor,
                labelColor: request.labelColor,
                logoText: request.logoText
            )

            // Set the appropriate pass type field
            switch request.passContent.type {
            case .generic:
                pass.generic = passFields
            case .storeCard:
                pass.storeCard = passFields
            case .eventTicket:
                pass.eventTicket = passFields
            case .coupon:
                pass.coupon = passFields
            case .boardingPass:
                pass.boardingPass = passFields
            }

            // Generate and sign the pass using our custom PassSigner
            let passData = try await passSigner.sign(pass: pass)

            return CreatePassResponse(passData: passData)
        }

        let app = Application(
            router: router,
            configuration: .init(address: .hostname("127.0.0.1", port: 8084))
        )
        try await app.runService()
    }
}
