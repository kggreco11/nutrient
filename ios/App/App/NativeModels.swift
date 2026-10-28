import Foundation
import SwiftUI

struct NutrientDefinition: Codable, Identifiable {
  let id: String
  let name: String
  let unit: String
  let target: Double
  let group: String
}
struct FoodComponent: Codable {
  let name: String
  let serving: String
  let source: String
  let quantity: Double
}
struct NativeFood: Codable, Identifiable {
  var id: String
  var name: String
  var serving: String
  var calories: Double
  var values: [String: Double?]
  var kind: String?
  var source: String?
  var sourceId: String?
  var sourceUrl: String?
  var emoji: String?
  var archived: Bool?
  var partialNutrients: [String]?
  var components: [FoodComponent]?
  var evidence: String?
  var retrievedAt: String?
  func value(_ id: String) -> Double? { values[id] ?? nil }
  var isSupplement: Bool { kind == "supplement" }
}
struct DiaryEntry: Codable, Identifiable {
  var id: String
  var foodId: String
  var quantity: Double
  var meal: String
}
struct DiaryDay: Codable {
  var entries: [DiaryEntry] = []
  var water: Int = 0
  var demo: Bool?
}
struct NativeMessage: Codable {
  var role: String
  var content: String
}
struct MealItem: Codable, Identifiable {
  let id = UUID()
  enum CodingKeys: String, CodingKey { case food, quantity }
  var food: NativeFood
  var quantity: Double
}
struct NativeState: Codable {
  var version: Int
  var targets: [String: Double]
  var calorieTarget: Double
  var waterTarget: Int
  var customFoods: [NativeFood]
  var days: [String: DiaryDay]
  var referenceTargetVersion: Int?
  var chatHistory: [NativeMessage]?
  var pendingMeal: [MealItem]?
}
struct NativeSeed: Decodable {
  let nutrients: [NutrientDefinition]
  let foods: [NativeFood]
  let targets: [String: Double]
}
struct AgentResponse: Decodable {
  let reply: String
  let proposal: [MealItem]?
}
struct IntakeAverage: Identifiable {
  let nutrient: NutrientDefinition
  let value: Double
  let target: Double
  let reportedDays: Int
  let complete: Bool
  var id: String { nutrient.id }
  var percentage: Double { target > 0 ? value / target * 100 : 0 }
  var gap: Double { max(0, target - value) }
}
struct MonthAverage: Identifiable {
  let date: Date
  let value: Double
  let foodOnly: Double
  let days: Int
  var id: Date { date }
}
let nativeMeals = ["Breakfast", "Lunch", "Dinner", "Snacks", "Supplements"]
let nutrientGreen = Color(red: 0.29, green: 0.39, blue: 0.23)
func number(_ value: Double) -> String {
  value.formatted(.number.precision(.fractionLength(0...(value < 10 ? 1 : 0))))
}

