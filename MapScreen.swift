import SwiftUI
import MapKit
import CoreLocation
import Combine

// Make CLLocationCoordinate2D equatable for onChange
extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

// MARK: - Location Manager

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var userLocation: CLLocationCoordinate2D?
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            userLocation = location.coordinate
            manager.stopUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}

// MARK: - Map Screen

struct MapScreen: View {
    @EnvironmentObject var store: MemoryStore
    @StateObject private var locationManager = LocationManager()
    
    // Map
    @State private var cameraPosition: MapCameraPosition = .automatic
    
    // Pin Placement
    @State private var isPlacingPin = false
    @State private var tempPinCoordinate: CLLocationCoordinate2D?
    @State private var dragOffset: CGSize = .zero
    
    // Navigation
    @State private var selectedMemory: Memory?
    
    // Template Chooser
    @State private var showTemplateChooser = false
    @State private var pendingCoordinate: CLLocationCoordinate2D?
    
    // Geometry
    @State private var mapSize: CGSize = .zero
    
    // Sidebar
    @State private var showSidebar = false

    
    var body: some View {
        NavigationStack {
            ZStack {
                // MARK: Map
                mapLayer
                
                // MARK: Confirmation Bar
                if isPlacingPin {
                    confirmationBar
                }
                
                // MARK: Sidebar Overlay
                if showSidebar {
                    sidebarOverlay
                }
                
                // MARK: Hint Banner
                if store.memories.isEmpty && !isPlacingPin && !showSidebar {
                    VStack {
                        HStack(spacing: 10) {
                            Image(systemName: "hand.tap")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(Color(red: 0.56, green: 0.52, blue: 0.96))
                            Text("Tap on the map to place a memory pin")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .navigationTitle("Memory Atlas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !showSidebar {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                showSidebar.toggle()
                            }
                        } label: {
                            Image(systemName: "sidebar.leading")
                        }
                    }
                }
            }
            .fullScreenCover(item: $selectedMemory) { memory in
                MemoryPageView(memory: memory)
                    .environmentObject(store)
            }
            .sheet(isPresented: $showTemplateChooser) {
                TemplateChooserView(
                    onCancel: {
                        showTemplateChooser = false
                        pendingCoordinate = nil
                    },
                    onSelect: { template, name in
                        createMemoryWithTemplate(template, name: name)
                    }
                )
            }
            .onAppear {
                if let loc = locationManager.userLocation {
                    cameraPosition = .region(MKCoordinateRegion(
                        center: loc,
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    ))
                }
            }
            .onChange(of: locationManager.userLocation) { _, newLoc in
                if let loc = newLoc, !isPlacingPin {
                    cameraPosition = .region(MKCoordinateRegion(
                        center: loc,
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    ))
                }
            }
        }
    }
    
    // MARK: - Map Layer
    
