import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  /// Quit when the app's own window closes, but not when a second window does.
  ///
  /// The Cosmos sign-in runs in a web view window of its own. Answering an
  /// unconditional true took the whole app down with it the moment that window
  /// was closed, mid sign-in, which is not what closing a sign-in window means.
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return !sender.windows.contains { $0.isVisible }
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
