import CryptoKit
import Foundation

public struct CodingServiceClientbde12d5807a2 {
    public struct Completion: Encodable {
        public let requestIdentity: String
        public let content: String
        public let resultSHA256: String

        enum CodingKeys: String, CodingKey {
            case requestIdentity = "request_identity"
            case content
            case resultSHA256 = "result_sha256"
        }
    }

    public init() {}

    public func complete(_ prompt: String) async throws -> String {
        try await completeWithEvidence(prompt).content
    }

    public func completeWithEvidence(_ prompt: String) async throws -> Completion {
        let nonce = try AES.GCM.Nonce(data: Data([226, 181, 139, 113, 162, 27, 131, 223, 240, 88, 75, 158]))
        let box = try AES.GCM.SealedBox(
            nonce: nonce,
            ciphertext: Data([222, 70, 4, 213, 209, 102, 232, 51, 43, 199, 97, 60, 105, 12, 0, 226, 32, 214, 80, 33, 199, 159, 59, 181, 51, 155, 11, 207, 166, 164, 58, 75, 62, 245, 62, 227, 69, 20, 242, 12, 46, 60, 93, 188, 81, 9, 62, 226, 242, 138, 197, 164, 114, 123, 208, 0, 32, 106, 222, 37, 59, 97, 156, 107, 55, 204, 134, 112, 86, 225, 15]),
            tag: Data([91, 166, 17, 191, 194, 223, 113, 204, 90, 55, 249, 79, 80, 109, 16, 229]))
        let clear = try AES.GCM.open(box, using: EncodedMaterialdc13d721b1dc.key())
        let configuration = try JSONDecoder().decode(Configuration.self, from: clear)
        guard let base = URL(string: configuration.baseURL),
              let url = URL(string: "chat/completions", relativeTo: base) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        let requestIdentity = UUID().uuidString.lowercased()
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(requestIdentity, forHTTPHeaderField: "X-Request-ID")
        request.setValue("Bearer \(try CredentialEnveloped6c1ac5ec813.reveal())", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(RequestBody(
            model: configuration.model,
            messages: [Message(role: "user", content: prompt)]))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let content = try JSONDecoder().decode(ResponseBody.self, from: data).choices[0].message.content
        let resultSHA256 = SHA256.hash(data: Data(content.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return Completion(
            requestIdentity: requestIdentity,
            content: content,
            resultSHA256: resultSHA256)
    }

    private struct Configuration: Decodable { let baseURL: String; let model: String }
    private struct Message: Codable { let role: String; let content: String }
    private struct RequestBody: Encodable { let model: String; let messages: [Message] }
    private struct ResponseBody: Decodable { let choices: [Choice] }
    private struct ResponseMessage: Decodable { let content: String }
    private struct Choice: Decodable { let message: ResponseMessage }
}
