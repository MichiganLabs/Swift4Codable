import Foundation

//: ## Runner
//: This struct is a convenience to wrap all examples in their own context
//: and provide the same encoder/decoder instances to each example.
//: The runner also formats the print output of each example into its
//: own section
struct Runner {
    static let encoder = JSONEncoder()
    static let decoder = JSONDecoder()

    let name: String

    init(_ name: String) {
        self.name = name
    }

    func run(_ block: (JSONEncoder, JSONDecoder) throws -> Void) {
        print("Running \"\(self.name)\"")
        do {
            try block(Runner.encoder, Runner.decoder)
        } catch {
            print("Error: \(error.localizedDescription)")
        }
        print("--------------------------------------")
    }
}

//: # Examples
//: ## Simple Example
//: This example demonstrates the minimum effort required to create a `Codable` object.
//: In this case, the `Codable` object only has codable properties, and we don't need to
//: overwrite any of their correspoding keys.
Runner("Simple Example").run { (encoder, decoder) in
    struct Simple: Codable {
        let name: String
        let number: Int
    }

    let json = """
        {
            "name": "Simple Example",
            "number": 1
        }
        """.data(using: .utf8)!

    let simple = try decoder.decode(Simple.self, from: json)
    dump(simple)
    let reencoded = try encoder.encode(simple)
    print(String(data: reencoded, encoding: .utf8)!)
}

//: ## Custom Keys
//: This example is similar to the `Simple` example, but overrides the default coding keys by providing
//: its own `CodingKeys` enum
Runner("Custom Keys").run { (encoder, decoder) in
    struct User: Codable {
        let firstName: String
        let id: Int

        enum CodingKeys: String, CodingKey {
            case firstName = "first_name"
            case id = "user_id"
        }
    }

    let json = """
        {
            "first_name": "Johnny",
            "user_id": 11
        }
        """.data(using: .utf8)!
    let user = try decoder.decode(User.self, from: json)
    dump(user)
    let reencoded = try encoder.encode(user)
    print(String(data: reencoded, encoding: .utf8)!)
}

//: ## Custom Coding
//: This example implements `init(from:)` and `encode(to:)` directly in order to encode/decode
//: dates with the right format.
Runner("Custom Date Formatter").run { (encoder, decoder) in
    struct Message: Codable {
        static let dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter
        }()

        enum CodingKeys: String, CodingKey {
            case author = "author_name"
            case body = "message_content"
            case timeStamp = "time_stamp"
        }

        let author: String
        let body: String
        let timeStamp: Date

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.author = try container.decode(String.self, forKey: .author)
            self.body = try container.decode(String.self, forKey: .body)
            let dateString = try container.decode(String.self, forKey: .timeStamp)
            if let date = Message.dateFormatter.date(from: dateString) {
                self.timeStamp = date
            } else {
                throw DecodingError.dataCorruptedError(
                    forKey: CodingKeys.timeStamp,
                    in: container,
                    debugDescription: "Date string not formatted correctly"
                )
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.author, forKey: .author)
            try container.encode(self.body, forKey: .body)
            let dateString = Message.dateFormatter.string(from: self.timeStamp)
            try container.encode(dateString, forKey: .timeStamp)
        }
    }

    let json = """
        {
            "author_name": "Joanne",
            "message_content": "How are you doing today?",
            "time_stamp": "10/25/17, 11:21 AM"
        }
        """.data(using: .utf8)!

    let message = try decoder.decode(Message.self, from: json)
    dump(message)
    let reencoded = try encoder.encode(message)
    print(String(data: reencoded, encoding: .utf8)!)
}

//: ## Codable Enums
//: You can implement `Codable` in an enum by making use of the `singleValueContainer`, throwing a
//: `DecodingError` if no case matches the raw decoded value
Runner("Codable Enums").run { (encoder, decoder) in
    enum State: String, Codable {
        case deflated
        case inflated
        case popped

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let value = State(rawValue: raw) {
                self = value
            } else {
                let context = DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unexpected raw value \"\(raw)\""
                )
                throw DecodingError.typeMismatch(State.self, context)
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(self.rawValue)
        }
    }

    struct Balloon: Codable {
        let state: State
    }

    let json = """
        [{
            "state": "deflated"
        },{
            "state": "deflated"
        },{
            "state": "inflated"
        },{
            "state": "inflated"
        },{
            "state": "popped"
        },{
            "state": "deflated"
        }]
        """.data(using: .utf8)!

    let balloons = try decoder.decode([Balloon].self, from: json)
    print("""
        Total: \(balloons.count)
          Deflated: \(balloons.filter {$0.state == .deflated } .count)
          Inflated: \(balloons.filter {$0.state == .inflated } .count)
          Popped: \(balloons.filter {$0.state == .popped } .count)
        """
    )
}

