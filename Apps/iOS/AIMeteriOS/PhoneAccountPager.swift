import SwiftUI
import AIMeterCore

struct PhoneAccountPager<Page: View>: View {
    @EnvironmentObject private var store: UsageStore
    @ViewBuilder var page: (AccountRuntime?) -> Page

    var body: some View {
        if store.visibleAccounts.count > 1 {
            TabView(selection: activeBinding) {
                ForEach(store.visibleAccounts) { account in
                    page(account)
                        .tag(account.id)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        } else {
            page(store.activeAccount)
        }
    }

    private var activeBinding: Binding<UUID> {
        Binding(
            get: { store.activeAccountID ?? store.visibleConnections.first?.id ?? UUID() },
            set: { store.setActive(id: $0) }
        )
    }
}

struct PhoneAccountSwitcherChrome: View {
    @EnvironmentObject private var store: UsageStore

    var body: some View {
        if store.visibleAccounts.count > 1 {
            HStack(spacing: 8) {
                chevron("chevron.left", label: "Previous account", step: -1)
                Spacer(minLength: 0)
                dots
                Spacer(minLength: 0)
                chevron("chevron.right", label: "Next account", step: 1)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Account \(currentIndex) of \(store.visibleAccounts.count). Swipe or tap arrows to switch accounts.")
        }
    }

    private func chevron(_ systemImage: String, label: String, step: Int) -> some View {
        Button {
            advance(by: step)
        } label: {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(store.visibleAccounts) { item in
                Circle()
                    .fill(item.id == store.activeAccountID ? Color.primary : Color.primary.opacity(0.25))
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityHidden(true)
    }

    private var currentIndex: Int {
        guard let id = store.activeAccountID,
              let index = store.visibleAccounts.firstIndex(where: { $0.id == id })
        else { return 1 }
        return index + 1
    }

    private func advance(by delta: Int) {
        let accounts = store.visibleAccounts
        guard !accounts.isEmpty else { return }
        let current = store.activeAccountID.flatMap { id in
            accounts.firstIndex(where: { $0.id == id })
        } ?? 0
        let next = (current + delta + accounts.count) % accounts.count
        store.setActive(id: accounts[next].id)
    }
}
