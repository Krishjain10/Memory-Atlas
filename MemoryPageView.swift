import SwiftUI
import PencilKit
import PhotosUI

// MARK: - Unified Canvas Item for Layer Ordering

enum CanvasItemType: String { case shape, image, sticky, text, sticker, washiTape, stamp }

struct CanvasItem: Identifiable {
    let id: UUID
    let type: CanvasItemType
    var zIndex: Int
}

// MARK: - Scrapbook Memory Page

struct MemoryPageView: View {
    @EnvironmentObject var store: MemoryStore
    @Environment(\.dismiss) private var dismiss
    @State var memory: Memory
    
    @State private var drawing = PKDrawing()
    @State private var toolPickerIsActive = false
    @State private var textElements: [TextElement] = []
    @State private var imageElements: [ImageElement] = []
    @State private var stickyNotes: [StickyNote] = []
    @State private var shapeElements: [ShapeElement] = []
    @State private var stickerElements: [StickerElement] = []
    @State private var washiTapeElements: [WashiTapeElement] = []
    @State private var stampElements: [StampElement] = []
    @State private var loadedImages: [String: UIImage] = [:]
    @State private var selectedElementID: UUID?
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showShapePicker = false
    @State private var showStickyColorPicker = false
    @State private var showStickerPicker = false
    @State private var showWashiTapePicker = false
    @State private var showStampPicker = false
    @State private var showFontPicker = false
    @State private var showPhotoPicker = false
    @State private var currentShapeColor: Color = .blue.opacity(0.4)
    @State private var currentStrokeWidth: Double = 2
    @State private var currentShapeFilled: Bool = true
    @State private var showDeleteAlert = false
    @State private var showBackConfirmation = false
    @State private var hasUnsavedChanges = false
    @State private var madeChanges = false
    @State private var discardingChanges = false
    @State private var saveTask: Task<Void, Never>?
    @State private var nextZIndex: Int = 1
    @State private var originalMemory: Memory?
    @State private var originalDrawingData: Data?
    
    // Clipboard
    enum CopiedElement {
        case text(TextElement)
        case image(ImageElement)
        case sticky(StickyNote)
        case shape(ShapeElement)
        case sticker(StickerElement)
        case washiTape(WashiTapeElement)
        case stamp(StampElement)
    }
    @State private var copiedElement: CopiedElement?
    @State private var showPasteBar = false
    @State private var pasteTapLocation: CGPoint = .zero
    
    private let warmAccent = Color(red: 0.56, green: 0.52, blue: 0.96)
    
    private var sortedItems: [CanvasItem] {
        var items: [CanvasItem] = []
        items += shapeElements.map { CanvasItem(id: $0.id, type: .shape, zIndex: $0.zIndex) }
        items += imageElements.map { CanvasItem(id: $0.id, type: .image, zIndex: $0.zIndex) }
        items += stickyNotes.map { CanvasItem(id: $0.id, type: .sticky, zIndex: $0.zIndex) }
        items += textElements.map { CanvasItem(id: $0.id, type: .text, zIndex: $0.zIndex) }
        items += stickerElements.map { CanvasItem(id: $0.id, type: .sticker, zIndex: $0.zIndex) }
        items += washiTapeElements.map { CanvasItem(id: $0.id, type: .washiTape, zIndex: $0.zIndex) }
        items += stampElements.map { CanvasItem(id: $0.id, type: .stamp, zIndex: $0.zIndex) }
        return items.sorted { $0.zIndex < $1.zIndex }
    }
    
