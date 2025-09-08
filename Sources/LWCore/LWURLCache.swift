import Foundation
public enum LWURLCache { public static func configure(memoryMB:Int=64, diskMB:Int=256){ URLCache.shared = URLCache(memoryCapacity: memoryMB*1024*1024, diskCapacity: diskMB*1024*1024, diskPath: "lw.urlcache") } }
