import SwiftUI

// MARK: - Element Action

enum ElementAction {
    case delete, duplicate, cut, copy, lockToggle, sendToBack, bringToFront
}

// MARK: - Draggable/Resizable/Rotatable Base Modifier

struct ScrapbookElementModifier: ViewModifier {
    @Binding var x: Double
    @Binding var y: Double
    @Binding var width: Double
    @Binding var height: Double
    @Binding var rotation: Double
    var isSelected: Bool
    var isLocked: Bool
    var onTap: () -> Void
    var onDelete: () -> Void
    var onChange: () -> Void
    var onAction: (ElementAction) -> Void = { _ in }
    
    @State private var dragOffset: CGSize = .zero
    @State private var baseWidth: Double = 0
    @State private var baseHeight: Double = 0
    @State private var baseRotation: Double = 0
    
    private let selectionBlue = Color(red: 0.0, green: 0.48, blue: 1.0)
    
    func body(content: Content) -> some View {
        content
            .frame(width: max(width, 50), height: max(height, 30))
            .rotationEffect(.degrees(rotation))
            .overlay {
                if isSelected {
                    ZStack {
                        Rectangle().stroke(selectionBlue, lineWidth: 1.5)
                        GeometryReader { geo in
                            let s: CGFloat = 10
                            let positions: [(CGFloat, CGFloat)] = [
                                (0, 0), (geo.size.width, 0),
                                (0, geo.size.height), (geo.size.width, geo.size.height)
                            ]
                            ForEach(0..<4, id: \.self) { i in
                                Circle().fill(selectionBlue)
                                    .frame(width: s, height: s)
                                    .position(x: positions[i].0, y: positions[i].1)
                            }
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .bottom) {
                if isSelected {
                    elementToolbar
                        .offset(y: 48)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if isLocked && isSelected {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(selectionBlue.opacity(0.8), in: Circle())
                        .offset(x: 8, y: 8)
                        .allowsHitTesting(false)
                }
            }
            .position(x: x, y: y)
            .offset(x: dragOffset.width, y: dragOffset.height)
            .highPriorityGesture(
                DragGesture()
                    .onChanged { v in if !isLocked { dragOffset = v.translation } }
                    .onEnded { v in
                        if !isLocked { x += v.translation.width; y += v.translation.height }
                        dragOffset = .zero
                        if !isLocked { onChange() }
                    }
            )
            .simultaneousGesture(
                MagnifyGesture().simultaneously(with: RotateGesture())
                    .onChanged { value in
                        guard !isLocked else { return }
                        if let scale = value.first?.magnification {
                            width = max(50, baseWidth * scale)
                            height = max(30, baseHeight * scale)
                        }
                        if let angle = value.second?.rotation {
                            rotation = baseRotation + angle.degrees
                        }
                    }
                    .onEnded { _ in
                        guard !isLocked else { return }
                        baseWidth = width
                        baseHeight = height
                        baseRotation = rotation
                        onChange()
                    }
            )
            .onTapGesture { onTap() }
            .onAppear {
                baseWidth = width
                baseHeight = height
                baseRotation = rotation
            }
    }
    
    // MARK: - Element Toolbar (below element)
    private var elementToolbar: some View {
        HStack(spacing: 18) {
            Button { onAction(.delete) } label: {
                Image(systemName: "trash")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.red)
            }
            
            Menu {
                Section {
                    Button { onAction(.sendToBack) } label: { Label("Send to Back", systemImage: "square.3.layers.3d.down.left") }
                    Button { onAction(.bringToFront) } label: { Label("Bring to Front", systemImage: "square.3.layers.3d.top.filled") }
                }
                Section {
                    Button { onAction(.cut) } label: { Label("Cut", systemImage: "scissors") }
                    Button { onAction(.copy) } label: { Label("Copy", systemImage: "doc.on.doc") }
                    Button { onAction(.duplicate) } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                    Button { onAction(.lockToggle) } label: { Label(isLocked ? "Unlock" : "Lock", systemImage: isLocked ? "lock.open" : "lock") }
                }
                Section {
                    Button(role: .destructive) { onAction(.delete) } label: { Label("Delete", systemImage: "trash") }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.black)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
    }
}

// MARK: - Scrapbook Image View

struct ScrapbookImageView: View {
    @Binding var element: ImageElement
    var image: UIImage?
    var isSelected: Bool
    var onTap: () -> Void
    var onDelete: () -> Void
    var onChange: () -> Void
    var isLocked: Bool
    var onAction: (ElementAction) -> Void = { _ in }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3).fill(.white)
                .shadow(color: Color(red: 0.4, green: 0.3, blue: 0.2).opacity(0.25), radius: 8, y: 5)
            VStack(spacing: 0) {
                Group {
                    if let img = image { Image(uiImage: img).resizable().aspectRatio(contentMode: .fill).clipped() }
                    else { Rectangle().fill(Color(red: 0.95, green: 0.93, blue: 0.9)).overlay { ProgressView().tint(.brown) } }
                }.clipShape(RoundedRectangle(cornerRadius: 2)).padding(.top, 6).padding(.horizontal, 6)
                Spacer().frame(height: 16)
            }
        }
        .modifier(ScrapbookElementModifier(x: $element.x, y: $element.y, width: $element.width, height: $element.height, rotation: $element.rotation, isSelected: isSelected, isLocked: isLocked, onTap: onTap, onDelete: onDelete, onChange: onChange, onAction: onAction))
    }
}

// MARK: - Washi Tape Strip (decorative)

struct TapeStripView: View {
    var color: Color = Color(red: 0.95, green: 0.88, blue: 0.72)
    var body: some View {
        RoundedRectangle(cornerRadius: 1).fill(color.opacity(0.55))
            .overlay { GeometryReader { geo in HStack(spacing: 3) { ForEach(0..<Int(geo.size.width / 5), id: \.self) { _ in Rectangle().fill(color.opacity(0.15)).frame(width: 1) } } } }
    }
}

// MARK: - Scrapbook Text View (improved UX)

struct ScrapbookTextView: View {
    @Binding var element: TextElement
    var isSelected: Bool
    var onTap: () -> Void
    var onDelete: () -> Void
    var onChange: () -> Void
    var onFontTap: () -> Void
    var isLocked: Bool
    var onAction: (ElementAction) -> Void = { _ in }
    
    @State private var baseFontSize: Double = 18
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(isSelected ? 0.6 : 0.01))
            
            if isSelected {
                VStack(spacing: 0) {
                    TextEditor(text: $element.text)
                        .scrollContentBackground(.hidden)
                        .font(.custom(element.fontName, size: element.fontSize))
                        .foregroundStyle(Color(hex: element.colorHex))
                        .padding(8)
                        .onChange(of: element.text) { _, _ in onChange() }
                    
                    HStack(spacing: 12) {
                        Button { onFontTap() } label: { Image(systemName: "textformat").font(.system(size: 14)).foregroundStyle(Color(red: 0.65, green: 0.42, blue: 0.32)) }
                    }.padding(.bottom, 4)
                }
            } else {
                Text(element.text.isEmpty ? "Write something..." : element.text)
                    .font(.custom(element.fontName, size: element.fontSize))
                    .foregroundStyle(element.text.isEmpty ? Color.brown.opacity(0.3) : Color(hex: element.colorHex))
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .gesture(
            MagnifyGesture()
                .onChanged { value in
                    let newSize = baseFontSize * value.magnification
                    element.fontSize = max(10, min(80, newSize))
                }
                .onEnded { _ in
                    baseFontSize = element.fontSize
                    onChange()
                }
        )
        .onAppear { baseFontSize = element.fontSize }
        .modifier(ScrapbookElementModifier(x: $element.x, y: $element.y, width: $element.width, height: $element.height, rotation: $element.rotation, isSelected: isSelected, isLocked: isLocked, onTap: onTap, onDelete: onDelete, onChange: onChange, onAction: onAction))
    }
}

// MARK: - Scrapbook Sticky Note View

struct ScrapbookStickyView: View {
    @Binding var note: StickyNote
    var isSelected: Bool
    var onTap: () -> Void
    var onDelete: () -> Void
    var onChange: () -> Void
    var isLocked: Bool
    var onAction: (ElementAction) -> Void = { _ in }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 4).fill(LinearGradient(colors: [Color(hex: note.colorHex), Color(hex: note.colorHex).opacity(0.85)], startPoint: .top, endPoint: .bottom))
                .shadow(color: Color(red: 0.3, green: 0.25, blue: 0.15).opacity(0.2), radius: 6, x: 2, y: 4)
            VStack { HStack { Spacer(); FoldedCorner().fill(Color(hex: note.colorHex).opacity(0.6)).frame(width: 20, height: 20).shadow(color: .black.opacity(0.08), radius: 2, x: -1, y: 1) }; Spacer() }
            if isSelected {
                TextEditor(text: $note.text).scrollContentBackground(.hidden).font(.custom("Bradley Hand", size: 15)).foregroundStyle(.black.opacity(0.8)).padding(12).onChange(of: note.text) { _, _ in onChange() }
            } else {
                Text(note.text.isEmpty ? "Write note..." : note.text).font(.custom("Bradley Hand", size: 15))
                    .foregroundStyle(note.text.isEmpty ? .black.opacity(0.25) : .black.opacity(0.8)).padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .modifier(ScrapbookElementModifier(x: $note.x, y: $note.y, width: $note.width, height: $note.height, rotation: $note.rotation, isSelected: isSelected, isLocked: isLocked, onTap: onTap, onDelete: onDelete, onChange: onChange, onAction: onAction))
    }
}

