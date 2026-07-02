import SwiftUI

// MARK: - Template Elements Container

struct TemplateElements {
    var textElements: [TextElement] = []
    var imageElements: [ImageElement] = []
    var stickyNotes: [StickyNote] = []
    var shapeElements: [ShapeElement] = []
    var stickerElements: [StickerElement] = []
    var washiTapeElements: [WashiTapeElement] = []
}

// MARK: - Template Definitions

enum MemoryTemplate: String, CaseIterable, Identifiable {
    case blank
    case travelJournal
    case photoCollage
    case diaryEntry
    
    var id: String { rawValue }
    
    var name: String {
        switch self {
        case .blank: return "Blank Page"
        case .travelJournal: return "Travel Journal"
        case .photoCollage: return "Photo Collage"
        case .diaryEntry: return "Dear Diary"
        }
    }
    
    var description: String {
        switch self {
        case .blank: return "Start with a clean canvas"
        case .travelJournal: return "Photos, notes & travel vibes"
        case .photoCollage: return "Showcase your best moments"
        case .diaryEntry: return "Write your heart out"
        }
    }
    
    func generateElements() -> TemplateElements {
        switch self {
        case .blank: return TemplateElements()
        case .travelJournal: return Self.makeTravelJournal()
        case .photoCollage: return Self.makePhotoCollage()
        case .diaryEntry: return Self.makeDiaryEntry()
        }
    }
}

// MARK: - Template Element Generators

extension MemoryTemplate {
    
    static func makeTravelJournal() -> TemplateElements {
        var t = TemplateElements()
        
        // Washi tape across the top
        t.washiTapeElements.append(WashiTapeElement(
            x: 200, y: 90, width: 200, height: 24, rotation: -2,
            colorHex: "E74C3C", patternType: .striped, zIndex: 1
        ))
        
        // Title
        t.textElements.append(TextElement(
            text: "My Adventure", x: 200, y: 140, width: 280, height: 50,
            fontSize: 28, colorHex: "2C3E50", fontName: "Noteworthy-Bold", zIndex: 2
        ))
        
        // Body text
        t.textElements.append(TextElement(
            text: "Write about your journey...", x: 140, y: 280, width: 200, height: 150,
            fontSize: 16, colorHex: "555555", fontName: "Bradley Hand", zIndex: 3
        ))
        
        // Sticky note
        t.stickyNotes.append(StickyNote(
            text: "To-do:\n• \n• \n• ", x: 310, y: 240, width: 150, height: 140,
            rotation: 3, colorHex: "CCFF90", zIndex: 4
        ))
        
        // Travel stickers
        t.stickerElements.append(StickerElement(
            emoji: "✈️", x: 65, y: 105, width: 50, height: 50, rotation: -15, zIndex: 5
        ))
        t.stickerElements.append(StickerElement(
            emoji: "📌", x: 340, y: 165, width: 40, height: 40, rotation: 10, zIndex: 6
        ))
        t.stickerElements.append(StickerElement(
            emoji: "🗺️", x: 80, y: 470, width: 55, height: 55, rotation: -8, zIndex: 7
        ))
        
        // Bottom washi tape
        t.washiTapeElements.append(WashiTapeElement(
            x: 280, y: 420, width: 140, height: 22, rotation: 12,
            colorHex: "5DADE2", patternType: .dotted, zIndex: 8
        ))
        
        // Bottom text
        t.textElements.append(TextElement(
            text: "Favorite moment...", x: 160, y: 490, width: 220, height: 60,
            fontSize: 15, colorHex: "7B5B3A", fontName: "Bradley Hand", zIndex: 9
        ))
        
        return t
    }
    
    static func makePhotoCollage() -> TemplateElements {
        var t = TemplateElements()
        
        // Title
        t.textElements.append(TextElement(
            text: "Memories", x: 200, y: 115, width: 250, height: 50,
            fontSize: 30, colorHex: "2C3E50", fontName: "Noteworthy-Bold", zIndex: 1
        ))
        
        // Photo frame placeholders (using shapes)
        t.shapeElements.append(ShapeElement(
            shapeType: .roundedRect, x: 140, y: 250, width: 160, height: 130, rotation: -4,
            fillColorHex: "EEEEEE", strokeColorHex: "CCCCCC", strokeWidth: 2, isFilled: true, zIndex: 2
        ))
        t.shapeElements.append(ShapeElement(
            shapeType: .roundedRect, x: 290, y: 265, width: 140, height: 120, rotation: 5,
            fillColorHex: "E8E8E8", strokeColorHex: "CCCCCC", strokeWidth: 2, isFilled: true, zIndex: 3
        ))
        t.shapeElements.append(ShapeElement(
            shapeType: .roundedRect, x: 190, y: 420, width: 170, height: 140, rotation: 2,
            fillColorHex: "F0F0F0", strokeColorHex: "CCCCCC", strokeWidth: 2, isFilled: true, zIndex: 4
        ))
        
        // Washi tape accents
        t.washiTapeElements.append(WashiTapeElement(
            x: 130, y: 185, width: 100, height: 20, rotation: -8,
            colorHex: "FFB5C2", patternType: .striped, zIndex: 5
        ))
        t.washiTapeElements.append(WashiTapeElement(
            x: 310, y: 345, width: 110, height: 20, rotation: 15,
            colorHex: "AF7AC5", patternType: .dotted, zIndex: 6
        ))
        
        // Captions
        t.textElements.append(TextElement(
            text: "Caption...", x: 140, y: 330, width: 120, height: 30,
            fontSize: 12, colorHex: "888888", fontName: "Bradley Hand", zIndex: 7
        ))
        t.textElements.append(TextElement(
            text: "Caption...", x: 290, y: 340, width: 120, height: 30,
            fontSize: 12, colorHex: "888888", fontName: "Bradley Hand", zIndex: 8
        ))
        
        // Stickers
        t.stickerElements.append(StickerElement(
            emoji: "⭐", x: 345, y: 115, width: 45, height: 45, rotation: 12, zIndex: 9
        ))
        t.stickerElements.append(StickerElement(
            emoji: "📸", x: 65, y: 475, width: 50, height: 50, rotation: -10, zIndex: 10
        ))
        
        return t
    }
    