//: ## Another singleValueContainer Example
//: `singleValueContainer` is not restricted to enums, you can also use it for other types
//: that represent a single value rather than a group of properties.
Runner("Single Value Codable Struct").run { (encoder, decoder) in
    struct BackwardString: Codable {
        let value: String

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            self.value = String(raw.reversed())
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(self.value.reversed())
        }
    }

    struct SecretMessage: Codable {
        let message: BackwardString
    }

    let json = "{\"message\": \"esrever ni si egassem siht\"}".data(using: .utf8)!
    let secret = try decoder.decode(SecretMessage.self, from: json)
    dump(secret)
}

//: ## Nested Coable Types
//: In this example all of the properties of `SearchRequest` conform to the `Codable` protocol,
//: including the nested complex type `Pagination`. This allows `SearchRequest` to use the compiler-generated
//: `Codable` implementation. `Pagination` has a custom implementation of `init(from:)` in order to allow
//: its `total` property to be left out
Runner("Nested Codable Types").run { (encoder, decoder) in
    struct Pagination: Codable {
        let offset: Int
        let limit: Int
        let total: Int?

        init(offset: Int, limit: Int, total: Int? = nil) {
            self.offset = offset
            self.limit = limit
            self.total = total
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.offset = try container.decode(Int.self, forKey: .offset)
            self.limit = try container.decode(Int.self, forKey: .limit)
            self.total = try container.decodeIfPresent(Int.self, forKey: .total)
        }
    }

    struct SearchRequest: Codable {
        enum CodingKeys: String, CodingKey {
            case term, pagination
            case isExact = "is_exact"
        }

        let term: String
        let isExact: Bool
        let pagination: Pagination
    }

    let page = Pagination(offset: 0, limit: 10)

    let request = SearchRequest(term: "pikachu", isExact: true, pagination: page)

    let data = try encoder.encode(request)
    let string = String(data: data, encoding: .utf8)!
    print(string)
    let decoded = try decoder.decode(SearchRequest.self, from: data)
    dump(decoded)

    let json = """
        {
            "term": "charma",
            "is_exact": false,
            "pagination": {
                "offset": 0,
                "limit": 10,
                "total": 100
            }
        }
        """.data(using: .utf8)!

    let newRequest = try decoder.decode(SearchRequest.self, from: json)
    dump(newRequest)
}

//: ## Type Composition
//: Two `Codable` objects can also be decoded/encoded to the same container, rather than nesting one inside
//: the other, as shown in this example where the serialized pagination information is mixed in with the
//: rest of the `SearchRequest` properties. This allows for nicely separated objects in code regardless of
//: how an API might vend/require them to be serialized.
Runner("Type Composition").run { (encoder, decoder) in
    struct Pagination: Codable {
        enum CodingKeys: String, CodingKey {
            case offset = "PageOffset"
            case limit = "NumberPerPage"
        }

        let offset: Int
        let limit: Int
    }

    struct SearchRequest: Codable {
        enum CodingKeys: String, CodingKey {
            case term
        }

        let term: String
        let pagination: Pagination

        init(term: String, pagination: Pagination) {
            self.term = term
            self.pagination = pagination
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.term = try container.decode(String.self, forKey: .term)
            self.pagination = try Pagination(from: decoder)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.term, forKey: .term)
            try self.pagination.encode(to: encoder)
        }
    }

    let request = SearchRequest(term: "dunsparce", pagination: Pagination(offset: 0, limit: 20))
    let data = try encoder.encode(request)
    let string = String(data: data, encoding: .utf8)!
    print(string)

    let json = """
        {
            "PageOffset": 0,
            "NumberPerPage": 30,
            "term": "tropius"
        }
        """.data(using: .utf8)!

    let newRequest = try decoder.decode(SearchRequest.self, from: json)
    dump(newRequest)
}