struct FoldedCorner: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path(); p.move(to: CGPoint(x: rect.maxX, y: rect.minY)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY)); p.addLine(to: CGPoint(x: rect.minX, y: rect.minY)); p.closeSubpath(); return p
    }
}

// MARK: - Scrapbook Shape View

struct ScrapbookShapeView: View {
    @Binding var element: ShapeElement
    var isSelected: Bool
    var onTap: () -> Void
    var onDelete: () -> Void
    var onChange: () -> Void
    var isLocked: Bool
    var onAction: (ElementAction) -> Void = { _ in }
    
    var body: some View {
        shapeContent.modifier(ScrapbookElementModifier(x: $element.x, y: $element.y, width: $element.width, height: $element.height, rotation: $element.rotation, isSelected: isSelected, isLocked: isLocked, onTap: onTap, onDelete: onDelete, onChange: onChange, onAction: onAction))
    }
    
    @ViewBuilder private var shapeContent: some View {
        let fill = Color(hex: element.fillColorHex); let stroke = Color(hex: element.strokeColorHex)
        switch element.shapeType {
        case .rectangle: Rectangle().fill(element.isFilled ? fill : .clear).overlay(Rectangle().stroke(stroke, lineWidth: element.strokeWidth))
        case .roundedRect: RoundedRectangle(cornerRadius: 12).fill(element.isFilled ? fill : .clear).overlay(RoundedRectangle(cornerRadius: 12).stroke(stroke, lineWidth: element.strokeWidth))
        case .circle: Ellipse().fill(element.isFilled ? fill : .clear).overlay(Ellipse().stroke(stroke, lineWidth: element.strokeWidth))
        case .star: StarShape().fill(element.isFilled ? fill : .clear).overlay(StarShape().stroke(stroke, lineWidth: element.strokeWidth))
        case .triangle: TriangleShape().fill(element.isFilled ? fill : .clear).overlay(TriangleShape().stroke(stroke, lineWidth: element.strokeWidth))
        case .line: Rectangle().fill(stroke).frame(height: max(element.strokeWidth, 3))
        case .arrow: ArrowShape().fill(element.isFilled ? fill : .clear).overlay(ArrowShape().stroke(stroke, lineWidth: element.strokeWidth))
        case .diamond: DiamondShape().fill(element.isFilled ? fill : .clear).overlay(DiamondShape().stroke(stroke, lineWidth: element.strokeWidth))
        case .hexagon: HexagonShape().fill(element.isFilled ? fill : .clear).overlay(HexagonShape().stroke(stroke, lineWidth: element.strokeWidth))
        case .pentagon: PentagonShape().fill(element.isFilled ? fill : .clear).overlay(PentagonShape().stroke(stroke, lineWidth: element.strokeWidth))
        case .heart: HeartShape().fill(element.isFilled ? fill : .clear).overlay(HeartShape().stroke(stroke, lineWidth: element.strokeWidth))
        }
    }
}

