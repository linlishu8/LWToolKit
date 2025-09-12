import Foundation

/// 串行编排工具：将一系列异步步骤顺序执行并返回结果数组。
/// - Tip: 如果你更偏好强类型，可以继续使用 `loginPipeline` 这类函数式封装。
public enum Flow {
    public static func sequence(_ steps: [() async throws -> Any]) async throws -> [Any] {
        var out: [Any] = []
        for step in steps { out.append(try await step()) }
        return out
    }
}
