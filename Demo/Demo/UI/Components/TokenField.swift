import SwiftUI

struct TokenField: View {
  @Binding var token: String
  let isLoading: Bool
  let onValidate: () -> Void

  var body: some View {
    VStack(spacing: 10) {
      HStack {
        Text("Developer Token")
          .font(.headline)
        Spacer()
      }

      HStack {
        TextField("Enter your token", text: $token)
          .textFieldStyle(.roundedBorder)
          .disabled(isLoading)

        Button("Validate") {
          onValidate()
        }
        .disabled(token.isEmpty || isLoading)
        .buttonStyle(.borderedProminent)
      }

      if isLoading {
        ProgressView("Validating...")
          .progressViewStyle(CircularProgressViewStyle())
      }
    }
    .padding()
    .background(Color.gray.opacity(0.1))
    .cornerRadius(10)
    .padding(.horizontal)
  }
}
