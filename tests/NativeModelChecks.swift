import Foundation
import SwiftUI
import UIKit

@main struct NativeModelChecks {
  @MainActor static func main() throws {
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