// MARK: - Scrapbook Sticker View

struct ScrapbookStickerView: View {
    @Binding var element: StickerElement
    var isSelected: Bool
    var onTap: () -> Void
    var onDelete: () -> Void
    var onChange: () -> Void
    var isLocked: Bool
    var onAction: (ElementAction) -> Void = { _ in }
    
    var body: some View {
        Text(element.emoji).font(.system(size: min(element.width, element.height) * 0.75))
            .modifier(ScrapbookElementModifier(x: $element.x, y: $element.y, width: $element.width, height: $element.height, rotation: $element.rotation, isSelected: isSelected, isLocked: isLocked, onTap: onTap, onDelete: onDelete, onChange: onChange, onAction: onAction))
    }
}

// MARK: - Scrapbook Washi Tape View

struct ScrapbookWashiTapeView: View {
    @Binding var element: WashiTapeElement
    var isSelected: Bool
    var onTap: () -> Void
    var onDelete: () -> Void
    var onChange: () -> Void
    var isLocked: Bool
    var onAction: (ElementAction) -> Void = { _ in }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2).fill(Color(hex: element.colorHex).opacity(0.6))
            // Pattern overlay
            GeometryReader { geo in
                switch element.patternType {
                case .striped:
                    HStack(spacing: 4) { ForEach(0..<Int(geo.size.width / 6), id: \.self) { _ in Rectangle().fill(Color.white.opacity(0.2)).frame(width: 1.5) } }
                case .dotted:
                    let cols = Int(geo.size.width / 10); let rows = max(Int(geo.size.height / 10), 1)
                    VStack(spacing: 4) { ForEach(0..<rows, id: \.self) { _ in HStack(spacing: 6) { ForEach(0..<cols, id: \.self) { _ in Circle().fill(Color.white.opacity(0.25)).frame(width: 3, height: 3) } } } }
                case .checkered:
                    HStack(spacing: 0) {
                        ForEach(0..<Int(geo.size.width / 8), id: \.self) { i in
                            Rectangle().fill(i.isMultiple(of: 2) ? Color.white.opacity(0.15) : Color.clear).frame(width: 8)
                        }
                    }
                case .solid: Color.clear
                }
            }
            // Torn edges
            HStack { Rectangle().fill(Color(hex: element.colorHex).opacity(0.3)).frame(width: 3); Spacer(); Rectangle().fill(Color(hex: element.colorHex).opacity(0.3)).frame(width: 3) }
        }
        .modifier(ScrapbookElementModifier(x: $element.x, y: $element.y, width: $element.width, height: $element.height, rotation: $element.rotation, isSelected: isSelected, isLocked: isLocked, onTap: onTap, onDelete: onDelete, onChange: onChange, onAction: onAction))
    }
}

