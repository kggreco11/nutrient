import Foundation
import Security

// Native networking. The private service credential stays in Keychain;
// the OpenRouter credential exists only on the server.
final class NativeBackend {
  private let origin = "https://nutrient-kggreco11.blue-brush-8571.chatgpt.site"
  private var query: [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "com.kggreco11.nutrient",
      kSecAttrAccount as String: "nutrient-private-backend",
    ]
  }
  var configured: Bool { token != nil }
  private var token: String? {
    var q = query
    q[kSecReturnData as String] = true
    q[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: CFTypeRef?
    guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess,
      let data = result as? Data
    else { return nil }
    return String(data: data, encoding: .utf8)
  }
  func configure(_ token: String) throws {
    guard !token.isEmpty else { throw failure("Enter a connection token.") }
    let data = Data(token.utf8)
    let result = SecItemUpdate(
      query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
    if result == errSecSuccess { return }
    guard result == errSecItemNotFound else { throw failure("Couldn't save this connection.") }
    var q = query
    q[kSecValueData as String] = data
    q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    guard SecItemAdd(q as CFDictionary, nil) == errSecSuccess else {
      throw failure("Couldn't save this connection.")
    }
  }
  func bootstrap() {
    if let token = ProcessInfo.processInfo.environment["NUTRIENT_SERVICE_TOKEN"] {
      try? configure(token)
      unsetenv("NUTRIENT_SERVICE_TOKEN")
    }
  }
  private func failure(_ message: String) -> NSError {
    NSError(domain: "Nutrient", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
  }
  func request(_ payload: [String: Any], path: String = "/api/chat") async throws -> Data {
    guard let token else {
      throw failure("Chat isn't connected on this iPhone. Open Settings → Chat connection.")
    }
    var request = URLRequest(url: URL(string: origin + path)!)
    request.httpMethod = "POST"
    request.timeoutInterval = 180
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer " + token, forHTTPHeaderField: "OAI-Sites-Authorization")
    request.httpBody = try JSONSerialization.data(withJSONObject: payload)
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse else {
      throw failure("Couldn't reach chat. Try again.")
    }
    if http.statusCode == 401 || http.statusCode == 403 {
      throw failure("Your chat connection expired. Reconnect in Settings.")
    }
    guard (200..<300).contains(http.statusCode) else {
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
      throw failure(json?["error"] as? String ?? "Couldn't send that message. Try again.")
    }
    return data
  }
  func barcode(_ code: String) async throws -> NativeFood {
    guard (8...14).contains(code.count), code.allSatisfy(\.isNumber) else {
      throw failure("Enter an 8–14 digit barcode.")
    }
    let url = URL(
      string:
        "https://world.openfoodfacts.org/api/v2/product/\(code).json?fields=product_name,brands,nutriments,code"
    )!
    let (data, _) = try await URLSession.shared.data(from: url)
    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      (json["status"] as? Int) == 1, let product = json["product"] as? [String: Any],
      let nutrition = product["nutriments"] as? [String: Any]
    else { throw failure("No product found. Search foods or enter the label.") }
    func value(_ key: String, scale: Double = 1) -> Double? {
      let raw = nutrition[key + "_100g"]
      let number = (raw as? NSNumber)?.doubleValue ?? Double(raw as? String ?? "")
      guard let number, number.isFinite, number >= 0 else { return nil }
      return number * scale
    }
    guard let calories = value("energy-kcal") ?? value("energy-kj").map({ $0 / 4.184 }) else {
      throw failure("This product has no calorie data. Enter its label instead.")
    }
    let map: [String: (String, Double)] = [
      "protein": ("proteins", 1), "carbs": ("carbohydrates", 1), "fat": ("fat", 1),
      "fiber": ("fiber", 1), "vitA": ("vitamin-a", 1_000_000), "vitC": ("vitamin-c", 1000),
      "vitD": ("vitamin-d", 1_000_000), "vitE": ("vitamin-e", 1000),
      "vitK": ("vitamin-k", 1_000_000), "b1": ("vitamin-b1", 1000), "b2": ("vitamin-b2", 1000),
      "b6": ("vitamin-b6", 1000),
      "b5": ("pantothenic-acid", 1000), "biotin": ("biotin", 1_000_000),
      "choline": ("choline", 1000),
      "phosphorus": ("phosphorus", 1000), "sodium": ("sodium", 1000),
      "chloride": ("chloride", 1000),
      "copper": ("copper", 1000), "iodine": ("iodine", 1_000_000), "manganese": ("manganese", 1000),
      "molybdenum": ("molybdenum", 1_000_000), "chromium": ("chromium", 1_000_000),
      "fluoride": ("fluoride", 1000), "b12": ("vitamin-b12", 1_000_000),
      "folate": ("folates", 1_000_000), "calcium": ("calcium", 1000), "iron": ("iron", 1000),
      "magnesium": ("magnesium", 1000), "potassium": ("potassium", 1000), "zinc": ("zinc", 1000),
      "selenium": ("selenium", 1_000_000), "omega3": ("omega-3-fat", 1),
    ]
    var values: [String: Double?] = [:]
    for (id, entry) in map { values[id] = .some(value(entry.0, scale: entry.1)) }
    values["b3"] = .some(nil)  // Product niacin alone does not establish niacin equivalents.
    let name = product["product_name"] as? String ?? "Packaged food"
    return NativeFood(
      id: "off-" + code, name: name, serving: "100 g", calories: calories, values: values,
      kind: "food", source: "Open Food Facts",
      sourceUrl: "https://world.openfoodfacts.org/product/" + code)
  }
}
