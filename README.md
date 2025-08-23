# ASNetworkKit

A lightweight, Alamofire-inspired networking package built on top of **URLSession**, written in Swift.
- Request building (`GET/POST/PUT/PATCH/DELETE/HEAD`)
- Query & JSON parameter encoding
- Request adapters & interceptors
- Automatic retry policy (exponential backoff)
- Validation by status code & content type
- Response serialization: `Data`, `String`, `JSON`, `Decodable`
- File upload (data, file URL, multipart/form-data)
- File download with resume support
- Async/Await **and** callback APIs
- Reachability-independent design

> **Copyright** © 2025 **Arindam Santra** — All rights reserved.

## Installation (Swift Package Manager)
In Xcode: **File → Add Packages...** and use the repository URL of this package.

## Quick Start

```swift
import ASNetworkKit

let session = Session.default

// Simple GET
let request = session.request(
    "https://httpbin.org/get",
    method: .get,
    parameters: ["page": 1, "q": "swift"],
    encoding: URLEncoding.default
).validate()

request.responseDecodable(of: HTTPBinGet.self) { result in
    switch result {
    case .success(let model):
        print(model)
    case .failure(let error):
        print(error)
    }
}
```

### Async/Await
```swift
struct User: Decodable { let id: Int; let name: String }

let session = Session.default
let user: User = try await session
    .request("https://jsonplaceholder.typicode.com/users/1")
    .serializingDecodable(User.self)
    .value
print(user.name)
```

### Upload (multipart)
```swift
let data = Data("hello".utf8)
let req = session.upload(
    multipart: MultipartFormData() { form in
        form.append("Arindam", name: "author")
        form.append(data, name: "file", fileName: "hello.txt", mimeType: "text/plain")
    },
    to: "https://httpbin.org/post"
)
req.validate().responseJSON { print($0) }
```

### Download
```swift
let destination = FileManager.default.temporaryDirectory.appendingPathComponent("file.bin")
let task = session.download("https://speed.hetzner.de/100MB.bin", to: destination)
let url = try await task.serializingDownloadedFile().value
print("Saved to:", url)
```

## LICENSE
See `LICENSE`. This package is © 2025 **Arindam Santra**.