// MARK: - Scrapbook Stamp View (Travel Memorabilia)

struct ScrapbookStampView: View {
    @Binding var element: StampElement
    var isSelected: Bool
    var onTap: () -> Void
    var onDelete: () -> Void
    var onChange: () -> Void
    var isLocked: Bool
    var onAction: (ElementAction) -> Void = { _ in }
    
    var body: some View {
        stampContent
            .modifier(ScrapbookElementModifier(x: $element.x, y: $element.y, width: $element.width, height: $element.height, rotation: $element.rotation, isSelected: isSelected, isLocked: isLocked, onTap: onTap, onDelete: onDelete, onChange: onChange, onAction: onAction))
    }
    
    @ViewBuilder private var stampContent: some View {
        let color = Color(hex: element.colorHex)
        switch element.stampStyle {
        case .passportCircle: passportCircleStamp(color: color)
        case .passportRect: passportRectStamp(color: color)
        case .concertTicket: concertTicketView(color: color)
        case .movieTicket: movieTicketView(color: color)
        case .trainTicket: trainTicketView(color: color)
        case .boardingPass: boardingPassView(color: color)
        case .postcard: postcardView(color: color)
        case .receipt: receiptView(color: color)
        case .luggageTag: luggageTagView(color: color)
        case .hotelKey: hotelKeyView(color: color)
        }
    }
    