    var body: some View {
        ZStack {
            Color(red: 0.93, green: 0.91, blue: 0.97).ignoresSafeArea()
            GeometryReader { geo in
                let pageSize = calculatePageSize(in: geo.size)
                ZStack {
                    journalPaper
                    
                    ZStack {
                        ForEach(sortedItems) { item in
                            renderItem(item)
                        }
                        CanvasView(drawing: $drawing, toolPickerIsActive: $toolPickerIsActive)
                            .onChange(of: drawing) { _, _ in scheduleAutoSave() }
                            .allowsHitTesting(toolPickerIsActive)
                    }
                    .padding(24)
                }
                .frame(width: pageSize.width, height: pageSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: Color(red: 0.4, green: 0.35, blue: 0.55).opacity(0.25), radius: 20, y: 8)
                .coordinateSpace(name: "canvas")
                .gesture(
                    SpatialTapGesture()
                        .onEnded { value in
                            selectedElementID = nil
                            let hasInternalCopy = copiedElement != nil
                            let hasExternalCopy = UIPasteboard.general.hasImages || UIPasteboard.general.hasStrings
                            if (hasInternalCopy || hasExternalCopy) && !showPasteBar {
                                pasteTapLocation = value.location
                                withAnimation(.easeInOut(duration: 0.15)) { showPasteBar = true }
                            } else {
                                withAnimation(.easeInOut(duration: 0.15)) { showPasteBar = false }
                            }
                        }
                )
                .overlay {
                    if showPasteBar && (copiedElement != nil || UIPasteboard.general.hasImages || UIPasteboard.general.hasStrings) {
                        pasteBar
                            .position(x: pasteTapLocation.x, y: pasteTapLocation.y - 40)
                            .transition(.scale(scale: 0.85).combined(with: .opacity))
                    }
                }
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
        .overlay(alignment: .top) { headerBar }
        .overlay(alignment: .bottom) { creativeToolbar }
        .onChange(of: selectedElementID) { _, newID in
            if newID != nil { withAnimation(.easeInOut(duration: 0.15)) { showPasteBar = false } }
        }
        .sheet(isPresented: $showShapePicker) { shapePickerSheet }
        .sheet(isPresented: $showStickyColorPicker) { stickyColorSheet }
        .sheet(isPresented: $showStickerPicker) { stickerPickerSheet }
        .sheet(isPresented: $showWashiTapePicker) { washiTapePickerSheet }
        .sheet(isPresented: $showStampPicker) { stampPickerSheet }
        .sheet(isPresented: $showFontPicker) { fontPickerSheet }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItems, maxSelectionCount: 1, matching: .images)
        .onChange(of: selectedPhotoItems) { _, items in handlePhotoPicker(items: items) }
        .alert("Delete Memory?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) { store.deleteMemory(memory); dismiss() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This memory will be permanently deleted.") }
        .alert("Unsaved Changes", isPresented: $showBackConfirmation) {
            Button("Save Changes") { saveAllData(); dismiss() }
            Button("Discard Changes", role: .destructive) { discardChanges() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("You have unsaved changes. What would you like to do?") }
        .onAppear(perform: loadData)
        .onDisappear { if !discardingChanges { saveAllData() } }
        .ignoresSafeArea(.keyboard)
    }
    
    // MARK: - Render Unified Items
    @ViewBuilder
    private func renderItem(_ item: CanvasItem) -> some View {
        switch item.type {
        case .shape:
            if let idx = shapeElements.firstIndex(where: { $0.id == item.id }) {
                ScrapbookShapeView(element: $shapeElements[idx], isSelected: selectedElementID == item.id,
                    onTap: { selectedElementID = item.id; toolPickerIsActive = false },
                    onDelete: { shapeElements.remove(at: idx); scheduleAutoSave() },
                    onChange: { scheduleAutoSave() }, isLocked: shapeElements[idx].isLocked == true,
                    onAction: { action in handleElementAction(action) })
            }
        case .image:
            if let idx = imageElements.firstIndex(where: { $0.id == item.id }) {
                ScrapbookImageView(element: $imageElements[idx], image: loadedImages[imageElements[idx].fileName],
                    isSelected: selectedElementID == item.id,
                    onTap: { selectedElementID = item.id; toolPickerIsActive = false },
                    onDelete: { store.deleteImage(named: imageElements[idx].fileName); imageElements.remove(at: idx); memory.imageElements = imageElements; store.updateMemory(memory) },
                    onChange: { scheduleAutoSave() }, isLocked: imageElements[idx].isLocked == true,
                    onAction: { action in handleElementAction(action) })
            }
        case .sticky:
            if let idx = stickyNotes.firstIndex(where: { $0.id == item.id }) {
                ScrapbookStickyView(note: $stickyNotes[idx], isSelected: selectedElementID == item.id,
                    onTap: { selectedElementID = item.id; toolPickerIsActive = false },
                    onDelete: { stickyNotes.remove(at: idx); scheduleAutoSave() },
                    onChange: { scheduleAutoSave() }, isLocked: stickyNotes[idx].isLocked == true,
                    onAction: { action in handleElementAction(action) })
            }
        case .text:
            if let idx = textElements.firstIndex(where: { $0.id == item.id }) {
                ScrapbookTextView(element: $textElements[idx], isSelected: selectedElementID == item.id,
                    onTap: { selectedElementID = item.id; toolPickerIsActive = false },
                    onDelete: { textElements.remove(at: idx); scheduleAutoSave() },
                    onChange: { scheduleAutoSave() },
                    onFontTap: { selectedElementID = item.id; showFontPicker = true },
                    isLocked: textElements[idx].isLocked == true,
                    onAction: { action in handleElementAction(action) })
            }
        case .sticker:
            if let idx = stickerElements.firstIndex(where: { $0.id == item.id }) {
                ScrapbookStickerView(element: $stickerElements[idx], isSelected: selectedElementID == item.id,
                    onTap: { selectedElementID = item.id; toolPickerIsActive = false },
                    onDelete: { stickerElements.remove(at: idx); scheduleAutoSave() },
                    onChange: { scheduleAutoSave() }, isLocked: stickerElements[idx].isLocked == true,
                    onAction: { action in handleElementAction(action) })
            }
        case .washiTape:
            if let idx = washiTapeElements.firstIndex(where: { $0.id == item.id }) {
                ScrapbookWashiTapeView(element: $washiTapeElements[idx], isSelected: selectedElementID == item.id,
                    onTap: { selectedElementID = item.id; toolPickerIsActive = false },
                    onDelete: { washiTapeElements.remove(at: idx); scheduleAutoSave() },
                    onChange: { scheduleAutoSave() }, isLocked: washiTapeElements[idx].isLocked == true,
                    onAction: { action in handleElementAction(action) })
            }
        case .stamp:
            if let idx = stampElements.firstIndex(where: { $0.id == item.id }) {
                ScrapbookStampView(element: $stampElements[idx], isSelected: selectedElementID == item.id,
                    onTap: { selectedElementID = item.id; toolPickerIsActive = false },
                    onDelete: { stampElements.remove(at: idx); scheduleAutoSave() },
                    onChange: { scheduleAutoSave() }, isLocked: stampElements[idx].isLocked == true,
                    onAction: { action in handleElementAction(action) })
            }
        }
    }
    
    // MARK: - Handle Element Actions
    private func handleElementAction(_ action: ElementAction) {
        switch action {
        case .delete: deleteSelectedElement()
        case .duplicate: duplicateElement()
        case .cut: cutElement()
        case .copy: copyElement()
        case .lockToggle: toggleLock()
        case .sendToBack: moveLayerToExtreme(toFront: false)
        case .bringToFront: moveLayerToExtreme(toFront: true)
        }
    }
    
    // MARK: - Paste Bar
    private var pasteBar: some View {
        Button {
            pasteElement()
            withAnimation(.easeInOut(duration: 0.15)) { showPasteBar = false }
        } label: {
            Text("Paste")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.black)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
                .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        }
    }
    
