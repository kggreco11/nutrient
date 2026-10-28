import Charts
import SwiftUI
import UniformTypeIdentifiers

struct NutrientAppView: View {
  @StateObject private var store = NutrientStore()
  var body: some View {
    TabView(selection: $store.tab) {
      NativeToday().tabItem { Label("Today", systemImage: "circle.grid.2x2") }.tag(0)
      NativeDiary().tabItem { Label("Diary", systemImage: "list.bullet.rectangle") }.tag(1)
      NativeChat().tabItem { Label("Chat", systemImage: "bubble.left") }.tag(2)
      NativeTrends().tabItem { Label("Trends", systemImage: "chart.xyaxis.line") }.tag(3)
      NativeMore().tabItem { Label("More", systemImage: "ellipsis") }.tag(4)
    }
    .environmentObject(store).tint(nutrientGreen)
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
struct ScoreRing: View {
  let score: Double
  var body: some View {
    ZStack {
      Circle().stroke(nutrientGreen.opacity(0.14), lineWidth: 10)
      Circle().trim(from: 0, to: min(1, max(0, score / 100))).stroke(
        nutrientGreen, style: StrokeStyle(lineWidth: 10, lineCap: .round)
      ).rotationEffect(.degrees(-90))
      VStack(spacing: 0) {
        Text(number(score)).font(.system(.largeTitle, design: .rounded).weight(.semibold))
        Text("/ 100").font(.caption).foregroundStyle(.secondary)
      }
    }.frame(width: 86, height: 86).padding(8).accessibilityElement(children: .ignore)
      .accessibilityLabel("Nutrient score, \(Int(score)) out of 100")
  }
}
struct NativeToday: View {
  @EnvironmentObject var store: NutrientStore
  @State private var add = false
  @State private var group = "Overview"
  var tracked: [NutrientDefinition] { store.nutrients.filter { $0.group != "Macros" } }
  var shown: [NutrientDefinition] {
    group == "Overview"
      ? ["vitD", "choline", "chromium", "b6", "b12", "magnesium"].compactMap { id in
        tracked.first { $0.id == id }
      } : tracked.filter { $0.group == group }
  }
  var body: some View {
    NavigationStack {
      List {
        Section {
          HStack(spacing: 16) {
            ScoreRing(score: store.score())
            VStack(alignment: .leading, spacing: 6) {
              Text("Nutrient coverage").font(.headline)
              Text(
                "\(tracked.filter{store.reported($0.id) && store.total($0.id) >= (store.state.targets[$0.id] ?? $0.target)}.count) of \(tracked.count) targets met"
              ).foregroundStyle(.secondary)
              Text("\(number(store.total("calories"))) / \(number(store.state.calorieTarget)) kcal")
                .font(.subheadline)
            }
          }
          HStack(spacing: 16) {
            ForEach(["protein", "carbs", "fat"], id: \.self) { id in
              VStack(alignment: .leading, spacing: 5) {
                Text(id == "carbs" ? "Carbs" : id.capitalized).font(.subheadline).foregroundStyle(
                  .secondary)
                Text("\(number(store.total(id))) / \(number(store.state.targets[id] ?? 0)) g").font(
                  .subheadline.weight(.semibold))
              }.frame(maxWidth: .infinity, alignment: .leading)
            }
          }.padding(.vertical, 6)
        }
        Section {
          Picker("Show", selection: $group) {
            ForEach(["Overview", "Vitamins", "Minerals", "Other"], id: \.self) { Text($0) }
          }
          ForEach(shown) { NativeNutrientRow(nutrient: $0) }
          NavigationLink("All \(store.nutrients.count) nutrients") { NativeNutrients() }
        } header: {
          Text("Nutrients")
        }
        Section("Today's food") {
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
      }.scrollIndicators(.hidden).navigationTitle("Today").navigationBarTitleDisplayMode(.inline)
        .onAppear { store.date = Date() }
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            Button {
              add = true
            } label: {
              Image(systemName: "plus")
            }.accessibilityLabel("Log food")
          }
        }
        .sheet(isPresented: $add) { NativeFoodSearch() }
    }
  }
}
struct NativeNutrientRow: View {
  @EnvironmentObject var store: NutrientStore
  let nutrient: NutrientDefinition
  var body: some View {
    let value = store.total(nutrient.id)
    let target = store.state.targets[nutrient.id] ?? nutrient.target
    VStack(alignment: .leading, spacing: 7) {
      HStack(alignment: .firstTextBaseline) {
        Text(nutrient.name)
        Spacer()
        Text(
          store.reported(nutrient.id)
            ? "\(number(value)) / \(number(target)) \(nutrient.unit)"
            : "— / \(number(target)) \(nutrient.unit)"
        ).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
      }
      if store.reported(nutrient.id) {
        ProgressView(value: min(value / target, 1)).tint(nutrientGreen)
        if store.incomplete(nutrient.id) {
          Text("Partial data").font(.caption).foregroundStyle(.secondary)
        }
      } else {
        Text(store.day.entries.isEmpty ? "No food logged" : "Not reported in logged foods").font(
          .caption
        ).foregroundStyle(.secondary)
      }
    }.padding(.vertical, 4)
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
              .foregroundStyle(.secondary)
          }
          Spacer()
          VStack(alignment: .trailing, spacing: 8) {
            Text("\(number(food.calories*entry.quantity)) kcal").font(.subheadline).foregroundStyle(
              .secondary)
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
      Form {
        if let food = store.food(entry.foodId) {
          Section {
            Text(food.name).font(.headline)
            LabeledContent("Source serving", value: food.serving)
            HStack {
              Text("Servings")
              Spacer()
              TextField("Servings", value: $quantity, format: .number).keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
            }
            LabeledContent("Energy", value: "\(number(food.calories*quantity)) kcal")
          }
          Section {
            Picker("Meal", selection: $meal) {
              ForEach(food.isSupplement ? ["Supplements"] : nativeMeals, id: \.self) { Text($0) }
            }
            DatePicker("Date", selection: $date, displayedComponents: .date)
          }
        }
        if let failure { Text(failure).foregroundStyle(.red) }
      }.navigationTitle("Edit entry").navigationBarTitleDisplayMode(.inline)
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
struct NativeDiary: View {
  @EnvironmentObject var store: NutrientStore
  @State private var add = false
  var body: some View {
    NavigationStack {
      List {
        DatePicker("Date", selection: $store.date, displayedComponents: .date)
        ForEach(nativeMeals, id: \.self) { meal in
          Section(meal) {
            let entries = store.day.entries.filter { $0.meal == meal }
            if entries.isEmpty { Text("No entries").foregroundStyle(.secondary) }
            ForEach(entries) { entry in NativeLoggedEntry(entry: entry, sourceDate: store.date) }
            Button("Add food") { add = true }
          }
        }
      }.scrollIndicators(.hidden).navigationTitle("Diary")
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            Button {
              add = true
            } label: {
              Image(systemName: "plus")
            }.accessibilityLabel("Log food")
          }
        }
        .sheet(isPresented: $add) { NativeFoodSearch() }
    }
  }
}
struct NativeNutrients: View {
  @EnvironmentObject var store: NutrientStore
  @State private var query = ""
  var body: some View {
    List {
      ForEach(
        store.nutrients.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
      ) { n in
        NativeNutrientRow(nutrient: n)
      }
    }.searchable(text: $query, prompt: "Find a nutrient").scrollIndicators(.hidden).navigationTitle(
      "Nutrients"
    ).navigationBarTitleDisplayMode(.inline)
  }
}
struct NativeChat: View {
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
              Text("What did you eat?").font(.title3).foregroundStyle(.secondary).frame(
                maxWidth: .infinity
              ).padding(.top, 80)
            }
            ForEach(Array(store.history.enumerated()), id: \.offset) { index, message in
              MessageRow(message: message).id(index)
            }
            if store.sending {
              HStack(spacing: 10) {
                ProgressView()
                Text("Looking up your meal…").foregroundStyle(.secondary)
              }
            }
            if let error = store.chatError {
              VStack(alignment: .leading, spacing: 8) {
                Text(error).foregroundStyle(.red)
                Button("Retry") {
                  Task {
                    await store.send(
                      store.history.last(where: { $0.role == "user" })?.content ?? "", retry: true)
                  }
                }
              }
            }
            if !store.pending.isEmpty {
              Button {
                focused = false
                review = true
              } label: {
                Label("Review meal", systemImage: "checklist").frame(maxWidth: .infinity).padding(
                  12)
              }.buttonStyle(.borderedProminent).foregroundStyle(nutrientOnGreen)
            }
            Color.clear.frame(height: 1).id("bottom")
          }.padding(16)
        }.scrollIndicators(.hidden).scrollDismissesKeyboard(.interactively)
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
      .navigationTitle("Chat").navigationBarTitleDisplayMode(.inline)
      .toolbar {
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
        Image(systemName: "barcode.viewfinder").frame(width: 36, height: 44)
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
          width: 36, height: 44)
      }.accessibilityLabel(speech.listening ? "Stop dictation" : "Dictate a meal")
      Button {
        let message = store.draft
        speech.stop()
        focused = false
        Task { await store.send(message) }
      } label: {
        Image(systemName: "arrow.up.circle.fill").font(.system(size: 36))
      }.disabled(
        store.sending || store.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      ).accessibilityLabel("Send message")
    }.padding(.horizontal, 10).background(
      .quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 24)
    ).padding(.horizontal, 12).padding(.vertical, 8).background(.bar)
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
        message.role == "user" ? Color(.secondarySystemGroupedBackground) : .clear,
        in: RoundedRectangle(cornerRadius: 18)
      ).frame(maxWidth: .infinity, alignment: message.role == "user" ? .trailing : .leading)
      if message.role != "user" { Spacer(minLength: 4) }
    }
  }
}
struct NativeMealReview: View {
  @EnvironmentObject var store: NutrientStore
  @Environment(\.dismiss) var dismiss
  @State var items: [MealItem]
  var fromChat = false
  @State private var meal = "Breakfast"
  @State private var name = ""
  @State private var saveMeal = false
  var calories: Double { items.reduce(0) { $0 + $1.food.calories * $1.quantity } }
  var body: some View {
    NavigationStack {
      Form {
        Section {
          ForEach($items) { $item in
            VStack(alignment: .leading, spacing: 8) {
              Text(item.food.name).font(.headline)
              HStack {
                Text("Servings of \(item.food.serving)").foregroundStyle(.secondary)
                Spacer()
                TextField("Servings", value: $item.quantity, format: .number).keyboardType(
                  .decimalPad
                ).multilineTextAlignment(.trailing).frame(width: 70)
              }
              if let source = item.food.source {
                Text(source).font(.caption).foregroundStyle(.secondary)
              }
              if let url = item.food.sourceUrl, let link = URL(string: url), link.scheme == "https"
              {
                Link("Source", destination: link).font(.caption)
              }
            }.padding(.vertical, 4)
          }
        }
        Section {
          LabeledContent("Energy", value: "\(number(calories)) kcal")
          Picker("Log to", selection: $meal) { ForEach(nativeMeals, id: \.self) { Text($0) } }
          DatePicker("Date", selection: $store.date, displayedComponents: .date)
        }
        Section {
          Toggle("Save as a reusable meal", isOn: $saveMeal)
          if saveMeal { TextField("Meal name", text: $name) }
        }
        Button("Confirm & log meal") {
          store.log(items, meal: meal, saveAs: saveMeal ? name : "")
          if fromChat {
            store.state.chatHistory =
              store.history + [NativeMessage(role: "assistant", content: "Logged this meal.")]
            store.save()
          }
          dismiss()
        }.disabled(
          items.isEmpty
            || items.contains { $0.quantity <= 0 || $0.quantity > 100 || !$0.quantity.isFinite }
            || (saveMeal && name.trimmingCharacters(in: .whitespaces).isEmpty))
      }.navigationTitle("Review meal").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
    }
  }
}
struct NativeFoodSearch: View {
  @EnvironmentObject var store: NutrientStore
  @Environment(\.dismiss) var dismiss
  var selected: ((NativeFood) -> Void)? = nil
  @State private var query = ""
  @State private var chosen: NativeFood?
  @State private var scan = false
  var body: some View {
    NavigationStack {
      List {
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
        if store.search(query).isEmpty { Text("No matching foods").foregroundStyle(.secondary) }
      }.scrollIndicators(.hidden).searchable(text: $query, prompt: "Search foods or a brand")
        .navigationTitle("Add food").navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
          ToolbarItem(placement: .topBarTrailing) {
            Button {
              scan = true
            } label: {
              Image(systemName: "barcode.viewfinder")
            }.accessibilityLabel("Scan barcode")
          }
        }
        .sheet(item: $chosen) { food in NativeMealReview(items: [MealItem(food: food, quantity: 1)])
        }
        .sheet(isPresented: $scan) { NativeScanSheet() }
    }
  }
}
struct FoodRow: View {
  let food: NativeFood
  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(food.name)
      Text("\(food.serving) · \(number(food.calories)) kcal").font(.subheadline).foregroundStyle(
        .secondary)
      if let source = food.source { Text(source).font(.caption).foregroundStyle(.secondary) }
    }.padding(.vertical, 4)
  }
}
struct NativeScanSheet: View {
  @EnvironmentObject var store: NutrientStore
  @Environment(\.dismiss) var dismiss
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
        if let status { Text(status).foregroundStyle(.secondary) }
        HStack {
          TextField("Barcode", text: $code).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
          Button("Look up") { Task { await lookup() } }.disabled(loading || code.isEmpty)
        }
        Spacer(minLength: 0)
      }.padding().navigationTitle("Scan barcode").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        .sheet(item: $product) { food in
          NativeMealReview(items: [MealItem(food: food, quantity: 1)])
        }
    }
  }
  private func lookup() async {
    guard !loading else { return }
    loading = true
    status = nil
    defer { loading = false }
    do { product = try await store.backend.barcode(code) } catch {
      status = error.localizedDescription
    }
  }
}
struct NativeTrends: View {
  @EnvironmentObject var store: NutrientStore
  @State private var range = 6
  @State private var metric = "score"
  var averages: [IntakeAverage] { store.averages(months: range) }
  var months: [MonthAverage] { store.months(range, metric: metric) }
  var unit: String { metric == "calories" ? "kcal" : "%" }
  var body: some View {
    NavigationStack {
      List {
        Section {
          Picker("Range", selection: $range) {
            Text("3 months").tag(3)
            Text("6 months").tag(6)
            Text("12 months").tag(12)
          }.pickerStyle(.segmented)
        }
        Section("Monthly averages") {
          Picker("Show", selection: $metric) {
            Text("Nutrient score").tag("score")
            Text("Energy").tag("calories")
            ForEach(store.nutrients) { n in Text(n.name).tag(n.id) }
          }
          if months.isEmpty {
            Text("No data for this nutrient yet.").foregroundStyle(.secondary)
          } else {
            chart.frame(height: 220).padding(.vertical, 10)
          }
        }
        if averages.isEmpty {
          Section {
            Text("Log meals to see your averages and gaps.").foregroundStyle(.secondary)
            Button("Log a meal in Chat") { store.tab = 2 }
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
                      .foregroundStyle(.secondary)
                  }
                  Spacer()
                  Text(
                    average.gap > 0
                      ? "Gap \(number(average.gap)) \(average.nutrient.unit)" : "Target met"
                  ).font(.subheadline).foregroundStyle(.secondary)
                }
                ProgressView(value: min(1, average.percentage / 100)).tint(nutrientGreen)
                if !average.complete {
                  Text("Partial data").font(.caption).foregroundStyle(.secondary)
                }
              }.padding(.vertical, 6)
            }
          }
        }

      }.scrollIndicators(.hidden).navigationTitle("Trends")
    }
  }
  private var chart: some View {
    Chart {
      ForEach(months) { month in
        BarMark(x: .value("Month", month.date, unit: .month), y: .value("Food", month.foodOnly))
          .foregroundStyle(by: .value("Source", "Food"))
        BarMark(
          x: .value("Month", month.date, unit: .month),
          y: .value("Supplements", max(0, month.value - month.foodOnly))
        ).foregroundStyle(by: .value("Source", "Supplements"))
      }
      RuleMark(y: .value("Target", metric == "calories" ? store.state.calorieTarget : 100))
        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4])).foregroundStyle(.secondary)
    }.chartForegroundStyleScale(["Food": nutrientGreen, "Supplements": Color.orange.opacity(0.7)])
      .chartXAxis {
        AxisMarks(values: .stride(by: .month)) { _ in
          AxisValueLabel(format: .dateTime.month(.abbreviated))
        }
      }
  }
}
struct NativeMore: View {
  var body: some View {
    NavigationStack {
      List {
        NavigationLink("Library") { NativeLibrary() }
        NavigationLink("Nutrients") { NativeNutrients() }
        NavigationLink("Settings") { NativeSettings() }
      }
      .scrollIndicators(.hidden).navigationTitle("More")
    }
  }
}
struct NativeLibrary: View {
  @EnvironmentObject var store: NutrientStore
  @State private var query = ""
  @State private var filter = "All"
  @State private var custom = false
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
    List {
      Picker("Type", selection: $filter) {
        ForEach(["All", "Food", "Meal", "Supplement"], id: \.self) { Text($0) }
      }.pickerStyle(.segmented)
      if list.isEmpty {
        Text("Save foods, meals, and supplements here.").foregroundStyle(.secondary)
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
    }.scrollIndicators(.hidden).searchable(text: $query, prompt: "Find saved items")
      .navigationTitle("Library").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Menu {
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
            Image(systemName: "plus")
          }
        }
      }
      .sheet(isPresented: $custom) { NativeCustomFood(supplement: supplement) }
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
  @State private var name = ""
  @State private var serving = "1 serving"
  @State private var calories = ""
  @State private var values: [String: String] = [:]
  @State private var source = ""
  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("Name", text: $name)
          TextField("Serving", text: $serving)
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
        if let existing {
          name = existing.name
          serving = existing.serving
          calories = String(existing.calories)
          source = existing.sourceUrl ?? ""
          for n in store.nutrients { values[n.id] = existing.value(n.id).map { String($0) } ?? "" }
        }
      }.navigationTitle(
        existing != nil ? "Edit label" : supplement ? "New supplement" : "Custom food"
      ).navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
          ToolbarItem(placement: .confirmationAction) {
            Button("Save") { save() }.disabled(
              name.trimmingCharacters(in: .whitespaces).isEmpty || serving.isEmpty
                || Double(calories) == nil || (Double(calories) ?? -1) < 0
                || values.values.contains {
                  !$0.isEmpty && (Double($0) == nil || (Double($0) ?? -1) < 0)
                })
          }
        }
    }
  }
  private func save() {
    var nutrients: [String: Double?] = [:]
    for n in store.nutrients { nutrients[n.id] = .some(Double(values[n.id] ?? "")) }
    let f = NativeFood(
      id: "custom-" + UUID().uuidString, name: name, serving: serving,
      calories: Double(calories) ?? 0, values: nutrients, kind: supplement ? "supplement" : "food",
      source: "Custom label", sourceUrl: source.isEmpty ? nil : source)
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
      Form {
        TextField("Meal name", text: $name)
        ForEach($items) { $item in
          VStack(alignment: .leading) {
            Text(item.food.name)
            TextField("Servings of \(item.food.serving)", value: $item.quantity, format: .number)
              .keyboardType(.decimalPad)
          }
        }.onDelete { items.remove(atOffsets: $0) }
        Button("Add ingredient") { search = true }
        LabeledContent(
          "Energy", value: "\(number(items.reduce(0){$0+$1.food.calories*$1.quantity})) kcal")
      }.navigationTitle("Build a meal").navigationBarTitleDisplayMode(.inline)
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
    Form {
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
              Text(n.unit).font(.caption).foregroundStyle(.secondary)
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
    }.scrollIndicators(.hidden).navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
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
