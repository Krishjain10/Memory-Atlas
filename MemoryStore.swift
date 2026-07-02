import SwiftUI
import CoreLocation

// MARK: - Element Models

struct TextElement: Identifiable, Codable, Equatable {
    var id = UUID()
    var text: String = "Write something..."
    var x: Double
    var y: Double
    var width: Double = 200
    var height: Double = 100
    var fontSize: Double = 18
    var colorHex: String = "333333"
    var fontName: String = "Bradley Hand"
    var rotation: Double = 0
    var zIndex: Int = 0
    var isLocked: Bool = false
}

struct ImageElement: Identifiable, Codable, Equatable {
    var id = UUID()
    var fileName: String
    var x: Double
    var y: Double
    var width: Double = 200
    var height: Double = 160
    var rotation: Double = 0
    var zIndex: Int = 0
    var isLocked: Bool = false
}

struct StickyNote: Identifiable, Codable, Equatable {
    var id = UUID()
    var text: String = ""
    var x: Double
    var y: Double
    var width: Double = 150
    var height: Double = 140
    var rotation: Double = 0
    var colorHex: String = "FFED8E"
    var zIndex: Int = 0
    var isLocked: Bool = false
}

enum ShapeType: String, Codable, CaseIterable {
    case rectangle, roundedRect, circle, star, triangle, line, arrow, diamond, hexagon, pentagon, heart
    
    var icon: String {
        switch self {
        case .rectangle: return "rectangle"
        case .roundedRect: return "rectangle.roundedtop"
        case .circle: return "circle"
        case .star: return "star"
        case .triangle: return "triangle"
        case .line: return "line.diagonal"
        case .arrow: return "arrow.right"
        case .diamond: return "diamond"
        case .hexagon: return "hexagon"
        case .pentagon: return "pentagon"
        case .heart: return "heart"
        }
    }
}

struct ShapeElement: Identifiable, Codable, Equatable {
    var id = UUID()
    var shapeType: ShapeType
    var x: Double
    var y: Double
    var width: Double = 120
    var height: Double = 100
    var rotation: Double = 0
    var fillColorHex: String = "5DADE2"
    var strokeColorHex: String = "333333"
    var strokeWidth: Double = 2
    var isFilled: Bool = true
    var zIndex: Int = 0
    var isLocked: Bool = false
}

struct StickerElement: Identifiable, Codable, Equatable {
    var id = UUID()
    var emoji: String
    var x: Double
    var y: Double
    var width: Double = 60
    var height: Double = 60
    var rotation: Double = 0
    var zIndex: Int = 0
    var isLocked: Bool = false
}

enum WashiTapePattern: String, Codable, CaseIterable {
    case striped, dotted, checkered, solid
}

struct WashiTapeElement: Identifiable, Codable, Equatable {
    var id = UUID()
    var x: Double
    var y: Double
    var width: Double = 180
    var height: Double = 24
    var rotation: Double = 0
    var colorHex: String = "E74C3C"
    var patternType: WashiTapePattern = .striped
    var zIndex: Int = 0
    var isLocked: Bool = false
}

enum StampStyle: String, Codable, CaseIterable {
    case passportCircle, passportRect, concertTicket, movieTicket, trainTicket, boardingPass, postcard, receipt, luggageTag, hotelKey
    
    var displayName: String {
        switch self {
        case .passportCircle: return "Passport Stamp"
        case .passportRect: return "Entry Stamp"
        case .concertTicket: return "Concert Ticket"
        case .movieTicket: return "Movie Ticket"
        case .trainTicket: return "Train Ticket"
        case .boardingPass: return "Boarding Pass"
        case .postcard: return "Postcard"
        case .receipt: return "Receipt"
        case .luggageTag: return "Luggage Tag"
        case .hotelKey: return "Hotel Key"
        }
    }
    