    private func moveLayer(by delta: Int) {
        guard let id = selectedElementID else { return }
        let sorted = sortedItems
        guard let currentIndex = sorted.firstIndex(where: { $0.id == id }) else { return }
        let targetIndex = currentIndex + delta
        guard targetIndex >= 0, targetIndex < sorted.count else { return }
        let targetItem = sorted[targetIndex]
        let currentZ = getZIndex(for: id)
        let targetZ = getZIndex(for: targetItem.id)
        setZIndex(for: id, value: targetZ)
        setZIndex(for: targetItem.id, value: currentZ)
        scheduleAutoSave()
    }
    
    private func moveLayerToExtreme(toFront: Bool) {
        guard let id = selectedElementID else { return }
        if toFront { nextZIndex += 1; setZIndex(for: id, value: nextZIndex) }
        else { let minZ = sortedItems.first?.zIndex ?? 0; setZIndex(for: id, value: minZ - 1) }
        scheduleAutoSave()
    }
    
    // MARK: - Element Actions
    
    private func deleteSelectedElement() {
        guard let id = selectedElementID else { return }
        if let idx = imageElements.firstIndex(where: { $0.id == id }) {
            store.deleteImage(named: imageElements[idx].fileName)
            imageElements.remove(at: idx)
            memory.imageElements = imageElements
        } else if let idx = textElements.firstIndex(where: { $0.id == id }) {
            textElements.remove(at: idx)
        } else if let idx = stickyNotes.firstIndex(where: { $0.id == id }) {
            stickyNotes.remove(at: idx)
        } else if let idx = shapeElements.firstIndex(where: { $0.id == id }) {
            shapeElements.remove(at: idx)
        } else if let idx = stickerElements.firstIndex(where: { $0.id == id }) {
            stickerElements.remove(at: idx)
        } else if let idx = washiTapeElements.firstIndex(where: { $0.id == id }) {
            washiTapeElements.remove(at: idx)
        } else if let idx = stampElements.firstIndex(where: { $0.id == id }) {
            stampElements.remove(at: idx)
        }
        selectedElementID = nil
        scheduleAutoSave()
    }
    
    private func copyElement() {
        guard let id = selectedElementID else { return }
        if let i = textElements.firstIndex(where: { $0.id == id }) { copiedElement = .text(textElements[i]) }
        else if let i = imageElements.firstIndex(where: { $0.id == id }) { copiedElement = .image(imageElements[i]) }
        else if let i = stickyNotes.firstIndex(where: { $0.id == id }) { copiedElement = .sticky(stickyNotes[i]) }
        else if let i = shapeElements.firstIndex(where: { $0.id == id }) { copiedElement = .shape(shapeElements[i]) }
        else if let i = stickerElements.firstIndex(where: { $0.id == id }) { copiedElement = .sticker(stickerElements[i]) }
        else if let i = washiTapeElements.firstIndex(where: { $0.id == id }) { copiedElement = .washiTape(washiTapeElements[i]) }
        else if let i = stampElements.firstIndex(where: { $0.id == id }) { copiedElement = .stamp(stampElements[i]) }
    }
    
    private func cutElement() {
        copyElement()
        deleteSelectedElement()
    }
    
    private func duplicateElement() {
        guard let id = selectedElementID else { return }
        let offset = 20.0
        if let i = textElements.firstIndex(where: { $0.id == id }) {
            var dup = textElements[i]; dup.id = UUID(); dup.x += offset; dup.y += offset; dup.zIndex = nextZIndex; nextZIndex += 1
            textElements.append(dup); selectedElementID = dup.id
        } else if let i = imageElements.firstIndex(where: { $0.id == id }) {
            var dup = imageElements[i]; dup.id = UUID(); dup.x += offset; dup.y += offset; dup.zIndex = nextZIndex; nextZIndex += 1
            imageElements.append(dup); selectedElementID = dup.id
        } else if let i = stickyNotes.firstIndex(where: { $0.id == id }) {
            var dup = stickyNotes[i]; dup.id = UUID(); dup.x += offset; dup.y += offset; dup.zIndex = nextZIndex; nextZIndex += 1
            stickyNotes.append(dup); selectedElementID = dup.id
        } else if let i = shapeElements.firstIndex(where: { $0.id == id }) {
            var dup = shapeElements[i]; dup.id = UUID(); dup.x += offset; dup.y += offset; dup.zIndex = nextZIndex; nextZIndex += 1
            shapeElements.append(dup); selectedElementID = dup.id
        } else if let i = stickerElements.firstIndex(where: { $0.id == id }) {
            var dup = stickerElements[i]; dup.id = UUID(); dup.x += offset; dup.y += offset; dup.zIndex = nextZIndex; nextZIndex += 1
            stickerElements.append(dup); selectedElementID = dup.id
        } else if let i = washiTapeElements.firstIndex(where: { $0.id == id }) {
            var dup = washiTapeElements[i]; dup.id = UUID(); dup.x += offset; dup.y += offset; dup.zIndex = nextZIndex; nextZIndex += 1
            washiTapeElements.append(dup); selectedElementID = dup.id
        } else if let i = stampElements.firstIndex(where: { $0.id == id }) {
            var dup = stampElements[i]; dup.id = UUID(); dup.x += offset; dup.y += offset; dup.zIndex = nextZIndex; nextZIndex += 1
            stampElements.append(dup); selectedElementID = dup.id
        }
        scheduleAutoSave()
    }
    
