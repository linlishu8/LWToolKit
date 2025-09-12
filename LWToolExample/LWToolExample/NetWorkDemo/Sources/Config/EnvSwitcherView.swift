import SwiftUI

/// Debug 面板：用于在开发/测试阶段手动切环境
public struct EnvSwitcherView: View {
    @State private var selected: AppEnv = TestAppEnvironment.shared.current

    public init() {}

    public var body: some View {
        #if DEBUG
        VStack(alignment: .leading, spacing: 16) {
            Text("Environment Switcher").font(.headline)
            Picker("Environment", selection: $selected) {
                ForEach(AppEnv.allCases, id: \.self) { env in
                    Text(env.rawValue).tag(env)
                }
            }
            .pickerStyle(.segmented)

            Button("Apply & Restart Network") {
                TestAppEnvironment.shared.switchEnv(to: selected)
            }

            Text("Current: " + TestAppEnvironment.shared.current.rawValue)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding()
        #else
        Text("Env switcher is disabled in Release.")
        #endif
    }
}
