import Flutter
import UIKit
import MSAL
import GoogleMaps // 1. Ensure this is imported

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // 2. Initialize Google Maps with your API Key
    GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // 3. Keep your existing MSAL Logic intact
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    return MSALPublicClientApplication.handleMSALResponse(
      url,
      sourceApplication: options[UIApplication.OpenURLOptionsKey.sourceApplication] as? String
    )
  }
}
