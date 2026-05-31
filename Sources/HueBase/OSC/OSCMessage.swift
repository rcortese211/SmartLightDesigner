import Foundation

struct OSCMessage {
    let address: String
    let arguments: [OSCArgument]
}

enum OSCArgument {
    case int(Int32)
    case float(Float)
    case string(String)
    case blob(Data)
    case bool(Bool)

    var intValue: Int? {
        switch self {
        case .int(let v): return Int(v)
        case .float(let v): return Int(v)
        default: return nil
        }
    }
    var floatValue: Float? {
        switch self {
        case .float(let v): return v
        case .int(let v): return Float(v)
        default: return nil
        }
    }
    var boolValue: Bool? {
        switch self {
        case .bool(let v): return v
        case .int(let v): return v != 0
        case .float(let v): return v != 0
        default: return nil
        }
    }
    var stringValue: String? {
        if case .string(let v) = self { return v }
        return nil
    }
}

extension OSCMessage {
    static func parse(_ data: Data) -> OSCMessage? {
        var offset = 0

        func readPaddedString() -> String? {
            guard offset < data.count else { return nil }
            var end = offset
            while end < data.count && data[end] != 0 { end += 1 }
            let str = String(bytes: data[offset..<end], encoding: .utf8)
            offset = ((end + 4) / 4) * 4   // pad to 4 bytes
            return str
        }

        func readInt32() -> Int32? {
            guard offset + 4 <= data.count else { return nil }
            let v = data[offset..<(offset+4)].withUnsafeBytes {
                $0.load(as: Int32.self).byteSwapped
            }
            offset += 4
            return v
        }

        func readFloat() -> Float? {
            guard offset + 4 <= data.count else { return nil }
            let bits = data[offset..<(offset+4)].withUnsafeBytes {
                $0.load(as: UInt32.self).byteSwapped
            }
            offset += 4
            return Float(bitPattern: bits)
        }

        func readBlob() -> Data? {
            guard let size = readInt32() else { return nil }
            let len = Int(size)
            guard offset + len <= data.count else { return nil }
            let blob = data[offset..<(offset+len)]
            offset = ((offset + len + 3) / 4) * 4
            return Data(blob)
        }

        guard let address = readPaddedString(), address.hasPrefix("/") else { return nil }
        guard let typeTag = readPaddedString(), typeTag.hasPrefix(",") else {
            return OSCMessage(address: address, arguments: [])
        }

        var arguments: [OSCArgument] = []
        for tag in typeTag.dropFirst() {
            switch tag {
            case "i": if let v = readInt32() { arguments.append(.int(v)) }
            case "f": if let v = readFloat()  { arguments.append(.float(v)) }
            case "s": if let v = readPaddedString() { arguments.append(.string(v)) }
            case "b": if let v = readBlob()   { arguments.append(.blob(v)) }
            case "T": arguments.append(.bool(true))
            case "F": arguments.append(.bool(false))
            default:  break
            }
        }
        return OSCMessage(address: address, arguments: arguments)
    }

    // Build a basic OSC message (int/float/string arguments)
    static func build(address: String, arguments: [OSCArgument] = []) -> Data {
        func pad(_ d: inout Data) {
            while d.count % 4 != 0 { d.append(0) }
        }

        var packet = Data()
        var str = Data(address.utf8); str.append(0); pad(&str)
        packet.append(str)

        var tags = Data(",".utf8)
        var argData = Data()
        for arg in arguments {
            switch arg {
            case .int(let v):
                tags.append(UInt8(ascii: "i"))
                withUnsafeBytes(of: v.bigEndian) { argData.append(contentsOf: $0) }
            case .float(let v):
                tags.append(UInt8(ascii: "f"))
                withUnsafeBytes(of: v.bitPattern.bigEndian) { argData.append(contentsOf: $0) }
            case .string(let v):
                tags.append(UInt8(ascii: "s"))
                var s = Data(v.utf8); s.append(0); pad(&s)
                argData.append(s)
            case .bool(let v):
                tags.append(UInt8(ascii: v ? "T" : "F"))
            case .blob(let d):
                tags.append(UInt8(ascii: "b"))
                var size = Int32(d.count)
                withUnsafeBytes(of: size.bigEndian) { argData.append(contentsOf: $0) }
                argData.append(d)
                pad(&argData)
            }
        }
        tags.append(0); pad(&tags)
        packet.append(tags)
        packet.append(argData)
        return packet
    }
}
