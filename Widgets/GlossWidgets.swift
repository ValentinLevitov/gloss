import SwiftUI
import WidgetKit

@main
struct GlossWidgets: WidgetBundle {
    var body: some Widget {
        CameraWidget()
        StudyWidget()
    }
}

private struct StaticEntry: TimelineEntry {
    let date = Date()
    let count: Int
}

private struct StaticProvider: TimelineProvider {
    func placeholder(in context: Context) -> StaticEntry { StaticEntry(count: 0) }
    func getSnapshot(in context: Context, completion: @escaping (StaticEntry) -> Void) { completion(StaticEntry(count: cardsToLearn())) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<StaticEntry>) -> Void) {
        completion(Timeline(entries: [StaticEntry(count: cardsToLearn())], policy: .after(Date().addingTimeInterval(1800))))
    }

    /// Reads the shared cards file directly; the widget process must not depend on app code.
    private func cardsToLearn() -> Int {
        guard let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.vlevitov.translator"),
              let data = try? Data(contentsOf: dir.appendingPathComponent("cards.json")),
              let cards = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return 0 }
        return cards.filter { $0["learnedAt"] == nil }.count
    }
}

/// Lock-screen / home-screen button: opens the app straight into the camera.
struct CameraWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.vlevitov.translator.camera", provider: StaticProvider()) { _ in
            CameraWidgetView()
                .widgetURL(URL(string: "gloss://camera"))
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Translate with camera")
        .description("Snap a photo of text and translate it.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .systemSmall])
    }
}

private struct CameraWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "camera.viewfinder").font(.title2)
            }
        case .accessoryRectangular:
            HStack {
                Image(systemName: "camera.viewfinder").font(.title2)
                VStack(alignment: .leading) {
                    Text("Gloss").font(.headline)
                    Text("Translate with camera").font(.caption)
                }
            }
        default:
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "camera.viewfinder").font(.largeTitle)
                Spacer()
                Text("Translate").font(.headline)
                Text("with camera").font(.subheadline).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

/// Lock-screen / home-screen button: opens study mode, showing how many words are waiting.
struct StudyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.vlevitov.translator.study", provider: StaticProvider()) { entry in
            StudyWidgetView(count: entry.count)
                .widgetURL(URL(string: "gloss://study"))
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Study words")
        .description("Your flashcards, one tap away.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .systemSmall])
    }
}

private struct StudyWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let count: Int

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "rectangle.stack").font(.caption)
                    Text("\(count)").font(.headline)
                }
            }
        case .accessoryRectangular:
            HStack {
                Image(systemName: "rectangle.stack").font(.title2)
                VStack(alignment: .leading) {
                    Text("\(count) words").font(.headline)
                    Text("to learn").font(.caption)
                }
            }
        default:
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "rectangle.stack").font(.largeTitle)
                Spacer()
                Text("\(count)").font(.system(size: 34, weight: .bold))
                Text("words to learn").font(.subheadline).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
