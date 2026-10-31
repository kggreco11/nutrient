import Foundation
import SwiftUI
import UIKit

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
  var values: [String: Double?]? = nil
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
  var energyUnreported: Bool?
  var servingGrams: Double?
  var portions: [NativePortionMeasure]?
  func value(_ id: String) -> Double? { values[id] ?? nil }
  var isSupplement: Bool { kind == "supplement" }
}
struct NativePortionMeasure: Codable, Identifiable {
  let id: String
  let label: String
  let grams: Double
}
struct NativeAmountUnit: Identifiable {
  let id: String
  let label: String
  let servings: Double
}
extension NativeFood {
  // Mass units are exact. Volume/count measures require a weight from this food.
  var gramsPerServing: Double? {
    if let servingGrams, servingGrams.isFinite, servingGrams > 0 { return servingGrams }
    let pattern = #"(?i)(?<![0-9/.,])([0-9]+(?:\.[0-9]+)?)\s*(kg|kilograms?|g|grams?|oz|ounces?|lb|lbs|pounds?)\b"#
    guard let expression = try? NSRegularExpression(pattern: pattern),
      let match = expression.matches(in: serving, range: NSRange(serving.startIndex..., in: serving)).sorted(by: {
        let a = (serving as NSString).substring(with: $0.range(at: 2)).lowercased()
        let b = (serving as NSString).substring(with: $1.range(at: 2)).lowercased()
        return (a == "g" || a.hasPrefix("gram")) && !(b == "g" || b.hasPrefix("gram"))
      }).first,
      let numberRange = Range(match.range(at: 1), in: serving),
      let unitRange = Range(match.range(at: 2), in: serving),
      let amount = Double(serving[numberRange]), amount > 0 else { return nil }
    // Do not read the denominator of a fractional or mixed mass as a whole mass.
    let prefix = String(serving[..<numberRange.lowerBound])
    if prefix.last == "/" || prefix.last?.isNumber == true { return nil }
    let unit = serving[unitRange].lowercased()
    let multiplier = unit.hasPrefix("kg") || unit.hasPrefix("kilogram") ? 1000.0
      : unit == "oz" || unit.hasPrefix("ounce") ? 28.349523125
      : unit.hasPrefix("lb") || unit.hasPrefix("pound") ? 453.59237 : 1
    return amount * multiplier
  }
  var amountUnits: [NativeAmountUnit] {
    let original = NativeAmountUnit(id: "serving", label: "Servings", servings: 1)
    guard let grams = gramsPerServing else { return [original] }
    return [
      NativeAmountUnit(id: "g", label: "Grams", servings: 1 / grams),
      NativeAmountUnit(id: "oz", label: "Ounces (oz)", servings: 28.349523125 / grams),
      NativeAmountUnit(id: "lb", label: "Pounds (lb)", servings: 453.59237 / grams),
      NativeAmountUnit(id: "kg", label: "Kilograms (kg)", servings: 1000 / grams), original,
    ] + (portions ?? []).filter { $0.grams.isFinite && $0.grams > 0 }.map {
      NativeAmountUnit(id: "portion-" + $0.id, label: $0.label, servings: $0.grams / grams)
    }
  }
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
  var personalTargetVersion: Int?
  var chatHistory: [NativeMessage]?
  var pendingMeal: [MealItem]?
}
struct NativeSeed: Decodable {
  let calorieTarget: Double?
  let supplements: [NativeFood]?
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
struct NativeTrendBucket: Identifiable {
  let date: Date
  let value: Double
  let foodOnly: Double
  let days: Int
  var id: Date { date }
}
enum NativeTrendInterval: String, CaseIterable, Identifiable {
  case daily = "Daily", weekly = "Weekly", monthly = "Monthly"
  var id: String { rawValue }
  var component: Calendar.Component {
    switch self { case .daily: return .day; case .weekly: return .weekOfYear; case .monthly: return .month }
  }
  var ranges: [Int] {
    switch self { case .daily: return [7, 14, 30]; case .weekly: return [4, 8, 12]; case .monthly: return [3, 6, 12] }
  }
  var rangeUnit: String {
    switch self { case .daily: return "days"; case .weekly: return "weeks"; case .monthly: return "months" }
  }
  var heading: String { self == .daily ? "Daily scores" : "\(rawValue) averages" }
  var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .current
    calendar.firstWeekday = 2 // Monday–Sunday, including weeks across month/year boundaries.
    calendar.minimumDaysInFirstWeek = 4
    return calendar
  }
  func start(of date: Date) -> Date { calendar.dateInterval(of: component, for: date)!.start }
}
let nativeMeals = ["Breakfast", "Lunch", "Dinner", "Snacks", "Supplements"]
let nutrientGreen = Color(uiColor: UIColor(named: "FieldFern") ?? UIColor { traits in
  traits.userInterfaceStyle == .dark
    ? UIColor(red: 177/255, green: 216/255, blue: 186/255, alpha: 1)
    : UIColor(red: 54/255, green: 95/255, blue: 77/255, alpha: 1)
})
let nutrientOnGreen = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? .black : .white })
func number(_ value: Double) -> String {
  value.formatted(.number.precision(.fractionLength(0...(value < 10 ? 1 : 0))))
}

