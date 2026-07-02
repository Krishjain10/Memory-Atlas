import SwiftUI

struct SplashScreen: View {
    @State private var iconScale: CGFloat = 0.3
    @State private var iconOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 20
    @State private var subtitleOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.5
    @State private var ringOpacity: Double = 0
    @State private var ring2Rotation: Double = 0
    @State private var floatingPins: [FloatingPin] = []
    @State private var pinsVisible = false
    @State private var gradientPhase: CGFloat = 0
    
    // Pastel palette
    private let lavender = Color(red: 0.56, green: 0.52, blue: 0.96)
    private let coral = Color(red: 1.0, green: 0.56, blue: 0.69)
    private let mint = Color(red: 0.47, green: 0.87, blue: 0.68)
    private let peach = Color(red: 1.0, green: 0.78, blue: 0.64)
    private let softBlue = Color(red: 0.55, green: 0.73, blue: 1.0)
    
    struct FloatingPin: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        let emoji: String
        let delay: Double
        let size: CGFloat
    }
    
    var body: some View {
        ZStack {
            // Dreamy gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.93, blue: 1.0),
                    Color(red: 0.97, green: 0.94, blue: 0.98),
                    Color(red: 0.96, green: 0.97, blue: 1.0),
                    Color(red: 0.98, green: 0.95, blue: 0.97)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Soft blurred orbs for depth
            Circle()
                .fill(lavender.opacity(0.12))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: -100, y: -200)
            
            Circle()
                .fill(coral.opacity(0.1))
                .frame(width: 250, height: 250)
                .blur(radius: 70)
                .offset(x: 120, y: 200)
            
            Circle()
                .fill(mint.opacity(0.08))
                .frame(width: 200, height: 200)
                .blur(radius: 60)
                .offset(x: 80, y: -300)
            
            // Floating memory emojis
            ForEach(floatingPins) { pin in
                Text(pin.emoji)
                    .font(.system(size: pin.size))
                    .opacity(pinsVisible ? 0.2 : 0)
                    .offset(y: pinsVisible ? -12 : 12)
                    .position(x: pin.x, y: pin.y)
                    .animation(
                        .easeInOut(duration: 2.8)
                        .repeatForever(autoreverses: true)
                        .delay(pin.delay),
                        value: pinsVisible
                    )
            }
            
            // Center content
            VStack(spacing: 24) {
                ZStack {
                    // Outer decorative ring
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [lavender.opacity(0.2), coral.opacity(0.15), mint.opacity(0.2), lavender.opacity(0.2)],
                                center: .center
                            ),
                            lineWidth: 1.5
                        )
                        .frame(width: 170, height: 170)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)
                        .rotationEffect(.degrees(ring2Rotation))
                    
                    // Inner decorative ring
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [coral.opacity(0.2), peach.opacity(0.15), softBlue.opacity(0.2), coral.opacity(0.2)],
                                center: .center
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 140, height: 140)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)
                    
                    // App icon
                    ZStack {
                        // Gradient circle background
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [lavender, coral.opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 110, height: 110)
                            .shadow(color: lavender.opacity(0.4), radius: 24, y: 10)
                        
                        // Map icon
                        Image(systemName: "map.fill")
                            .font(.system(size: 44, weight: .medium))
                            .foregroundStyle(.white)
                        
                        // Heart accent
                        Image(systemName: "heart.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.9))
                            .offset(x: 24, y: -24)
                        
                        // Sparkle accent
                        Image(systemName: "sparkle")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.8))
                            .offset(x: -28, y: -20)
                    }
                    .scaleEffect(iconScale)
                    .opacity(iconOpacity)
                }
                
                VStack(spacing: 10) {
                    Text("Memory Atlas")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.35, green: 0.30, blue: 0.58),
                                    Color(red: 0.56, green: 0.42, blue: 0.68)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .opacity(titleOpacity)
                        .offset(y: titleOffset)
                    
                    Text("Your stories, pinned to the world")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(lavender.opacity(0.6))
                        .opacity(subtitleOpacity)
                }
            }
        }
        .onAppear {
            setupFloatingPins()
            animateIn()
        }
    }
    
    private func setupFloatingPins() {
        let emojis = ["📌", "🗺️", "✈️", "🌸", "📷", "⭐", "🏔️", "🌊", "🎒", "💝"]
        let screenW = UIScreen.main.bounds.width
        let screenH = UIScreen.main.bounds.height
        
        floatingPins = emojis.enumerated().map { i, emoji in
            FloatingPin(
                x: CGFloat.random(in: 40...(screenW - 40)),
                y: CGFloat.random(in: 60...(screenH - 60)),
                emoji: emoji,
                delay: Double(i) * 0.15,
                size: CGFloat.random(in: 28...42)
            )
        }
    }
    
    private func animateIn() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.65).delay(0.2)) {
            iconScale = 1.0
            iconOpacity = 1.0
        }
        
        withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
            ringScale = 1.0
            ringOpacity = 1.0
        }
        
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            ring2Rotation = 360
        }
        
        withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
            titleOpacity = 1.0
            titleOffset = 0
        }
        
        withAnimation(.easeOut(duration: 0.5).delay(0.7)) {
            subtitleOpacity = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation { pinsVisible = true }
        }
    }
}
