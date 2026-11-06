import AVFoundation
import Charts
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

// Instrument Sans is bundled locally; semantic styles preserve iOS Dynamic Type scaling.
enum NutrientType {
  static func font(_ style: Font.TextStyle, weight: Font.Weight? = nil) -> Font {
    let size: CGFloat
    switch style {
    case .largeTitle: size = 34
    case .title: size = 28
    case .title2: size = 22
    case .title3: size = 20
    case .headline, .body: size = 17
    case .callout: size = 16
    case .subheadline: size = 15
    case .footnote: size = 13
    case .caption: size = 12
    case .caption2: size = 11
    default: size = 17
    }
    let chosen = weight ?? (style == .headline ? .semibold : .regular)
    let face = chosen == .bold ? "InstrumentSans-Bold" : chosen == .semibold ? "InstrumentSans-SemiBold"
      : chosen == .medium ? "InstrumentSans-Medium" : "InstrumentSans-Regular"
    return .custom(face, size: size, relativeTo: style)
  }
}

struct NutrientAppView: View {
  @StateObject private var store: NutrientStore
  init() {
    #if DEBUG
      if NativeDesignFixture.enabled {
        let storage = FileManager.default.temporaryDirectory.appendingPathComponent(
          "nutrient-design-fixture.json")
        let preview = NutrientStore(storageURL: storage, mirrorPreferences: false)
        NativeDesignFixture.prepare(preview)
        _store = StateObject(wrappedValue: preview)
        return
      }
    #endif
    _store = StateObject(wrappedValue: NutrientStore())
  }
  @ViewBuilder private var content: some View {
    #if DEBUG
      if NativeDesignFixture.enabled {
        switch NativeDesignFixture.argument("--design-screen") {
        case "review": NativeMealReview(items: NativeDesignFixture.ingredients)
        case "trends": NavigationStack { NativeTrends() }
        case "diary": NavigationStack { NativeDiary() }
        case "library": NavigationStack { NativeLibrary() }
        case "saved-meal": NativeSavedMealDetail(food: store.food("fixture-recipe")!)
        case "edit-meal": NativeMealBuilder(existing: store.food("fixture-recipe")!, initialItems: NativeDesignFixture.ingredients)
        case "nutrient": NavigationStack { NativeNutrientDetail(id: "protein") }
        case "chat": NativeChat()
        default: NativeToday()
        }
      } else {
        NativeToday()
      }
    #else
      NativeToday()
    #endif
  }
  var body: some View {
    content
      .sheet(isPresented: $store.showingChat) {
        NativeChat().environmentObject(store).presentationDragIndicator(.visible)
      }
      .environmentObject(store).tint(nutrientGreen)
      .font(NutrientType.font(.body))
      .foregroundStyle(Color("FieldInk"))
      .task {
        #if DEBUG
          if NativeDesignFixture.enabled {
            if ["reading", "follow"].contains(NativeDesignFixture.argument("--design-fixture") ?? "") {
              try? await Task.sleep(for: .seconds(2))
              store.state.chatHistory = store.history + [NativeMessage(
                role: "assistant", content: "New assistant response at the end of the conversation.")]
            }
            if NativeDesignFixture.argument("--design-fixture") == "motion" {
              try? await Task.sleep(for: .seconds(2))
              store.log(NativeDesignFixture.ingredients, meal: "Dinner")
            }
            return
          }
        #endif
        await store.loadDatabase()
      }
      .alert(
        "Couldn't complete that",
        isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })
      ) {
        Button("OK", role: .cancel) { store.error = nil }
      } message: {
        Text(store.error ?? "")
      }
  }
}
let calorieAccent = Color("FieldOchre")

// Spacing describes relationships; Dynamic Type may grow every minimum.
enum FieldSpace {
  static let tight: CGFloat = 4
  static let item: CGFloat = 8
  static let controls: CGFloat = 12
  static let inset: CGFloat = 16
  static let gutter: CGFloat = 20
  static let section: CGFloat = 24
  static let row: CGFloat = 52
}
struct FieldValuePair<Leading: View, Trailing: View>: View {
  @ViewBuilder var leading: Leading
  @ViewBuilder var trailing: Trailing
  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .firstTextBaseline, spacing: FieldSpace.item) {
        leading.fixedSize(horizontal: true, vertical: false)
        Spacer(minLength: FieldSpace.item)
        trailing.fixedSize(horizontal: true, vertical: false)
      }
      VStack(alignment: .leading, spacing: FieldSpace.tight) {
        leading
        trailing
      }.frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}