struct DailyNutrientProgress: Identifiable {
  let nutrient: NutrientDefinition
  let consumed: Double
  let target: Double
  let reported: Bool
  let partial: Bool
  var id: String { nutrient.id }
  var remaining: Double { max(0, target - consumed) }
  var fraction: Double { consumed / target }
}
struct NutrientContribution: Identifiable {
  let entry: DiaryEntry
  let food: NativeFood
  let amount: Double?
  let partial: Bool
  var id: String { entry.id }
}
struct NativeDayContext: Encodable {
  struct Entry: Encodable {
    let quantity: Double
    let food: NativeFood
  }
  let date: String
  let calorieTarget: Double
  let targets: [String: Double]
  let entries: [Entry]
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
  private let plannedSupplements: [NativeFood]
  private let dataURL: URL
  private let mirrorPreferences: Bool
  init(seedURL: URL? = nil, storageURL: URL? = nil, mirrorPreferences: Bool = true) {
    self.mirrorPreferences = mirrorPreferences
    let seedURL = seedURL ?? Bundle.main.url(forResource: "NativeSeed", withExtension: "json")!
    let seed = try! JSONDecoder().decode(NativeSeed.self, from: Data(contentsOf: seedURL))
    nutrients = seed.nutrients
    sampleFoods = seed.foods
    plannedSupplements = seed.supplements ?? []
    let directory = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask)[0]
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    dataURL = storageURL ?? directory.appendingPathComponent("nutrient-native.json")
    let existing =
      (try? Data(contentsOf: dataURL))
      ?? (mirrorPreferences
        ? UserDefaults.standard.string(forKey: "CapacitorStorage.nutrient-v1")?.data(using: .utf8)
        : nil)
    if let existing, let decoded = try? JSONDecoder().decode(NativeState.self, from: existing),
      let restored = Self.expanded(
        decoded, nutrients: seed.nutrients, supplements: seed.supplements ?? []),
      Self.valid(restored, nutrients: seed.nutrients, foods: seed.foods)
    {
      state = restored
    } else {
      state = NativeState(
        version: 1, targets: seed.targets, calorieTarget: seed.calorieTarget ?? 3500,
        waterTarget: 8, customFoods: seed.supplements ?? [],
        days: [:], referenceTargetVersion: 1, personalTargetVersion: 2)
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
    save()
  }
  static func expanded(
    _ original: NativeState, nutrients: [NutrientDefinition], supplements: [NativeFood] = []
  ) -> NativeState? {
    var state = original
    for n in nutrients where state.targets[n.id] == nil { state.targets[n.id] = n.target }
    for i in state.customFoods.indices {
      for n in nutrients where !state.customFoods[i].values.keys.contains(n.id) {
        state.customFoods[i].values[n.id] = .some(nil)
      }
    }
    if state.personalTargetVersion != 2 {
      if state.calorieTarget == 2200 { state.calorieTarget = 3500 }
      state.targets["protein"] = 160
      state.targets["carbs"] = 500
      state.targets["fat"] = 95
      let previous: [String: Double] = [
        "protein": 100, "carbs": 275, "fat": 78, "b6": 1.3, "b12": 2.4, "vitD": 15,
      ]
      for (id, value) in previous where state.targets[id] == value {
        state.targets[id] = nutrients.first { $0.id == id }?.target
      }
      for food in supplements where !state.customFoods.contains(where: { $0.id == food.id }) {
        state.customFoods.append(food)
      }
      state.personalTargetVersion = 2
    }
    return state
  }
  func updateEntry(
    _ original: DiaryEntry, from sourceDate: Date, to destinationDate: Date, quantity: Double,
    meal: String
  ) throws {
    guard quantity.isFinite, quantity > 0, quantity <= 100, nativeMeals.contains(meal),
      let food = food(original.foodId), !food.isSupplement || meal == "Supplements"
    else {
      throw NSError(
        domain: "Nutrient", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Enter a valid portion and meal."])
    }
    let sourceKey = key(sourceDate)
    let destinationKey = key(destinationDate)
    guard var source = state.days[sourceKey],
      let index = source.entries.firstIndex(where: { $0.id == original.id })
    else {
      throw NSError(
        domain: "Nutrient", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "This entry no longer exists."])
    }
    var updated = source.entries[index]
    updated.quantity = quantity
    updated.meal = meal
    if sourceKey == destinationKey {
      source.entries[index] = updated
      state.days[sourceKey] = source
    } else {
      source.entries.remove(at: index)
      var destination = state.days[destinationKey] ?? DiaryDay()
      destination.entries.append(updated)
      state.days[sourceKey] = source
      state.days[destinationKey] = destination
    }
    save()
  }
  func reported(_ nutrient: String) -> Bool {
    day.entries.contains { food($0.foodId)?.value(nutrient) != nil }
  }
  func incomplete(_ nutrient: String) -> Bool {
    day.entries.contains {
      guard let food = food($0.foodId) else { return true }
      return food.value(nutrient) == nil || food.partialNutrients?.contains(nutrient) == true
    }
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
  private func persist() throws {
    let data = try JSONEncoder().encode(state)
    try data.write(to: dataURL, options: .atomic)
    if mirrorPreferences {
      UserDefaults.standard.set(String(data: data, encoding: .utf8), forKey: "CapacitorStorage.nutrient-v1")
    }
  }
  func save() {
    do { try persist() }
    catch { self.error = "Couldn't save. Export a backup before closing the app." }
  }
  @discardableResult func saveDiaryMeal(_ name: String, entryIDs: Set<String>, from date: Date) throws -> NativeFood {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    func invalid(_ message: String) -> NSError {
      NSError(domain: "Nutrient", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
    guard !trimmed.isEmpty else { throw invalid("Give this meal a name.") }
    let entries = (state.days[key(date)]?.entries ?? []).filter { entryIDs.contains($0.id) }
    guard !entries.isEmpty && entries.count == entryIDs.count else {
      throw invalid("Some selected entries changed. Select the foods again.")
    }
    let items = try entries.map { entry -> MealItem in
      guard let food = food(entry.foodId), !food.isSupplement,
        entry.quantity.isFinite && entry.quantity > 0 && entry.quantity <= 100 else {
        throw invalid("Select food entries with valid amounts to create a meal.")
      }
      return MealItem(food: food, quantity: entry.quantity)
    }
    let meal = composite(trimmed, items: items)
    state.customFoods.append(meal)
    do { try persist() }
    catch {
      state.customFoods.removeAll { $0.id == meal.id }
      throw invalid("Couldn't save this meal. Try again.")
    }
    return meal
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
  func log(_ items: [MealItem], meal: String, saveAs name: String = "", groupedAs groupName: String? = nil) {
    guard !items.isEmpty, items.allSatisfy({ $0.quantity.isFinite && $0.quantity > 0 && $0.quantity <= 100 }) else { return }
    let ingredients = items.filter { !$0.food.isSupplement }
    let reusable = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    var loggedItems = items
    if let groupName, ingredients.count > 1 {
      var combined = composite(reusable ? name : groupName, items: ingredients)
      combined.archived = !reusable
      combined.source = "Meal"
      loggedItems = [MealItem(food: combined, quantity: 1)] + items.filter { $0.food.isSupplement }
    } else if reusable && !ingredients.isEmpty {
      state.customFoods.append(composite(name, items: ingredients))
    }
    var d = day
    for item in loggedItems {
      guard item.quantity.isFinite, item.quantity > 0, item.quantity <= 100 else { continue }
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
          quantity: $0.quantity, values: $0.food.values)
      }, energyUnreported: items.contains { $0.food.energyUnreported == true },
      servingGrams: items.allSatisfy { $0.food.gramsPerServing != nil }
        ? items.reduce(0) { $0 + ($1.food.gramsPerServing ?? 0) * $1.quantity } : nil)
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
      let indexed = Dictionary(uniqueKeysWithValues: database.map { ($0.id, $0) })
      let added = [
        "b3", "b5", "biotin", "choline", "phosphorus", "sodium", "chloride", "copper", "iodine",
        "manganese", "molybdenum", "chromium", "fluoride",
      ]
      var changed = false
      for i in state.customFoods.indices where state.customFoods[i].source == "USDA SR Legacy" {
        if let record = indexed[state.customFoods[i].id] {
          if state.customFoods[i].portions == nil {
            state.customFoods[i].portions = record.portions
            state.customFoods[i].servingGrams = record.servingGrams
            changed = true
          }
          for id in added where state.customFoods[i].value(id) == nil {
            if let value = record.value(id) {
              state.customFoods[i].values[id] = .some(value)
              changed = true
            }
          }
        }
      }
      if changed { save() }
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
  var dailyProgress: [DailyNutrientProgress] {
    nutrients.filter { $0.group != "Macros" }.map { n in
      DailyNutrientProgress(
        nutrient: n, consumed: total(n.id), target: state.targets[n.id] ?? n.target,
        reported: reported(n.id), partial: incomplete(n.id))
    }
  }
  var dailyGaps: [DailyNutrientProgress] {
    dailyProgress.filter { $0.reported && $0.remaining > 0 }.sorted {
      $0.fraction == $1.fraction ? $0.nutrient.name < $1.nutrient.name : $0.fraction < $1.fraction
    }
  }
  var unreportedNutrients: [DailyNutrientProgress] { dailyProgress.filter { !$0.reported } }
  func contributions(_ nutrient: String) -> [NutrientContribution] {
    day.entries.compactMap { entry in
      guard let food = food(entry.foodId) else { return nil }
      return NutrientContribution(
        entry: entry, food: food, amount: food.value(nutrient).map { $0 * entry.quantity },
        partial: food.partialNutrients?.contains(nutrient) == true)
    }.sorted { ($0.amount ?? -1) > ($1.amount ?? -1) }
  }
  func dayContextPayload() throws -> Any {
    let snapshot = NativeDayContext(
      date: key(date), calorieTarget: state.calorieTarget, targets: state.targets,
      entries: day.entries.compactMap { e in
        guard let food = food(e.foodId) else { return nil }
        return NativeDayContext.Entry(quantity: e.quantity, food: food)
      })
    return try JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot))
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
        "dayContext": try dayContextPayload(),
      ])
      let response = try JSONDecoder().decode(AgentResponse.self, from: result)
      state.chatHistory = Array(
        (history + [NativeMessage(role: "assistant", content: response.reply)]).suffix(100))
      state.pendingMeal = response.proposal
      save()
    } catch { chatError = error.localizedDescription }
  }
  var realDays: [(String, DiaryDay)] {
    state.days.filter { $0.value.demo != true }.map { key, day in
      (key, DiaryDay(entries: day.entries.filter { !$0.id.hasPrefix("sample-") }, water: day.water))
    }.filter { !$0.1.entries.isEmpty && $0.0 <= key(date) }.sorted { $0.0 < $1.0 }
  }
  func trendStart(_ interval: NativeTrendInterval, count: Int) -> Date {
    interval.calendar.date(byAdding: interval.component, value: -max(0, count - 1), to: interval.start(of: date))!
  }
  func averages(interval: NativeTrendInterval, count: Int) -> [IntakeAverage] {
    let start = trendStart(interval, count: count)
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
  func trendBuckets(_ interval: NativeTrendInterval, count: Int, metric: String) -> [NativeTrendBucket] {
    let calendar = interval.calendar
    let first = trendStart(interval, count: count)
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = "yyyy-MM-dd"
    let eligible = realDays.filter { $0.0 >= key(first) }.compactMap { day -> (Date, DiaryDay)? in
      guard let parsed = formatter.date(from: day.0) else { return nil }
      if metric != "score" && metric != "calories" && !day.1.entries.contains(where: { food($0.foodId)?.value(metric) != nil }) { return nil }
      return (interval.start(of: parsed), day.1)
    }
    let grouped = Dictionary(grouping: eligible, by: { $0.0 })
    func value(_ entries: [DiaryEntry]) -> Double {
      metric == "score" ? score(entries: entries)
        : metric == "calories" ? total(metric, entries: entries)
        : total(metric, entries: entries) / (state.targets[metric] ?? 1) * 100
    }
    return grouped.keys.sorted().map { start in
      let days = grouped[start]!
      return NativeTrendBucket(date: start,
        value: days.reduce(0) { $0 + value($1.1.entries) } / Double(days.count),
        foodOnly: days.reduce(0) { $0 + value($1.1.entries.filter { food($0.foodId)?.isSupplement != true }) } / Double(days.count),
        days: days.count)
    }
  }
  func export() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("nutrient-backup.json")
    try JSONEncoder().encode(state).write(to: url, options: .atomic)
    return url
  }
  func restore(_ data: Data) throws {
    let decoded = try JSONDecoder().decode(NativeState.self, from: data)
    let candidate = Self.expanded(decoded, nutrients: nutrients, supplements: plannedSupplements)!
    guard Self.valid(candidate, nutrients: nutrients, foods: sampleFoods) else {
      throw NSError(
        domain: "Nutrient", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "This backup contains invalid records."])
    }
    state = candidate
    save()
  }
}
