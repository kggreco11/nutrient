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