// Shared native surfaces: field-journal colors with system controls and Dynamic Type.
struct FieldSurface: ViewModifier {
  func body(content: Content) -> some View {
    content.scrollContentBackground(.hidden)
      .background(Color("FieldBackground"))
      .scrollIndicators(.hidden)
      .listRowSeparatorTint(Color("FieldRule"))
      .environment(\.defaultMinListRowHeight, FieldSpace.row)
      .monospacedDigit()
  }
}
extension View {
  func fieldSurface() -> some View { modifier(FieldSurface()) }
  func fieldTitle(_ title: String) -> some View {
    navigationTitle(title).navigationBarTitleDisplayMode(.inline)
  }
}
struct FieldSegmentedStyle: ViewModifier {
  @Environment(\.dynamicTypeSize) private var typeSize
  @ViewBuilder func body(content: Content) -> some View {
    if typeSize.isAccessibilitySize {
      content.pickerStyle(.menu)
    } else {
      content.pickerStyle(.segmented)
    }
  }
}
extension View {
  func fieldSegments() -> some View { modifier(FieldSegmentedStyle()) }
}
struct FieldList<Content: View>: View {
  @ViewBuilder var content: Content
  var body: some View {
    List { content.listRowBackground(Color("FieldSurface")) }
      .listStyle(.insetGrouped).listSectionSpacing(FieldSpace.section).fieldSurface()
  }
}
struct FieldForm<Content: View>: View {
  @ViewBuilder var content: Content
  var body: some View {
    Form { content.listRowBackground(Color("FieldSurface")) }.fieldSurface()
  }
}
// Align the actual circles, independent of title or detail wrapping in either column.
private enum NutrientRingCenter: AlignmentID {
  static func defaultValue(in dimensions: ViewDimensions) -> CGFloat { dimensions[VerticalAlignment.center] }
}
private extension VerticalAlignment {
  static let nutrientRingCenter = VerticalAlignment(NutrientRingCenter.self)
}
struct DashboardRing: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var typeSize
  let title: String
  let value: Double
  let target: Double
  let unit: String
  let detail: String
  let color: Color
  var opensDetail = false
  private var fraction: Double { min(1, max(0, value / max(1, target))) }
  var body: some View {
    VStack(spacing: FieldSpace.item) {
      HStack(spacing: 5) {
        Text(title).font(NutrientType.font(.subheadline, weight: .semibold))
        if opensDetail {
          Image(systemName: "chevron.right").font(NutrientType.font(.caption, weight: .semibold))
            .foregroundStyle(Color("FieldSecondary")).accessibilityHidden(true)
        }
      }
      if typeSize.isAccessibilitySize {
        Text("\(number(value)) \(unit)").font(NutrientType.font(.title, weight: .semibold))
          .contentTransition(.numericText(value: value))
          .fixedSize(horizontal: false, vertical: true)
        ProgressView(value: fraction).tint(color)
      } else {
        ZStack {
          Circle().stroke(Color("FieldRule"), lineWidth: 5)
          Circle().trim(from: 0, to: fraction).stroke(
            color, style: StrokeStyle(lineWidth: 5, lineCap: .round)
          ).rotationEffect(.degrees(-90))
          VStack(spacing: 2) {
            Text(number(value)).font(NutrientType.font(.title, weight: .medium)).tracking(-0.7)
              .lineLimit(1).minimumScaleFactor(0.6)
              .contentTransition(.numericText(value: value))
            Text(unit).font(NutrientType.font(.subheadline)).foregroundStyle(Color("FieldSecondary"))
          }
        }.frame(width: 104, height: 104)
          .alignmentGuide(.nutrientRingCenter) { $0[VerticalAlignment.center] }
      }
      Text(detail).font(NutrientType.font(.subheadline)).foregroundStyle(Color("FieldSecondary"))
        .fixedSize(horizontal: false, vertical: true)
    }.multilineTextAlignment(.center).frame(maxWidth: .infinity)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("\(title), \(number(value)) \(unit), \(detail)")
      .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: value)
  }
}
// A compact mark shared by the header and the original vector app icon.
struct NutrientMark: Shape {
  func path(in rect: CGRect) -> Path {
    var p = Path()
    p.move(to: CGPoint(x: rect.width * 0.16, y: rect.height * 0.82))
    p.addLine(to: CGPoint(x: rect.width * 0.16, y: rect.height * 0.18))
    p.addLine(to: CGPoint(x: rect.width * 0.84, y: rect.height * 0.82))
    p.addLine(to: CGPoint(x: rect.width * 0.84, y: rect.height * 0.18))
    return p
  }
}
struct NutrientWordmark: View {
  @Environment(\.dynamicTypeSize) private var typeSize
  var body: some View {
    HStack(spacing: 8) {
      NutrientMark().stroke(nutrientGreen, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
        .frame(width: 18, height: 23).accessibilityHidden(true)
      if !typeSize.isAccessibilitySize {
        Text("nutrient").font(NutrientType.font(.title2, weight: .semibold)).tracking(-0.4)
      }
    }.accessibilityElement(children: .ignore).accessibilityLabel("Nutrient")
  }
}
struct NutrientCaptureStyle: ButtonStyle {
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var primary = false
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(NutrientType.font(.body, weight: .medium))
      .frame(maxWidth: .infinity, minHeight: 54)
      .foregroundStyle(primary ? nutrientOnGreen : Color("FieldInk"))
      .background {
        RoundedRectangle(cornerRadius: 12).fill(
          primary ? nutrientGreen : Color("FieldSurface"))
      }
      .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(primary ? nutrientGreen : Color("FieldRule"), lineWidth: 1))
      .opacity(configuration.isPressed ? 0.84 : 1)
      .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
      .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
  }
}
struct NutrientMeter: View {
  let fraction: Double
  var color = nutrientGreen
  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Capsule().fill(Color("FieldRule"))
        Capsule().fill(color).frame(width: geometry.size.width * min(1, max(0, fraction)))
      }
    }.frame(height: 4).accessibilityHidden(true)
  }
}
struct NutrientSectionHeading: View {
  let title: String
  var detail: String? = nil
  var body: some View {
    FieldValuePair {
      Text(title).font(NutrientType.font(.headline)).accessibilityAddTraits(.isHeader)
    } trailing: {
      if let detail { Text(detail).font(NutrientType.font(.subheadline)).foregroundStyle(Color("FieldSecondary")) }
    }
  }
}
// Group related information without making every metric look like a separate destination.
struct NutrientHomeSection<Content: View>: View {
  @Environment(\.colorScheme) private var colorScheme
  @ViewBuilder var content: Content
  var body: some View {
    VStack(alignment: .leading, spacing: FieldSpace.controls) { content }
      .padding(FieldSpace.inset)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color("FieldSurface"), in: RoundedRectangle(cornerRadius: 20))
      .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color("FieldRule"), lineWidth: 0.5))
  }
}
struct NutrientHomeLink: View {
  let title: String
  let symbol: String
  var body: some View {
    HStack(spacing: FieldSpace.item) {
      Label(title, systemImage: symbol).font(NutrientType.font(.subheadline, weight: .semibold))
      Spacer(minLength: 8)
      Image(systemName: "chevron.right").font(NutrientType.font(.caption, weight: .semibold))
    }.frame(minHeight: 44).contentShape(Rectangle())
  }
}
struct NativeToday: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var typeSize
  @EnvironmentObject var store: NutrientStore
  @State private var add = false
  @State private var scan = false
  var tracked: [NutrientDefinition] { store.nutrients.filter { $0.group != "Macros" } }
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: FieldSpace.section) {
          NutrientHomeSection {
            (typeSize.isAccessibilitySize
              ? AnyLayout(VStackLayout(spacing: FieldSpace.section))
              : AnyLayout(HStackLayout(alignment: .nutrientRingCenter, spacing: FieldSpace.inset))) {
              NavigationLink { NativeDailyCoverage() } label: {
                DashboardRing(title: "Coverage", value: store.score(), target: 100, unit: "/100",
                  detail: "\(tracked.filter { store.reported($0.id) && store.total($0.id) >= (store.state.targets[$0.id] ?? $0.target) }.count) of \(tracked.count) at target", color: nutrientGreen, opensDetail: true)
              }.buttonStyle(.plain).accessibilityHint("See all targets and shortfalls")
              DashboardRing(title: "Calories", value: store.total("calories"), target: store.state.calorieTarget, unit: "kcal",
                detail: calorieBalanceText(intake: store.total("calories"), target: store.state.calorieTarget), color: calorieAccent)
            }
            Rectangle().fill(Color("FieldRule")).frame(height: 1)
            VStack(spacing: 0) {
              ForEach(["protein", "carbs", "fat"], id: \.self) { id in
                let value = store.total(id)
                let target = store.state.targets[id] ?? 1
                NavigationLink { NativeNutrientDetail(id: id) } label: {
                  VStack(spacing: FieldSpace.item) {
                    FieldValuePair {
                      HStack(spacing: FieldSpace.tight) {
                        Text(id == "carbs" ? "Carbs" : id.capitalized).font(NutrientType.font(.body, weight: .medium))
                        if value >= target { Image(systemName: "checkmark").font(NutrientType.font(.subheadline)).foregroundStyle(nutrientGreen).accessibilityHidden(true) }
                      }
                    } trailing: {
                      HStack(spacing: 8) {
                        (Text(number(value)).font(NutrientType.font(.body, weight: .semibold)).foregroundColor(Color("FieldInk"))
                          + Text(" / \(number(target)) g").font(NutrientType.font(.subheadline)).foregroundColor(Color("FieldSecondary")))
                          .contentTransition(.numericText(value: value))
                        Image(systemName: "chevron.right").font(NutrientType.font(.subheadline)).foregroundStyle(Color("FieldSecondary")).accessibilityHidden(true)
                      }
                    }
                    NutrientMeter(fraction: value / max(1, target))
                  }.frame(minHeight: FieldSpace.row).contentShape(Rectangle())
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: value)
                }.buttonStyle(.plain).accessibilityHint("See contributing foods")
              }
            }
          }
          NativeDailyGaps(home: true)
          VStack(alignment: .leading, spacing: FieldSpace.item) {
            FieldValuePair {
              Text("Food log").font(NutrientType.font(.headline)).accessibilityAddTraits(.isHeader)
            } trailing: {
              NavigationLink("View & edit") { NativeDiary() }
                .font(NutrientType.font(.subheadline, weight: .medium)).frame(minHeight: 44)
            }
            if store.day.entries.isEmpty {
              Text("Nothing logged today.").font(NutrientType.font(.subheadline)).foregroundStyle(Color("FieldSecondary"))
            }
            ForEach(store.day.entries) { entry in
              NativeLoggedEntry(entry: entry, sourceDate: store.date).padding(.vertical, 8)
              Divider()
            }
            NavigationLink { NativeLibrary() } label: {
              NutrientHomeLink(title: "Saved foods & meals", symbol: "books.vertical")
            }.buttonStyle(.plain).foregroundStyle(nutrientGreen)
          }
          VStack(alignment: .leading, spacing: FieldSpace.item) {
            NutrientSectionHeading(title: "Water")
            Stepper("\(store.day.water) / \(store.state.waterTarget) glasses",
              value: Binding(get: { store.day.water }, set: { store.water($0) }), in: 0...30)
          }
          NavigationLink { NativeNutrients() } label: {
            NutrientHomeLink(title: "All nutrients", symbol: "list.bullet")
          }.buttonStyle(.plain).foregroundStyle(nutrientGreen)
        }.frame(maxWidth: 600).padding(.horizontal, FieldSpace.inset).padding(.top, 8).padding(.bottom, 24)
          .frame(maxWidth: .infinity)
      }.fieldSurface().toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) { homeHeader }
        .safeAreaInset(edge: .bottom, spacing: 0) { captureActions }
        .sensoryFeedback(.success, trigger: store.logRevision)
        .onAppear { store.date = Date() }
        .sheet(isPresented: $add) { NativeFoodSearch() }
        .sheet(isPresented: $scan) { NativeScanSheet() }
    }
  }
  private var homeHeader: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: FieldSpace.controls) {
        homeDate.fixedSize(horizontal: true, vertical: true)
        Spacer(minLength: FieldSpace.controls)
        homeNavigation.fixedSize(horizontal: true, vertical: true)
      }
      VStack(alignment: .leading, spacing: FieldSpace.item) {
        homeDate
        homeNavigation
      }.frame(maxWidth: .infinity, alignment: .leading)
    }.padding(.horizontal, 16).padding(.vertical, 12).frame(maxWidth: 632)
      .frame(maxWidth: .infinity).background(Color("FieldBackground"))
  }
  private var homeDate: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text("Today").font(NutrientType.font(.title2, weight: .semibold)).accessibilityAddTraits(.isHeader)
      Text(store.date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
        .font(NutrientType.font(.subheadline)).foregroundStyle(Color("FieldSecondary"))
    }
  }
  private var homeNavigation: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: FieldSpace.controls) { homeNavigationLinks }
        .fixedSize(horizontal: true, vertical: true)
      VStack(alignment: .leading, spacing: FieldSpace.tight) { homeNavigationLinks }
        .frame(maxWidth: .infinity, alignment: .leading)
    }.font(NutrientType.font(.subheadline, weight: .semibold))
      .foregroundStyle(Color("FieldInk")).buttonStyle(.plain)
  }
  @ViewBuilder private var homeNavigationLinks: some View {
    NavigationLink { NativeTrends() } label: {
      Text("Trends").fixedSize(horizontal: true, vertical: true).frame(minWidth: 44, minHeight: 44)
    }
    NavigationLink { NativeLibrary() } label: {
      Text("Library").fixedSize(horizontal: true, vertical: true).frame(minWidth: 44, minHeight: 44)
    }
    Menu {
      Button("Search foods", systemImage: "magnifyingglass") { add = true }
      NavigationLink { NativeSettings() } label: { Label("Settings", systemImage: "slider.horizontal.3") }
    } label: { Image(systemName: "ellipsis").frame(minWidth: 44, minHeight: 44) }
      .accessibilityLabel("More options")
  }
  private var captureActions: some View {
    (typeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(spacing: 8))
      : AnyLayout(HStackLayout(spacing: 8))) {
      Button { scan = true } label: { Label("Scan", systemImage: "barcode.viewfinder") }
        .buttonStyle(NutrientCaptureStyle())
      Button { store.showingChat = true } label: { Label("Log food", systemImage: "plus") }
        .buttonStyle(NutrientCaptureStyle(primary: true))
      Button {
        store.startChatDictation = true
        store.showingChat = true
      } label: { Label("Speak", systemImage: "mic") }.buttonStyle(NutrientCaptureStyle())
    }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8).frame(maxWidth: 632)
      .frame(maxWidth: .infinity).background(Color("FieldBackground"))
  }
}
struct NativeDailyGaps: View {
  @EnvironmentObject var store: NutrientStore
  @State private var expanded = false
  var showAll = false
  var home = false
  @ViewBuilder var body: some View {
    if home {
      VStack(alignment: .leading, spacing: 0) {
        FieldValuePair {
          Text("Remaining nutrients").font(NutrientType.font(.headline)).accessibilityAddTraits(.isHeader)
        } trailing: {
          if !store.day.entries.isEmpty {
            NavigationLink("View \(store.dailyGaps.count)") { NativeDailyCoverage() }
              .font(NutrientType.font(.subheadline, weight: .medium)).frame(minHeight: 44)
          }
        }
        content
      }
    } else {
      Section { content } header: {
        Text(store.dailyGaps.isEmpty ? "Daily nutrient gaps" : "Still to go · \(store.dailyGaps.count) targets")
      }
    }
  }
  @ViewBuilder private var content: some View {
      if store.day.entries.isEmpty {
        Text("Log food to see what's still needed.").foregroundStyle(Color("FieldSecondary"))
      } else if store.dailyGaps.isEmpty {
        Text(
          store.unreportedNutrients.isEmpty
            ? "All nutrient targets met" : "All reported targets met"
        ).foregroundStyle(nutrientGreen)
      }
      ForEach(Array(store.dailyGaps.prefix(expanded || showAll ? 31 : home ? 2 : 3))) { gap in
        NavigationLink {
          NativeNutrientDetail(id: gap.id)
        } label: {
          VStack(alignment: .leading, spacing: FieldSpace.item) {
            FieldValuePair {
              Text(gap.nutrient.name)
            } trailing: {
              HStack(spacing: 8) {
                Text("\(number(gap.remaining)) \(gap.nutrient.unit) left").font(NutrientType.font(.subheadline, weight: .medium)).foregroundStyle(Color("FieldInk"))
                if home { Image(systemName: "chevron.right").font(NutrientType.font(.subheadline)).foregroundStyle(Color("FieldSecondary")).accessibilityHidden(true) }
              }
            }
            if !home { NutrientMeter(fraction: gap.fraction) }
            if gap.partial {
              Text("Partial intake data").font(NutrientType.font(.footnote)).foregroundStyle(Color("FieldSecondary"))
            }
          }.padding(.vertical, 4).frame(minHeight: 44).contentShape(Rectangle())
        }.buttonStyle(.plain).foregroundStyle(.primary)
        if home { Rectangle().fill(Color("FieldRule")).frame(height: 1) }
      }
      if !home && !showAll && store.dailyGaps.count > 3 {
        Button(expanded ? "Show fewer" : "Show all \(store.dailyGaps.count) shortfalls") {
          expanded.toggle()
        }.font(NutrientType.font(.subheadline, weight: .medium)).frame(minHeight: 44)
      }
      if !store.day.entries.isEmpty && !store.unreportedNutrients.isEmpty {
        DisclosureGroup {
          ForEach(store.unreportedNutrients) { item in
            NavigationLink(item.nutrient.name) { NativeNutrientDetail(id: item.id) }
          }
        } label: {
          Text("Not reported · \(store.unreportedNutrients.count) nutrients").frame(minHeight: 44)
        }
      }
      Button {
        store.showingChat = true
        Task {
          await store.send(
            "Which foods would help me hit the remaining nutrient goals for \(store.key(store.date))? Use my logged intake and remaining calories; suggest food options without logging them."
          )
        }
      } label: {
        Label("Find foods for these gaps", systemImage: "arrow.right")
          .font(NutrientType.font(.subheadline, weight: .medium)).frame(minHeight: 44).contentShape(Rectangle())
      }.disabled(store.sending)
  }
}
struct NativeDailyCoverage: View {
  @EnvironmentObject var store: NutrientStore
  var body: some View {
    FieldList {
      Text(store.date, format: .dateTime.month(.wide).day().year()).foregroundStyle(
        Color("FieldSecondary"))
      Section {
        Text("\(number(store.score())) /100").font(NutrientType.font(.largeTitle, weight: .semibold))
        Text("Average coverage across \(store.nutrients.filter { $0.group != "Macros" }.count) nutrient targets").foregroundStyle(Color("FieldSecondary"))
      }
      NativeDailyGaps(showAll: true)
      Section("Targets met") {
        ForEach(store.dailyProgress.filter { $0.reported && $0.remaining == 0 }) { item in
          NativeNutrientRow(nutrient: item.nutrient)
        }
      }
    }.fieldSurface().navigationTitle("Daily coverage").navigationBarTitleDisplayMode(
      .inline)
  }
}
struct NativeNutrientDetail: View {
  @EnvironmentObject var store: NutrientStore
  let id: String
  var nutrient: NutrientDefinition { store.nutrients.first { $0.id == id }! }
  var contributions: [NutrientContribution] { store.contributions(id) }
  var body: some View {
    FieldList {
      Section {
        Text(store.date, format: .dateTime.month(.wide).day().year()).font(NutrientType.font(.subheadline))
          .foregroundStyle(Color("FieldSecondary"))
        FieldValuePair {
          Text(
            store.reported(id)
              ? "\(store.incomplete(id) ? "≥ " : "")\(number(store.total(id))) \(nutrient.unit)"
              : "Not reported"
          ).font(NutrientType.font(.largeTitle, weight: .medium))
        } trailing: {
          Text("of \(number(store.state.targets[id] ?? nutrient.target)) \(nutrient.unit)")
            .foregroundStyle(Color("FieldSecondary"))
        }
        ProgressView(value: min(1, store.total(id) / (store.state.targets[id] ?? nutrient.target)))
          .tint(nutrientGreen)
      }
      Section("Food contributions") {
        if contributions.allSatisfy { ($0.amount ?? 0) == 0 } {
          Text(
            contributions.isEmpty
              ? "No food logged on this day." : "No positive contribution reported."
          ).foregroundStyle(Color("FieldSecondary"))
        }
        ForEach(contributions.filter { ($0.amount ?? 0) > 0 }) { item in
          VStack(alignment: .leading, spacing: FieldSpace.item) {
            FieldValuePair {
              Text(item.food.name)
            } trailing: {
              Text("\(item.partial ? "≥ " : "")\(number(item.amount ?? 0)) \(nutrient.unit)").font(
                .headline
              ).foregroundStyle(nutrientGreen)
            }
            Text("\(number(item.entry.quantity)) × \(item.food.serving) · \(item.entry.meal)").font(
              .subheadline
            ).foregroundStyle(Color("FieldSecondary"))
            if let components = item.food.components,
              components.contains(where: { $0.values != nil })
            {
              DisclosureGroup("Ingredients") {
                ForEach(Array(components.enumerated()), id: \.offset) { _, component in
                  FieldValuePair {
                    Text(component.name)
                  } trailing: {
                    if let value = component.values?[id] ?? nil {
                      Text(
                        "\(number(value * component.quantity * item.entry.quantity)) \(nutrient.unit)"
                      )
                      .monospacedDigit()
                    } else {
                      Text("Not reported").foregroundStyle(Color("FieldSecondary"))
                    }
                  }.font(NutrientType.font(.subheadline))
                }
              }
            }
          }.padding(.vertical, 5)
        }
      }
      if contributions.contains(where: { $0.amount == nil }) {
        Section {
          DisclosureGroup("Not reported by these foods") {
            ForEach(contributions.filter { $0.amount == nil }) { item in Text(item.food.name) }
          }
        }
      }
      if contributions.contains(where: { $0.amount == 0 }) {
        Section {
          DisclosureGroup("Reported zero") {
            ForEach(contributions.filter { $0.amount == 0 }) { item in Text(item.food.name) }
          }
        }
      }
    }.fieldSurface().navigationTitle(nutrient.name).navigationBarTitleDisplayMode(
      .inline)
  }
}
struct NativeNutrientRow: View {
  @EnvironmentObject var store: NutrientStore
  let nutrient: NutrientDefinition
  var body: some View {
    let value = store.total(nutrient.id)
    let target = store.state.targets[nutrient.id] ?? nutrient.target
    NavigationLink {
      NativeNutrientDetail(id: nutrient.id)
    } label: {
      VStack(alignment: .leading, spacing: FieldSpace.item) {
        FieldValuePair {
          Text(nutrient.name)
        } trailing: {
          Text(
            store.reported(nutrient.id)
              ? "\(number(value)) / \(number(target)) \(nutrient.unit)"
              : "— / \(number(target)) \(nutrient.unit)"
          ).font(NutrientType.font(.subheadline)).foregroundStyle(Color("FieldSecondary")).multilineTextAlignment(
            .trailing)
        }
        if store.reported(nutrient.id) {
          ProgressView(value: min(value / target, 1)).tint(nutrientGreen)
          if store.incomplete(nutrient.id) {
            Text("Partial data").font(NutrientType.font(.caption)).foregroundStyle(Color("FieldSecondary"))
          }
        } else {
          Text(store.day.entries.isEmpty ? "No food logged" : "Not reported in logged foods").font(
            .caption
          ).foregroundStyle(Color("FieldSecondary"))
        }
      }.padding(.vertical, 4)
    }.foregroundStyle(.primary).accessibilityHint("See contributing foods")
  }
}
struct NativeLoggedEntry: View {
  @EnvironmentObject var store: NutrientStore
  let entry: DiaryEntry
  let sourceDate: Date
  @State private var edit = false
  var body: some View {
    if let food = store.food(entry.foodId) {
      Button {
        edit = true
      } label: {
        FieldValuePair {
          VStack(alignment: .leading, spacing: 5) {
            Text(food.name).font(NutrientType.font(.body, weight: .medium)).foregroundStyle(Color("FieldInk"))
            Text("\(number(entry.quantity)) × \(food.serving) · \(entry.meal)").font(NutrientType.font(.subheadline))
              .foregroundStyle(Color("FieldSecondary"))
          }
        } trailing: {
          HStack(spacing: 12) {
            VStack(alignment: .trailing, spacing: 2) {
              Text(food.energyUnreported == true ? "—" : number(food.calories * entry.quantity))
                .font(NutrientType.font(.body, weight: .semibold)).foregroundStyle(Color("FieldInk"))
              Text(food.energyUnreported == true ? "Unreported" : "kcal")
                .font(NutrientType.font(.subheadline)).foregroundStyle(Color("FieldSecondary"))
            }
            Image(systemName: "pencil").font(NutrientType.font(.subheadline)).foregroundStyle(Color("FieldSecondary"))
          }
        }
      }.buttonStyle(.plain).contentShape(Rectangle()).accessibilityHint("Edit portion, meal, or date")
        .contextMenu {
          Button("Edit entry", systemImage: "pencil") { edit = true }
          Button("Remove entry", systemImage: "trash", role: .destructive) { store.remove(entry) }
        }
        .swipeActions {
          Button("Remove", role: .destructive) { store.remove(entry) }
          Button("Edit") { edit = true }.tint(nutrientGreen)
        }
        .sheet(isPresented: $edit) { NativeEntryEditor(entry: entry, sourceDate: sourceDate) }
    }
  }
}
struct NativeEntryEditor: View {
  @EnvironmentObject var store: NutrientStore
  @Environment(\.dismiss) var dismiss
  let entry: DiaryEntry
  let sourceDate: Date
  @State private var quantity: Double
  @State private var meal: String
  @State private var date: Date
  @State private var failure: String?
  init(entry: DiaryEntry, sourceDate: Date) {
    self.entry = entry
    self.sourceDate = sourceDate
    _quantity = State(initialValue: entry.quantity)
    _meal = State(initialValue: entry.meal)
    _date = State(initialValue: sourceDate)
  }
  var body: some View {
    NavigationStack {
      FieldForm {
        if let food = store.food(entry.foodId) {
          Section {
            Text(food.name).font(NutrientType.font(.headline))
            if let components = food.components {
              ForEach(Array(components.enumerated()), id: \.offset) { _, component in
                Text("\(component.name) · \(number(component.quantity)) × \(component.serving)")
                  .font(NutrientType.font(.subheadline)).foregroundStyle(Color("FieldSecondary"))
              }
            }
            NativeQuantityInput(food: food, quantity: $quantity)
            LabeledContent(
              "Energy",
              value: food.energyUnreported == true
                ? "Unreported" : "\(number(food.calories*quantity)) kcal")
          }
          Section {
            Picker("Meal", selection: $meal) {
              ForEach(food.isSupplement ? ["Supplements"] : nativeMeals, id: \.self) { Text($0) }
            }
            DatePicker("Date", selection: $date, displayedComponents: .date)
          }
        }
        if let failure { Text(failure).foregroundStyle(Color("FieldError")) }
      }.fieldSurface().navigationTitle("Edit entry").navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
          ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
              do {
                try store.updateEntry(
                  entry, from: sourceDate, to: date, quantity: quantity, meal: meal)
                dismiss()
              } catch { failure = error.localizedDescription }
            }.disabled(!quantity.isFinite || quantity <= 0 || quantity > 100)
          }
        }
    }
  }
}
struct NativeDiaryMealDraft: Identifiable {
  let id = UUID()
  let date: Date
  let entryIDs: Set<String>
  let items: [MealItem]
}
struct NativeDiaryMealSave: View {
  @EnvironmentObject var store: NutrientStore
  @Environment(\.dismiss) var dismiss
  let draft: NativeDiaryMealDraft
  var saved: () -> Void
  @State private var name = ""
  @State private var error: String?
  var body: some View {
    NavigationStack {
      FieldForm {
        Section {
          TextField("Meal name", text: $name).textInputAutocapitalization(.sentences)
        }
        Section("Ingredients") {
          ForEach(draft.items) { item in
            VStack(alignment: .leading, spacing: 5) {
              Text(item.food.name)
              Text(
                "\(item.quantity.formatted(.number.precision(.fractionLength(0...3)))) × \(item.food.serving)"
              )
              .font(NutrientType.font(.subheadline)).foregroundStyle(Color("FieldSecondary"))
            }
          }
          LabeledContent(
            "Energy",
            value:
              "\(draft.items.contains { $0.food.energyUnreported == true } ? "≥ " : "")\(number(draft.items.reduce(0) { $0 + $1.food.calories * $1.quantity })) kcal"
          )
        }
        if let error { Text(error).foregroundStyle(Color("FieldError")) }
      }.fieldSurface().navigationTitle("Save meal").navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
          ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
              do {
                try store.saveDiaryMeal(name, entryIDs: draft.entryIDs, from: draft.date)
                saved()
                dismiss()
              } catch { self.error = error.localizedDescription }
            }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          }
        }
    }.tint(nutrientGreen)
  }
}
struct NativeDiary: View {
  @EnvironmentObject var store: NutrientStore
  @State private var add = false
  @State private var selecting = false
  @State private var selectedIDs = Set<String>()
  @State private var mealDraft: NativeDiaryMealDraft?
  var selectable: [DiaryEntry] {
    store.day.entries.filter { store.food($0.foodId).map { !$0.isSupplement } ?? false }
  }
  var body: some View {
    FieldList {
      DatePicker("Date", selection: $store.date, displayedComponents: .date)
      if !selecting {
        NavigationLink {
          NativeDailyCoverage()
        } label: {
          LabeledContent(
            "Coverage",
            value: store.day.entries.isEmpty
              ? "No food logged"
              : "\(number(store.score()))% · \(store.dailyGaps.count) still short")
        }
      }
      if store.day.entries.isEmpty {
        ContentUnavailableView {
          Label("No food logged", systemImage: "fork.knife")
        } actions: {
          Button("Add food") { add = true }.buttonStyle(.borderedProminent)
            .foregroundStyle(nutrientOnGreen)
        }
      }
      ForEach(
        nativeMeals.filter { meal in store.day.entries.contains { $0.meal == meal } }, id: \.self
      ) { meal in
        Section(meal) {
          let entries = store.day.entries.filter { $0.meal == meal }
          ForEach(entries) { entry in
            if selecting {
              if let food = store.food(entry.foodId) {
                Button {
                  if selectedIDs.contains(entry.id) {
                    selectedIDs.remove(entry.id)
                  } else {
                    selectedIDs.insert(entry.id)
                  }
                } label: {
                  HStack(alignment: .top, spacing: 12) {
                    Image(
                      systemName: selectedIDs.contains(entry.id)
                        ? "checkmark.circle.fill" : "circle"
                    )
                    .font(NutrientType.font(.title2)).foregroundStyle(nutrientGreen)
                    VStack(alignment: .leading, spacing: 5) {
                      Text(food.name).foregroundStyle(.primary)
                      Text(
                        "\(entry.quantity.formatted(.number.precision(.fractionLength(0...3)))) × \(food.serving)"
                      )
                      .font(NutrientType.font(.subheadline)).foregroundStyle(Color("FieldSecondary"))
                    }
                  }.padding(.vertical, 4)
                }.buttonStyle(.plain).disabled(food.isSupplement)
                  .accessibilityLabel(
                    "\(selectedIDs.contains(entry.id) ? "Deselect" : "Select") \(food.name)"
                  )
                  .accessibilityAddTraits(selectedIDs.contains(entry.id) ? .isSelected : [])
              }
            } else {
              NativeLoggedEntry(entry: entry, sourceDate: store.date)
            }
          }
          if !selecting { Button("Add food") { add = true } }
        }
      }
    }.fieldSurface().fieldTitle("Diary")
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button(selecting ? "Cancel" : "Select") {
            selectedIDs.removeAll()
            selecting.toggle()
          }.disabled(!selecting && selectable.isEmpty)
        }
        ToolbarItem(placement: .topBarTrailing) {
          if selecting {
            Button(selectedIDs.count == selectable.count ? "Deselect all" : "Select all") {
              selectedIDs = selectedIDs.count == selectable.count ? [] : Set(selectable.map(\.id))
            }.disabled(selectable.isEmpty)
          } else {
            Button {
              add = true
            } label: {
              Image(systemName: "plus")
            }.accessibilityLabel("Log food")
          }
        }
      }
      .safeAreaInset(edge: .bottom) {
        if selecting {
          Button {
            let entries = selectable.filter { selectedIDs.contains($0.id) }
            mealDraft = NativeDiaryMealDraft(
              date: store.date, entryIDs: Set(entries.map(\.id)),
              items: entries.compactMap { entry in
                store.food(entry.foodId).map { MealItem(food: $0, quantity: entry.quantity) }
              })
          } label: {
            Text("Save as meal (\(selectedIDs.count))").font(NutrientType.font(.headline)).frame(maxWidth: .infinity)
              .padding(.vertical, 6)
          }.buttonStyle(.borderedProminent).tint(nutrientGreen)
            .foregroundStyle(selectedIDs.isEmpty ? Color.secondary : nutrientOnGreen)
            .disabled(selectedIDs.isEmpty).padding().background(.bar)
        }
      }
      .onChange(of: store.date) { _, _ in selectedIDs.removeAll() }
      .sheet(isPresented: $add) { NativeFoodSearch() }
      .sheet(item: $mealDraft) { draft in
        NativeDiaryMealSave(
          draft: draft,
          saved: {
            selecting = false
            selectedIDs.removeAll()
          })
      }
  }
}
struct NativeNutrients: View {
  @EnvironmentObject var store: NutrientStore
  @State private var query = ""
  @State private var filter = "All"
  var visible: [NutrientDefinition] {
    store.nutrients.filter { n in
      let matches = query.isEmpty || n.name.localizedCaseInsensitiveContains(query)
      let known = store.reported(n.id)
      let met = known && store.total(n.id) >= (store.state.targets[n.id] ?? n.target)
      return matches && (filter == "All" || (filter == "Met" ? met : known && !met))
    }
  }
  var body: some View {
    FieldList {
      Picker("Coverage", selection: $filter) {
        ForEach(["Still to go", "All", "Met"], id: \.self) { Text($0).tag($0) }
      }.fieldSegments()
      if visible.isEmpty {
        Text(query.isEmpty ? "No nutrients in this view." : "No matching nutrients.")
          .foregroundStyle(Color("FieldSecondary"))
      }
      ForEach(visible) { n in NativeNutrientRow(nutrient: n) }
    }.searchable(text: $query, prompt: "Find a nutrient").fieldSurface().fieldTitle("Nutrients")
  }
}
private struct ChatBottomKey: PreferenceKey {
  static var defaultValue: CGFloat = .greatestFiniteMagnitude
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = min(value, nextValue())
  }
}
private struct ChatViewportKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}
struct NativeChat: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @EnvironmentObject var store: NutrientStore
  @StateObject private var speech = NativeDictation()
  @State private var speechPrefix = ""
  @State private var scan = false
  @State private var search = false
  @FocusState private var focused: Bool
  @State private var viewportHeight: CGFloat = 0
  @State private var bottomPosition: CGFloat = .greatestFiniteMagnitude
  @State private var nearBottom = true
  @State private var unreadResponse = false
  @State private var jumpRequest = 0
  @State private var followKeyboardResize = false
  @State private var followAfterLayout = false
  @State private var userDragging = false
  var body: some View {
    NavigationStack {
      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(alignment: .leading, spacing: FieldSpace.section) {
            if store.history.isEmpty {
              Text("What did you eat?").font(NutrientType.font(.title3)).foregroundStyle(Color("FieldSecondary"))
                .frame(
                  maxWidth: .infinity
                ).padding(.top, 80)
            }
            ForEach(Array(store.history.enumerated()), id: \.offset) { index, message in
              MessageRow(message: message).id(index)
            }
            if store.sending {
              HStack(spacing: FieldSpace.item) {
                ProgressView()
                Text("Looking up your meal…").foregroundStyle(Color("FieldSecondary"))
              }
            }
            if let error = store.chatError {
              VStack(alignment: .leading, spacing: 8) {
                Text(error).foregroundStyle(Color("FieldError"))
                Button("Retry") {
                  Task {
                    await store.send(
                      store.history.last(where: { $0.role == "user" })?.content ?? "", retry: true)
                  }
                }
              }
            }
            if !store.pending.isEmpty {
              NativeChatMealDraft(items: Binding(get: { store.pending }, set: {
                store.state.pendingMeal = $0
                store.save()
              }))
            }
            Color.clear.frame(height: 1).id("bottom")
          }.padding(FieldSpace.inset).background {
            GeometryReader { geometry in
              Color.clear.preference(
                key: ChatBottomKey.self,
                value: geometry.frame(in: .named("chatViewport")).maxY)
            }
          }
        }.simultaneousGesture(
          DragGesture(minimumDistance: 2)
            .onChanged { _ in
              userDragging = true
              followAfterLayout = false
              followKeyboardResize = false
            }
            .onEnded { _ in
              updateProximity()
              userDragging = false
            }
        ).coordinateSpace(name: "chatViewport")
          .background {
            GeometryReader { geometry in
              Color.clear.preference(key: ChatViewportKey.self, value: geometry.size.height)
            }
          }
          .onPreferenceChange(ChatBottomKey.self) { value in
            let changed = bottomPosition != value
            bottomPosition = value
            updateProximity()
            if changed && followAfterLayout && !userDragging {
              followAfterLayout = false
              scrollToBottom(proxy)
            }
          }
          .onPreferenceChange(ChatViewportKey.self) { value in
            viewportHeight = value
            updateProximity()
          }
          .fieldSurface().scrollDismissesKeyboard(.interactively)
          .onChange(of: store.history.count) { _, _ in
            let userInitiated = store.history.last?.role == "user"
            if NativeChatFollow.shouldScroll(
              userInitiated: userInitiated, nearBottom: nearBottom && !userDragging)
            {
              followAfterLayout = true
              scrollToBottom(proxy)
            } else {
              unreadResponse = true
            }
          }
          .onChange(of: focused) { _, active in
            followKeyboardResize = active
            if active { scrollToBottom(proxy) }
          }
          .onReceive(
            NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)
          ) { _ in
            if followKeyboardResize {
              scrollToBottom(proxy, animated: false)
              followKeyboardResize = false
            }
          }
          .onChange(of: store.sending) { _, _ in
            if nearBottom && !userDragging {
              followAfterLayout = true
              scrollToBottom(proxy)
            }
          }
          .onChange(of: store.pending.count) { _, _ in
            if nearBottom && !userDragging {
              followAfterLayout = true
              scrollToBottom(proxy)
            }
          }
          .onChange(of: jumpRequest) { _, _ in scrollToBottom(proxy) }
          .onAppear {
            #if DEBUG
              if NativeDesignFixture.argument("--design-fixture") == "reading" {
                nearBottom = false
                proxy.scrollTo(0, anchor: .top)
                return
              }
            #endif
            scrollToBottom(proxy, animated: false)
          }
          .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
              if unreadResponse {
                HStack {
                  Spacer()
                  Button("Latest message", systemImage: "arrow.down") { jumpRequest += 1 }
                    .buttonStyle(.bordered).frame(minHeight: 44)
                }.padding(.horizontal, FieldSpace.inset)
              }
              composer
            }.background(Color("FieldBackground"))
          }
      }
      .fieldSurface().fieldTitle("Log food")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            focused = false
            search = true
          } label: {
            Image(systemName: "magnifyingglass")
          }.accessibilityLabel("Search foods")
        }
      }
      .sheet(isPresented: $scan) { NativeScanSheet() }
      .sheet(isPresented: $search) { NativeFoodSearch() }
      .onChange(of: speech.transcript) { _, text in store.draft = speechPrefix + text }
      .onAppear {
        #if DEBUG
          if NativeDesignFixture.argument("--design-fixture") == "reading" { return }
        #endif
        if store.startChatDictation {
          store.startChatDictation = false
          focused = false
          speechPrefix = store.draft.isEmpty ? "" : store.draft + " "
          Task { await speech.start() }
        } else { focused = store.pending.isEmpty }
      }
      .onDisappear { speech.stop() }
      .alert(
        "Dictation",
        isPresented: Binding(get: { speech.error != nil }, set: { if !$0 { speech.error = nil } })
      ) {
        Button("OK", role: .cancel) { speech.error = nil }
      } message: {
        Text(speech.error ?? "")
      }
    }
  }
  private func updateProximity() {

    // Content growth must not replace the reader's intent before history onChange runs.
    guard viewportHeight > 0, userDragging || !nearBottom else { return }
    nearBottom = bottomPosition <= viewportHeight + 64
    if nearBottom { unreadResponse = false }
  }
  private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool = true) {

    nearBottom = true
    unreadResponse = false
    if reduceMotion || !animated {
      proxy.scrollTo("bottom", anchor: .bottom)
    } else {
      withAnimation(.easeOut(duration: 0.18)) { proxy.scrollTo("bottom", anchor: .bottom) }
    }
  }
  private var composer: some View {
    HStack(alignment: .bottom, spacing: 8) {
      Button {
        focused = false
        scan = true
      } label: {
        Image(systemName: "barcode.viewfinder").frame(width: 44, height: 44)
      }.accessibilityLabel("Scan barcode")
      TextField("What did you eat?", text: $store.draft, axis: .vertical).lineLimit(1...5).focused($focused)
        .padding(.vertical, 12).accessibilityLabel("Message")
      Button {
        if speech.listening {
          speech.stop()
        } else {
          speechPrefix = store.draft.isEmpty ? "" : store.draft + " "
          Task { await speech.start() }
        }
      } label: {
        Image(systemName: speech.listening ? "stop.circle.fill" : "mic").frame(
          width: 44, height: 44)
      }.accessibilityLabel(speech.listening ? "Stop dictation" : "Dictate a meal")
      Button {
        let message = store.draft
        jumpRequest += 1
        speech.stop()
        focused = false
        Task { await store.send(message) }
      } label: {
        Image(systemName: "arrow.up.circle.fill").font(.system(size: 34)).frame(
          width: 44, height: 44)
      }.disabled(
        store.sending || store.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      ).accessibilityLabel("Send message")
    }.padding(.horizontal, 10).background(
      Color("FieldSurface"), in: RoundedRectangle(cornerRadius: 24)
    ).overlay(RoundedRectangle(cornerRadius: 24).stroke(Color("FieldRule"), lineWidth: 1))
      .padding(.horizontal, 12).padding(.vertical, 8).background(Color("FieldBackground"))
  }
}
struct MessageRow: View {
  let message: NativeMessage
  var body: some View {
    HStack {
      if message.role == "user" { Spacer(minLength: 40) }
      Text(.init(message.content)).textSelection(.enabled).font(NutrientType.font(.body)).lineSpacing(4).padding(
        message.role == "user" ? 12 : 0
      ).background(
        message.role == "user" ? Color("FieldSoft") : .clear,
        in: RoundedRectangle(cornerRadius: 20)
      ).frame(maxWidth: .infinity, alignment: message.role == "user" ? .trailing : .leading)
      if message.role != "user" { Spacer(minLength: 4) }
    }
  }
}
struct NativeQuantityInput: View {
  @Environment(\.dynamicTypeSize) private var typeSize
  let food: NativeFood
  @Binding var quantity: Double
  var compact = false
  @State private var unitID = ""
  private var unit: NativeAmountUnit {
    food.amountUnits.first(where: { $0.id == unitID }) ?? food.amountUnits[0]
  }
  private var amountField: some View {
    TextField("Amount", value: Binding(
      get: { quantity / unit.servings }, set: { quantity = $0 * unit.servings }
    ), format: .number.precision(.fractionLength(0...3)))
      .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
      .frame(minWidth: 80, maxWidth: 140).frame(minHeight: 44)
      .accessibilityLabel("\(food.name) amount")
  }
  private var unitPicker: some View {
    Picker("Unit", selection: Binding(get: { unit.id }, set: { unitID = $0 })) {
      ForEach(food.amountUnits) { option in Text(option.label).tag(option.id) }
    }.pickerStyle(.menu).frame(minHeight: 44).accessibilityLabel("\(food.name) unit")
  }
  var body: some View {
    VStack(alignment: .leading, spacing: FieldSpace.item) {
      if compact && !typeSize.isAccessibilitySize {
        HStack {
          Text("Amount")
          Spacer(minLength: 8)
          amountField
          unitPicker.labelsHidden()
        }
      } else {
        FieldValuePair { Text("Amount") } trailing: { amountField }
        unitPicker
      }
      if let grams = food.gramsPerServing {
        Text("\((quantity * grams).formatted(.number.precision(.fractionLength(0...2)))) g · \(quantity.formatted(.number.precision(.fractionLength(0...3)))) × \(food.serving)")
          .font(NutrientType.font(.subheadline)).foregroundStyle(Color("FieldSecondary")).monospacedDigit()
      } else {
        Text("Per serving: \(food.serving)").font(NutrientType.font(.subheadline)).foregroundStyle(Color("FieldSecondary"))
      }
    }.padding(.vertical, 4)
  }
}
struct NativeMealSummary: View {
  @Environment(\.dynamicTypeSize) private var typeSize
  let items: [MealItem]
  private var energy: String {
    let total = number(items.reduce(0) { $0 + $1.food.calories * $1.quantity })
    return items.contains { $0.food.energyUnreported == true } ? "≥ " + total : total
  }
  private func amount(_ id: String) -> String {
    let reported = items.filter { $0.food.value(id) != nil }
    guard !reported.isEmpty else { return "—" }
    let total = number(reported.reduce(0) { $0 + ($1.food.value(id) ?? 0) * $1.quantity })
    return (reported.count < items.count ? "≥ " : "") + total + " g"
  }
  var body: some View {
    (typeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
      : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))) {
      metric(energy, label: "kcal", prominent: true)
      metric(amount("protein"), label: "Protein")
      metric(amount("carbs"), label: "Carbs")
      metric(amount("fat"), label: "Fat")
    }.padding(.vertical, 12)
  }
  private func metric(_ value: String, label: String, prominent: Bool = false) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(value).font(NutrientType.font(prominent ? .title2 : .body, weight: .semibold))
        .fixedSize(horizontal: false, vertical: true)
      Text(label).font(NutrientType.font(.subheadline)).foregroundStyle(Color("FieldSecondary"))
    }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .ignore)
      .accessibilityLabel(value == "—" ? "\(label), not reported" : "\(value) \(label)")
  }
}

