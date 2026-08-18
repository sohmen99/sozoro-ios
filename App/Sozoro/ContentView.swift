import SwiftUI
import MapKit
import SozoroCore

/// 混雑の地図と、そこから歩き方を決めるシート。
/// ウェブ版の「表紙→地図→シート」をそのまま持ってきている。
struct ContentView: View {
    @EnvironmentObject var location: LocationService
    @StateObject private var model = WalkModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            CrowdMap(spots: model.visibleSpots, here: location.coordinate, picks: model.picks)
                .ignoresSafeArea()

            switch model.stage {
            case .planning: sheet
            case .picking:  PickView(model: model)
            case .walking:  CompassView(model: model)
            case .arrived:  ArrivalView(model: model)
            }
        }
        .onChange(of: location.coordinate) { _, c in model.here = c }
        .onChange(of: location.heading) { _, h in model.heading = h }
        .onAppear { model.here = location.coordinate }
    }

    private var sheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Capsule().fill(.quaternary).frame(width: 38, height: 4)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 3) {
                Text("Where should we wander?").font(.title2.weight(.semibold))
                Text("Tell us what you're after. We draw from the quiet side, and keep the spot to ourselves.")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            label("Looking for")
            HStack(spacing: 8) {
                ForEach(Kind.allCases, id: \.self) { k in
                    Chip(title: k == .food ? "Something to eat" : "Something old",
                         icon: k == .food ? "fork.knife" : "building.columns",
                         on: model.kinds.contains(k)) { model.toggle(k) }
                }
            }

            label("How you walk")
            VStack(spacing: 8) {
                ModeRow(title: "Wander", icon: "dice",
                        note: "One stop at a time, about 15 minutes each. Stop whenever you like.",
                        on: model.mode == .wander) { model.mode = .wander }
                ModeRow(title: "Cross town", icon: "point.topleft.down.to.point.bottomright.curvepath",
                        note: "A fixed line out to a station. Two or three stops, then a train home.",
                        on: model.mode == .crossTown) { model.mode = .crossTown }
            }

            Button {
                model.begin()
            } label: {
                Text(model.here == nil ? "Looking for you…" : "Begin")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent).tint(.primary)
            .disabled(model.here == nil)

            if let m = model.note {
                Text(m).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(10)
    }

    private func label(_ s: String) -> some View {
        Text(s.uppercased()).font(.caption2.weight(.semibold))
            .tracking(1.4).foregroundStyle(.tertiary)
    }
}

struct Chip: View {
    let title: String, icon: String, on: Bool
    let tap: () -> Void
    var body: some View {
        Button(action: tap) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.caption)
                Text(title).font(.footnote.weight(.medium))
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(on ? Color.primary : Color.clear,
                        in: Capsule())
            .foregroundStyle(on ? Color(.systemBackground) : Color.primary)
            .overlay(Capsule().stroke(.quaternary, lineWidth: on ? 0 : 1))
        }
        .buttonStyle(.plain)
    }
}

struct ModeRow: View {
    let title: String, icon: String, note: String, on: Bool
    let tap: () -> Void
    var body: some View {
        Button(action: tap) {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: icon).font(.body).frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title).font(.subheadline.weight(.semibold))
                        if on { Image(systemName: "checkmark").font(.caption2) }
                    }
                    Text(note).font(.caption).opacity(0.72)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(on ? Color.primary : Color.clear,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .foregroundStyle(on ? Color(.systemBackground) : Color.primary)
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.quaternary, lineWidth: on ? 0 : 1))
            .opacity(on ? 1 : 0.66)
        }
        .buttonStyle(.plain)
    }
}

/// 地図。基準地点の混み具合を色で出す。ウェブ版のヒートマップにあたる。
struct CrowdMap: View {
    let spots: [(Spot, Int)]
    let here: Coordinate?
    let picks: [Spot]

    @State private var camera: MapCameraPosition = .region(
        MKCoordinateRegion(center: .init(latitude: 35.7138, longitude: 139.7772),
                           span: MKCoordinateSpan(latitudeDelta: 0.035, longitudeDelta: 0.035)))

    var body: some View {
        Map(position: $camera) {
            ForEach(spots, id: \.0.id) { item in
                let (s, crowd) = item
                Annotation("", coordinate: .init(latitude: s.coordinate.lat, longitude: s.coordinate.lon)) {
                    Circle().fill(colour(crowd)).frame(width: 9, height: 9)
                        .overlay(Circle().stroke(.white.opacity(0.85), lineWidth: 1.4))
                }
            }
            if let h = here {
                Annotation("", coordinate: .init(latitude: h.lat, longitude: h.lon)) {
                    ZStack {
                        Circle().fill(.blue.opacity(0.18)).frame(width: 34, height: 34)
                        Circle().fill(.blue).frame(width: 13, height: 13)
                            .overlay(Circle().stroke(.white, lineWidth: 2.5))
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
    }

    /// 空いている=緑 / ふつう=琥珀 / 混雑=朱。ウェブ版と同じ切り方。
    func colour(_ c: Int) -> Color {
        c <= 45 ? Color(red: 0.25, green: 0.44, blue: 0.31)
      : c <= 75 ? Color(red: 0.54, green: 0.40, blue: 0.09)
                : Color(red: 0.70, green: 0.15, blue: 0.12)
    }
}