    private func toggleLock() {
        guard let id = selectedElementID else { return }
        if let i = textElements.firstIndex(where: { $0.id == id }) { textElements[i].isLocked = !(textElements[i].isLocked == true) }
        else if let i = imageElements.firstIndex(where: { $0.id == id }) { imageElements[i].isLocked = !(imageElements[i].isLocked == true) }
        else if let i = stickyNotes.firstIndex(where: { $0.id == id }) { stickyNotes[i].isLocked = !(stickyNotes[i].isLocked == true) }
        else if let i = shapeElements.firstIndex(where: { $0.id == id }) { shapeElements[i].isLocked = !(shapeElements[i].isLocked == true) }
        else if let i = stickerElements.firstIndex(where: { $0.id == id }) { stickerElements[i].isLocked = !(stickerElements[i].isLocked == true) }
        else if let i = washiTapeElements.firstIndex(where: { $0.id == id }) { washiTapeElements[i].isLocked = !(washiTapeElements[i].isLocked == true) }
        else if let i = stampElements.firstIndex(where: { $0.id == id }) { stampElements[i].isLocked = !(stampElements[i].isLocked == true) }
        scheduleAutoSave()
    }
    
    private func pasteElement() {
        let loc = pasteTapLocation
        
        // 1. Try internal clipboard first
        if let copied = copiedElement {
            switch copied {
            case .text(var el): el.id = UUID(); el.x = loc.x; el.y = loc.y; el.zIndex = nextZIndex; nextZIndex += 1; textElements.append(el); selectedElementID = el.id
            case .image(var el): el.id = UUID(); el.x = loc.x; el.y = loc.y; el.zIndex = nextZIndex; nextZIndex += 1; imageElements.append(el); selectedElementID = el.id
            case .sticky(var el): el.id = UUID(); el.x = loc.x; el.y = loc.y; el.zIndex = nextZIndex; nextZIndex += 1; stickyNotes.append(el); selectedElementID = el.id
            case .shape(var el): el.id = UUID(); el.x = loc.x; el.y = loc.y; el.zIndex = nextZIndex; nextZIndex += 1; shapeElements.append(el); selectedElementID = el.id
            case .sticker(var el): el.id = UUID(); el.x = loc.x; el.y = loc.y; el.zIndex = nextZIndex; nextZIndex += 1; stickerElements.append(el); selectedElementID = el.id
            case .washiTape(var el): el.id = UUID(); el.x = loc.x; el.y = loc.y; el.zIndex = nextZIndex; nextZIndex += 1; washiTapeElements.append(el); selectedElementID = el.id
            case .stamp(var el): el.id = UUID(); el.x = loc.x; el.y = loc.y; el.zIndex = nextZIndex; nextZIndex += 1; stampElements.append(el); selectedElementID = el.id
            }
            scheduleAutoSave()
            return
        }
        
        // 2. Try system clipboard — images
        if let clipImage = UIPasteboard.general.image,
           let jpeg = clipImage.jpegData(compressionQuality: 0.8),
           let fn = store.saveImage(jpeg, for: memory.id) {
            let el = ImageElement(fileName: fn, x: loc.x, y: loc.y, rotation: 0, zIndex: nextZIndex); nextZIndex += 1
            imageElements.append(el); loadedImages[fn] = clipImage; memory.imageElements = imageElements; store.updateMemory(memory); selectedElementID = el.id; toolPickerIsActive = false
            scheduleAutoSave()
            return
        }
        
        // 3. Try system clipboard — text
        if let clipText = UIPasteboard.general.string, !clipText.isEmpty {
            let el = TextElement(text: clipText, x: loc.x, y: loc.y, zIndex: nextZIndex); nextZIndex += 1
            textElements.append(el); selectedElementID = el.id
            scheduleAutoSave()
            return
        }
    }
    
    private func getZIndex(for id: UUID) -> Int {
        if let i = shapeElements.firstIndex(where: { $0.id == id }) { return shapeElements[i].zIndex }
        if let i = imageElements.firstIndex(where: { $0.id == id }) { return imageElements[i].zIndex }
        if let i = stickyNotes.firstIndex(where: { $0.id == id }) { return stickyNotes[i].zIndex }
        if let i = textElements.firstIndex(where: { $0.id == id }) { return textElements[i].zIndex }
        if let i = stickerElements.firstIndex(where: { $0.id == id }) { return stickerElements[i].zIndex }
        if let i = washiTapeElements.firstIndex(where: { $0.id == id }) { return washiTapeElements[i].zIndex }
        if let i = stampElements.firstIndex(where: { $0.id == id }) { return stampElements[i].zIndex }
        return 0
    }
    
    private func setZIndex(for id: UUID, value: Int) {
        if let i = shapeElements.firstIndex(where: { $0.id == id }) { shapeElements[i].zIndex = value }
        if let i = imageElements.firstIndex(where: { $0.id == id }) { imageElements[i].zIndex = value }
        if let i = stickyNotes.firstIndex(where: { $0.id == id }) { stickyNotes[i].zIndex = value }
        if let i = textElements.firstIndex(where: { $0.id == id }) { textElements[i].zIndex = value }
        if let i = stickerElements.firstIndex(where: { $0.id == id }) { stickerElements[i].zIndex = value }
        if let i = washiTapeElements.firstIndex(where: { $0.id == id }) { washiTapeElements[i].zIndex = value }
        if let i = stampElements.firstIndex(where: { $0.id == id }) { stampElements[i].zIndex = value }
    }
    
    // MARK: - Page Size
    private func calculatePageSize(in available: CGSize) -> CGSize {
        let ratio: CGFloat = 3.0 / 4.0
        let maxW = max(1, available.width - 32)
        let maxH = max(1, available.height - 32)
        let widthFromHeight = maxH * ratio
        if widthFromHeight <= maxW {
            return CGSize(width: max(1, widthFromHeight), height: max(1, maxH))
        } else {
            return CGSize(width: max(1, maxW), height: max(1, maxW / ratio))
        }
    }
    
