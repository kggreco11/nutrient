import Foundation
import SwiftUI
import UIKit

@main struct NativeModelChecks {
  @MainActor static func main() throws {
    let labelText = "Nutrition Facts\nServing size 1 cup (240 mL)\nCalories 120\nTotal Fat 5g\nSodium 110mg\nTotal Carbohydrate 12g\nProtein 8g\nVitamin D 2.5mcg\nCalcium 300mg"
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1100, height: 1000))
    let labelImage = renderer.image { context in
      UIColor.white.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 1100, height: 1000))
      (labelText as NSString).draw(in: CGRect(x: 40, y: 40, width: 1000, height: 900), withAttributes: [.font: UIFont.systemFont(ofSize: 48), .foregroundColor: UIColor.black])
    }
    let recognized = try NativeLabelReader.recognize(labelImage.pngData()!)
    precondition(recognized.contains("Calories 120") && recognized.contains("Protein 8g") && recognized.contains("300mg"), "Label OCR lost nutrition amounts: \(recognized)")
    try recognized.write(toFile: "/tmp/nutrient-label-ocr-fixture.txt", atomically: true, encoding: .utf8)
    print("Native Vision label OCR passed")
    let seedURL = URL(fileURLWithPath: CommandLine.arguments[1])
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let storage = directory.appendingPathComponent("state.json")
    let store = NutrientStore(seedURL: seedURL, storageURL: storage, mirrorPreferences: false)
    let start = store.date
    let end = Calendar.current.date(byAdding: .day, value: -1, to: start)!
    let food = NativeFood(
      id: "test-food", name: "Test oats", serving: "100 g", calories: 100,
      values: ["protein": 10, "magnesium": 50])
    let oz = food.amountUnits.first { $0.id == "oz" }!
    precondition(abs(4 * oz.servings * food.gramsPerServing! - 113.3980925) < 0.000001)
    precondition(abs(4 * oz.servings * food.value("protein")! - 11.33980925) < 0.000001)
    var measured = food
    measured.serving = "2/3 cup (55 g)"
    precondition(measured.gramsPerServing == 55)
    measured.serving = "1 oz (28 g)"
    precondition(measured.gramsPerServing == 28)
    measured.serving = "1/2 oz"
    precondition(measured.gramsPerServing == nil)
    measured.serving = "1 cup"
    precondition(measured.amountUnits.count == 1, "Volume must not assume water density")
    measured.servingGrams = 160
    measured.portions = [NativePortionMeasure(id: "cup", label: "cup, cooked", grams: 160)]
    let cup = measured.amountUnits.first { $0.id == "portion-cup" }!
    precondition(0.5 * cup.servings * measured.gramsPerServing! == 80)
    let pounds = food.amountUnits.first { $0.id == "lb" }!
    precondition(abs(pounds.servings * 100 - 453.59237) < 0.000001)
    let roundtrip = try JSONDecoder().decode(NativeFood.self, from: JSONEncoder().encode(measured))
    precondition(roundtrip.portions?.first?.grams == 160 && roundtrip.servingGrams == 160)
    print("Mass conversion, food-specific measures, label weights and portion persistence passed")
    store.log([MealItem(food: food, quantity: 1)], meal: "Breakfast")
    let entry = store.day.entries[0]
    try store.updateEntry(entry, from: start, to: start, quantity: 2, meal: "Lunch")
    precondition(
      store.day.entries.count == 1 && store.day.entries[0].id == entry.id
        && store.day.entries[0].meal == "Lunch")
    precondition(store.total("calories") == 200 && store.total("magnesium") == 100)
    try store.updateEntry(entry, from: start, to: end, quantity: 0.5, meal: "Dinner")
    precondition(store.day.entries.isEmpty)
    precondition(store.state.days[store.key(end)]!.entries.count == 1)
    precondition(store.state.days[store.key(end)]!.entries[0].id == entry.id)
    let before = try JSONEncoder().encode(store.state)
    do {
      try store.updateEntry(entry, from: end, to: start, quantity: 0, meal: "Lunch")
      fatalError("Accepted invalid portion")
    } catch {}
    let after = try JSONEncoder().encode(store.state)
    let a = try JSONSerialization.jsonObject(with: before) as! NSDictionary
    let b = try JSONSerialization.jsonObject(with: after) as! NSDictionary
    precondition(a == b)
    store.state.personalTargetVersion = nil
    store.state.calorieTarget = 2200
    store.state.targets["protein"] = 100
    store.state.targets["b6"] = 1.3
    store.state.targets["b12"] = 2.4
    store.state.targets["vitD"] = 50
    store.state.targets.removeValue(forKey: "chromium")
    store.save()
    let reloaded = NutrientStore(seedURL: seedURL, storageURL: storage, mirrorPreferences: false)
    precondition(
      reloaded.state.calorieTarget == 3500 && reloaded.state.targets["protein"] == 160
        && reloaded.state.targets["b6"] == 1.8 && reloaded.state.targets["b12"] == 4)
    precondition(reloaded.state.targets["chromium"] == 35 && reloaded.state.targets["vitD"] == 50)
    precondition(reloaded.state.days[store.key(end)]!.entries.count == 1)
    precondition(!store.reported("chromium"))
    let daily = NutrientStore(
      seedURL: seedURL, storageURL: directory.appendingPathComponent("daily.json"),
      mirrorPreferences: false)
    let meat = NativeFood(
      id: "contribution-meat", name: "Meat", serving: "100 g", calories: 100,
      values: ["protein": 20])
    let milk = NativeFood(
      id: "contribution-milk", name: "Milk", serving: "1 glass", calories: 100,
      values: ["protein": 8, "vitC": 0])
    let unknown = NativeFood(
      id: "unknown", name: "Unreported food", serving: "1 serving", calories: 0, values: [:])
    daily.log(
      [
        MealItem(food: meat, quantity: 2), MealItem(food: milk, quantity: 1.5),
        MealItem(food: unknown, quantity: 1),
      ], meal: "Breakfast")
    let contributions = daily.contributions("protein")
    precondition(
      contributions.count == 3 && contributions[0].amount == 40 && contributions[1].amount == 12
        && contributions[2].amount == nil)
    precondition(daily.total("protein") == 52)
    precondition(daily.dailyGaps.contains { $0.id == "vitC" && $0.remaining == 90 && $0.partial })
    precondition(!daily.dailyGaps.contains { $0.id == "chromium" })
    precondition(daily.unreportedNutrients.contains { $0.id == "chromium" })
    daily.date = end
    let snapshot = try daily.dayContextPayload() as! [String: Any]
    precondition(snapshot["date"] as? String == daily.key(end))
    precondition((snapshot["entries"] as? [Any])?.isEmpty == true)
    print(
      "Daily gap, unknown-data, food contribution scaling and selected-day snapshot checks passed")
    func luminance(_ color: UIColor, _ traits: UITraitCollection) -> Double {
      var r: CGFloat = 0
      var g: CGFloat = 0
      var b: CGFloat = 0
      var a: CGFloat = 0
      color.resolvedColor(with: traits).getRed(&r, green: &g, blue: &b, alpha: &a)
      func linear(_ v: CGFloat) -> Double {
        let x = Double(v)
        return x <= 0.04045 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4)
      }
      return linear(r) * 0.2126 + linear(g) * 0.7152 + linear(b) * 0.0722
    }
    let mealStore = NutrientStore(seedURL: seedURL, storageURL: directory.appendingPathComponent("meals.json"), mirrorPreferences: false)
    mealStore.state.days = [:]
    let bread = NativeFood(id: "bread-test", name: "Bread", serving: "100 g", calories: 250, values: ["protein": 10, "vitC": nil])
    let cheese = NativeFood(id: "cheese-test", name: "Cheese", serving: "100 g", calories: 400, values: ["protein": 25, "vitC": 0])
    let butter = NativeFood(id: "butter-test", name: "Butter", serving: "100 g", calories: 700, values: ["protein": 1, "vitC": nil])
    let ingredients = [MealItem(food: bread, quantity: 0.6), MealItem(food: cheese, quantity: 0.3), MealItem(food: butter, quantity: 0.1)]
    mealStore.log(ingredients, meal: "Lunch", groupedAs: "Grilled cheese")
    precondition(mealStore.day.entries.count == 1, "A combined meal must be one diary entry")
    let sandwich = mealStore.food(mealStore.day.entries[0].foodId)!
    precondition(sandwich.name == "Grilled cheese" && sandwich.components?.count == 3)
    precondition(sandwich.archived == true, "Logging alone must not add a reusable meal to the library")
    precondition(abs(mealStore.total("calories") - 340) < 0.00001 && abs(mealStore.total("protein") - 13.6) < 0.00001)
    precondition(sandwich.partialNutrients?.contains("vitC") == true)
    precondition(sandwich.components?[1].values?["protein"] == 25)
    precondition(sandwich.servingGrams == 100)
    let persistedMeal = NutrientStore(seedURL: seedURL, storageURL: directory.appendingPathComponent("meals.json"), mirrorPreferences: false)
    precondition(persistedMeal.day.entries.count == 1 && persistedMeal.food(sandwich.id)?.components?.count == 3)
    mealStore.log(ingredients, meal: "Dinner", saveAs: "Usual grilled cheese", groupedAs: "Grilled cheese")
    precondition(mealStore.day.entries.count == 2)
    precondition(mealStore.state.customFoods.filter { $0.name == "Usual grilled cheese" && $0.archived != true }.count == 1)
    var supplement = cheese
    supplement.id = "supplement-test"; supplement.kind = "supplement"
    mealStore.log(ingredients + [MealItem(food: supplement, quantity: 1)], meal: "Lunch", groupedAs: "Lunch with supplement")
    precondition(mealStore.day.entries.count == 4 && mealStore.day.entries.last?.meal == "Supplements")
    let beforeInvalid = mealStore.day.entries.count
    mealStore.log([MealItem(food: bread, quantity: .nan), MealItem(food: cheese, quantity: 1)], meal: "Lunch", groupedAs: "Invalid")
    precondition(mealStore.day.entries.count == beforeInvalid)
    print("Combined meal logging, quantities, ingredient snapshots, partial data, supplements and persistence passed")
    let trendStore = NutrientStore(seedURL: seedURL, storageURL: directory.appendingPathComponent("trends.json"), mirrorPreferences: false)
    let trendCalendar = NativeTrendInterval.weekly.calendar
    trendStore.date = trendCalendar.date(from: DateComponents(year: 2027, month: 1, day: 6, hour: 12))!
    trendStore.state.targets["vitC"] = 90
    let halfC = NativeFood(id: "half-c", name: "Half C", serving: "1 serving", calories: 100, values: ["vitC": 45])
    let fullC = NativeFood(id: "full-c", name: "Full C", serving: "1 serving", calories: 200, values: ["vitC": 90])
    let zeroC = NativeFood(id: "zero-c", name: "Zero C", serving: "1 serving", calories: 0, values: ["vitC": 0])
    let unknownC = NativeFood(id: "unknown-c", name: "Unknown C", serving: "1 serving", calories: 300, values: ["vitC": nil])
    [halfC, fullC, zeroC, unknownC].forEach { trendStore.remember($0) }
    func trendDay(_ food: NativeFood, _ id: String = UUID().uuidString) -> DiaryDay {
      DiaryDay(entries: [DiaryEntry(id: id, foodId: food.id, quantity: 1, meal: "Lunch")])
    }
    trendStore.state.days = [
      "2026-12-27": trendDay(halfC), "2026-12-28": trendDay(halfC),
      "2027-01-03": trendDay(fullC), "2027-01-04": trendDay(zeroC),
      "2027-01-05": trendDay(unknownC), "2027-01-07": trendDay(fullC),
      "2027-01-01": trendDay(fullC, "sample-test"),
      "2027-01-02": DiaryDay(entries: trendDay(fullC).entries, demo: true),
    ]
    let dailyC = trendStore.trendBuckets(.daily, count: 10, metric: "vitC")
    precondition(dailyC.map { $0.value } == [50, 100, 0], "Daily buckets must preserve explicit zero, skip unknown/future/demo days")
    let weeklyC = trendStore.trendBuckets(.weekly, count: 2, metric: "vitC")
    precondition(weeklyC.count == 2 && weeklyC[0].value == 75 && weeklyC[1].value == 0)
    precondition(trendStore.key(weeklyC[0].date) == "2026-12-28" && trendStore.key(weeklyC[1].date) == "2027-01-04")
    precondition(weeklyC.map { $0.days } == [2, 1], "Missing/unknown days must not dilute nutrient averages")
    let monthlyC = trendStore.trendBuckets(.monthly, count: 2, metric: "vitC")
    precondition(monthlyC.map { $0.value } == [50, 50], "Month grouping must remain available")
    let dailyEnergy = trendStore.trendBuckets(.daily, count: 10, metric: "calories")
    precondition(dailyEnergy.map { $0.value } == [100, 200, 0, 300])
    let dailyScore = trendStore.trendBuckets(.daily, count: 10, metric: "score")
    let weeklyScore = trendStore.trendBuckets(.weekly, count: 2, metric: "score")
    precondition(abs(weeklyScore[0].value - (dailyScore[0].value + dailyScore[1].value) / 2) < 0.000001)
    let summary = trendStore.averages(interval: .weekly, count: 2).first { $0.id == "vitC" }!
    precondition(summary.reportedDays == 3 && abs(summary.value - 45) < 0.000001)
    print("Daily, Monday-week and monthly trends passed: year boundaries, unknown/zero, gaps, future/sample exclusion and matching summaries")
    let diaryStore = NutrientStore(seedURL: seedURL, storageURL: directory.appendingPathComponent("diary-meals.json"), mirrorPreferences: false)
    let sourceDate = diaryStore.date
    let sourceKey = diaryStore.key(sourceDate)
    [bread, cheese, butter].forEach { diaryStore.remember($0) }
    var diarySupplement = cheese
    diarySupplement.id = "diary-supplement"; diarySupplement.kind = "supplement"
    diaryStore.remember(diarySupplement)
    let selectedBread = DiaryEntry(id: "bread-first", foodId: bread.id, quantity: 0.6, meal: "Lunch")
    let selectedCheese = DiaryEntry(id: "cheese-first", foodId: cheese.id, quantity: 0.3, meal: "Lunch")
    let selectedButter = DiaryEntry(id: "butter-first", foodId: butter.id, quantity: 0.1, meal: "Lunch")
    let otherBread = DiaryEntry(id: "bread-second", foodId: bread.id, quantity: 0.2, meal: "Dinner")
    let supplementEntry = DiaryEntry(id: "pill", foodId: diarySupplement.id, quantity: 1, meal: "Supplements")
    diaryStore.state.days = [sourceKey: DiaryDay(entries: [selectedBread, selectedCheese, selectedButter, otherBread, supplementEntry])]
    diaryStore.date = Calendar.current.date(byAdding: .day, value: 1, to: sourceDate)!
    let recipe = try diaryStore.saveDiaryMeal("  Grilled cheese  ", entryIDs: [selectedBread.id, selectedCheese.id, selectedButter.id], from: sourceDate)
    precondition(recipe.name == "Grilled cheese" && recipe.kind == "meal" && recipe.archived != true)
    precondition(recipe.components?.count == 3 && abs(recipe.calories - 340) < 0.000001 && abs(recipe.value("protein")! - 13.6) < 0.000001)
    precondition(recipe.partialNutrients?.contains("vitC") == true)
    let afterDays = diaryStore.state.days[sourceKey]!.entries
    precondition(afterDays.map { $0.id } == ["bread-first", "cheese-first", "butter-first", "bread-second", "pill"])
    precondition(afterDays.map { $0.quantity } == [0.6, 0.3, 0.1, 0.2, 1], "Saving to the library must not replace or re-log diary entries")
    precondition(diaryStore.day.entries.isEmpty, "Saving from an earlier date must not log anything today")
    let duplicateBreadMeal = try diaryStore.saveDiaryMeal("Two bread entries", entryIDs: [selectedBread.id, otherBread.id], from: sourceDate)
    precondition(duplicateBreadMeal.components?.count == 2 && abs(duplicateBreadMeal.calories - 200) < 0.000001)
    let libraryCount = diaryStore.state.customFoods.count
    for (name, ids) in [("", Set([selectedBread.id])), ("Empty", Set<String>()), ("Missing", Set(["missing"])), ("Supplement", Set([supplementEntry.id]))] {
      do {
        try diaryStore.saveDiaryMeal(name, entryIDs: ids, from: sourceDate)
        preconditionFailure("Invalid selection was accepted")
      } catch { }
    }
    precondition(diaryStore.state.customFoods.count == libraryCount)
    let reloadedDiary = NutrientStore(seedURL: seedURL, storageURL: directory.appendingPathComponent("diary-meals.json"), mirrorPreferences: false)
    precondition(reloadedDiary.food(recipe.id)?.components?.count == 3 && reloadedDiary.state.days[sourceKey]?.entries.count == 5)
    try diaryStore.updateEntry(selectedBread, from: sourceDate, to: sourceDate, quantity: 2, meal: "Lunch")
    precondition(abs(diaryStore.food(recipe.id)!.calories - 340) < 0.000001, "Saved recipe must snapshot the selected portions")
    print("Diary selection-to-library passed: logged portions, duplicate foods, historical dates, unchanged diary, validation and persistence")
    for style in [UIUserInterfaceStyle.light, .dark] {
      let traits = UITraitCollection(userInterfaceStyle: style)
      traits.performAsCurrent {
        let accent = luminance(UIColor(nutrientGreen), traits)
        let background = luminance(.secondarySystemGroupedBackground, traits)
        let foreground = luminance(UIColor(nutrientOnGreen), traits)
        let contrast = (max(accent, background) + 0.05) / (min(accent, background) + 0.05)
        let button = (max(accent, foreground) + 0.05) / (min(accent, foreground) + 0.05)
        precondition(
          contrast >= 4.5 && button >= 4.5, "Accent contrast failed: \(contrast), button: \(button)"
        )
        print("Accent text and filled-button contrast passed: \(style == .dark ? "dark" : "light")")
      }
    }
    print(
      "Native entry edit/move, invalid edit, persistence, target migration and unknown-data checks passed"
    )
  }
}
