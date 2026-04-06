import Cocoa

// FIXME: rename popover does not work

class Document: NSDocument, NSWindowDelegate, NSDraggingDestination {
	var url: URL? = nil
	var loaded: Bool = false
	
	override var isInViewingMode: Bool {true}
	
	override nonisolated class var autosavesInPlace: Bool {
		return true
	}
	
	override var windowNibName: NSNib.Name? {
		return NSNib.Name("Document")
	}
	
	override func windowControllerDidLoadNib(_ wc: NSWindowController) {
		let ctrl = ArchiveController()
		wc.contentViewController = ctrl
		if let url {
			ctrl.load(url)
		}
		loaded = true
		if let win = wc.window {
			restoreWindowSize(win)
		}
		wc.window?.registerForDraggedTypes([.fileURL])
	}
	
	override nonisolated func read(from url: URL, ofType typeName: String) throws {
		MainActor.assumeIsolated {
			self.url = url // becaues `fileURL` isnt stable in copyItem (-> autosavedContentsFileURL)
		}
	}
	
	override nonisolated func write(to url: URL, ofType typeName: String) throws {
		try MainActor.assumeIsolated {
			if let original = self.url {
				try FileManager.default.copyItem(at: original, to: url)
			}
		}
	}
	
	func windowDidResize(_ notification: Notification) {
		if loaded {
			persistWindowSize()
		}
	}
	
	// MARK: - Window resize
	
	/// Save current window size to user-defaults
	func persistWindowSize() {
		let sz = self.windowForSheet?.frame.size
		UserDefaults.standard.set(Int(sz?.width ?? 0), forKey: "winSizeW")
		UserDefaults.standard.set(Int(sz?.height ?? 0), forKey: "winSizeH")
	}
	
	/// Restore previous window size
	func restoreWindowSize(_ win: NSWindow) {
		let w = UserDefaults.standard.integer(forKey: "winSizeW")
		let h = UserDefaults.standard.integer(forKey: "winSizeH")
		if w > 0 && h > 0 {
			win.setFrame(CGRect(origin: win.frame.origin, size: .init(width: w, height: h)), display: true)
		}
	}
	
	// MARK: - Drag-drop open files
	
	func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
		.generic
	}
	
	func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
		if let files = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] {
			NSWorkspace.shared.open(files, withApplicationAt: Bundle.main.bundleURL, configuration: NSWorkspace.OpenConfiguration())
			return true
		}
		return false
	}
}