    static func makeDiaryEntry() -> TemplateElements {
        var t = TemplateElements()
        
        // Header
        t.textElements.append(TextElement(
            text: "Dear Diary,", x: 160, y: 115, width: 250, height: 50,
            fontSize: 26, colorHex: "4A3728", fontName: "Bradley Hand", zIndex: 1
        ))
        
        // Decorative line
        t.shapeElements.append(ShapeElement(
            shapeType: .line, x: 200, y: 150, width: 280, height: 3,
            fillColorHex: "C0A882", strokeColorHex: "C0A882", strokeWidth: 1.5, isFilled: true, zIndex: 2
        ))
        
        // Main text area
        t.textElements.append(TextElement(
            text: "Today was special because...", x: 190, y: 300, width: 300, height: 200,
            fontSize: 17, colorHex: "555555", fontName: "Bradley Hand", zIndex: 3
        ))
        
        // Side sticky note
        t.stickyNotes.append(StickyNote(
            text: "Remember:\n", x: 310, y: 460, width: 130, height: 110,
            rotation: 5, colorHex: "FFD4A3", zIndex: 4
        ))
        
        // Stickers
        t.stickerElements.append(StickerElement(
            emoji: "📝", x: 345, y: 95, width: 40, height: 40, rotation: 8, zIndex: 5
        ))
        t.stickerElements.append(StickerElement(
            emoji: "💭", x: 65, y: 500, width: 50, height: 50, rotation: -5, zIndex: 6
        ))
        
        // Washi tape decoration
        t.washiTapeElements.append(WashiTapeElement(
            x: 100, y: 520, width: 130, height: 22, rotation: -10,
            colorHex: "F4D03F", patternType: .checkered, zIndex: 7
        ))
        
        return t
    }
}

// MARK: - Template Chooser View

struct TemplateChooserView: View {
    let onCancel: () -> Void
    let onSelect: (MemoryTemplate, String) -> Void
    
    @State private var selectedTemplate: MemoryTemplate = .blank
    @State private var memoryName: String = ""
    @FocusState private var isNameFieldFocused: Bool
    
    private let warmAccent = Color(red: 0.56, green: 0.52, blue: 0.96)
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Memory name input
                VStack(alignment: .leading, spacing: 6) {
                    Text("Name your memory")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    TextField("e.g. Summer in Tokyo", text: $memoryName)
                        .font(.body)
                        .padding(12)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                        .focused($isNameFieldFocused)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)
                
                // Template cards grid
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                        ForEach(MemoryTemplate.allCases) { template in
                            TemplateCard(template: template, isSelected: selectedTemplate == template)
                                .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { selectedTemplate = template } }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 20)
                }
                
                // Create button
                Button {
                    let name = memoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSelect(selectedTemplate, name.isEmpty ? "Untitled Memory" : name)
                } label: {
                    Text("Create")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(warmAccent, in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
            }
        }
        .presentationDetents([.large])
        .onAppear { isNameFieldFocused = true }
    }
}

// MARK: - Template Card

struct TemplateCard: View {
    let template: MemoryTemplate
    let isSelected: Bool
    
    private let warmAccent = Color(red: 0.56, green: 0.52, blue: 0.96)
    
    var body: some View {
        VStack(spacing: 8) {
            // Preview thumbnail
            templatePreview
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? warmAccent : Color.gray.opacity(0.3), lineWidth: isSelected ? 3 : 1)
                )
                .shadow(color: isSelected ? warmAccent.opacity(0.2) : .clear, radius: 6, y: 2)
            
            VStack(spacing: 2) {
                Text(template.name)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? warmAccent : .primary)
                Text(template.description)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
    
    // MARK: - Preview Thumbnails
    