    var icon: String {
        switch self {
        case .passportCircle: return "seal"
        case .passportRect: return "rectangle"
        case .concertTicket: return "music.note"
        case .movieTicket: return "film"
        case .trainTicket: return "tram"
        case .boardingPass: return "airplane"
        case .postcard: return "envelope"
        case .receipt: return "doc.text"
        case .luggageTag: return "tag"
        case .hotelKey: return "key"
        }
    }
}

struct StampElement: Identifiable, Codable, Equatable {
    var id = UUID()
    var stampStyle: StampStyle = .passportCircle
    var text: String = "TOKYO"
    var subText: String = "2024"
    var x: Double
    var y: Double
    var width: Double = 140
    var height: Double = 140
    var rotation: Double = 0
    var colorHex: String = "C0392B"
    var zIndex: Int = 0
    var isLocked: Bool = false
}

// MARK: - Memory Model

struct Memory: Identifiable, Codable, Equatable {
    var id = UUID()
    var latitude: Double
    var longitude: Double
    var placeName: String
    var createdDate: Date
    var lastEditedDate: Date = Date()
    var textElements: [TextElement] = []
    var imageElements: [ImageElement] = []
    var stickyNotes: [StickyNote] = []
    var shapeElements: [ShapeElement] = []
    var stickerElements: [StickerElement] = []
    var washiTapeElements: [WashiTapeElement] = []
    var stampElements: [StampElement] = []
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Memory Store

class MemoryStore: ObservableObject {
    @Published var memories: [Memory] = []
    
    private let memoriesKey = "saved_memories"
    private let fileManager = FileManager.default
    
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private var memoriesFileURL: URL {
        documentsDirectory.appendingPathComponent("memories.json")
    }
    
    init() {
        loadMemories()
    }
    
    // MARK: - Memory CRUD
    
    func addMemory(_ memory: Memory) {
        memories.append(memory)
        saveMemories()
    }
    
    func updateMemory(_ memory: Memory) {
        if let index = memories.firstIndex(where: { $0.id == memory.id }) {
            var updated = memory
            updated.lastEditedDate = Date()
            memories[index] = updated
            saveMemories()
        }
    }
    
    func deleteMemory(_ memory: Memory) {
        for imageElement in memory.imageElements {
            deleteImage(named: imageElement.fileName)
        }
        let drawingURL = documentsDirectory.appendingPathComponent("drawing_\(memory.id.uuidString).data")
        try? fileManager.removeItem(at: drawingURL)
        
        memories.removeAll { $0.id == memory.id }
        saveMemories()
    }
    
    // MARK: - Drawing Data
    
    func saveDrawingData(_ data: Data, for memoryId: UUID) {
        let url = documentsDirectory.appendingPathComponent("drawing_\(memoryId.uuidString).data")
        try? data.write(to: url)
    }
    
    func loadDrawingData(for memoryId: UUID) -> Data? {
        let url = documentsDirectory.appendingPathComponent("drawing_\(memoryId.uuidString).data")
        return try? Data(contentsOf: url)
    }
    
    // MARK: - Image Management
    
    func saveImage(_ data: Data, for memoryId: UUID) -> String? {
        let fileName = "\(memoryId.uuidString)_\(UUID().uuidString).jpg"
        let url = documentsDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: url)
            return fileName
        } catch {
            return nil
        }
    }
    
    func loadImage(named fileName: String) -> UIImage? {
        let url = documentsDirectory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
    
    func deleteImage(named fileName: String) {
        let url = documentsDirectory.appendingPathComponent(fileName)
        try? fileManager.removeItem(at: url)
    }
    
    // MARK: - Persistence
    
    private func saveMemories() {
        do {
            let data = try JSONEncoder().encode(memories)
            try data.write(to: memoriesFileURL)
        } catch {
            print("Failed to save memories: \(error)")
        }
    }
    
    private func loadMemories() {
        guard let data = try? Data(contentsOf: memoriesFileURL),
              let decoded = try? JSONDecoder().decode([Memory].self, from: data) else { return }
        memories = decoded
    }
}

// MARK: - Color Extensions

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
    
    func toHex() -> String {
        let uic = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uic.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