// The proposal itself is the review surface. Logging always requires confirmation.
struct NativeChatMealDraft: View {
  @EnvironmentObject var store: NutrientStore
  @Binding var items: [MealItem]
  @State private var expanded: UUID?
  @State private var meal = "Lunch"
  @State private var name = ""
  @State private var groupMeal = true
  @State private var saveMeal = false
  @State private var search = false
  var body: some View {
    VStack(alignment: .leading, spacing: FieldSpace.controls) {
      Text("Meal draft").font(NutrientType.font(.headline)).accessibilityAddTraits(.isHeader)
      NativeMealSummary(items: items)
      ForEach($items) { $item in
        let itemID = item.id
        DisclosureGroup(isExpanded: Binding(get: { expanded == itemID }, set: { expanded = $0 ? itemID : nil })) {
          NativeQuantityInput(food: item.food, quantity: $item.quantity)
          if let source = item.food.source { Text(source).font(NutrientType.font(.subheadline)).foregroundStyle(Color("FieldSecondary")) }
          if let sourceURL = item.food.sourceUrl, let url = URL(string: sourceURL), url.scheme == "https" {
            Link("Nutrition source", destination: url).frame(minHeight: 44)
          }
          Button("Remove ingredient", role: .destructive) { items.removeAll { $0.id == itemID } }.frame(minHeight: 44)
        } label: {
          VStack(alignment: .leading, spacing: 4) {
            Text(item.food.name).font(NutrientType.font(.body, weight: .medium)).foregroundStyle(Color("FieldInk"))
            FieldValuePair {
              Text(item.food.gramsPerServing.map { "\(number(item.quantity * $0)) g" }
                ?? "\(number(item.quantity)) × \(item.food.serving)")
            } trailing: {
              Text(item.food.energyUnreported == true ? "Energy unreported" : "\(number(item.food.calories * item.quantity)) kcal")
            }.font(NutrientType.font(.subheadline)).foregroundStyle(Color("FieldSecondary"))
          }.frame(minHeight: 52, alignment: .leading)
        }
        Divider()
      }
      Button("Add ingredient", systemImage: "plus") { search = true }.frame(minHeight: 44)
      Picker("Meal", selection: $meal) { ForEach(nativeMeals, id: \.self) { Text($0) } }
      DatePicker("Date", selection: $store.date, displayedComponents: .date)
      DisclosureGroup("Meal options") {
        if items.filter({ !$0.food.isSupplement }).count > 1 { Toggle("Log as one meal", isOn: $groupMeal) }
        Toggle("Save as a reusable meal", isOn: $saveMeal)
        TextField(saveMeal ? "Meal name" : "Meal name (optional)", text: $name).frame(minHeight: 44)
      }
      Button {
        store.log(items, meal: meal, saveAs: saveMeal ? name : "",
          groupedAs: groupMeal && items.filter({ !$0.food.isSupplement }).count > 1
            ? (name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Meal" : name) : nil)
        store.state.chatHistory = store.history + [NativeMessage(role: "assistant", content: "Logged this meal.")]
        store.save()
      } label: {
        Label("Confirm & log", systemImage: "checkmark")
      }.buttonStyle(NutrientCaptureStyle(primary: true))
        .disabled(items.isEmpty || items.contains { !$0.quantity.isFinite || $0.quantity <= 0 || $0.quantity > 100 }
          || (saveMeal && name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
    }.padding(16).background(Color("FieldSurface"), in: RoundedRectangle(cornerRadius: 16))
      .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color("FieldRule"), lineWidth: 0.5))
      .sheet(isPresented: $search) { NativeFoodSearch(selected: { items.append(MealItem(food: $0, quantity: 1)) }) }
  }
}

struct NativeMealReview: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @EnvironmentObject var store: NutrientStore
  @Environment(\.dismiss) var dismiss
  @State var items: [MealItem]
  var fromChat = false
  var onLog: (() -> Void)? = nil
  @State private var scanMore = false
  @State private var addIngredient = false
  @State private var groupMeal = true
  @State private var meal = "Breakfast"
  @State private var name = ""
  @State private var saveMeal = false
  @State private var expandedItem: UUID?
  var calories: Double { items.reduce(0) { $0 + $1.food.calories * $1.quantity } }
  var body: some View {
    NavigationStack {
      FieldForm {
        Section {
          ForEach($items) { $item in
            DisclosureGroup(
              isExpanded: Binding(
                get: { expandedItem == item.id },
                set: { opened in
                  withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                    expandedItem = opened ? item.id : nil
                  }
                }
              )
            ) {
              NativeQuantityInput(food: item.food, quantity: $item.quantity)
              let macros = [("protein", "protein"), ("carbs", "carbs"), ("fat", "fat")].compactMap { id, label -> String? in
                guard let value = item.food.values[id] ?? nil else { return nil }
                return "\(number(value * item.quantity)) g \(label)"
              }
              if !macros.isEmpty {
                Text(macros.joined(separator: " · ")).font(NutrientType.font(.subheadline))
                  .foregroundStyle(Color("FieldSecondary"))
                  .contentTransition(.numericText())
                  .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: item.quantity)
              }
              if let source = item.food.source {
                Text(source).font(NutrientType.font(.subheadline)).foregroundStyle(Color("FieldSecondary"))
              }
              if let url = item.food.sourceUrl, let link = URL(string: url), link.scheme == "https"
              {
                Link("Source", destination: link)
              }
            } label: {
              VStack(alignment: .leading, spacing: FieldSpace.tight) {
                Text(item.food.name).font(NutrientType.font(.body, weight: .medium)).foregroundStyle(.primary)
                FieldValuePair {
                  Text(
                    item.food.gramsPerServing.map {
                      "\(number(item.quantity * $0)) g"
                    } ?? "\(number(item.quantity)) × \(item.food.serving)")
                } trailing: {
                  Text(
                    item.food.energyUnreported == true
                      ? "Energy unreported" : "\(number(item.food.calories * item.quantity)) kcal")
                    .contentTransition(.numericText(value: item.food.calories * item.quantity))
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: item.quantity)
                }.font(NutrientType.font(.subheadline)).foregroundStyle(Color("FieldSecondary"))
              }.frame(minHeight: FieldSpace.row, alignment: .leading)
            }
          }.onDelete { offsets in
            if offsets.contains(where: { items[$0].id == expandedItem }) { expandedItem = nil }
            items.remove(atOffsets: offsets)
          }
          Button("Scan another item", systemImage: "barcode.viewfinder") { scanMore = true }
          Button("Add from foods", systemImage: "plus") { addIngredient = true }
        }
        Section {
          LabeledContent(
            "Energy",
            value: items.contains { $0.food.energyUnreported == true }
              ? "≥ \(number(calories)) kcal (partial)" : "\(number(calories)) kcal")
          Picker("Log to", selection: $meal) { ForEach(nativeMeals, id: \.self) { Text($0) } }
          DatePicker("Date", selection: $store.date, displayedComponents: .date)
        }
        Section {
          if items.filter({ !$0.food.isSupplement }).count > 1 {
            Toggle("Log as one meal", isOn: $groupMeal)
          }
          if (items.count > 1 && groupMeal) || saveMeal {
            TextField(saveMeal ? "Meal name" : "Meal name (optional)", text: $name)
          }
          Toggle("Save as a reusable meal", isOn: $saveMeal)
        }
      }.fieldSurface().navigationTitle("Review meal").navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
          Button {
            store.log(
              items, meal: meal, saveAs: saveMeal ? name : "",
              groupedAs: groupMeal && items.filter({ !$0.food.isSupplement }).count > 1
                ? (name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Meal" : name)
                : nil)
            if fromChat {
              store.state.chatHistory =
                store.history + [NativeMessage(role: "assistant", content: "Logged this meal.")]
              store.save()
            }
            onLog?()
            dismiss()
          } label: {
            Label("Confirm & log meal", systemImage: "checkmark")
              .font(NutrientType.font(.headline)).frame(maxWidth: .infinity).padding(.vertical, 8)
          }.buttonStyle(.borderedProminent).foregroundStyle(nutrientOnGreen).disabled(
            items.isEmpty
              || items.contains { $0.quantity <= 0 || $0.quantity > 100 || !$0.quantity.isFinite }
              || (saveMeal && name.trimmingCharacters(in: .whitespaces).isEmpty)
          )

          .padding().background(Color("FieldBackground"))
        }
        .onAppear {
          #if DEBUG
            if NativeDesignFixture.enabled
              && ProcessInfo.processInfo.arguments.contains("--expand-first")
            {
              expandedItem = items.first?.id
            }
          #endif
        }
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        .sheet(isPresented: $scanMore) {
          NativeScanSheet(selected: { append($0) })
        }
        .sheet(isPresented: $addIngredient) {
          NativeFoodSearch(selected: { append($0) })
        }
    }
  }
  private func append(_ food: NativeFood) {
    items.append(MealItem(food: food, quantity: 1))
  }
}
struct NativeFoodSearch: View {
  @EnvironmentObject var store: NutrientStore
  @Environment(\.dismiss) var dismiss
  var selected: ((NativeFood) -> Void)? = nil
  @State private var query = ""
  @State private var chosen: NativeFood?
  @State private var scan = false
  @State private var label = false
  @State private var scannedSelection: NativeFood?
  var body: some View {
    NavigationStack {
      FieldList {
        if let error = store.databaseError { Text(error) }
        ForEach(store.search(query).filter { selected == nil || !$0.isSupplement }) { food in
          Button {
            if let selected {
              selected(food)
              dismiss()
            } else {
              chosen = food
            }
          } label: {
            FoodRow(food: food)
          }.foregroundStyle(.primary)
        }
        if store.search(query).isEmpty {
          Text("No matching foods").foregroundStyle(Color("FieldSecondary"))
        }
      }.fieldSurface().searchable(text: $query, prompt: "Search foods or a brand").navigationTitle(
        "Add food"
      ).navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
          ToolbarItem(placement: .topBarTrailing) {
            Menu {
              Button("Scan barcode", systemImage: "barcode.viewfinder") { scan = true }
              Button("Scan nutrition label", systemImage: "camera.viewfinder") { label = true }
            } label: {
              Image(systemName: "camera.viewfinder")
            }
            .accessibilityLabel("Scan food")
          }
        }
        .sheet(item: $chosen) { food in NativeMealReview(items: [MealItem(food: food, quantity: 1)])
        }
        .sheet(
          isPresented: $scan,
          onDismiss: {
            if let food = scannedSelection {
              scannedSelection = nil
              selected?(food)
              dismiss()
            }
          }
        ) {
          if selected != nil {
            NativeScanSheet(selected: { scannedSelection = $0 })
          } else {
            NativeScanSheet()
          }
        }
        .sheet(isPresented: $label) { NativeCustomFood(supplement: false, scanOnOpen: true) }
    }
  }
}
struct FoodRow: View {
  let food: NativeFood
  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: food.isSupplement ? "pills" : food.kind == "meal" ? "fork.knife" : "circle.grid.2x2")
        .font(NutrientType.font(.body, weight: .medium)).foregroundStyle(Color("FieldSecondary"))
        .frame(width: 24, height: 26)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 5) {
        Text(food.name).font(NutrientType.font(.body, weight: .medium))
        Text(
          food.energyUnreported == true
            ? "\(food.serving) · energy unreported"
            : "\(food.serving) · \(number(food.calories)) kcal"
        )
        .font(NutrientType.font(.subheadline)).foregroundStyle(Color("FieldSecondary"))
      }.frame(maxWidth: .infinity, alignment: .leading)
    }.padding(.vertical, 6).accessibilityElement(children: .combine)
  }
}
struct NativeScanSheet: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @EnvironmentObject var store: NutrientStore
  @Environment(\.dismiss) var dismiss
  var selected: ((NativeFood) -> Void)? = nil
  @State private var logged = false
  @State private var code = ""
  @State private var camera = true
  @State private var status: String?
  @State private var loading = false
  @State private var product: NativeFood?
  @State private var recognition = 0
  @State private var captured = false
  var body: some View {
    NavigationStack {
      VStack(spacing: 16) {
        if camera {
          NativeScanner(
            scanned: { code in
              captured = true
              recognition += 1
              self.code = code
              Task { await lookup() }
            },
            failed: {
              status = $0
              camera = false
            }
          ).clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay {
              RoundedRectangle(cornerRadius: 12)
                .strokeBorder(captured ? nutrientGreen : .white.opacity(0.85), lineWidth: captured ? 3 : 1)
                .padding(24)
                .overlay(alignment: .bottom) {
                  if captured {
                    Label("Barcode captured", systemImage: "checkmark")
                      .font(NutrientType.font(.subheadline, weight: .semibold)).padding(10)
                      .foregroundStyle(nutrientOnGreen).background(nutrientGreen, in: Capsule())
                      .padding(.bottom, 32)
                  }
                }
                .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: captured)
                .allowsHitTesting(false).accessibilityHidden(true)
            }
            .accessibilityLabel(captured ? "Barcode captured" : "Barcode camera")
        }
        if loading { ProgressView("Looking up product…") }
        if let status { Text(status).foregroundStyle(Color("FieldSecondary")) }
        if !camera && !loading {
          Button("Scan barcode", systemImage: "barcode.viewfinder") {
            code = ""
            status = nil
            captured = false
            camera = true
          }
        }
        HStack {
          TextField("Barcode", text: $code).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
          Button("Look up") { Task { await lookup() } }.disabled(loading || code.isEmpty)
        }
        Spacer(minLength: 0)
      }.padding().background(Color("FieldBackground")).navigationTitle("Scan barcode")
        .sensoryFeedback(.impact(weight: .light), trigger: recognition)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        .sheet(item: $product, onDismiss: { if logged { dismiss() } }) { food in
          NativeMealReview(items: [MealItem(food: food, quantity: 1)], onLog: { logged = true })
        }
    }
  }
  private func lookup() async {
    guard !loading else { return }
    loading = true
    status = nil
    defer { loading = false }
    do {
      let food = try await store.backend.barcode(code)
      camera = false
      if let selected {
        selected(food)
        dismiss()
      } else {
        product = food
      }
    } catch {
      camera = false
      status = error.localizedDescription
    }
  }
}
struct NativeTrends: View {
  @EnvironmentObject var store: NutrientStore
  @State private var interval = NativeTrendInterval.daily
  @State private var range = 14
  @State private var metric = "score"
  private var unit: String { metric == "calories" ? "kcal" : metric == "score" ? "/100" : "%" }
  var body: some View {
    let buckets = store.trendBuckets(interval, count: range, metric: metric)
    let averages = store.averages(interval: interval, count: range)
    FieldList {
      Section {
        Picker(
          "Frequency",
          selection: Binding(
            get: { interval },
            set: {
              interval = $0
              range = $0.ranges[1]
            })
        ) {
          ForEach(NativeTrendInterval.allCases) { Text($0.rawValue).tag($0) }
        }.fieldSegments()
        ViewThatFits(in: .horizontal) {
          HStack {
            rangePicker
            Spacer(minLength: 8)
            metricPicker
          }
          VStack(alignment: .leading) { rangePicker; metricPicker }
        }
      }
      Section {
        if buckets.isEmpty {
          Text("No data for this nutrient yet.").foregroundStyle(Color("FieldSecondary"))
        } else {
          NativeTrendPlot(
            buckets: buckets, interval: interval, range: range, metric: metric,
            calorieTarget: store.state.calorieTarget,
            rangeStart: store.trendStart(interval, count: range), through: store.date
          ).id("\(interval.rawValue)-\(range)-\(metric)")

        }
      }
      if averages.isEmpty {
        Section {
          Text("Log meals to see your averages and gaps.").foregroundStyle(Color("FieldSecondary"))
          Button("Quick log a meal") { store.showingChat = true }
        }
      } else {
        let shortfalls = averages.filter { $0.gap > 0 }
        Section("Lowest target coverage") {
          if shortfalls.isEmpty {
            Text("All reported averages meet their targets.").foregroundStyle(
              Color("FieldSecondary"))
          }
          ForEach(Array(shortfalls.prefix(3))) { average in
            NativeAverageRow(average: average)
          }
        }
        Section {
          DisclosureGroup("All nutrient averages") {
            ForEach(averages) { average in NativeAverageRow(average: average) }
          }
        }
      }
      if !buckets.isEmpty {
        Section {
          DisclosureGroup(
            interval == .daily
              ? "Daily values" : interval == .weekly ? "Weekly values" : "Monthly values"
          ) {
            ForEach(buckets.reversed()) { bucket in
              FieldValuePair {
                Text(periodLabel(bucket.date))
              } trailing: {
                Text("\(bucket.value.formatted(.number.precision(.fractionLength(0...1)))) \(unit)")
                  .monospacedDigit().foregroundStyle(nutrientGreen)
              }.accessibilityElement(children: .combine)
            }
          }
        }
      }

    }.contentMargins(.top, 8, for: .scrollContent).fieldSurface().fieldTitle("Trends")
  }
  private var rangePicker: some View {
    Picker("Range", selection: $range) {
      ForEach(interval.ranges, id: \.self) { Text("\($0) \(interval.rangeUnit)").tag($0) }
    }.pickerStyle(.menu).labelsHidden().frame(minHeight: 44)
  }
  private var metricPicker: some View {
    Picker("Nutrient", selection: $metric) {
      Text("Coverage").tag("score")
      Text("Calories").tag("calories")
      ForEach(store.nutrients) { n in Text(n.name).tag(n.id) }
    }.pickerStyle(.menu).labelsHidden().frame(minHeight: 44)
  }
  private func periodLabel(_ date: Date) -> String {
    switch interval {
    case .daily: return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    case .weekly:
      let end = min(store.date, interval.calendar.date(byAdding: .day, value: 6, to: date)!)
      return "\(date.formatted(.dateTime.month(.abbreviated).day())) – \(end.formatted(.dateTime.month(.abbreviated).day()))"
    case .monthly: return date.formatted(.dateTime.month(.wide).year())
    }
  }
}
struct NativeTrendPlot: View {
  let buckets: [NativeTrendBucket]
  let interval: NativeTrendInterval
  let range: Int
  let metric: String
  let calorieTarget: Double
  let rangeStart: Date
  let through: Date
  @State private var selection: NativeTrendSelection
  init(buckets: [NativeTrendBucket], interval: NativeTrendInterval, range: Int,
       metric: String, calorieTarget: Double, rangeStart: Date, through: Date) {
    self.buckets = buckets
    self.interval = interval
    self.range = range
    self.metric = metric
    self.calorieTarget = calorieTarget
    self.rangeStart = rangeStart
    self.through = through
    _selection = State(initialValue: NativeTrendSelection(interval: interval, buckets: buckets))
  }
  private var unit: String { metric == "calories" ? "kcal" : metric == "score" ? "/100" : "%" }
  private var selectedDate: Date? { selection.date }
  private var selectionBinding: Binding<Date?> {
    Binding(get: { selection.date }, set: { rawDate in
      // Do not publish another view update for movement within the same period.
      guard selection.period(for: rawDate) != selection.date else { return }
      selection.select(rawDate)
    })
  }
  var body: some View {
    Group {
      VStack(alignment: .leading, spacing: 6) {
        Text(selection.date.map(periodLabel) ?? "Period average")
          .font(NutrientType.font(.subheadline)).foregroundStyle(Color("FieldSecondary"))
        if selection.date != nil && selection.bucket == nil {
          Text("Not recorded").font(NutrientType.font(.title2, weight: .semibold))
        } else {
          let days = max(1, buckets.reduce(0) { $0 + $1.days })
          let average = buckets.reduce(0) { $0 + $1.value * Double($1.days) } / Double(days)
          Text("\(number(selection.bucket?.value ?? average)) \(unit)")
            .font(NutrientType.font(.largeTitle, weight: .medium)).foregroundStyle(Color("FieldInk"))
        }
        Text(selection.date == nil
          ? "Across \(buckets.reduce(0) { $0 + $1.days }) recorded days"
          : metric == "calories" ? "Target \(number(calorieTarget)) kcal" : "Target \(metric == "score" ? "100/100" : "100%")")
          .font(NutrientType.font(.subheadline)).foregroundStyle(Color("FieldSecondary"))
      }.padding(.vertical, 4).accessibilityElement(children: .combine)
      chart.frame(height: 220).padding(.vertical, 8)
      HStack {
        Text("\(buckets.count) of \(range) \(interval.rangeUnit) recorded")
          .font(NutrientType.font(.subheadline)).foregroundStyle(Color("FieldSecondary"))
        Spacer()
        if selection.date != nil {
          Button("Average") { selection.select(nil) }.frame(minHeight: 44)
            .accessibilityLabel("Show period average")
        }
      }
    }
    .sensoryFeedback(.selection, trigger: selection.date)
    .onChange(of: buckets) { _, updated in
      let previous = selection.date
      selection = NativeTrendSelection(interval: interval, buckets: updated)
      selection.select(previous)
    }
    .onAppear {
      #if DEBUG
        if NativeDesignFixture.enabled,
          let offset = NativeDesignFixture.argument("--inspect-period").flatMap(Int.init),
          buckets.indices.contains(offset) { selection.select(buckets[offset].date) }
      #endif
    }
  }
  private var chart: some View {
    Chart {
      ForEach(buckets) { bucket in
        BarMark(
          x: .value("Period", bucket.date), y: .value("Food", bucket.foodOnly),
          width: .fixed(CGFloat(max(4, min(28, 240 / Double(range)))))
        )
        .foregroundStyle(by: .value("Source", "Food")).cornerRadius(2)
        BarMark(
          x: .value("Period", bucket.date),
          y: .value("Supplements", max(0, bucket.value - bucket.foodOnly)),
          width: .fixed(CGFloat(max(4, min(28, 240 / Double(range)))))
        )
        .foregroundStyle(by: .value("Source", "Supplements")).cornerRadius(2)
      }
      if let selectedDate {
        RuleMark(x: .value("Selected period", interval.start(of: selectedDate)))
          .foregroundStyle(Color("FieldInk").opacity(0.45)).lineStyle(StrokeStyle(lineWidth: 1))
      }
      RuleMark(y: .value("Target", metric == "calories" ? calorieTarget : 100))
        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4])).foregroundStyle(Color("FieldSecondary"))
    }.chartForegroundStyleScale(["Food": nutrientGreen, "Supplements": calorieAccent])
      .chartLegend(buckets.contains { $0.value - $0.foodOnly > 0.01 } ? .visible : .hidden)
      .chartXSelection(value: selectionBinding)
      .chartGesture { proxy in
        DragGesture(minimumDistance: 0)
          .onChanged { proxy.selectXValue(at: $0.location.x) }
      }
      .accessibilityHint("Touch and drag to inspect a period. Exact values are also available below.")
      .chartXScale(
        domain: rangeStart...interval.calendar.date(
          byAdding: interval.component, value: 1, to: interval.start(of: through))!,
        range: .plotDimension(padding: 16)
      )
      .chartXAxis {
        AxisMarks(values: axisDates) { _ in
          if interval == .monthly {
            AxisValueLabel(format: .dateTime.month(.abbreviated))
          } else {
            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
          }
        }
      }
  }
  private var axisDates: [Date] {
    let step = max(1, Int(ceil(Double(range) / 5)))
    let first = rangeStart
    return stride(from: 0, to: range, by: step).compactMap {
      interval.calendar.date(byAdding: interval.component, value: $0, to: first)
    }
  }
  private func periodLabel(_ date: Date) -> String {
    switch interval {
    case .daily: return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    case .weekly:
      let end = min(through, interval.calendar.date(byAdding: .day, value: 6, to: date)!)
      return
        "\(date.formatted(.dateTime.month(.abbreviated).day())) – \(end.formatted(.dateTime.month(.abbreviated).day()))"
    case .monthly: return date.formatted(.dateTime.month(.wide).year())
    }
  }
}
struct NativeAverageRow: View {
  let average: IntakeAverage
  var body: some View {
    VStack(alignment: .leading, spacing: FieldSpace.item) {
      FieldValuePair {
        Text(average.nutrient.name).font(NutrientType.font(.headline))
      } trailing: {
        Text("\(number(average.percentage))%").foregroundStyle(nutrientGreen)
      }
      FieldValuePair {
        VStack(alignment: .leading, spacing: FieldSpace.tight) {
          Text("\(number(average.value)) \(average.nutrient.unit)")
          Text("Target \(number(average.target)) \(average.nutrient.unit)")
            .font(NutrientType.font(.subheadline)).foregroundStyle(Color("FieldSecondary"))
        }
      } trailing: {
        Text(
          average.gap > 0 ? "\(number(average.gap)) \(average.nutrient.unit) short" : "Target met"
        )
        .font(NutrientType.font(.subheadline)).foregroundStyle(Color("FieldSecondary"))
      }
      ProgressView(value: min(1, average.percentage / 100)).tint(nutrientGreen)
      if !average.complete {
        Text("Partial data").font(NutrientType.font(.subheadline)).foregroundStyle(Color("FieldSecondary"))
      }
    }.padding(.vertical, FieldSpace.tight)
  }
}
struct NativeLibrary: View {
  @EnvironmentObject var store: NutrientStore
  @State private var query = ""
  @State private var filter = "All"
  @State private var custom = false
  @State private var label = false
  @State private var supplement = false
  @State private var build = false
  @State private var chosen: NativeFood?
  @State private var editing: NativeFood?
  var list: [NativeFood] {
    store.state.customFoods.filter {
      $0.archived != true && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query))
        && (filter == "All" || $0.kind == filter.lowercased())
    }
  }
  var body: some View {
    FieldList {
      Picker("Type", selection: $filter) {
        ForEach(["All", "Food", "Meal", "Supplement"], id: \.self) { Text($0) }
      }.fieldSegments()
      if list.isEmpty {
        Text("Save foods, meals, and supplements here.").foregroundStyle(Color("FieldSecondary"))
      }
      ForEach(list) { food in
        Button {
          chosen = food
        } label: {
          HStack(spacing: FieldSpace.item) {
            FoodRow(food: food)
            if food.kind == "meal" {
              Image(systemName: "chevron.right").font(NutrientType.font(.subheadline))
                .foregroundStyle(Color("FieldSecondary")).accessibilityHidden(true)
            }
          }
        }.foregroundStyle(.primary).swipeActions {
          Button("Archive", role: .destructive) { store.archive(food) }
        }.swipeActions(edge: .leading) {
          Button("Edit") { editing = food }
        }
      }
    }.fieldSurface().searchable(text: $query, prompt: "Find saved items")
      .fieldTitle("Library")
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          NavigationLink {
            NativeSettings()
          } label: {
            Image(systemName: "slider.horizontal.3").frame(minWidth: 44, minHeight: 44)
          }.accessibilityLabel("Settings and targets")
        }
        ToolbarItem(placement: .topBarTrailing) {
          Menu {
            Button("Scan nutrition label", systemImage: "camera.viewfinder") { label = true }
            Button("Custom food") {
              supplement = false
              custom = true
            }
            Button("Supplement") {
              supplement = true
              custom = true
            }
            Button("Build a meal") { build = true }
          } label: {
            Image(systemName: "plus").frame(minWidth: 44, minHeight: 44)
          }.accessibilityLabel("Create food, meal or supplement")
        }
      }
      .sheet(isPresented: $custom) { NativeCustomFood(supplement: supplement) }
      .sheet(isPresented: $label) { NativeCustomFood(supplement: false, scanOnOpen: true) }
      .sheet(item: $editing) { food in
        if food.kind == "meal" {
          NativeMealBuilder(existing: food, initialItems: store.mealItems(food))
        } else {
          NativeCustomFood(supplement: food.isSupplement, existing: food)
        }
      }
      .sheet(isPresented: $build) { NativeMealBuilder() }
      .sheet(item: $chosen) { food in
        if food.kind == "meal" { NativeSavedMealDetail(food: food) }
        else { NativeMealReview(items: [MealItem(food: food, quantity: 1)]) }
      }
  }
}
struct NativeSavedMealDetail: View {
  @EnvironmentObject var store: NutrientStore
  @Environment(\.dismiss) private var dismiss
  @State var food: NativeFood
  @State private var editing = false
  @State private var logging = false
  var body: some View {
    NavigationStack {
      FieldList {
        Section {
          Text(food.name).font(NutrientType.font(.title2, weight: .semibold))
          Text("Per \(food.serving)").foregroundStyle(Color("FieldSecondary"))
          NativeMealSummary(items: [MealItem(food: food, quantity: 1)])
        }
        Section("Ingredients · \(food.components?.count ?? 0)") {
          ForEach(Array(store.mealItems(food).enumerated()), id: \.offset) { _, item in
            DisclosureGroup {
              LabeledContent("Amount", value: "\(number(item.quantity)) × \(item.food.serving)")
              if item.food.energyUnreported != true {
                LabeledContent("Energy", value: "\(number(item.food.calories * item.quantity)) kcal")
              }
              ForEach(store.nutrients.filter { item.food.value($0.id) != nil }) { nutrient in
                FieldValuePair {
                  Text(nutrient.name)
                } trailing: {
                  Text("\(number((item.food.value(nutrient.id) ?? 0) * item.quantity)) \(nutrient.unit)")
                }.frame(maxWidth: .infinity)
              }
            } label: {
              VStack(alignment: .leading, spacing: FieldSpace.tight) {
                Text(item.food.name).font(NutrientType.font(.body, weight: .medium))
                FieldValuePair {
                  Text(item.food.gramsPerServing.map { "\(number(item.quantity * $0)) g" }
                    ?? "\(number(item.quantity)) × \(item.food.serving)")
                } trailing: {
                  Text(item.food.energyUnreported == true ? "Energy unreported" : "\(number(item.food.calories * item.quantity)) kcal")
                }.font(NutrientType.font(.subheadline)).foregroundStyle(Color("FieldSecondary"))
              }.frame(minHeight: FieldSpace.row, alignment: .leading)
            }
          }
        }
      }.fieldTitle("Saved meal")
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
          ToolbarItem(placement: .confirmationAction) { Button("Edit") { editing = true } }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
          Button("Log meal", systemImage: "plus") { logging = true }
            .buttonStyle(NutrientCaptureStyle(primary: true))
            .padding().background(Color("FieldBackground"))
        }
        .sheet(isPresented: $editing) {
          NativeMealBuilder(existing: food, initialItems: store.mealItems(food), onSave: { food = $0 })
        }
        .sheet(isPresented: $logging) { NativeMealReview(items: [MealItem(food: food, quantity: 1)]) }
        .task { await store.loadDatabase() }
    }
  }
}
struct NativeCustomFood: View {
  @EnvironmentObject var store: NutrientStore
  @Environment(\.dismiss) var dismiss
  var supplement: Bool
  var existing: NativeFood? = nil
  var scanOnOpen = false
  @State private var name = ""
  @State private var serving = "1 serving"
  @State private var servingWeight = ""
  @State private var calories = ""
  @State private var values: [String: String] = [:]
  @State private var source = ""
  @StateObject private var labelReader = NativeLabelReader()
  @State private var labelCamera = false
  @State private var labelPhoto: PhotosPickerItem?
  @State private var cameraError: String?
  @State private var scanned = false
  @State private var initialized = false
  var body: some View {
    NavigationStack {
      FieldForm {
        Section {
          Button {
            openLabelCamera()
          } label: {
            Label("Scan nutrition label", systemImage: "camera.viewfinder")
          }.disabled(labelReader.busy)
          PhotosPicker(selection: $labelPhoto, matching: .images) {
            Label("Choose label photo", systemImage: "photo")
          }.disabled(labelReader.busy)
          if labelReader.busy {
            HStack {
              ProgressView()
              Text(labelReader.stage)
            }
          }
          if let error = labelReader.error {
            Text(error).foregroundStyle(Color("FieldError"))
            if !labelReader.recognizedText.isEmpty {
              Button("Try again") { labelReader.retry() }
            }
          }
          if scanned { Label("Label ready to review", systemImage: "checkmark.circle") }
        }
        Section("Per serving") {
          TextField("Name", text: $name)
          TextField("Serving", text: $serving)
          HStack {
            Text("Serving weight")
            Spacer()
            TextField("Optional", text: $servingWeight).keyboardType(.decimalPad)
              .multilineTextAlignment(.trailing)
            Text("g").foregroundStyle(Color("FieldSecondary"))
          }
          TextField("Calories", text: $calories).keyboardType(.decimalPad)
          TextField("Source URL (optional)", text: $source).keyboardType(.URL)
            .textInputAutocapitalization(.never)
        }
        ForEach(["Macros", "Vitamins", "Minerals", "Other"], id: \.self) { group in
          Section(group) {
            ForEach(store.nutrients.filter { $0.group == group }) { n in
              HStack {
                Text(n.name)
                Spacer()
                TextField(
                  n.unit, text: Binding(get: { values[n.id] ?? "" }, set: { values[n.id] = $0 })
                ).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
              }
            }
          }
        }
      }.onAppear {
        guard !initialized else { return }
        initialized = true
        if scanOnOpen { openLabelCamera() }
        if let existing {
          name = existing.name
          serving = existing.serving
          servingWeight = existing.gramsPerServing.map { String($0) } ?? ""
          calories = String(existing.calories)
          source = existing.sourceUrl ?? ""
          for n in store.nutrients { values[n.id] = existing.value(n.id).map { String($0) } ?? "" }
        }
      }
      .fullScreenCover(isPresented: $labelCamera) {
        NativeLabelCamera(
          captured: { image in
            labelCamera = false
            labelReader.read(image)
          }, cancelled: { labelCamera = false }
        ).ignoresSafeArea()
      }
      .alert(
        "Camera",
        isPresented: Binding(get: { cameraError != nil }, set: { if !$0 { cameraError = nil } })
      ) {
        Button("OK") { cameraError = nil }
      } message: {
        Text(cameraError ?? "")
      }
      .onChange(of: labelPhoto) { _, photo in
        guard let photo else { return }
        Task {
          do {
            guard let data = try await photo.loadTransferable(type: Data.self),
              let image = UIImage(data: data)
            else {
              labelReader.error = "Couldn’t open this photo. Choose another."
              return
            }
            labelReader.read(image)
          } catch { labelReader.error = error.localizedDescription }
          labelPhoto = nil
        }
      }
      .onReceive(labelReader.$draft) { draft in
        guard let draft else { return }
        if !draft.name.isEmpty { name = draft.name }
        serving = draft.serving
        servingWeight = ""
        calories = draft.calories.map { String($0) } ?? ""
        values = draft.values.mapValues { $0.map { String($0) } ?? "" }
        scanned = true
      }
      .onDisappear { labelReader.cancel() }
      .navigationTitle(
        existing != nil ? "Edit label" : supplement ? "New supplement" : "Custom food"
      ).navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { save() }.disabled(
            labelReader.busy || name.trimmingCharacters(in: .whitespaces).isEmpty
              || serving.trimmingCharacters(in: .whitespaces).isEmpty
              || (!servingWeight.isEmpty
                && (Double(servingWeight) == nil || !(Double(servingWeight) ?? 0).isFinite
                  || (Double(servingWeight) ?? 0) <= 0))
              || Double(calories) == nil || (Double(calories) ?? -1) < 0
              || values.values.contains {
                !$0.isEmpty && (Double($0) == nil || (Double($0) ?? -1) < 0)
              })
        }
      }
    }
  }
  private func openLabelCamera() {
    Task {
      guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
        cameraError = "Camera isn’t available. Choose a label photo instead."
        return
      }
      let granted = await AVCaptureDevice.requestAccess(for: .video)
      if granted {
        labelCamera = true
      } else {
        cameraError = "Allow camera access in iPhone Settings, or choose a label photo."
      }
    }
  }
  private func save() {
    var nutrients: [String: Double?] = [:]
    for n in store.nutrients { nutrients[n.id] = .some(Double(values[n.id] ?? "")) }
    let f = NativeFood(
      id: "custom-" + UUID().uuidString, name: name, serving: serving,
      calories: Double(calories) ?? 0, values: nutrients, kind: supplement ? "supplement" : "food",
      source: scanned ? "Scanned nutrition label" : "Custom label",
      sourceUrl: source.isEmpty ? nil : source,
      evidence: scanned ? labelReader.recognizedText : nil,
      servingGrams: Double(servingWeight), portions: existing?.portions)
    if let existing { store.archive(existing) }
    store.state.customFoods.append(f)
    store.save()
    dismiss()
  }
}
struct NativeMealBuilder: View {
  @EnvironmentObject var store: NutrientStore
  @Environment(\.dismiss) var dismiss
  let existing: NativeFood?
  var onSave: ((NativeFood) -> Void)?
  @State private var name: String
  @State private var items: [MealItem]
  @State private var search = false
  @State private var failure: String?
  @State private var energyInputs: [UUID: String]
  init(existing: NativeFood? = nil, initialItems: [MealItem] = [], onSave: ((NativeFood) -> Void)? = nil) {
    self.existing = existing
    self.onSave = onSave
    _name = State(initialValue: existing?.name ?? "")
    _items = State(initialValue: initialItems)
    _energyInputs = State(initialValue: Dictionary(uniqueKeysWithValues:
      initialItems.filter { $0.food.energyUnreported == true }.map { ($0.id, "") }))
  }
  var body: some View {
    NavigationStack {
      FieldForm {
        Section("Meal") { TextField("Meal name", text: $name) }
        Section { NativeMealSummary(items: items) }
        Section("Ingredients") {
          ForEach($items) { $item in
            let ingredientID = item.id
            VStack(alignment: .leading, spacing: FieldSpace.controls) {
              Text(item.food.name).font(NutrientType.font(.body, weight: .medium))
              NativeQuantityInput(food: item.food, quantity: $item.quantity, compact: true)
              if energyInputs[ingredientID] != nil {
                TextField("Calories per \(item.food.serving)", text: Binding(
                  get: { energyInputs[ingredientID] ?? "" },
                  set: { text in
                    energyInputs[ingredientID] = text
                    if let value = Double(text), value.isFinite, value >= 0 {
                      item.food.calories = value
                      item.food.energyUnreported = false
                    } else {
                      item.food.calories = 0
                      item.food.energyUnreported = true
                    }
                  })).keyboardType(.decimalPad)
              }
              Button("Remove ingredient", role: .destructive) {
                items.removeAll { $0.id == ingredientID }
              }
            }
          }.onDelete { items.remove(atOffsets: $0) }
          Button("Add ingredient", systemImage: "plus") { search = true }
        }

      }.fieldSurface().navigationTitle(existing == nil ? "Build a meal" : "Edit meal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
          ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
              do {
                let saved = try store.saveMeal(name, items: items, replacing: existing)
                onSave?(saved)
                dismiss()
              } catch { failure = error.localizedDescription }
            }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || items.isEmpty
              || items.contains { !$0.quantity.isFinite || $0.quantity <= 0 || $0.quantity > 100 })
          }
        }
        .alert("Couldn't save meal", isPresented: Binding(
          get: { failure != nil }, set: { if !$0 { failure = nil } })) {
          Button("OK", role: .cancel) { failure = nil }
        } message: { Text(failure ?? "") }
        .sheet(isPresented: $search) {
          NativeFoodSearch(selected: { food in
            if !food.isSupplement {
              let item = MealItem(food: food, quantity: 1)
              if food.energyUnreported == true { energyInputs[item.id] = "" }
              items.append(item)
            }
          })
        }
    }
  }
}
struct NativeSettings: View {
  @EnvironmentObject var store: NutrientStore
  @State private var token = ""
  @State private var connection = ""
  @State private var importer = false
  @State private var imported: Data?
  @State private var confirm = false
  @State private var exportURL: URL?
  var body: some View {
    FieldForm {
      Section("Daily targets") {
        HStack {
          Text("Energy")
          Spacer()
          TextField(
            "kcal",
            value: Binding(
              get: { store.state.calorieTarget },
              set: {
                store.state.calorieTarget = max(1, min(20000, $0))
                store.save()
              }), format: .number
          ).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
        }
        Stepper(
          "Water: \(store.state.waterTarget) glasses",
          value: Binding(
            get: { store.state.waterTarget },
            set: {
              store.state.waterTarget = $0
              store.save()
            }), in: 1...30)
      }
      ForEach(["Macros", "Vitamins", "Minerals", "Other"], id: \.self) { group in
        Section(group) {
          ForEach(store.nutrients.filter { $0.group == group }) { n in
            HStack {
              Text(n.name)
              Spacer()
              TextField(
                n.unit,
                value: Binding(
                  get: { store.state.targets[n.id] ?? n.target },
                  set: {
                    store.state.targets[n.id] = max(0.01, min(100000, $0))
                    store.save()
                  }), format: .number
              ).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
              Text(n.unit).font(NutrientType.font(.caption)).foregroundStyle(Color("FieldSecondary"))
            }
          }
        }
      }
      Section("Chat connection") {
        LabeledContent("Status", value: store.backend.configured ? "Connected" : "Not connected")
        SecureField("Connection token", text: $token)
        Button("Save connection") {
          do {
            try store.backend.configure(token)
            token = ""
            connection = "Connected"
          } catch { connection = error.localizedDescription }
        }
        if !connection.isEmpty { Text(connection) }
      }
      Section("Backup") {
        Button("Export data") {
          do { exportURL = try store.export() } catch { store.error = error.localizedDescription }
        }
        if let exportURL { ShareLink("Share backup", item: exportURL) }
        Button("Import backup") { importer = true }
      }
      Section("References") {
        Link(
          "Vitamin reference intakes",
          destination: URL(
            string:
              "https://www.canada.ca/en/health-canada/services/food-nutrition/healthy-eating/dietary-reference-intakes/tables/reference-values-vitamins.html"
          )!)
        Link(
          "Mineral reference intakes",
          destination: URL(
            string:
              "https://www.canada.ca/en/health-canada/services/food-nutrition/healthy-eating/dietary-reference-intakes/tables/reference-values-elements.html"
          )!)
      }
    }.fieldSurface().navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
      .fileImporter(isPresented: $importer, allowedContentTypes: [.json]) { result in
        do {
          let url = try result.get()
          let access = url.startAccessingSecurityScopedResource()
          defer { if access { url.stopAccessingSecurityScopedResource() } }
          imported = try Data(contentsOf: url)
          confirm = true
        } catch { store.error = error.localizedDescription }
      }
      .confirmationDialog(
        "Replace your diary with this backup?", isPresented: $confirm, titleVisibility: .visible
      ) {
        Button("Replace & restore", role: .destructive) {
          if let imported {
            do { try store.restore(imported) } catch { store.error = error.localizedDescription }
          }
        }
        Button("Cancel", role: .cancel) { imported = nil }
      }
  }
}

