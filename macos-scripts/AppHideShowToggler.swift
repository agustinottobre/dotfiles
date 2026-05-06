import Cocoa

// Use the correct bundle identifier
let appBundleIdentifier = CommandLine.arguments[1]

func getRunningApplication(bundleIdentifier: String) -> NSRunningApplication? {
    return NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first
}

func toggleAppVisibility(bundleIdentifier: String) {
    if let app = getRunningApplication(bundleIdentifier: bundleIdentifier) {
        if app.isActive {
            // Minimize the app
            app.hide()
        } else {
            // Activate the app without using deprecated methods
            app.activate(options: [])
        }
    } else {
        // Launch the app if it's not running
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-b", bundleIdentifier]
        task.launch()
    }
}

// Check if the script received an argument
if CommandLine.argc > 1 {
    toggleAppVisibility(bundleIdentifier: appBundleIdentifier)
} else {
    print("Please provide the bundle identifier of the application.")
}