    private var mapLayer: some View {
        MapReader { proxy in
            Map(position: $cameraPosition, interactionModes: .all) {
                // Saved memory pins
                ForEach(store.memories) { memory in
                    Annotation(memory.placeName, coordinate: memory.coordinate) {
                        Button {
                            selectedMemory = memory
                        } label: {
                            VStack(spacing: 0) {
                                Image(systemName: "heart.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(.white, Color(red: 0.56, green: 0.52, blue: 0.96))
                                    .shadow(color: Color(red: 0.56, green: 0.52, blue: 0.96).opacity(0.4), radius: 4, y: 2)
                                
                                Image(systemName: "triangle.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(Color(red: 0.56, green: 0.52, blue: 0.96))
                                    .rotationEffect(.degrees(180))
                                    .offset(y: -3)
                            }
                        }
                    }
                }
                
                // Temporary pin while placing
                if let coord = tempPinCoordinate, isPlacingPin {
                    Annotation("New Memory", coordinate: coord) {
                        VStack(spacing: 0) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.white, Color(red: 0.56, green: 0.52, blue: 0.96))
                                .shadow(color: Color(red: 0.56, green: 0.52, blue: 0.96).opacity(0.5), radius: 6, y: 3)
                            
                            Image(systemName: "triangle.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(Color(red: 0.56, green: 0.52, blue: 0.96))
                                .rotationEffect(.degrees(180))
                                .offset(y: -3)
                        }
                        .scaleEffect(1.2)
                        .animation(.spring(response: 0.3), value: tempPinCoordinate?.latitude)
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .onTapGesture { screenCoord in
                if !isPlacingPin {
                    if let coordinate = proxy.convert(screenCoord, from: .local) {
                        startPinPlacement(at: coordinate)
                    }
                }
            }
            .overlay {
                GeometryReader { geo in
                    Color.clear.onAppear {
                        mapSize = geo.size
                    }
                }
            }
        }
    }
    
    
    
    
    // MARK: - Confirmation Bar
    
    private var confirmationBar: some View {
        VStack {
            Spacer()
            
            HStack(spacing: 40) {
                // Cancel
                Button {
                    cancelPinPlacement()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color(red: 1.0, green: 0.56, blue: 0.69).gradient, in: Circle())
                        .shadow(color: Color(red: 1.0, green: 0.56, blue: 0.69).opacity(0.4), radius: 8, y: 4)
                }
                
                // Confirm
                Button {
                    confirmPinPlacement()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color(red: 0.47, green: 0.87, blue: 0.68).gradient, in: Circle())
                        .shadow(color: Color(red: 0.47, green: 0.87, blue: 0.68).opacity(0.4), radius: 8, y: 4)
                }
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 40)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
            .padding(.bottom, 30)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isPlacingPin)
    }
    
    // MARK: - Sidebar Overlay
    
    private var sortedMemories: [Memory] {
        store.memories.sorted { $0.lastEditedDate > $1.lastEditedDate }
    }
    
    private var sidebarOverlay: some View {
        ZStack(alignment: .leading) {
            // Dimmed background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                        showSidebar = false
                    }
                }
            
            // Native-style sidebar panel
            VStack(spacing: 0) {
                // Header — only "Memories" heading
                Text("Memories")
                    .font(.title.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 20)
                    .padding(.trailing, 12)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                
                // Pin list
                if store.memories.isEmpty {
                    VStack(spacing: 10) {
                        Spacer()
                        Image(systemName: "mappin.slash")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                        Text("No Pins Yet")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("Tap on the map to add a memory.")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    List {
                        ForEach(sortedMemories) { memory in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                    showSidebar = false
                                }
                                withAnimation(.easeInOut(duration: 0.8)) {
                                    cameraPosition = .region(MKCoordinateRegion(
                                        center: memory.coordinate,
                                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                                    ))
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    selectedMemory = memory
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "heart.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundStyle(.white, Color(red: 0.56, green: 0.52, blue: 0.96))
                                    
                                    Text(memory.placeName.isEmpty ? "Unknown Location" : memory.placeName)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(.black)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color(.tertiaryLabel))
                                }
                                .padding(.vertical, 4)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    store.deleteMemory(memory)
                                } label: {
                                    Image(systemName: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .frame(width: 340)
            .frame(maxHeight: .infinity)
            .padding(.bottom, 5)
            .padding(.leading, 5)
            .background(Color(.systemGroupedBackground), in: UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: 16, topTrailingRadius: 16))
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: 16, topTrailingRadius: 16))
            .transition(.move(edge: .leading).combined(with: .opacity))
        }
    }
    
    // MARK: - Actions
    
    private func startPinPlacement(at coordinate: CLLocationCoordinate2D) {
        withAnimation(.spring(response: 0.3)) {
            tempPinCoordinate = coordinate
            isPlacingPin = true
        }
    }
    
    private func cancelPinPlacement() {
        withAnimation(.spring(response: 0.3)) {
            isPlacingPin = false
            tempPinCoordinate = nil
        }
    }
    
    private func confirmPinPlacement() {
        guard let coordinate = tempPinCoordinate else { return }
        
        pendingCoordinate = coordinate
        
        withAnimation(.spring(response: 0.3)) {
            isPlacingPin = false
            tempPinCoordinate = nil
        }
        
        // Show template chooser
        showTemplateChooser = true
    }
    
    private func createMemoryWithTemplate(_ template: MemoryTemplate, name: String) {
        guard let coordinate = pendingCoordinate else { return }
        
        let elements = template.generateElements()
        let memory = Memory(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            placeName: name,
            createdDate: Date(),
            textElements: elements.textElements,
            stickyNotes: elements.stickyNotes,
            shapeElements: elements.shapeElements,
            stickerElements: elements.stickerElements,
            washiTapeElements: elements.washiTapeElements
        )
        
        store.addMemory(memory)
        showTemplateChooser = false
        pendingCoordinate = nil
        
        // Open the memory page
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            selectedMemory = memory
        }
    }
}