#if DEBUG
  // Isolated fixtures exercise native geometry without touching the real diary or making requests.
  @MainActor private enum NativeDesignFixture {
    static func argument(_ flag: String) -> String? {
      let args = ProcessInfo.processInfo.arguments
      guard let index = args.firstIndex(of: flag), args.indices.contains(index + 1) else {
        return nil
      }
      return args[index + 1]
    }
    static var enabled: Bool { argument("--design-fixture") != nil }
    static var ingredients: [MealItem] {
      [
        NativeFood(
          id: "fixture-bread", name: "Whole-grain bread", serving: "2 slices (64 g)", calories: 170,
          values: ["protein": 8], servingGrams: 64),
        NativeFood(
          id: "fixture-cheese", name: "Cheddar", serving: "35 g", calories: 141,
          values: ["protein": 9], servingGrams: 35),
        NativeFood(
          id: "fixture-butter", name: "Butter", serving: "5 g", calories: 36,
          values: ["protein": 0], servingGrams: 5),
      ].map { MealItem(food: $0, quantity: 1) }
    }
    static func prepare(_ store: NutrientStore) {
      store.state.days = [:]
      store.state.customFoods = []
      store.state.chatHistory = []
      store.state.pendingMeal = nil
      store.date = Date()
      guard argument("--design-fixture") != "empty" else { return }
      var values: [String: Double?] = [:]
      for (index, n) in store.nutrients.enumerated() {
        values[n.id] = (store.state.targets[n.id] ?? n.target) * (index < 24 ? 1.05 : 0.8)
      }
      values["protein"] = 128
      values["carbs"] = 342
      values["fat"] = 67
      values["vitC"] = 41
      values["fiber"] = 30
      values["magnesium"] = 336
      let energy = argument("--design-fixture") == "over" ? 3700.0 : 2480.0
      let sample = NativeFood(
        id: "fixture-day",
        name: argument("--design-fixture") == "long"
          ? "Homemade chicken, roasted vegetables and whole-grain rice bowl with yogurt dressing"
          : "Chicken rice bowl", serving: "1 meal", calories: energy, values: values, kind: "meal")
      store.state.customFoods = [sample]
      for offset in 0..<14 {
        let date = Calendar.current.date(byAdding: .day, value: -offset, to: store.date)!
        store.state.days[store.key(date)] = DiaryDay(entries: [
          DiaryEntry(id: "fixture-entry-\(offset)", foodId: sample.id, quantity: 1, meal: "Lunch")
        ])
      }
      store.state.chatHistory = [
        NativeMessage(
          role: "user", content: "I ate a grilled cheese with bread, cheddar and butter."),
        NativeMessage(role: "assistant", content: "Your meal is ready to review."),
      ]
      store.state.pendingMeal = ingredients
      if ["saved-meal", "edit-meal", "library"].contains(argument("--design-screen") ?? "") {
        var recipe = store.composite("Grilled cheese", items: ingredients)
        recipe.id = "fixture-recipe"
        store.state.customFoods.append(recipe)
      }
      if ["reading", "follow"].contains(argument("--design-fixture") ?? "") {
        store.state.pendingMeal = nil
        store.state.chatHistory = (1...30).map {
          NativeMessage(
            role: "assistant",
            content:
              "Earlier message \($0): a saved food conversation that stays in place while you read."
          )
        }
      }
    }
  }
#endif