    // MARK: - Passport Circle Stamp
    private func passportCircleStamp(color: Color) -> some View {
        ZStack {
            Circle().stroke(color.opacity(0.7), lineWidth: 3)
            Circle().stroke(color.opacity(0.5), lineWidth: 1).padding(6)
            VStack(spacing: 2) {
                Text("✈").font(.system(size: 16))
                Text(element.text.uppercased())
                    .font(.system(size: 14, weight: .black, design: .serif))
                    .foregroundStyle(color.opacity(0.8))
                Text(element.subText)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(color.opacity(0.6))
            }
            // Dashed border ring
            Circle().stroke(color.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [3, 3])).padding(3)
        }
        .opacity(0.85)
    }
    
    // MARK: - Passport Rectangle Stamp
    private func passportRectStamp(color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .stroke(color.opacity(0.7), lineWidth: 3)
            RoundedRectangle(cornerRadius: 2)
                .stroke(color.opacity(0.4), lineWidth: 1)
                .padding(5)
            VStack(spacing: 3) {
                Text(element.text.uppercased())
                    .font(.system(size: 13, weight: .black, design: .serif))
                    .foregroundStyle(color.opacity(0.8))
                Rectangle().fill(color.opacity(0.4)).frame(height: 1).padding(.horizontal, 12)
                Text("IMMIGRATION")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundStyle(color.opacity(0.5))
                    .tracking(2)
                Text(element.subText)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(color.opacity(0.6))
            }.padding(8)
        }
        .opacity(0.85)
    }
    
    // MARK: - Concert Ticket
    private func concertTicketView(color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.08))
            RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.4), lineWidth: 1.5)
            VStack(spacing: 0) {
                ZStack {
                    Rectangle().fill(color.opacity(0.15))
                    Text("🎵 LIVE CONCERT 🎵")
                        .font(.system(size: 7, weight: .heavy, design: .monospaced))
                        .foregroundStyle(color.opacity(0.6))
                        .tracking(2)
                }.frame(height: 18)
                VStack(spacing: 4) {
                    Text(element.text.uppercased())
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(color)
                    Text(element.subText)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(color.opacity(0.6))
                    Text("GENERAL ADMISSION")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(color.opacity(0.4))
                        .tracking(1.5)
                }.padding(8)
                HStack(spacing: 4) {
                    ForEach(0..<25, id: \.self) { _ in Circle().fill(color.opacity(0.15)).frame(width: 3, height: 3) }
                }
                HStack {
                    Text("🎸").font(.system(size: 10))
                    Text(element.text.prefix(8).uppercased())
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(color.opacity(0.5))
                    Spacer()
                    Text("#\(element.subText)")
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundStyle(color.opacity(0.4))
                }.padding(.horizontal, 10).padding(.vertical, 6)
            }
        }
    }
    
    // MARK: - Movie Ticket
    private func movieTicketView(color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(.white)
                .shadow(color: .black.opacity(0.06), radius: 3, y: 2)
            RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.15), lineWidth: 1)
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("🎬").font(.system(size: 14))
                        Text("CINEMA").font(.system(size: 7, weight: .heavy, design: .monospaced)).foregroundStyle(color.opacity(0.4)).tracking(2)
                    }
                    Text(element.text)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.black.opacity(0.8))
                        .lineLimit(2)
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("ROW").font(.system(size: 6, weight: .medium)).foregroundStyle(.gray)
                            Text("E").font(.system(size: 14, weight: .black)).foregroundStyle(color)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("SEAT").font(.system(size: 6, weight: .medium)).foregroundStyle(.gray)
                            Text("14").font(.system(size: 14, weight: .black)).foregroundStyle(color)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("TIME").font(.system(size: 6, weight: .medium)).foregroundStyle(.gray)
                            Text(element.subText).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(.black.opacity(0.6))
                        }
                    }
                }.padding(10)
                Rectangle().fill(.clear).frame(width: 1)
                    .overlay { VStack(spacing: 3) { ForEach(0..<12, id: \.self) { _ in Circle().fill(color.opacity(0.15)).frame(width: 3) } } }
                VStack(spacing: 4) {
                    Text("🍿").font(.system(size: 16))
                    Text("E14").font(.system(size: 10, weight: .black)).foregroundStyle(color)
                }.frame(width: 40).padding(6)
            }
        }
    }
    
    // MARK: - Train Ticket
    private func trainTicketView(color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6).fill(color.opacity(0.05))
            RoundedRectangle(cornerRadius: 6).stroke(color.opacity(0.3), lineWidth: 1.5)
            VStack(spacing: 6) {
                HStack {
                    Text("🚂").font(.system(size: 12))
                    Text("RAIL PASS").font(.system(size: 7, weight: .heavy, design: .monospaced)).foregroundStyle(color.opacity(0.5)).tracking(2)
                    Spacer()
                    Text("CLASS 1").font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundStyle(color.opacity(0.4))
                }
                Rectangle().fill(color.opacity(0.15)).frame(height: 0.5)
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("FROM").font(.system(size: 6, weight: .medium)).foregroundStyle(.gray)
                        Text(element.text.prefix(10).uppercased())
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(color)
                    }
                    Image(systemName: "arrow.right").font(.system(size: 10)).foregroundStyle(color.opacity(0.3))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("TO").font(.system(size: 6, weight: .medium)).foregroundStyle(.gray)
                        Text(element.subText.prefix(10).uppercased())
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(color)
                    }
                }
                Rectangle().fill(color.opacity(0.15)).frame(height: 0.5)
                HStack {
                    Text("PLATFORM 3 • CAR 4")
                        .font(.system(size: 6, weight: .medium, design: .monospaced))
                        .foregroundStyle(.gray)
                    Spacer()
                    RoundedRectangle(cornerRadius: 2).fill(color.opacity(0.1)).frame(width: 20, height: 20)
                        .overlay {
                            VStack(spacing: 1) {
                                ForEach(0..<4, id: \.self) { _ in
                                    HStack(spacing: 1) {
                                        ForEach(0..<4, id: \.self) { _ in
                                            Rectangle().fill(color.opacity(Double.random(in: 0.2...0.6))).frame(width: 3, height: 3)
                                        }
                                    }
                                }
                            }
                        }
                }
            }.padding(10)
        }
    }
    
    // MARK: - Boarding Pass
    private func boardingPassView(color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(.white)
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
            RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.2), lineWidth: 1)
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("BOARDING PASS")
                        .font(.system(size: 7, weight: .heavy, design: .monospaced))
                        .foregroundStyle(color.opacity(0.5))
                        .tracking(2)
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(element.text.prefix(3).uppercased())
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundStyle(color)
                            Text("FROM").font(.system(size: 6, weight: .medium)).foregroundStyle(.gray)
                        }
                        Image(systemName: "airplane").font(.system(size: 12)).foregroundStyle(color.opacity(0.4))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(element.subText.prefix(3).uppercased())
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundStyle(color)
                            Text("TO").font(.system(size: 6, weight: .medium)).foregroundStyle(.gray)
                        }
                    }
                    Text("GATE A12 • SEAT 24F")
                        .font(.system(size: 7, weight: .medium, design: .monospaced))
                        .foregroundStyle(.gray)
                }.padding(10)
                // Dashed separator
                Rectangle().fill(.clear).frame(width: 1)
                    .overlay { VStack(spacing: 3) { ForEach(0..<15, id: \.self) { _ in Circle().fill(color.opacity(0.2)).frame(width: 2) } } }
                // Barcode area
                VStack(spacing: 3) {
                    HStack(spacing: 1) { ForEach(0..<8, id: \.self) { i in Rectangle().fill(color.opacity(Double.random(in: 0.3...0.7))).frame(width: CGFloat.random(in: 1.5...3), height: 25) } }
                }.frame(width: 35).padding(6)
            }
        }
    }
    
    // MARK: - Postcard
    private func postcardView(color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6).fill(Color(red: 0.99, green: 0.97, blue: 0.94))
            RoundedRectangle(cornerRadius: 6).stroke(color.opacity(0.2), lineWidth: 1)
            HStack(spacing: 0) {
                // Left: message area
                VStack(alignment: .leading, spacing: 6) {
                    Text(element.text)
                        .font(.system(size: 12, weight: .medium, design: .serif))
                        .foregroundStyle(.black.opacity(0.6))
                        .italic()
                    Spacer()
                    ForEach(0..<3, id: \.self) { _ in
                        Rectangle().fill(.gray.opacity(0.15)).frame(height: 0.5)
                    }
                }.padding(10)
                // Divider
                Rectangle().fill(.gray.opacity(0.2)).frame(width: 0.5)
                // Right: address area
                VStack(alignment: .trailing, spacing: 6) {
                    // Stamp
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(color.opacity(0.4), lineWidth: 1)
                        .frame(width: 28, height: 32)
                        .overlay { Text("📮").font(.system(size: 14)) }
                    Spacer()
                    ForEach(0..<3, id: \.self) { _ in
                        Rectangle().fill(.gray.opacity(0.15)).frame(width: 50, height: 0.5)
                    }
                    Text(element.subText)
                        .font(.system(size: 8, weight: .medium, design: .serif))
                        .foregroundStyle(.gray)
                }.padding(10)
            }
        }
    }
    
    // MARK: - Receipt
    private func receiptView(color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2).fill(.white)
                .shadow(color: .black.opacity(0.06), radius: 3, y: 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(element.text.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.black.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .center)
                Rectangle().fill(.black.opacity(0.1)).frame(height: 0.5)
                ForEach(0..<3, id: \.self) { i in
                    HStack {
                        Text(["Item 1", "Item 2", "Tax"][i])
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(.black.opacity(0.5))
                        Spacer()
                        Text(["$12.00", "$8.50", "$1.64"][i])
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(.black.opacity(0.5))
                    }
                }
                Rectangle().fill(.black.opacity(0.1)).frame(height: 0.5)
                HStack {
                    Text("TOTAL").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.black.opacity(0.7))
                    Spacer()
                    Text(element.subText).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.black.opacity(0.7))
                }
                Text("Thank you!").font(.system(size: 8, design: .serif)).foregroundStyle(.gray).frame(maxWidth: .infinity, alignment: .center).padding(.top, 4)
            }.padding(10)
        }
    }
    
    // MARK: - Luggage Tag
    private func luggageTagView(color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.12))
            RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.4), lineWidth: 1.5)
            VStack(spacing: 4) {
                Circle().stroke(color.opacity(0.3), lineWidth: 1.5).frame(width: 12, height: 12)
                    .background(Circle().fill(Color.white).frame(width: 8, height: 8))
                Text("🏷️").font(.system(size: 14))
                Text(element.text.uppercased())
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(color)
                Rectangle().fill(color.opacity(0.2)).frame(height: 0.5).padding(.horizontal, 15)
                Text(element.subText)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(color.opacity(0.6))
                HStack(spacing: 1) {
                    ForEach(0..<12, id: \.self) { _ in
                        Rectangle().fill(color.opacity(Double.random(in: 0.2...0.5)))
                            .frame(width: CGFloat.random(in: 1...2.5), height: 14)
                    }
                }.padding(.top, 2)
                Text("FRAGILE")
                    .font(.system(size: 6, weight: .heavy, design: .monospaced))
                    .foregroundStyle(color.opacity(0.3))
                    .tracking(3)
            }.padding(8)
        }
    }
    
    // MARK: - Hotel Key Card
    private func hotelKeyView(color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(
                LinearGradient(colors: [color.opacity(0.15), color.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.3), lineWidth: 1)
            VStack(spacing: 6) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(element.text.uppercased())
                            .font(.system(size: 10, weight: .heavy, design: .serif))
                            .foregroundStyle(color.opacity(0.7))
                        Text("HOTEL & RESORT")
                            .font(.system(size: 6, weight: .medium, design: .monospaced))
                            .foregroundStyle(color.opacity(0.4))
                            .tracking(1)
                    }
                    Spacer()
                    Text("⭐⭐⭐⭐⭐").font(.system(size: 4))
                }
                Spacer()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ROOM").font(.system(size: 6, weight: .medium)).foregroundStyle(.gray)
                        Text(element.subText)
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(color)
                    }
                    Spacer()
                    Image(systemName: "key.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(color.opacity(0.25))
                }
                HStack {
                    RoundedRectangle(cornerRadius: 2).fill(color.opacity(0.2)).frame(height: 8)
                }
            }.padding(12)
        }
    }
}


