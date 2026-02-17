// Uploader.swift
import Foundation

enum UploadError: Error, LocalizedError {
    case invalidURL
    case badResponse(String)
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid upload URL."
        case .badResponse(let msg): return "Unexpected response: \(msg)"
        case .server(let msg): return "Server error: \(msg)"
        }
    }
}

final class Uploader {
    let config: ShareXServerConfig

    init(config: ShareXServerConfig) {
        self.config = config
    }

    func upload(
        fileURL: URL,
        onProgress: @escaping (Double) -> Void,
        onTaskCreated: @escaping (URLSessionUploadTask) -> Void
    ) async throws -> URL {
        let trimmed = config.RequestURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let endpoint = URL(string: trimmed) else { throw UploadError.invalidURL }

        let fileData = try Data(contentsOf: fileURL)
        let filename = fileURL.lastPathComponent
        let mime = mimeType(for: fileURL)

        var request = URLRequest(url: endpoint)
        request.httpMethod = config.method
        for (key, value) in config.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let body = makeMultipartBody(
            boundary: boundary,
            fields: config.nonNullArguments,
            fileFieldName: config.fileFormName,
            filename: filename,
            mimeType: mime,
            fileData: fileData
        )

        let session = URLSession(configuration: .default)

        return try await withCheckedThrowingContinuation { cont in
            // Keep the observation alive until completion.
            var observation: NSKeyValueObservation?

            let task = session.uploadTask(with: request, from: body) { [weak self] data, response, error in
                guard let self else {
                    cont.resume(throwing: URLError(.cancelled))
                    return
                }

                observation?.invalidate()
                observation = nil

                if let error = error {
                    cont.resume(throwing: error)
                    return
                }
                guard let data = data, let response = response else {
                    cont.resume(throwing: UploadError.badResponse("No data/response"))
                    return
                }

                guard let http = response as? HTTPURLResponse else {
                    cont.resume(throwing: UploadError.badResponse("No HTTPURLResponse"))
                    return
                }

                guard (200..<300).contains(http.statusCode) else {
                    let msg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
                    cont.resume(throwing: UploadError.server(msg))
                    return
                }

                if let text = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                   let u = URL(string: text),
                   u.scheme != nil {
                    cont.resume(returning: u)
                    return
                }
                
                if let template = self.config.URL,
                   let u = try? self.extractURLUsingShareXPath(template, data: data) {
                    cont.resume(returning: u)
                    return
                }

                do {
                    if let u = try self.extractURLFromJSON(
                        data: data,
                        candidates: [["url"], ["link"], ["result"], ["data", "url"]]
                    ) {
                        cont.resume(returning: u)
                        return
                    }
                } catch {}

                let preview = String(data: data, encoding: .utf8) ?? "\(data.count) bytes"
                cont.resume(throwing: UploadError.badResponse(preview))
            }

            onTaskCreated(task)

            observation = task.progress.observe(\.fractionCompleted, options: [.new]) { prog, _ in
                onProgress(prog.fractionCompleted)
            }

            task.resume()
        }
    }

    private func extractURLFromJSON(data: Data, candidates: [[String]]) throws -> URL? {
        let obj = try JSONSerialization.jsonObject(with: data, options: [])
        for path in candidates {
            if let s = getJSONValue(obj, keyPath: path) as? String,
               let u = URL(string: s),
               u.scheme != nil {
                return u
            }
        }
        return nil
    }

    private func getJSONValue(_ root: Any, keyPath: [String]) -> Any? {
        var current: Any? = root
        for key in keyPath {
            guard let dict = current as? [String: Any] else { return nil }
            current = dict[key]
        }
        return current
    }

    // MARK: - Multipart

    private func makeMultipartBody(
        boundary: String,
        fields: [String: String],
        fileFieldName: String,
        filename: String,
        mimeType: String,
        fileData: Data
    ) -> Data {
        var data = Data()
        let crlf = "\r\n"

        func append(_ string: String) {
            data.append(string.data(using: .utf8)!)
        }

        for (k, v) in fields {
            append("--\(boundary)\(crlf)")
            append("Content-Disposition: form-data; name=\"\(k)\"\(crlf)\(crlf)")
            append("\(v)\(crlf)")
        }

        append("--\(boundary)\(crlf)")
        append("Content-Disposition: form-data; name=\"\(fileFieldName)\"; filename=\"\(filename)\"\(crlf)")
        append("Content-Type: \(mimeType)\(crlf)\(crlf)")
        data.append(fileData)
        append(crlf)

        append("--\(boundary)--\(crlf)")
        return data
    }

    private func mimeType(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "mp4": return "video/mp4"
        case "mov": return "video/quicktime"
        case "pdf": return "application/pdf"
        default: return "application/octet-stream"
        }
    }
    
    private func extractURLUsingShareXPath(_ template: String, data: Data) throws -> URL? {
        guard template.hasPrefix("{json:"), template.hasSuffix("}") else { return nil }

        let pathString = template
            .replacingOccurrences(of: "{json:", with: "")
            .replacingOccurrences(of: "}", with: "")

        let obj = try JSONSerialization.jsonObject(with: data)
        let components = pathString
            .replacingOccurrences(of: "[", with: ".")
            .replacingOccurrences(of: "]", with: "")
            .split(separator: ".")
            .map(String.init)

        var current: Any = obj

        for key in components {
            if let index = Int(key), let arr = current as? [Any], index < arr.count {
                current = arr[index]
            } else if let dict = current as? [String: Any], let val = dict[key] {
                current = val
            } else {
                return nil
            }
        }

        if let s = current as? String {
            return URL(string: s)
        }

        return nil
    }
}
