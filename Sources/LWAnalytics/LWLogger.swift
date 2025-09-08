import Foundation
import OSLog
public enum LWLogger { public static func debug(_ s:String){ if #available(iOS 14.0, *){ Logger().debug("\(s)") } else { NSLog(s) } } }
