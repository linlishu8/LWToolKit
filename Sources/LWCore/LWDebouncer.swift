import Foundation
public final class LWDebouncer {
    private let delay: TimeInterval; private var work: DispatchWorkItem?
    public init(delay: TimeInterval){ self.delay = delay }
    public func call(_ block: @escaping ()->Void){ work?.cancel(); let item=DispatchWorkItem(block:block); work=item; DispatchQueue.main.asyncAfter(deadline:.now()+delay, execute:item) }
}
