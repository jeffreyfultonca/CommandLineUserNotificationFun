import Foundation
import os

os_log("Starting main.swift", log: .default, type: .debug)

/*
 UserNotificationCenter appears to require an app's "bundle identifier" to identify app posting the
 notification. However command line tools don't use the bundle structure so the main bundle's
 identifier is always `nil`. It looks like UserNotificationCenter just ignores notifications from
 processes with nil bundle identifiers.
 
 My solution is to "swizzle" the main bundle's identifier so it returns Terminal.app's identifier
 instead of nil. This makes UserNotificationCenter think the notification is coming from
 Terminal.app.
 
 Swizzling is a crazy Objective-C thing that we should probably never do... but it get's the job
 done here.
 */

extension Bundle {
    @objc var swizzledBundleIdentifier: String?  { return "com.apple.terminal" }
}

let mainBundleClass: AnyClass = object_getClass(Bundle.main)!
let originalMethod = class_getInstanceMethod(mainBundleClass, #selector(getter: Bundle.bundleIdentifier))!
let swizzledMethod = class_getInstanceMethod(mainBundleClass, #selector(getter: Bundle.swizzledBundleIdentifier))!

method_exchangeImplementations(originalMethod, swizzledMethod)

// Used to keep command line tool executing until UserNotification is successfully delivered.
class UserNotificationCenterDelegate: NSObject, NSUserNotificationCenterDelegate {
    private(set) var isWaitingForUserNotification = true
    
    func userNotificationCenter(
        _ center: NSUserNotificationCenter,
        didDeliver notification: NSUserNotification)
    {
        os_log("UserNotification delivered", log: .default, type: .debug)
        self.isWaitingForUserNotification = false
    }
}

let userNotificationCenterDelegate = UserNotificationCenterDelegate()

// Get default NSUserNotificationCenter instance and assign delegate.
let userNotificationCenter = NSUserNotificationCenter.default
userNotificationCenter.delegate = userNotificationCenterDelegate

// Create and post UserNotification
let userNotification = NSUserNotification()
userNotification.title = "Testing title"
userNotification.subtitle = "Testing subtitle"

os_log("Posting UserNotification", log: .default, type: .debug)
userNotificationCenter.deliver(userNotification)

// Keep command line tool executing until UserNotification is successfully delivered to delegate.
while userNotificationCenterDelegate.isWaitingForUserNotification {
    os_log("inside while loop...", log: .default, type: .debug)
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.5))
}

// At this point the UserNotification has been received and we can exit.
os_log("Exiting", log: .default, type: .debug)