// MARK: - Shape Paths

struct StarShape: Shape {
    var points: Int = 5
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY); let oR = min(rect.width, rect.height) / 2; let iR = oR * 0.4
        var path = Path(); let inc = CGFloat.pi * 2 / CGFloat(points * 2)
        for i in 0..<(points * 2) { let r = i.isMultiple(of: 2) ? oR : iR; let a: CGFloat = inc * CGFloat(i) - .pi / 2; let p = CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r); if i == 0 { path.move(to: p) } else { path.addLine(to: p) } }
        path.closeSubpath(); return path
    }
}

struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path { var p = Path(); p.move(to: CGPoint(x: rect.midX, y: rect.minY)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY)); p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY)); p.closeSubpath(); return p }
}

struct ArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path(); let h3 = rect.height / 3
        p.move(to: CGPoint(x: rect.minX, y: h3)); p.addLine(to: CGPoint(x: rect.width * 0.65, y: h3)); p.addLine(to: CGPoint(x: rect.width * 0.65, y: rect.minY)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY)); p.addLine(to: CGPoint(x: rect.width * 0.65, y: rect.maxY)); p.addLine(to: CGPoint(x: rect.width * 0.65, y: h3 * 2)); p.addLine(to: CGPoint(x: rect.minX, y: h3 * 2)); p.closeSubpath(); return p
    }
}

