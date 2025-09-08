import SwiftUI
public struct LWToastModifier: ViewModifier {
    @Binding var message: String?
    public func body(content: Content) -> some View {
        ZStack {
            content
            if let msg = message {
                Text(msg).padding(.horizontal,16).padding(.vertical,10)
                    .background(Color.black.opacity(0.8)).foregroundColor(.white)
                    .cornerRadius(12).transition(.opacity)
                    .onAppear { DispatchQueue.main.asyncAfter(deadline: .now()+1.6){ withAnimation{ message = nil } } }
            }
        }
    }
}
public extension View { func lwToast(message: Binding<String?>) -> some View { modifier(LWToastModifier(message: message)) } }
