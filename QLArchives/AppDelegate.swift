import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
	func applicationDidFinishLaunching(_ aNotification: Notification) {}
	
	func applicationWillTerminate(_ aNotification: Notification) {}
	
	func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
		return true
	}
	
	@IBAction func showLibarchiveVersion(_ sender: Any?) {
		let alert = NSAlert()
		alert.messageText = LibArchive.version()
		alert.runModal()
	}
}