struct DiamondShape: Shape {
    func path(in rect: CGRect) -> Path { var p = Path(); p.move(to: CGPoint(x: rect.midX, y: rect.minY)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY)); p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY)); p.addLine(to: CGPoint(x: rect.minX, y: rect.midY)); p.closeSubpath(); return p }
}

struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path(); let c = CGPoint(x: rect.midX, y: rect.midY); let r = min(rect.width, rect.height) / 2
        for i in 0..<6 { let a: CGFloat = .pi / 3 * CGFloat(i) - .pi / 2; let pt = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r); if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) } }; p.closeSubpath(); return p
    }
}

struct PentagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path(); let c = CGPoint(x: rect.midX, y: rect.midY); let r = min(rect.width, rect.height) / 2
        for i in 0..<5 { let a: CGFloat = .pi * 2 / 5 * CGFloat(i) - .pi / 2; let pt = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r); if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) } }; p.closeSubpath(); return p
    }
}

struct HeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path(); let w = rect.width; let h = rect.height
        p.move(to: CGPoint(x: w * 0.5, y: h * 0.25))
        p.addCurve(to: CGPoint(x: 0, y: h * 0.25), control1: CGPoint(x: w * 0.35, y: 0), control2: CGPoint(x: 0, y: 0))
        p.addCurve(to: CGPoint(x: w * 0.5, y: h), control1: CGPoint(x: 0, y: h * 0.55), control2: CGPoint(x: w * 0.5, y: h * 0.75))
        p.addCurve(to: CGPoint(x: w, y: h * 0.25), control1: CGPoint(x: w * 0.5, y: h * 0.75), control2: CGPoint(x: w, y: h * 0.55))
        p.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.25), control1: CGPoint(x: w, y: 0), control2: CGPoint(x: w * 0.65, y: 0))
        return p
    }
}

// MARK: - Seeded Random Number Generator

struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15; var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9; z = (z ^ (z >> 27)) &* 0x94d049bb133111eb; return z ^ (z >> 31)
    }
}
