import CoreGraphics

public enum Quadrant: String, Sendable {
    case topLeft = "top-left"
    case topRight = "top-right"
    case bottomLeft = "bottom-left"
    case bottomRight = "bottom-right"
}

public enum RegionSpec: Equatable, Sendable {
    case quadrant(Quadrant)
    case rect(x: Int, y: Int, width: Int, height: Int)
}

public enum RegionParseError: Error, Equatable {
    case empty
    case invalid
}

public func parseRegionSpec(_ raw: String) throws -> RegionSpec {
    let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if text.isEmpty { throw RegionParseError.empty }
    if let quadrant = Quadrant(rawValue: text) {
        return .quadrant(quadrant)
    }
    let parts = text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    guard parts.count == 4, let x = Int(parts[0]), let y = Int(parts[1]),
          let w = Int(parts[2]), let h = Int(parts[3]), w > 0, h > 0
    else {
        throw RegionParseError.invalid
    }
    return .rect(x: x, y: y, width: w, height: h)
}

public func cropRect(imageSize: CGSize, spec: RegionSpec) -> CGRect? {
    let width = imageSize.width
    let height = imageSize.height
    guard width > 0, height > 0 else { return nil }
    switch spec {
    case .quadrant(let quadrant):
        let halfW = floor(width / 2)
        let halfH = floor(height / 2)
        switch quadrant {
        case .topLeft:
            return CGRect(x: 0, y: 0, width: halfW, height: halfH)
        case .topRight:
            return CGRect(x: width - halfW, y: 0, width: halfW, height: halfH)
        case .bottomLeft:
            return CGRect(x: 0, y: height - halfH, width: halfW, height: halfH)
        case .bottomRight:
            return CGRect(x: width - halfW, y: height - halfH, width: halfW, height: halfH)
        }
    case .rect(let x, let y, let w, let h):
        let rect = CGRect(x: x, y: y, width: w, height: h)
            .intersection(CGRect(x: 0, y: 0, width: width, height: height))
        if rect.isNull || rect.width < 1 || rect.height < 1 { return nil }
        return rect
    }
}
