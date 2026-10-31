import AVFoundation
import Charts
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct NutrientAppView: View {
  @StateObject private var store = NutrientStore()
  var body: some View {
    NativeToday()
      .sheet(isPresented: $store.showingChat) {
        NativeChat().environmentObject(store).presentationDragIndicator(.visible)
      }
      .environmentObject(store).tint(nutrientGreen)
      .foregroundStyle(Color("FieldInk"))
      .task { await store.loadDatabase() }
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

// Shared native surfaces: field-journal colors with system controls and Dynamic Type.
struct FieldSurface: ViewModifier {
  func body(content: Content) -> some View {
    content.scrollContentBackground(.hidden)
      .background(Color("FieldBackground"))
      .scrollIndicators(.hidden)
      .environment(\.defaultMinListRowHeight, 52)
      .monospacedDigit()
  }
}
extension View {
  func fieldSurface() -> some View { modifier(FieldSurface()) }
  func fieldTitle(_ title: String) -> some View {
    navigationTitle(title).navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .principal) {
          Text(title).font(.system(.title2, design: .serif).weight(.semibold))
            .accessibilityAddTraits(.isHeader)
        }
      }
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
      .listStyle(.insetGrouped).fieldSurface()
  }
}
struct FieldForm<Content: View>: View {
  @ViewBuilder var content: Content
  var body: some View {
    Form { content.listRowBackground(Color("FieldSurface")) }.fieldSurface()
  }
}
struct DashboardRing: View {
  let title: String
  let value: Double
  let target: Double
  let unit: String
  let detail: String
  let color: Color
  @ScaledMetric(relativeTo: .title2) private var diameter = 116.0
  var body: some View {
    VStack(spacing: 12) {
      Text(title).font(.subheadline.weight(.semibold)).multilineTextAlignment(.center)
      ZStack {
        Circle().stroke(color.opacity(0.18), lineWidth: 10)
        Circle().trim(from: 0, to: min(1, max(0, value / max(1, target)))).stroke(
          color, style: StrokeStyle(lineWidth: 10, lineCap: .round)
        ).rotationEffect(.degrees(-90))
        VStack(spacing: 2) {
          Text(number(value)).font(.system(.title, design: .default).weight(.semibold))
            .minimumScaleFactor(0.75).lineLimit(1)
          Text(unit).font(.subheadline).foregroundStyle(Color("FieldSecondary"))
        }.padding(10)
      }.frame(width: min(190, diameter), height: min(190, diameter))
      Text(detail).font(.subheadline).foregroundStyle(Color("FieldSecondary"))
        .multilineTextAlignment(.center)
    }.frame(maxWidth: .infinity).accessibilityElement(children: .ignore).accessibilityLabel(
      "\(title), \(number(value)) \(unit), \(detail)")
  }
}
struct NativeToday: View {
  @Environment(\.dynamicTypeSize) private var typeSize
  @EnvironmentObject var store: NutrientStore
  @State private var add = false
  @State private var scan = false
  var tracked: [NutrientDefinition] { store.nutrients.filter { $0.group != "Macros" } }
  var body: some View {
    NavigationStack {
      FieldList {
        Section {
          (typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))) {
              Button {
                scan = true
              } label: {
                Label("Scan barcode", systemImage: "barcode.viewfinder")
                  .font(.headline).frame(maxWidth: .infinity, minHeight: 60)
              }.buttonStyle(.bordered).tint(nutrientGreen)
              Button {
                store.showingChat = true
              } label: {
                Label("Quick log", systemImage: "bubble.left.and.text.bubble.right")
                  .font(.headline).frame(maxWidth: .infinity, minHeight: 60)
              }.buttonStyle(.borderedProminent).foregroundStyle(nutrientOnGreen)
            }.listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowBackground(Color.clear)
        }
        Section {
          (typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 24))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 16))) {
              DashboardRing(
                title: "Coverage", value: store.score(), target: 100, unit: "%",
                detail:
                  "\(tracked.filter{store.reported($0.id) && store.total($0.id) >= (store.state.targets[$0.id] ?? $0.target)}.count) of \(tracked.count) targets met",
                color: nutrientGreen)
              DashboardRing(
                title: "Calories", value: store.total("calories"),
                target: store.state.calorieTarget,
                unit: "kcal",
                detail:
                  "\(number(max(0, store.state.calorieTarget - store.total("calories")))) kcal left",
                color: calorieAccent)
            }.padding(.vertical, 12).listRowBackground(Color("FieldSurface"))
          ForEach(["protein", "carbs", "fat"], id: \.self) { id in
            let value = store.total(id)
            let target = store.state.targets[id] ?? 1
            NavigationLink {
              NativeNutrientDetail(id: id)
            } label: {
              VStack(alignment: .leading, spacing: 10) {
                HStack {
                  Text(id == "carbs" ? "Carbs" : id.capitalized).font(
                    .subheadline.weight(.semibold))
                  Spacer()
                  Text("\(number(value)) / \(number(target)) g").font(.subheadline).foregroundStyle(
                    Color("FieldSecondary"))
                }
                ProgressView(value: min(value / target, 1)).tint(nutrientGreen).scaleEffect(
                  x: 1, y: 1.7, anchor: .center)
              }.padding(.vertical, 7)
            }.foregroundStyle(.primary).accessibilityHint("See contributing foods")
          }
        }
        NativeDailyGaps()
        Section { NavigationLink("All \(store.nutrients.count) nutrients") { NativeNutrients() } }
        Section {
          NavigationLink {
            NativeDiary()
          } label: {
            Label("Food log & past days", systemImage: "calendar")
          }

          if store.day.entries.isEmpty { Button("Log food") { add = true } }
          ForEach(store.day.entries) { entry in
            NativeLoggedEntry(entry: entry, sourceDate: store.date)
          }
        }
        Section("Water") {
          Stepper(
            "\(store.day.water) / \(store.state.waterTarget) glasses",
            value: Binding(get: { store.day.water }, set: { store.water($0) }), in: 0...30)
        }
      }.fieldSurface().fieldTitle("Today")
        .onAppear { store.date = Date() }
        .toolbar {
          ToolbarItem(placement: .topBarLeading) {
            Menu {
              NavigationLink {
                NativeTrends()
              } label: {
                Label("Trends", systemImage: "chart.xyaxis.line")
              }
              NavigationLink {
                NativeLibrary()
              } label: {
                Label("Library", systemImage: "books.vertical")
              }
              NavigationLink {
                NativeSettings()
              } label: {
                Label("Settings", systemImage: "slider.horizontal.3")
              }
            } label: {
              Image(systemName: "line.3.horizontal").frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Trends, library and settings")
          }
          ToolbarItem(placement: .topBarTrailing) {
            Button {
              add = true
            } label: {
              Image(systemName: "plus")
            }.accessibilityLabel("Log food")
          }
        }
        .sheet(isPresented: $add) { NativeFoodSearch() }
        .sheet(isPresented: $scan) { NativeScanSheet() }
    }
  }
}
struct NativeDailyGaps: View {
  @EnvironmentObject var store: NutrientStore
  @State private var expanded = false
  var showAll = false
  var body: some View {
    Section {
      if store.day.entries.isEmpty {
        Text("Log food to see what's still needed.").foregroundStyle(Color("FieldSecondary"))
      } else if store.dailyGaps.isEmpty {
        Text(
          store.unreportedNutrients.isEmpty
            ? "All nutrient targets met" : "All reported targets met"
        ).foregroundStyle(nutrientGreen)
      }
      ForEach(Array(store.dailyGaps.prefix(expanded || showAll ? 31 : 5))) { gap in
        NavigationLink {
          NativeNutrientDetail(id: gap.id)
        } label: {
          VStack(alignment: .leading, spacing: 7) {
            HStack {
              Text(gap.nutrient.name)
              Spacer()
              Text("\(number(gap.remaining)) \(gap.nutrient.unit) left").font(
                .subheadline.weight(.semibold)
              ).foregroundStyle(nutrientGreen)
            }
            ProgressView(value: min(1, gap.fraction)).tint(nutrientGreen)
            if gap.partial {
              Text("Partial intake data").font(.footnote).foregroundStyle(Color("FieldSecondary"))
            }
          }.padding(.vertical, 4)
        }.foregroundStyle(.primary)
      }
      if !showAll && store.dailyGaps.count > 5 {
        Button(expanded ? "Show fewer" : "Show all \(store.dailyGaps.count) shortfalls") {
          expanded.toggle()
        }
      }
      if !store.day.entries.isEmpty && !store.unreportedNutrients.isEmpty {
        DisclosureGroup("Not reported · \(store.unreportedNutrients.count) nutrients") {
          ForEach(store.unreportedNutrients) { item in
            NavigationLink(item.nutrient.name) { NativeNutrientDetail(id: item.id) }
          }
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
        Label("Find foods for these gaps", systemImage: "sparkles")
      }.disabled(store.sending)
    } header: {
      Text(
        store.dailyGaps.isEmpty
          ? "Daily nutrient gaps" : "Still to go · \(store.dailyGaps.count) targets")
    }
  }
}
struct NativeDailyCoverage: View {
  @EnvironmentObject var store: NutrientStore
  var body: some View {
    FieldList {
      Text(store.date, format: .dateTime.month(.wide).day().year()).foregroundStyle(
        Color("FieldSecondary"))
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
        Text(store.date, format: .dateTime.month(.wide).day().year()).font(.subheadline)
          .foregroundStyle(Color("FieldSecondary"))
        HStack(alignment: .firstTextBaseline) {
          Text(
            store.reported(id)
              ? "\(store.incomplete(id) ? "≥ " : "")\(number(store.total(id))) \(nutrient.unit)"
              : "Not reported"
          ).font(.title2.bold())
          Spacer()
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
          VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top) {
              Text(item.food.name)
              Spacer()
              Text("\(item.partial ? "≥ " : "")\(number(item.amount ?? 0)) \(nutrient.unit)").font(
                .headline
              ).foregroundStyle(nutrientGreen).fixedSize(horizontal: true, vertical: false)
            }
            Text("\(number(item.entry.quantity)) × \(item.food.serving) · \(item.entry.meal)").font(
              .subheadline
            ).foregroundStyle(Color("FieldSecondary"))
            if let components = item.food.components,
              components.contains(where: { $0.values != nil })
            {
              DisclosureGroup("Ingredients") {
                ForEach(Array(components.enumerated()), id: \.offset) { _, component in
                  HStack(alignment: .top) {
                    Text(component.name)
                    Spacer()
                    if let value = component.values?[id] ?? nil {
                      Text(
                        "\(number(value * component.quantity * item.entry.quantity)) \(nutrient.unit)"
                      )
                      .monospacedDigit()
                    } else {
                      Text("Not reported").foregroundStyle(Color("FieldSecondary"))
                    }
                  }.font(.subheadline)
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
      VStack(alignment: .leading, spacing: 7) {
        HStack(alignment: .firstTextBaseline) {
          Text(nutrient.name)
          Spacer()
          Text(
            store.reported(nutrient.id)
              ? "\(number(value)) / \(number(target)) \(nutrient.unit)"
              : "— / \(number(target)) \(nutrient.unit)"
          ).font(.subheadline).foregroundStyle(Color("FieldSecondary")).multilineTextAlignment(
            .trailing)
        }
        if store.reported(nutrient.id) {
          ProgressView(value: min(value / target, 1)).tint(nutrientGreen)
          if store.incomplete(nutrient.id) {
            Text("Partial data").font(.caption).foregroundStyle(Color("FieldSecondary"))
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
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 5) {
            Text(food.name).foregroundStyle(.primary)
            Text("\(number(entry.quantity)) × \(food.serving) · \(entry.meal)").font(.subheadline)
              .foregroundStyle(Color("FieldSecondary"))
          }
          Spacer()
          VStack(alignment: .trailing, spacing: 8) {
            Text(
              food.energyUnreported == true
                ? "Energy unreported" : "\(number(food.calories*entry.quantity)) kcal"
            ).font(.subheadline).foregroundStyle(
              Color("FieldSecondary"))
            Image(systemName: "pencil").foregroundStyle(nutrientGreen)
          }
        }
      }.buttonStyle(.plain).accessibilityHint("Edit portion, meal, or date")
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
            Text(food.name).font(.headline)
            if let components = food.components {
              ForEach(Array(components.enumerated()), id: \.offset) { _, component in
                Text("\(component.name) · \(number(component.quantity)) × \(component.serving)")
                  .font(.subheadline).foregroundStyle(Color("FieldSecondary"))
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
              .font(.subheadline).foregroundStyle(Color("FieldSecondary"))
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
            "Nutrient coverage",
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
                    .font(.title2).foregroundStyle(nutrientGreen)
                    VStack(alignment: .leading, spacing: 5) {
                      Text(food.name).foregroundStyle(.primary)
                      Text(
                        "\(entry.quantity.formatted(.number.precision(.fractionLength(0...3)))) × \(food.serving)"
                      )
                      .font(.subheadline).foregroundStyle(Color("FieldSecondary"))
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
            Text("Save as meal (\(selectedIDs.count))").font(.headline).frame(maxWidth: .infinity)
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
struct NativeChat: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject var store: NutrientStore
  @StateObject private var speech = NativeDictation()
  @State private var speechPrefix = ""
  @State private var review = false
  @State private var scan = false
  @State private var search = false
  @FocusState private var focused: Bool
  var body: some View {
    NavigationStack {
      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 20) {
            if store.history.isEmpty {
              Text("What did you eat?").font(.title3).foregroundStyle(Color("FieldSecondary"))
                .frame(
                  maxWidth: .infinity
                ).padding(.top, 80)
            }
            ForEach(Array(store.history.enumerated()), id: \.offset) { index, message in
              MessageRow(message: message).id(index)
            }
            if store.sending {
              HStack(spacing: 10) {
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
              VStack(alignment: .leading, spacing: 14) {
                Text("Meal draft").font(.headline)
                ForEach(store.pending) { item in
                  VStack(alignment: .leading, spacing: 4) {
                    Text(item.food.name).font(.body.weight(.medium))
                    Text("\(number(item.quantity)) × \(item.food.serving)")
                      .font(.subheadline).foregroundStyle(Color("FieldSecondary"))
                  }
                }
                Divider()
                LabeledContent(
                  "Energy",
                  value:
                    "\(number(store.pending.reduce(0) { $0 + $1.food.calories * $1.quantity })) kcal"
                )
                Button {
                  focused = false
                  review = true
                } label: {
                  Label("Review meal", systemImage: "checklist").frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }.buttonStyle(.borderedProminent).foregroundStyle(nutrientOnGreen)
              }.padding(18).background(
                Color("FieldSurface"), in: RoundedRectangle(cornerRadius: 18)
              )
              .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color("FieldRule"), lineWidth: 1))
            }
            Color.clear.frame(height: 1).id("bottom")
          }.padding(16)
        }.fieldSurface().scrollDismissesKeyboard(.interactively)
          .onChange(of: store.history.count) {
            withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
          }
          .onChange(of: focused) {
            if focused { withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } }
          }
          .onChange(of: store.sending) {
            withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
          }
          .onAppear { proxy.scrollTo("bottom", anchor: .bottom) }
          .safeAreaInset(edge: .bottom, spacing: 0) { composer }
      }
      .fieldSurface().fieldTitle("Quick log")
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
      .sheet(isPresented: $review) { NativeMealReview(items: store.pending, fromChat: true) }
      .sheet(isPresented: $scan) { NativeScanSheet() }
      .sheet(isPresented: $search) { NativeFoodSearch() }
      .onChange(of: speech.transcript) { _, text in store.draft = speechPrefix + text }
      .onAppear { focused = true }
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
  private var composer: some View {
    HStack(alignment: .bottom, spacing: 8) {
      Button {
        focused = false
        scan = true
      } label: {
        Image(systemName: "barcode.viewfinder").frame(width: 44, height: 44)
      }.accessibilityLabel("Scan barcode")
      TextField("Message…", text: $store.draft, axis: .vertical).lineLimit(1...5).focused($focused)
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
      Text(.init(message.content)).textSelection(.enabled).font(.body).lineSpacing(4).padding(
        message.role == "user" ? 12 : 0
      ).background(
        message.role == "user" ? Color("FieldSoft") : .clear,
        in: RoundedRectangle(cornerRadius: 18)
      ).frame(maxWidth: .infinity, alignment: message.role == "user" ? .trailing : .leading)
      if message.role != "user" { Spacer(minLength: 4) }
    }
  }
}
struct NativeQuantityInput: View {
  let food: NativeFood
  @Binding var quantity: Double
  @State private var unitID = ""
  private var unit: NativeAmountUnit {
    food.amountUnits.first(where: { $0.id == unitID }) ?? food.amountUnits[0]
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("Amount")
        Spacer()
        TextField(
          "Amount",
          value: Binding(
            get: { quantity / unit.servings },
            set: { quantity = $0 * unit.servings }
          ), format: .number.precision(.fractionLength(0...3))
        )
        .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
        .frame(minWidth: 80, maxWidth: 140).accessibilityLabel("Food amount")
      }
      Picker(
        "Unit",
        selection: Binding(
          get: { unit.id }, set: { unitID = $0 }
        )
      ) {
        ForEach(food.amountUnits) { option in Text(option.label).tag(option.id) }
      }.pickerStyle(.menu)
      if let grams = food.gramsPerServing {
        Text(
          "\((quantity * grams).formatted(.number.precision(.fractionLength(0...2)))) g · \(quantity.formatted(.number.precision(.fractionLength(0...3)))) × \(food.serving)"
        )
        .font(.subheadline).foregroundStyle(Color("FieldSecondary")).monospacedDigit()
      } else {
        Text("Per serving: \(food.serving)").font(.subheadline).foregroundStyle(
          Color("FieldSecondary"))
      }
    }.padding(.vertical, 4)
  }
}
struct NativeMealReview: View {
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
  var calories: Double { items.reduce(0) { $0 + $1.food.calories * $1.quantity } }
  var body: some View {
    NavigationStack {
      FieldForm {
        Section {
          ForEach($items) { $item in
            VStack(alignment: .leading, spacing: 8) {
              Text(item.food.name).font(.headline)
              NativeQuantityInput(food: item.food, quantity: $item.quantity)
              if let source = item.food.source {
                Text(source).font(.caption).foregroundStyle(Color("FieldSecondary"))
              }
              if let url = item.food.sourceUrl, let link = URL(string: url), link.scheme == "https"
              {
                Link("Source", destination: link).font(.caption)
              }
            }.padding(.vertical, 4)
          }.onDelete { items.remove(atOffsets: $0) }
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
              .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 8)
          }.buttonStyle(.borderedProminent).foregroundStyle(nutrientOnGreen).disabled(
            items.isEmpty
              || items.contains { $0.quantity <= 0 || $0.quantity > 100 || !$0.quantity.isFinite }
              || (saveMeal && name.trimmingCharacters(in: .whitespaces).isEmpty)
          )

          .padding().background(Color("FieldBackground"))
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
      Image(systemName: food.isSupplement ? "pills" : food.kind == "meal" ? "fork.knife" : "leaf")
        .font(.body.weight(.medium)).foregroundStyle(nutrientGreen)
        .frame(width: 42, height: 42)
        .background(Color("FieldSoft"), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 5) {
        Text(food.name).font(.body.weight(.medium))
        Text(
          food.energyUnreported == true
            ? "\(food.serving) · energy unreported"
            : "\(food.serving) · \(number(food.calories)) kcal"
        )
        .font(.subheadline).foregroundStyle(Color("FieldSecondary"))
      }.frame(maxWidth: .infinity, alignment: .leading)
    }.padding(.vertical, 6).accessibilityElement(children: .combine)
  }
}
struct NativeScanSheet: View {
  @EnvironmentObject var store: NutrientStore
  @Environment(\.dismiss) var dismiss
  var selected: ((NativeFood) -> Void)? = nil
  @State private var logged = false
  @State private var code = ""
  @State private var camera = true
  @State private var status: String?
  @State private var loading = false
  @State private var product: NativeFood?
  var body: some View {
    NavigationStack {
      VStack(spacing: 16) {
        if camera {
          NativeScanner(
            scanned: { code in
              camera = false
              self.code = code
              Task { await lookup() }
            },
            failed: {
              status = $0
              camera = false
            }
          ).clipShape(RoundedRectangle(cornerRadius: 16))
        }
        if loading { ProgressView("Looking up product…") }
        if let status { Text(status).foregroundStyle(Color("FieldSecondary")) }
        if !camera && !loading {
          Button("Scan barcode", systemImage: "barcode.viewfinder") {
            code = ""
            status = nil
            camera = true
          }
        }
        HStack {
          TextField("Barcode", text: $code).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
          Button("Look up") { Task { await lookup() } }.disabled(loading || code.isEmpty)
        }
        Spacer(minLength: 0)
      }.padding().background(Color("FieldBackground")).navigationTitle("Scan barcode")
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
      if let selected {
        selected(food)
        dismiss()
      } else {
        product = food
      }
    } catch {
      status = error.localizedDescription
    }
  }
}
struct NativeTrends: View {
  @EnvironmentObject var store: NutrientStore
  @State private var interval = NativeTrendInterval.daily
  @State private var range = 14
  @State private var metric = "score"
  var averages: [IntakeAverage] { store.averages(interval: interval, count: range) }
  var buckets: [NativeTrendBucket] { store.trendBuckets(interval, count: range, metric: metric) }
  var unit: String { metric == "calories" ? "kcal" : "%" }
  var body: some View {
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
        Picker("Range", selection: $range) {
          ForEach(interval.ranges, id: \.self) { Text("\($0) \(interval.rangeUnit)").tag($0) }
        }
      }
      Section(interval == .daily && metric != "score" ? "Daily intake" : interval.heading) {
        Picker("Show", selection: $metric) {
          Text("Coverage").tag("score")
          Text("Energy").tag("calories")
          ForEach(store.nutrients) { n in Text(n.name).tag(n.id) }
        }
        if buckets.isEmpty {
          Text("No data for this nutrient yet.").foregroundStyle(Color("FieldSecondary"))
        } else {
          if let latest = buckets.last {
            VStack(alignment: .leading, spacing: 6) {
              Text(periodLabel(latest.date)).font(.subheadline).foregroundStyle(
                Color("FieldSecondary"))
              Text("\(number(latest.value)) \(unit)")
                .font(.system(.largeTitle, design: .default).weight(.semibold))
                .foregroundStyle(nutrientGreen)
              Text(
                metric == "calories"
                  ? "Target \(number(store.state.calorieTarget)) kcal" : "Target 100%"
              )
              .font(.subheadline).foregroundStyle(Color("FieldSecondary"))
            }.padding(.vertical, 6).accessibilityElement(children: .combine)
          }
          chart.frame(height: 220).padding(.vertical, 10)
        }
      }
      if !buckets.isEmpty {
        Section(interval == .daily ? "By day" : interval == .weekly ? "By week" : "By month") {
          ForEach(buckets.reversed()) { bucket in
            LabeledContent {
              Text("\(bucket.value.formatted(.number.precision(.fractionLength(0...1)))) \(unit)")
                .monospacedDigit().foregroundStyle(nutrientGreen)
            } label: {
              Text(periodLabel(bucket.date))
            }
          }
        }
      }
      if averages.isEmpty {
        Section {
          Text("Log meals to see your averages and gaps.").foregroundStyle(
            Color("FieldSecondary"))
          Button("Log a meal in Chat") { store.showingChat = true }
        }
      } else {
        Section("Average daily intake") {
          ForEach(averages) { average in
            VStack(alignment: .leading, spacing: 7) {
              HStack {
                Text(average.nutrient.name).font(.headline)
                Spacer()
                Text("\(number(average.percentage))%").foregroundStyle(nutrientGreen)
              }
              HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                  Text("\(number(average.value)) \(average.nutrient.unit)")
                  Text("Target \(number(average.target)) \(average.nutrient.unit)").font(.caption)
                    .foregroundStyle(Color("FieldSecondary"))
                }
                Spacer()
                Text(
                  average.gap > 0
                    ? "Gap \(number(average.gap)) \(average.nutrient.unit)" : "Target met"
                ).font(.subheadline).foregroundStyle(Color("FieldSecondary"))
              }
              ProgressView(value: min(1, average.percentage / 100)).tint(nutrientGreen)
              if !average.complete {
                Text("Partial data").font(.caption).foregroundStyle(Color("FieldSecondary"))
              }
            }.padding(.vertical, 6)
          }
        }
      }

    }.fieldSurface().fieldTitle("Trends")
  }
  private var chart: some View {
    Chart {
      ForEach(buckets) { bucket in
        BarMark(
          x: .value("Period", bucket.date), y: .value("Food", bucket.foodOnly),
          width: .fixed(CGFloat(max(4, min(28, 240 / Double(range)))))
        )
        .foregroundStyle(by: .value("Source", "Food"))
        BarMark(
          x: .value("Period", bucket.date),
          y: .value("Supplements", max(0, bucket.value - bucket.foodOnly)),
          width: .fixed(CGFloat(max(4, min(28, 240 / Double(range)))))
        )
        .foregroundStyle(by: .value("Source", "Supplements"))
      }
      RuleMark(y: .value("Target", metric == "calories" ? store.state.calorieTarget : 100))
        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4])).foregroundStyle(Color("FieldSecondary"))
    }.chartForegroundStyleScale(["Food": nutrientGreen, "Supplements": calorieAccent])
      .chartXScale(
        domain: store.trendStart(interval, count: range)...interval.calendar.date(
          byAdding: interval.component, value: 1, to: interval.start(of: store.date))!,
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
    let first = store.trendStart(interval, count: range)
    return stride(from: 0, to: range, by: step).compactMap {
      interval.calendar.date(byAdding: interval.component, value: $0, to: first)
    }
  }
  private func periodLabel(_ date: Date) -> String {
    switch interval {
    case .daily: return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    case .weekly:
      let end = min(store.date, interval.calendar.date(byAdding: .day, value: 6, to: date)!)
      return
        "\(date.formatted(.dateTime.month(.abbreviated).day())) – \(end.formatted(.dateTime.month(.abbreviated).day()))"
    case .monthly: return date.formatted(.dateTime.month(.wide).year())
    }
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
          FoodRow(food: food)
        }.foregroundStyle(.primary).swipeActions {
          Button("Archive", role: .destructive) { store.archive(food) }
        }.swipeActions(edge: .leading) {
          if food.kind != "meal" { Button("Edit") { editing = food } }
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
        NativeCustomFood(supplement: food.isSupplement, existing: food)
      }
      .sheet(isPresented: $build) { NativeMealBuilder() }
      .sheet(item: $chosen) { food in NativeMealReview(items: [MealItem(food: food, quantity: 1)]) }
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
  @State private var name = ""
  @State private var items: [MealItem] = []
  @State private var search = false
  var body: some View {
    NavigationStack {
      FieldForm {
        TextField("Meal name", text: $name)
        ForEach($items) { $item in
          VStack(alignment: .leading) {
            Text(item.food.name)
            NativeQuantityInput(food: item.food, quantity: $item.quantity)
          }
        }.onDelete { items.remove(atOffsets: $0) }
        Button("Add ingredient") { search = true }
        LabeledContent(
          "Energy", value: "\(number(items.reduce(0){$0+$1.food.calories*$1.quantity})) kcal")
      }.fieldSurface().navigationTitle("Build a meal").navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
          ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
              store.state.customFoods.append(store.composite(name, items: items))
              store.save()
              dismiss()
            }.disabled(
              name.trimmingCharacters(in: .whitespaces).isEmpty || items.isEmpty
                || items.contains { $0.quantity <= 0 || $0.quantity > 100 })
          }
        }
        .sheet(isPresented: $search) {
          NativeFoodSearch(selected: { food in
            if !food.isSupplement {
              if let i = items.firstIndex(where: { $0.food.id == food.id }) {
                items[i].quantity += 1
              } else {
                items.append(MealItem(food: food, quantity: 1))
              }
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
              Text(n.unit).font(.caption).foregroundStyle(Color("FieldSecondary"))
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
