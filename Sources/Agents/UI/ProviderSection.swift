import SwiftUI

// One provider's card: its mark, name, and plan, a note when the numbers
// aren't current, then its limit windows — or a balance, for a prepaid
// account.
struct ProviderSection: View {
  let record: UsageRecord
  let now: Date

  var body: some View {
    let windows = Presentation.displayWindows(record.limits, now: now)
    Card {
      head

      if Presentation.needsSignIn(record) {
        Label("Sign-in required", systemImage: "exclamationmark.triangle.fill")
          .font(Theme.secondary)
          .foregroundStyle(Theme.urgent)
          .help(record.authHelpText.isEmpty ? record.usageStatusText : record.authHelpText)
      }

      ForEach(Array(windows.enumerated()), id: \.offset) { _, window in
        LimitRow(window: window, stale: record.limitsStale, fetchedAt: record.limitsFetchedAt, now: now)
      }

      if let balance = record.balance {
        BalanceRow(balance: balance)
      }
    }
  }

  private var head: some View {
    HStack(spacing: 8) {
      ProviderMark(id: record.id)
      Text(record.name).font(Theme.title).lineLimit(1)
      let note = Presentation.usageNote(record)
      if !note.isEmpty {
        Image(systemName: "info.circle")
          .font(Theme.secondary)
          .foregroundStyle(.secondary)
          .help(note)
      }
      Spacer(minLength: 8)
      let plan = Presentation.planLabel(record)
      if !plan.isEmpty {
        Text(plan).font(Theme.secondary).foregroundStyle(.secondary)
      }
    }
  }
}

// What is left, not what is used: a prepaid account drains toward empty
// rather than filling toward a cap.
struct BalanceRow: View {
  let balance: Balance

  var body: some View {
    let alarming = Presentation.balanceAlarming(balance)
    VStack(alignment: .leading, spacing: 4) {
      HStack(alignment: .firstTextBaseline) {
        Text("Balance").font(Theme.body)
        Spacer(minLength: 8)
        Text(Presentation.formatMoney(balance.remaining, currency: balance.currency))
          .font(Theme.secondary)
          .monospacedDigit()
          .foregroundStyle(alarming ? AnyShapeStyle(Theme.urgent) : AnyShapeStyle(.secondary))
      }
      Meter(value: balance.funded > 0 ? balance.remaining / balance.funded : 0, alarming: alarming)
      let detail = Presentation.balanceDetail(balance)
      if !detail.isEmpty {
        Text(detail).font(Theme.secondary).foregroundStyle(.secondary)
      }
    }
  }
}
