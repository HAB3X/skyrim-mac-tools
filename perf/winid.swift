// winid <pid>: the CGWindowID of the largest window of that process (for screencapture -l). Exit 1: none.
// Build: swiftc -O winid.swift -o build/winid
import CoreGraphics
import Foundation
let pid = Int32(CommandLine.arguments[1])!
// All windows: a game that captured the display isn't "on screen" to CoreGraphics
let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as! [[String: Any]]
var best: (Int, Double) = (0, 0)
for w in list where (w[kCGWindowOwnerPID as String] as? Int32) == pid {
  let b = w[kCGWindowBounds as String] as! [String: Double]; let a = b["Width"]! * b["Height"]!
  if a > best.1 { best = (w[kCGWindowNumber as String] as! Int, a) }
}
if best.0 == 0 { exit(1) }
print(best.0)