    @ViewBuilder
    private var templatePreview: some View {
        ZStack {
            // Paper background
            Color(red: 0.98, green: 0.96, blue: 0.92)
            
            switch template {
            case .blank:
                blankPreview
            case .travelJournal:
                travelJournalPreview
            case .photoCollage:
                photoCollagePreview
            case .diaryEntry:
                diaryEntryPreview
            }
        }
    }
    
    private var blankPreview: some View {
        VStack(spacing: 10) {
            ForEach(0..<9, id: \.self) { _ in
                Rectangle().fill(Color.gray.opacity(0.08)).frame(height: 0.5)
            }
        }
        .padding(16)
    }
    
    private var travelJournalPreview: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Washi tape
            RoundedRectangle(cornerRadius: 1)
                .fill(Color(red: 0.56, green: 0.52, blue: 0.96).opacity(0.45))
                .frame(width: 70, height: 7)
                .rotationEffect(.degrees(-3))
                .padding(.top, 12)
            
            // Title bar
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(red: 0.17, green: 0.24, blue: 0.31).opacity(0.35))
                .frame(width: 80, height: 9)
                .padding(.top, 10)
            
            HStack(alignment: .top, spacing: 8) {
                // Text lines
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(0..<4, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.gray.opacity(0.22))
                            .frame(width: CGFloat(35 + (i % 2 == 0 ? 18 : 0)), height: 3)
                    }
                }
                .padding(.top, 10)
                
                Spacer()
                
                // Sticky note
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: "CCFF90").opacity(0.7))
                    .frame(width: 38, height: 32)
                    .rotationEffect(.degrees(3))
                    .overlay(
                        VStack(spacing: 3) {
                            ForEach(0..<3, id: \.self) { _ in
                                Rectangle().fill(Color.black.opacity(0.12)).frame(width: 22, height: 1.5)
                            }
                        }
                    )
                    .padding(.top, 8)
            }
            
            // Travel sticker
            Text("✈️").font(.system(size: 16)).padding(.top, 6)
            
            Spacer()
            
            // Bottom washi tape
            HStack {
                Spacer()
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(red: 0.55, green: 0.73, blue: 1.0).opacity(0.40))
                    .frame(width: 45, height: 6)
                    .rotationEffect(.degrees(10))
            }
            .padding(.bottom, 10)
        }
        .padding(.horizontal, 14)
    }
    
    private var photoCollagePreview: some View {
        VStack(spacing: 0) {
            // Title
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(red: 0.17, green: 0.24, blue: 0.31).opacity(0.35))
                .frame(width: 60, height: 8)
                .padding(.top, 14)
            
            // Photo frames row
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: 48, height: 38)
                    Image(systemName: "photo").font(.system(size: 10)).foregroundStyle(.gray.opacity(0.3))
                }
                .rotationEffect(.degrees(-4))
                
                ZStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.12))
                        .frame(width: 42, height: 34)
                    Image(systemName: "photo").font(.system(size: 9)).foregroundStyle(.gray.opacity(0.3))
                }
                .rotationEffect(.degrees(5))
            }
            .padding(.top, 12)
            
            // Large frame
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.13))
                    .frame(width: 55, height: 42)
                Image(systemName: "photo").font(.system(size: 11)).foregroundStyle(.gray.opacity(0.3))
            }
            .rotationEffect(.degrees(2))
            .padding(.top, 8)
            
            // Washi tape
            RoundedRectangle(cornerRadius: 1)
                .fill(Color(red: 1.0, green: 0.56, blue: 0.69).opacity(0.4))
                .frame(width: 35, height: 5)
                .rotationEffect(.degrees(-8))
                .padding(.top, 8)
            
            Spacer()
            
            HStack {
                Spacer()
                Text("⭐").font(.system(size: 14))
            }
            .padding(.trailing, 14)
            .padding(.bottom, 10)
        }
    }
    
    private var diaryEntryPreview: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Dear Diary heading
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(red: 0.56, green: 0.52, blue: 0.96).opacity(0.5))
                .frame(width: 65, height: 8)
                .padding(.top, 14)
            
            // Separator line
            Rectangle()
                .fill(Color(red: 0.56, green: 0.52, blue: 0.96).opacity(0.2))
                .frame(height: 0.5)
                .padding(.top, 8)
            
            // Text lines
            VStack(alignment: .leading, spacing: 5) {
                ForEach(0..<6, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: CGFloat(45 + (i % 3 == 0 ? 25 : (i % 2 == 0 ? 12 : 0))), height: 3)
                }
            }
            .padding(.top, 10)
            
            Spacer()
            
            HStack {
                // Washi tape
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(red: 1.0, green: 0.78, blue: 0.64).opacity(0.55))
                    .frame(width: 40, height: 6)
                    .rotationEffect(.degrees(-10))
                
                Spacer()
                
                // Sticky note
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: "FFD4A3").opacity(0.6))
                    .frame(width: 32, height: 26)
                    .rotationEffect(.degrees(5))
                    .overlay(
                        VStack(spacing: 3) {
                            ForEach(0..<2, id: \.self) { _ in
                                Rectangle().fill(Color.black.opacity(0.1)).frame(width: 18, height: 1.5)
                            }
                        }
                    )
            }
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 14)
    }
}