    // MARK: - Journal Paper
    private var journalPaper: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            var rng = SeededRandom(seed: 42)
            for _ in 0..<500 {
                let gx = CGFloat.random(in: 0...size.width, using: &rng)
                let gy = CGFloat.random(in: 0...size.height, using: &rng)
                let op = Double.random(in: 0.02...0.05, using: &rng)
                ctx.fill(Path(ellipseIn: CGRect(x: gx-0.6, y: gy-0.6, width: 1.2, height: 1.2)),
                         with: .color(Color(red: 0.6, green: 0.6, blue: 0.7).opacity(op)))
            }
            let sp: CGFloat = 24; let r: CGFloat = 0.7; var y: CGFloat = sp
            while y < size.height { var x: CGFloat = sp
                while x < size.width { ctx.fill(Path(ellipseIn: CGRect(x: x-r, y: y-r, width: r*2, height: r*2)),
                    with: .color(Color(red: 0.7, green: 0.68, blue: 0.78).opacity(0.1))); x += sp }; y += sp }
            let shadowW: CGFloat = 18; let topGrad = Gradient(colors: [Color(red: 0.56, green: 0.52, blue: 0.96).opacity(0.04), .clear])
            ctx.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: shadowW)),
                     with: .linearGradient(topGrad, startPoint: .zero, endPoint: CGPoint(x: 0, y: shadowW)))
            ctx.fill(Path(CGRect(x: 0, y: 0, width: shadowW, height: size.height)),
                     with: .linearGradient(topGrad, startPoint: .zero, endPoint: CGPoint(x: shadowW, y: 0)))
        }
    }
    
    // MARK: - Header
    private var headerBar: some View {
        HStack {
            Button {
                if madeChanges {
                    showBackConfirmation = true
                } else {
                    dismiss()
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Map")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
                .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
            }
            Spacer()
            Menu {
                Button(role: .destructive) { showDeleteAlert = true } label: { Label("Delete Memory", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 38, height: 38)
                    .background(.regularMaterial, in: Circle())
                    .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }
    
    // MARK: - Creative Toolbar
    private var creativeToolbar: some View {
        HStack(spacing: 14) {
            toolButton(icon: toolPickerIsActive ? "pencil.tip.crop.circle.fill" : "pencil.tip.crop.circle", label: "Draw", isActive: toolPickerIsActive) {
                toolPickerIsActive.toggle(); if toolPickerIsActive { selectedElementID = nil }
            }
            Divider().frame(height: 42)
            toolButton(icon: "textformat.alt", label: "Text") { addText() }
            toolButton(icon: "note.text", label: "Note") { showStickyColorPicker = true }
            toolButton(icon: "photo.on.rectangle.angled", label: "Photo") { showPhotoPicker = true }
            toolButton(icon: "square.on.circle", label: "Shape") { showShapePicker = true }
            Divider().frame(height: 42)
            toolButton(icon: "face.smiling", label: "Sticker") { showStickerPicker = true }
            toolButton(icon: "rectangle.fill", label: "Tape") { showWashiTapePicker = true }
            toolButton(icon: "seal", label: "Stamps") { showStampPicker = true }
            Divider().frame(height: 42)
            toolButton(icon: "hand.point.up.left", label: "Select", isActive: !toolPickerIsActive) { toolPickerIsActive = false }
        }
        .padding(.horizontal, 21).padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: Color(red: 0.4, green: 0.35, blue: 0.55).opacity(0.12), radius: 10, y: -3)
        .padding(.horizontal, 12).padding(.bottom, 16)
    }
    
    private func toolButton(icon: String, label: String, isActive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 30)).frame(height: 30).foregroundStyle(isActive ? .black : .black.opacity(0.35))
                Text(label).font(.system(size: 15, design: .rounded)).frame(height: 16).foregroundStyle(isActive ? .black : .black.opacity(0.35))
            }
        }
    }
    
    private var formattedDate: String { let f = DateFormatter(); f.dateFormat = "EEEE, MMMM d, yyyy"; return f.string(from: memory.createdDate) }
    
    // MARK: - Data
    private func loadData() {
        if let data = store.loadDrawingData(for: memory.id), let d = try? PKDrawing(data: data) { drawing = d }
        textElements = memory.textElements; imageElements = memory.imageElements
        stickyNotes = memory.stickyNotes; shapeElements = memory.shapeElements
        stickerElements = memory.stickerElements; washiTapeElements = memory.washiTapeElements
        stampElements = memory.stampElements
        for el in imageElements { if let img = store.loadImage(named: el.fileName) { loadedImages[el.fileName] = img } }
        let allZ = sortedItems.map { $0.zIndex }; nextZIndex = (allZ.max() ?? 0) + 1
        originalMemory = memory
        originalDrawingData = store.loadDrawingData(for: memory.id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            saveTask?.cancel()
            madeChanges = false
            hasUnsavedChanges = false
        }
    }
    
    private func saveAllData() {
        store.saveDrawingData(drawing.dataRepresentation(), for: memory.id)
        memory.textElements = textElements; memory.imageElements = imageElements
        memory.stickyNotes = stickyNotes; memory.shapeElements = shapeElements
        memory.stickerElements = stickerElements; memory.washiTapeElements = washiTapeElements
        memory.stampElements = stampElements
        store.updateMemory(memory)
        hasUnsavedChanges = false
    }
    
    private func discardChanges() {
        saveTask?.cancel()
        discardingChanges = true
        if let original = originalMemory {
            store.updateMemory(original)
            if let drawingData = originalDrawingData {
                store.saveDrawingData(drawingData, for: memory.id)
            }
        }
        dismiss()
    }
    
    private func scheduleAutoSave() {
        hasUnsavedChanges = true
        madeChanges = true
        saveTask?.cancel()
        saveTask = Task { try? await Task.sleep(nanoseconds: 1_500_000_000); if !Task.isCancelled { await MainActor.run { saveAllData() } } }
    }
    
    // MARK: - Add Elements
    private func addText() {
        toolPickerIsActive = false
        let el = TextElement(x: Double.random(in: 100...300), y: Double.random(in: 200...500), zIndex: nextZIndex); nextZIndex += 1
        textElements.append(el); selectedElementID = el.id; scheduleAutoSave()
    }
    
    private func addStickyNoteWithColor(_ color: Color) {
        toolPickerIsActive = false
        let note = StickyNote(x: Double.random(in: 100...350), y: Double.random(in: 200...500), rotation: Double.random(in: -5...5), colorHex: color.toHex(), zIndex: nextZIndex); nextZIndex += 1
        stickyNotes.append(note); selectedElementID = note.id; scheduleAutoSave()
    }
    
    private func addShape(type: ShapeType) {
        toolPickerIsActive = false
        let el = ShapeElement(shapeType: type, x: Double.random(in: 100...350), y: Double.random(in: 200...500), fillColorHex: currentShapeColor.toHex(), strokeWidth: currentStrokeWidth, isFilled: currentShapeFilled, zIndex: nextZIndex); nextZIndex += 1
        shapeElements.append(el); selectedElementID = el.id; scheduleAutoSave()
    }
    
    private func addSticker(_ emoji: String) {
        toolPickerIsActive = false
        let el = StickerElement(emoji: emoji, x: Double.random(in: 100...350), y: Double.random(in: 200...500), rotation: Double.random(in: -10...10), zIndex: nextZIndex); nextZIndex += 1
        stickerElements.append(el); selectedElementID = el.id; scheduleAutoSave()
    }
    
    private func addWashiTape(colorHex: String, pattern: WashiTapePattern) {
        toolPickerIsActive = false
        let el = WashiTapeElement(x: Double.random(in: 100...350), y: Double.random(in: 200...500), rotation: Double.random(in: -15...15), colorHex: colorHex, patternType: pattern, zIndex: nextZIndex); nextZIndex += 1
        washiTapeElements.append(el); selectedElementID = el.id; scheduleAutoSave()
    }
    
    private func handlePhotoPicker(items: [PhotosPickerItem]) {
        for item in items {
            item.loadTransferable(type: Data.self) { result in
                if case .success(let data) = result, let data = data, let img = UIImage(data: data),
                   let jpeg = img.jpegData(compressionQuality: 0.8), let fn = store.saveImage(jpeg, for: memory.id) {
                    DispatchQueue.main.async {
                        let el = ImageElement(fileName: fn, x: Double.random(in: 100...350), y: Double.random(in: 200...500), rotation: Double.random(in: -6...6), zIndex: nextZIndex); nextZIndex += 1
                        imageElements.append(el); loadedImages[fn] = img; memory.imageElements = imageElements; store.updateMemory(memory); selectedElementID = el.id; toolPickerIsActive = false
                    }
                }
            }
        }
        selectedPhotoItems = []
    }
    
    // MARK: - Picker Sheets
    private var shapePickerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Choose a shape").font(.headline)
                    ColorPicker("Shape Color", selection: $currentShapeColor).padding(.horizontal, 20)
                    Toggle("Filled", isOn: $currentShapeFilled).padding(.horizontal, 20)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 12) {
                        ForEach(ShapeType.allCases, id: \.self) { type in
                            Button { addShape(type: type); showShapePicker = false } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: type.icon).font(.title2).frame(width: 50, height: 50).background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                                    Text(type.rawValue.capitalized).font(.caption2).lineLimit(1).minimumScaleFactor(0.8)
                                }.frame(minHeight: 72)
                            }.buttonStyle(.plain)
                        }
                    }.padding(.horizontal, 20)
                }.padding(.top, 16)
            }.presentationDetents([.medium])
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showShapePicker = false } } }
        }
    }
    
    private var stickyColorSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Sticky Note Color").font(.headline)
                let colors: [(String, Color)] = [("Yellow", Color(hex: "FFED8E")), ("Pink", Color(hex: "FFB5C2")), ("Green", Color(hex: "B8E6B8")), ("Blue", Color(hex: "A8D8EA")), ("Lavender", Color(hex: "D4B8E0")), ("Orange", Color(hex: "FFD4A3")), ("White", Color(hex: "F5F5F5"))]
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 12) {
                    ForEach(colors, id: \.0) { name, color in
                        Button { showStickyColorPicker = false; addStickyNoteWithColor(color) } label: {
                            VStack(spacing: 4) { RoundedRectangle(cornerRadius: 8).fill(color).frame(width: 50, height: 50).shadow(color: .black.opacity(0.1), radius: 3, y: 2); Text(name).font(.caption2) }
                        }.buttonStyle(.plain)
                    }
                }.padding(.horizontal, 20)
                Spacer()
            }.padding(.top, 16).presentationDetents([.fraction(0.35)])
        }
    }
    
    private var stickerPickerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    let categories: [(String, [String])] = [
                        ("🗺️ Travel", ["🗼","✈️","🧳","🏯","🗻","🌸","🎌","⛩️","🚂","🗾","🎒","🌍","🏖️","⛱️","🚢"]),
                        ("🍱 Food", ["🍣","🍜","🍡","🍰","☕","🧁","🍙","🥟","🫖","🍩","🍪","🧃","🍦","🎂","🍫"]),
                        ("🐱 Animals", ["🐱","🐶","🦊","🐼","🐸","🦋","🐝","🐾","🦄","🐧","🐰","🦩","🐢","🦎","🐠"]),
                        ("⭐ Decorative", ["⭐","🌟","💫","✨","❤️","🎀","🌈","🔖","📌","🏷️","💝","🎯","🎪","🎨","🖌️"]),
                        ("🌿 Nature", ["🌿","🌺","🌻","🍁","🍂","🌙","☀️","🌊","🏔️","🌴","🌵","🍄","🌾","💐","🪻"]),
                        ("😊 Expressions", ["😊","🥰","😍","🤩","😎","🥳","😇","🤗","😂","🫶","👏","💪","🙌","👋","✌️"]),
                        ("🌤️ Weather", ["🌤️","⛅","🌦️","🌧️","⛈️","🌩️","❄️","🌨️","🌪️","🌫️","☃️","⚡","💧","🔥","🫧"]),
                        ("🎵 Music & Arts", ["🎵","🎶","🎸","🥁","🎹","🎤","🎧","🎭","🎬","📷","📸","🖍️","✏️","📝","📖"])
                    ]
                    ForEach(categories, id: \.0) { name, emojis in
                        Text(name).font(.headline).padding(.leading, 20)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 10) {
                            ForEach(emojis, id: \.self) { emoji in
                                Button { addSticker(emoji); showStickerPicker = false } label: { Text(emoji).font(.system(size: 36)).frame(width: 50, height: 50).background(.quaternary, in: RoundedRectangle(cornerRadius: 10)) }.buttonStyle(.plain)
                            }
                        }.padding(.horizontal, 20)
                    }
                }.padding(.vertical, 16)
            }.presentationDetents([.medium, .large])
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showStickerPicker = false } } }
        }
    }
    
    private var washiTapePickerSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Washi Tape").font(.headline)
                let tapeColors: [(String, String)] = [("Red", "E74C3C"), ("Pink", "FFB5C2"), ("Blue", "5DADE2"), ("Green", "58D68D"), ("Yellow", "F4D03F"), ("Orange", "F39C12"), ("Purple", "AF7AC5"), ("Mint", "76D7C4")]
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 12) {
                    ForEach(tapeColors, id: \.0) { name, hex in
                        Button { addWashiTape(colorHex: hex, pattern: .striped); showWashiTapePicker = false } label: {
                            VStack(spacing: 4) { RoundedRectangle(cornerRadius: 3).fill(Color(hex: hex).opacity(0.7)).frame(width: 70, height: 22).overlay { HStack(spacing: 4) { ForEach(0..<6, id: \.self) { _ in Rectangle().fill(.white.opacity(0.2)).frame(width: 1) } } }; Text(name).font(.caption2) }
                        }.buttonStyle(.plain)
                    }
                }.padding(.horizontal, 20)
                Spacer()
            }.padding(.top, 16).presentationDetents([.fraction(0.4)])
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showWashiTapePicker = false } } }
        }
    }
    
    private func addStamp(style: StampStyle, text: String, subText: String, colorHex: String) {
        toolPickerIsActive = false
        var el = StampElement(stampStyle: style, text: text, subText: subText, x: Double.random(in: 100...350), y: Double.random(in: 200...500), colorHex: colorHex, zIndex: nextZIndex); nextZIndex += 1
        // Adjust sizes per style
        switch style {
        case .boardingPass: el.width = 240; el.height = 100
        case .postcard: el.width = 220; el.height = 140
        case .receipt: el.width = 140; el.height = 180
        case .concertTicket: el.width = 170; el.height = 180
        case .movieTicket: el.width = 240; el.height = 110
        case .trainTicket: el.width = 230; el.height = 120
        case .hotelKey: el.width = 200; el.height = 120
        case .luggageTag: el.width = 120; el.height = 180
        default: break
        }
        el.rotation = Double.random(in: -8...8)
        stampElements.append(el); selectedElementID = el.id; scheduleAutoSave()
    }
    
    private var stampPickerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Travel Memorabilia").font(.title3.bold()).padding(.horizontal, 20)
                    
                    let stampItems: [(StampStyle, String, String, String, String)] = [
                        (.passportCircle, "Passport Stamp", "TOKYO", "2024", "C0392B"),
                        (.passportRect, "Entry Stamp", "PARIS", "2024", "2E4057"),
                        (.concertTicket, "Concert Ticket", "COLDPLAY", "2024", "8E44AD"),
                        (.movieTicket, "Movie Ticket", "Interstellar", "7:30 PM", "E67E22"),
                        (.trainTicket, "Train Ticket", "LONDON", "PARIS", "27AE60"),
                        (.boardingPass, "Boarding Pass", "NYC", "LAX", "2980B9"),
                        (.postcard, "Postcard", "Wish you were here!", "From Italy", "D4A574"),
                        (.receipt, "Receipt", "CAFÉ PARIS", "$22.14", "333333"),
                        (.luggageTag, "Luggage Tag", "J. SMITH", "FLT 247", "C0392B"),
                        (.hotelKey, "Hotel Key", "GRAND PLAZA", "1204", "2E4057")
                    ]
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 16) {
                        ForEach(stampItems, id: \.0) { style, name, text, subText, colorHex in
                            Button {
                                addStamp(style: style, text: text, subText: subText, colorHex: colorHex)
                                showStampPicker = false
                            } label: {
                                VStack(spacing: 8) {
                                    // Preview
                                    stampPreview(style: style, text: text, subText: subText, colorHex: colorHex)
                                        .frame(width: 120, height: 80)
                                        .clipped()
                                    Text(name)
                                        .font(.caption.bold())
                                        .foregroundStyle(.primary)
                                }
                                .padding(12)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Text("Stamp Colors").font(.headline).padding(.horizontal, 20).padding(.top, 8)
                    let colors: [(String, String)] = [("Red", "C0392B"), ("Navy", "2E4057"), ("Purple", "8E44AD"), ("Blue", "2980B9"), ("Forest", "27AE60"), ("Brown", "8B6914"), ("Black", "333333"), ("Coral", "E74C3C")]
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 10) {
                        ForEach(colors, id: \.0) { name, hex in
                            Button {
                                addStamp(style: .passportCircle, text: "TRAVEL", subText: "2024", colorHex: hex)
                                showStampPicker = false
                            } label: {
                                VStack(spacing: 4) {
                                    Circle().fill(Color(hex: hex)).frame(width: 36, height: 36)
                                    Text(name).font(.caption2).foregroundStyle(.primary)
                                }
                            }.buttonStyle(.plain)
                        }
                    }.padding(.horizontal, 20)
                }.padding(.vertical, 16)
            }
            .presentationDetents([.medium, .large])
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showStampPicker = false } } }
        }
    }
    
    @ViewBuilder
    private func stampPreview(style: StampStyle, text: String, subText: String, colorHex: String) -> some View {
        let color = Color(hex: colorHex)
        switch style {
        case .passportCircle:
            ZStack {
                Circle().stroke(color.opacity(0.7), lineWidth: 2)
                VStack(spacing: 1) {
                    Text("✈").font(.system(size: 10))
                    Text(text).font(.system(size: 8, weight: .black, design: .serif)).foregroundStyle(color.opacity(0.8))
                    Text(subText).font(.system(size: 6, weight: .bold, design: .monospaced)).foregroundStyle(color.opacity(0.6))
                }
            }.scaleEffect(0.85)
        case .passportRect:
            ZStack {
                RoundedRectangle(cornerRadius: 3).stroke(color.opacity(0.7), lineWidth: 2)
                VStack(spacing: 2) {
                    Text(text).font(.system(size: 8, weight: .black, design: .serif)).foregroundStyle(color.opacity(0.8))
                    Text(subText).font(.system(size: 6, design: .monospaced)).foregroundStyle(color.opacity(0.6))
                }
            }.scaleEffect(0.85)
        case .concertTicket:
            ZStack {
                RoundedRectangle(cornerRadius: 5).fill(color.opacity(0.06))
                RoundedRectangle(cornerRadius: 5).stroke(color.opacity(0.3), lineWidth: 1)
                VStack(spacing: 2) {
                    Text("🎵").font(.system(size: 10))
                    Text(text).font(.system(size: 7, weight: .bold)).foregroundStyle(color)
                    Text("CONCERT").font(.system(size: 5, weight: .heavy, design: .monospaced)).foregroundStyle(color.opacity(0.4))
                }
            }
        case .movieTicket:
            ZStack {
                RoundedRectangle(cornerRadius: 5).fill(.white).shadow(color: .black.opacity(0.04), radius: 2)
                HStack(spacing: 3) {
                    Text("🎬").font(.system(size: 10))
                    Text(text.prefix(8)).font(.system(size: 7, weight: .bold)).foregroundStyle(.black.opacity(0.7))
                }
            }
        case .trainTicket:
            ZStack {
                RoundedRectangle(cornerRadius: 4).fill(color.opacity(0.04))
                RoundedRectangle(cornerRadius: 4).stroke(color.opacity(0.2), lineWidth: 1)
                HStack(spacing: 3) {
                    Text("🚂").font(.system(size: 9))
                    Text(text.prefix(3)).font(.system(size: 8, weight: .black)).foregroundStyle(color)
                    Text("→").font(.system(size: 7)).foregroundStyle(color.opacity(0.3))
                    Text(subText.prefix(3)).font(.system(size: 8, weight: .black)).foregroundStyle(color)
                }
            }
        case .boardingPass:
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(.white).shadow(color: .black.opacity(0.06), radius: 2)
                HStack(spacing: 4) {
                    Text(text.prefix(3)).font(.system(size: 10, weight: .black)).foregroundStyle(color)
                    Image(systemName: "airplane").font(.system(size: 8)).foregroundStyle(color.opacity(0.4))
                    Text(subText.prefix(3)).font(.system(size: 10, weight: .black)).foregroundStyle(color)
                }
            }
        case .postcard:
            ZStack {
                RoundedRectangle(cornerRadius: 4).fill(Color(red: 0.99, green: 0.97, blue: 0.94))
                RoundedRectangle(cornerRadius: 4).stroke(color.opacity(0.2), lineWidth: 0.5)
                Text(text.prefix(14)).font(.system(size: 7, design: .serif)).foregroundStyle(.gray).italic()
            }
        case .receipt:
            ZStack {
                RoundedRectangle(cornerRadius: 2).fill(.white).shadow(color: .black.opacity(0.04), radius: 2)
                VStack(spacing: 2) {
                    Text(text.prefix(10)).font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundStyle(.black.opacity(0.6))
                    Text(subText).font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(.black.opacity(0.7))
                }
            }
        case .luggageTag:
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.08))
                RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.3), lineWidth: 1)
                VStack(spacing: 2) {
                    Text("🏷️").font(.system(size: 10))
                    Text(text.prefix(6)).font(.system(size: 7, weight: .bold)).foregroundStyle(color)
                }
            }
        case .hotelKey:
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(color.opacity(0.08))
                RoundedRectangle(cornerRadius: 6).stroke(color.opacity(0.2), lineWidth: 1)
                HStack(spacing: 4) {
                    Image(systemName: "key.fill").font(.system(size: 10)).foregroundStyle(color.opacity(0.4))
                    Text(subText).font(.system(size: 10, weight: .black)).foregroundStyle(color)
                }
            }
        }
    }

    
    private var fontPickerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    Text("Choose Font").font(.headline)
                    let fonts = ["Bradley Hand", "Noteworthy", "Marker Felt", "Chalkduster", "Helvetica Neue", "Georgia", "Courier New", "Avenir Next"]
                    ForEach(fonts, id: \.self) { fontName in
                        Button {
                            if let id = selectedElementID, let idx = textElements.firstIndex(where: { $0.id == id }) {
                                textElements[idx].fontName = fontName; scheduleAutoSave()
                            }
                            showFontPicker = false
                        } label: {
                            Text("The quick brown fox").font(.custom(fontName, size: 20)).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).padding(.vertical, 6)
                        }.buttonStyle(.plain)
                        if fontName != fonts.last { Divider().padding(.horizontal, 20) }
                    }
                }.padding(.top, 16)
            }.presentationDetents([.medium])
        }
    }
}