@MainActor final class NutrientStore: ObservableObject {
  @Published var state: NativeState
  @Published var date = Date()
  @Published var tab = 0
  @Published var database: [NativeFood] = []
  @Published var sending = false
  @Published var chatError: String?
  @Published var databaseError: String?
  @Published var draft = ""
  @Published var error: String?
  let nutrients: [NutrientDefinition]
  let sampleFoods: [NativeFood]
  let backend = NativeBackend()
  private let dataURL: URL
  init() {
    let seedURL = Bundle.main.url(forResource: "NativeSeed", withExtension: "json")!
    let seed = try! JSONDecoder().decode(NativeSeed.self, from: Data(contentsOf: seedURL))
    nutrients = seed.nutrients
    sampleFoods = seed.foods
    let directory = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask)[0]
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    dataURL = directory.appendingPathComponent("nutrient-native.json")
    let existing =
      (try? Data(contentsOf: dataURL))
      ?? UserDefaults.standard.string(forKey: "CapacitorStorage.nutrient-v1")?.data(using: .utf8)
    if let existing, let restored = try? JSONDecoder().decode(NativeState.self, from: existing),
      Self.valid(restored, nutrients: seed.nutrients, foods: seed.foods)
    {
      state = restored
    } else {
      state = NativeState(
        version: 1, targets: seed.targets, calorieTarget: 2200, waterTarget: 8, customFoods: [],
        days: [:], referenceTargetVersion: 1)
      if let existing {
        let recovery = directory.appendingPathComponent(
          "nutrient-recovery-" + UUID().uuidString + ".json")
        try? existing.write(to: recovery, options: .atomic)
        error = "Saved data could not be read. A recovery copy has been kept."
      }
    }
    if state.referenceTargetVersion != 1 {
      let old: [String: Double] = [
        "fiber": 28, "vitD": 20, "b6": 1.7, "calcium": 1300, "iron": 18, "magnesium": 420,
        "potassium": 4700,
      ]
      for (key, value) in old where state.targets[key] == value {
        state.targets[key] = seed.targets[key]
      }
      state.referenceTargetVersion = 1
    }
    state.chatHistory = Array(
      (state.chatHistory ?? []).filter { ["user", "assistant"].contains($0.role) }.suffix(100))
    if let pending = state.pendingMeal,
      !pending.allSatisfy({ $0.quantity > 0 && $0.quantity <= 100 })
    {
      state.pendingMeal = nil
    }
    backend.bootstrap()
  }
  static func valid(_ state: NativeState, nutrients: [NutrientDefinition], foods: [NativeFood])
    -> Bool
  {
    guard state.version == 1, state.calorieTarget > 0, state.calorieTarget <= 20000,
      (1...30).contains(state.waterTarget),
      nutrients.allSatisfy({
        (state.targets[$0.id] ?? 0) > 0 && (state.targets[$0.id] ?? 0) <= 100000
      })
    else { return false }
    guard
      state.customFoods.allSatisfy({
        $0.calories >= 0 && $0.values.values.allSatisfy { $0 == nil || ($0! >= 0 && $0!.isFinite) }
      })
    else { return false }
    let ids = Set((foods + state.customFoods).map(\.id))
    return state.days.allSatisfy { key, day in
      key.count == 10 && (0...30).contains(day.water)
        && day.entries.allSatisfy {
          ids.contains($0.foodId) && $0.quantity > 0 && $0.quantity <= 100
            && nativeMeals.contains($0.meal)
        }
    }
  }
  var foods: [NativeFood] { sampleFoods + state.customFoods }
  var history: [NativeMessage] { state.chatHistory ?? [] }
  var pending: [MealItem] { state.pendingMeal ?? [] }
  func key(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: date)
  }
  var day: DiaryDay { state.days[key(date)] ?? DiaryDay() }
  func food(_ id: String) -> NativeFood? { foods.first { $0.id == id } }
  func save() {
    do {
      let data = try JSONEncoder().encode(state)
      try data.write(to: dataURL, options: .atomic)
      UserDefaults.standard.set(
        String(data: data, encoding: .utf8), forKey: "CapacitorStorage.nutrient-v1")
    } catch { self.error = "Couldn't save. Export a backup before closing the app." }
  }
  func total(_ nutrient: String, entries: [DiaryEntry]? = nil) -> Double {
    (entries ?? day.entries).reduce(0) { sum, e in
      guard let f = food(e.foodId) else { return sum }
      return sum + (nutrient == "calories" ? f.calories : (f.value(nutrient) ?? 0)) * e.quantity
    }
  }
  func score(entries: [DiaryEntry]? = nil) -> Double {
    let tracked = nutrients.filter { $0.group != "Macros" }
    return tracked.reduce(0) {
      $0 + min(100, total($1.id, entries: entries) / (state.targets[$1.id] ?? $1.target) * 100)
    } / Double(tracked.count)
  }
  func remember(_ food: NativeFood) {
    if !foods.contains(where: { $0.id == food.id }) { state.customFoods.append(food) }
  }
  func log(_ items: [MealItem], meal: String, saveAs name: String = "") {
    if !name.trimmingCharacters(in: .whitespaces).isEmpty {
      state.customFoods.append(composite(name, items: items.filter { !$0.food.isSupplement }))
    }
    var d = day
    for item in items {
      guard item.quantity > 0, item.quantity <= 100 else { continue }
      remember(item.food)
      d.entries.append(
        DiaryEntry(
          id: UUID().uuidString, foodId: item.food.id, quantity: item.quantity,
          meal: item.food.isSupplement ? "Supplements" : meal))
    }
    state.days[key(date)] = d
    state.pendingMeal = nil
    save()
  }
  func remove(_ entry: DiaryEntry) {
    var d = day
    d.entries.removeAll { $0.id == entry.id }
    state.days[key(date)] = d
    save()
  }
  func water(_ amount: Int) {
    var d = day
    d.water = max(0, min(30, amount))
    state.days[key(date)] = d
    save()
  }
  func archive(_ food: NativeFood) {
    if let i = state.customFoods.firstIndex(where: { $0.id == food.id }) {
      state.customFoods[i].archived = true
      save()
    }
  }
  func composite(_ name: String, items: [MealItem]) -> NativeFood {
    var values: [String: Double?] = [:]
    var partial: [String] = []
    for n in nutrients {
      let known = items.filter { $0.food.value(n.id) != nil }
      values[n.id] =
        known.isEmpty
        ? .some(nil) : .some(known.reduce(0) { $0 + ($1.food.value(n.id) ?? 0) * $1.quantity })
      if known.count != items.count
        || items.contains(where: { $0.food.partialNutrients?.contains(n.id) == true })
      {
        partial.append(n.id)
      }
    }
    return NativeFood(
      id: "meal-" + UUID().uuidString, name: name, serving: "1 meal",
      calories: items.reduce(0) { $0 + $1.food.calories * $1.quantity }, values: values,
      kind: "meal", source: "Saved meal", partialNutrients: partial,
      components: items.map {
        FoodComponent(
          name: $0.food.name, serving: $0.food.serving, source: $0.food.source ?? "Custom",
          quantity: $0.quantity)
      })
  }
  func loadDatabase() async {
    guard database.isEmpty else { return }
    guard let url = Bundle.main.url(forResource: "FoodDatabase", withExtension: "json") else {
      databaseError = "Food database is missing."
      return
    }
    do {
      database = try await Task.detached {
        try JSONDecoder().decode([NativeFood].self, from: Data(contentsOf: url))
      }.value
    } catch { databaseError = "Couldn't load the food database." }
  }
  func search(_ query: String) -> [NativeFood] {
    let active = state.customFoods.filter { $0.archived != true }
    guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
      return Array(active.prefix(30))
    }
    let words = query.lowercased().split(separator: " ").map(String.init)
    let match: (NativeFood) -> Bool = { food in
      words.allSatisfy { food.name.lowercased().contains($0) }
    }
    var seen = Set<String>()
    return Array(
      (active.filter(match) + database.filter(match)).filter { seen.insert($0.id).inserted }.prefix(
        60))
  }
  func send(_ message: String, retry: Bool = false) async {
    guard !sending, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    sending = true
    chatError = nil
    state.pendingMeal = nil
    if retry, let index = state.chatHistory?.lastIndex(where: { $0.role == "user" }) {
      state.chatHistory = Array(history.prefix(index + 1))
    } else {
      state.chatHistory = history + [NativeMessage(role: "user", content: message)]
    }
    draft = ""
    save()
    defer { sending = false }
    do {
      let saved = try JSONSerialization.jsonObject(
        with: JSONEncoder().encode(state.customFoods.filter { $0.archived != true }))
      let result = try await backend.request([
        "messages": history.suffix(12).map { ["role": $0.role, "content": $0.content] },
        "savedFoods": saved,
      ])
      let response = try JSONDecoder().decode(AgentResponse.self, from: result)
      state.chatHistory = Array(
        (history + [NativeMessage(role: "assistant", content: response.reply)]).suffix(100))
      state.pendingMeal = response.proposal
      save()
    } catch { chatError = error.localizedDescription }
  }
  var realDays: [(String, DiaryDay)] {
    state.days.map { key, day in
      (key, DiaryDay(entries: day.entries.filter { !$0.id.hasPrefix("sample-") }, water: day.water))
    }.filter { !$0.1.entries.isEmpty && $0.0 <= key(date) }.sorted { $0.0 < $1.0 }
  }
  func averages(months: Int) -> [IntakeAverage] {
    let start = Calendar.current.date(
      byAdding: .month, value: -months + 1,
      to: Calendar.current.date(
        from: Calendar.current.dateComponents([.year, .month], from: date))!)!
    let days = realDays.filter { $0.0 >= key(start) }
    return nutrients.filter { $0.group != "Macros" }.compactMap { n in
      let known = days.filter { $0.1.entries.contains { food($0.foodId)?.value(n.id) != nil } }
      guard !known.isEmpty else { return nil }
      let complete = known.allSatisfy {
        $0.1.entries.allSatisfy { e in
          guard let f = food(e.foodId) else { return false }
          return f.value(n.id) != nil && f.partialNutrients?.contains(n.id) != true
        }
      }
      return IntakeAverage(
        nutrient: n,
        value: known.reduce(0) { $0 + total(n.id, entries: $1.1.entries) } / Double(known.count),
        target: state.targets[n.id] ?? n.target, reportedDays: known.count, complete: complete)
    }.sorted { $0.percentage < $1.percentage }
  }
  func months(_ count: Int, metric: String) -> [MonthAverage] {
    let calendar = Calendar.current
    let current = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
    return (0..<count).reversed().compactMap { offset in
      let month = calendar.date(byAdding: .month, value: -offset, to: current)!
      let prefix = String(key(month).prefix(7))
      let days = realDays.filter {
        $0.0.hasPrefix(prefix)
          && (metric == "score" || metric == "calories"
            || $0.1.entries.contains { food($0.foodId)?.value(metric) != nil })
      }
      guard !days.isEmpty else { return nil }
      @MainActor func value(_ entries: [DiaryEntry]) -> Double {
        metric == "score"
          ? score(entries: entries)
          : metric == "calories"
            ? total(metric, entries: entries)
            : total(metric, entries: entries) / (state.targets[metric] ?? 1) * 100
      }
      return MonthAverage(
        date: month, value: days.reduce(0) { $0 + value($1.1.entries) } / Double(days.count),
        foodOnly: days.reduce(0) {
          $0 + value($1.1.entries.filter { food($0.foodId)?.isSupplement != true })
        } / Double(days.count), days: days.count)
    }
  }
  func export() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("nutrient-backup.json")
    try JSONEncoder().encode(state).write(to: url, options: .atomic)
    return url
  }
  func restore(_ data: Data) throws {
    let candidate = try JSONDecoder().decode(NativeState.self, from: data)
    guard Self.valid(candidate, nutrients: nutrients, foods: sampleFoods) else {
      throw NSError(
        domain: "Nutrient", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "This backup contains invalid records."])
    }
    state = candidate
    save()
  }
}
