import SwiftUI
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?
  func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let scene = scene as? UIWindowScene else { return }
    let titleFont = UIFont(name: "InstrumentSans-SemiBold", size: 17)
    let largeTitleFont = UIFont(name: "InstrumentSans-SemiBold", size: 34)
    assert(titleFont != nil && largeTitleFont != nil, "Bundled Instrument Sans fonts must be registered")
    let navigation = UINavigationBarAppearance()
    navigation.configureWithDefaultBackground()
    navigation.titleTextAttributes = [.font: UIFontMetrics(forTextStyle: .headline).scaledFont(
      for: titleFont ?? .preferredFont(forTextStyle: .headline))]
    navigation.largeTitleTextAttributes = [.font: UIFontMetrics(forTextStyle: .largeTitle).scaledFont(
      for: largeTitleFont ?? .preferredFont(forTextStyle: .largeTitle))]
    UINavigationBar.appearance().standardAppearance = navigation
    UINavigationBar.appearance().scrollEdgeAppearance = navigation
    UINavigationBar.appearance().compactAppearance = navigation
    let window = UIWindow(windowScene: scene)
    window.rootViewController = UIHostingController(rootView: NutrientAppView())
    self.window = window
    window.makeKeyAndVisible()
  }
}
