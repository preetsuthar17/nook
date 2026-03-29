import SwiftUI

struct PopoverContentView: View {
    @ObservedObject var model: AppModel
    var dismiss: () -> Void

    var body: some View {
        StatusMenuView(model: model, dismiss: dismiss)
            .frame(width: 260)
            .padding(.vertical, 8)
    }
}
