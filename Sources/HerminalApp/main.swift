// herminal — AI-native macOS terminal for Vietnamese developers.
// Executable entry point. Month-1 spike: prove libghostty embeds and renders a shell.

import AppKit

let delegate = AppDelegate()
let application = NSApplication.shared
application.delegate = delegate
application.setActivationPolicy(.regular)
application.run()
