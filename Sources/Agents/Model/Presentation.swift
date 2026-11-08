import Foundation

// Panel.qml's reading of the records, kept free of SwiftUI: limit windows and
// their titles, durations, status lines, and the hero's summary phrases. The
// English strings are Omarchy's en/shell.json; the collectors write English
// too, so statuses and help pass through as they came.

struct LimitWindow: Equatable {
  var title: String
  var percent: Double
  var resetAt: Date?
  // Model-scoped allowances on the same clock ("Fable" on Weekly), drawn as
  // ticks on this window's meter.
  var scoped: [Scoped] = []

  struct Scoped: Equatable {
    var title: String
    var percent: Double
  }
}

enum Presentation {
  // MARK: Windows

  static func windowIsLong(_ text: String) -> Bool {
    ["week", "7-day", "seven", "month", "30-day"].contains { text.contains($0) }
  }

  static func windowSpan(_ label: String) -> TimeInterval {
    let text = label.lowercased()
    if text.contains("month") || text.contains("30-day") { return 30 * 24 * 3600 }
    if windowIsLong(text) { return 7 * 24 * 3600 }
    if let hours = firstNumber(in: text, pattern: #"(\d+)\s*-?\s*h(?:our)?\b"#) { return hours * 3600 }
    if let minutes = firstNumber(in: text, pattern: #"(\d+)\s*-?\s*m(?:in(?:ute)?s?)?\b"#) { return minutes * 60 }
    return 0
  }

  static func windowTitle(_ label: String) -> String {
    let text = label.lowercased()
    if text.contains("month") { return "Monthly" }
    if windowIsLong(text) { return "Weekly" }
    if text.contains("session") || windowSpan(label) > 0 { return "Session" }
    let plain = label.replacingOccurrences(of: #"\s*\(.*\)\s*"#, with: "", options: .regularExpression)
      .trimmingCharacters(in: .whitespaces)
    return plain.isEmpty ? "Limit" : plain
  }

  // A collector that knows which window a limit belongs to says so in
  // `title`, which beats reading it out of the label. A window whose reset
  // has passed is untouched again, not unknown.
  static func limitWindows(_ limits: [UsageLimit], now: Date) -> [LimitWindow] {
    limits.map { limit in
      let reset = limit.resetDate
      let expired = reset.map { $0 <= now } ?? false
      return LimitWindow(
        title: limit.title.isEmpty ? windowTitle(limit.label) : limit.title,
        percent: expired ? 0 : limit.percent,
        resetAt: expired ? nil : reset
      )
    }
  }

  static func scopedPart(_ title: String) -> (model: String, window: String)? {
    guard let match = title.firstMatch(of: #/^(.+) (Session|Weekly|Monthly)$/#) else { return nil }
    return (String(match.1), String(match.2))
  }

  // A model-scoped window rides on the row of the window it's named for; one
  // with nothing to attach to keeps a row of its own.
  static func displayWindows(_ limits: [UsageLimit], now: Date) -> [LimitWindow] {
    let windows = limitWindows(limits, now: now)
    var out = windows.filter { scopedPart($0.title) == nil }
    for window in windows {
      guard let part = scopedPart(window.title) else { continue }
      if let index = out.firstIndex(where: { $0.title == part.window }) {
        out[index].scoped.append(.init(title: part.model, percent: window.percent))
      } else {
        out.append(window)
      }
    }
    return out
  }

  // The fullest window: what stops the next prompt.
  static func bindingWindow(_ record: UsageRecord, now: Date) -> LimitWindow? {
    limitWindows(record.limits, now: now).max { $0.percent < $1.percent }
  }

  static func scopedAllowanceText(_ scoped: LimitWindow.Scoped, windowTitle: String) -> String {
    let percent = Int((scoped.percent * 100).rounded())
    switch windowTitle {
    case "Session": return "\(scoped.title): \(percent)% of its session allowance"
    case "Weekly": return "\(scoped.title): \(percent)% of its weekly allowance"
    case "Monthly": return "\(scoped.title): \(percent)% of its monthly allowance"
    default: return "\(scoped.title): \(percent)% of its \(windowTitle) allowance"
    }
  }

  // The row's tooltip: how full, when it resets, how old kept numbers are,
  // and any model-scoped allowance on its meter.
  static func limitTooltip(_ window: LimitWindow, stale: Bool, fetchedAt: Double, now: Date) -> String {
    var lines: [String] = []
    let used = Int((window.percent * 100).rounded())
    if let reset = window.resetAt, reset > now {
      lines.append("\(window.title): \(used)% used · resets in \(formatDuration(reset.timeIntervalSince(now)))")
    } else {
      lines.append("\(window.title): \(used)% used")
    }
    if stale {
      let age = now.timeIntervalSince1970 - fetchedAt / 1000
      if fetchedAt > 0 && age > 60 {
        lines.append("Last updated \(formatDuration(age)) ago")
      } else {
        lines.append(fetchedAt > 0 ? "Last updated less than a minute ago" : "Last updated time unavailable")
      }
    }
    lines += window.scoped.map { scopedAllowanceText($0, windowTitle: window.title) }
    return lines.joined(separator: "\n")
  }

  static func formatDuration(_ seconds: TimeInterval) -> String {
    guard seconds > 0 else { return "now" }
    let minutes = Int(seconds / 60)
    let hours = minutes / 60
    let days = hours / 24
    if days > 0 { return "\(days)d \(hours % 24)h" }
    if hours > 0 { return "\(hours)h \(minutes % 60)m" }
    return "\(max(1, minutes))m"
  }

  // MARK: Status

  // How old the numbers are, from the newest record: the panel's footer.
  static func updatedText(_ records: [UsageRecord], now: Date, running: Bool) -> String {
    if running { return "Updating…" }
    guard let newest = records.compactMap({ ISODate.parse($0.updatedAt) }).max() else { return "" }
    let age = now.timeIntervalSince(newest)
    return age < 60 ? "Updated just now" : "Updated \(formatDuration(age)) ago"
  }

  // The commands that sign each agent's CLI in again, as its collector's
  // help text names them. Only these ever run; a record's own text never does.
  static let signInCommands: [String: String] = [
    "claude": "claude auth login",
    "codex": "codex login",
    "cursor": "cursor-agent login",
  ]

  static func planLabel(_ record: UsageRecord) -> String {
    let tier = record.tierLabel
    return tier.isEmpty ? "" : tier.prefix(1).uppercased() + tier.dropFirst()
  }

  // A lapsed or missing sign-in is the one trouble that has its own line.
  static func needsSignIn(_ record: UsageRecord) -> Bool {
    record.usageStatusText == "Sign-in expired" || record.usageStatusText == "Waiting for auth"
  }

  // Whatever keeps the numbers from being current, said beside the last ones
  // known. A failed refresh with numbers kept may say why only in its help.
  static func usageNote(_ record: UsageRecord) -> String {
    if needsSignIn(record) { return "" }
    let status = record.usageStatusText
    if status.isEmpty && !(record.limitsStale && !record.authHelpText.isEmpty) { return "" }
    return record.authHelpText.isEmpty ? status : record.authHelpText
  }

  // The bar icon lights up when a window is nearly out, or a prepaid balance
  // is down to its last 10%.
  static func alarming(_ records: [UsageRecord], now: Date) -> Bool {
    records.contains { record in
      (bindingWindow(record, now: now)?.percent ?? 0) >= 0.9 || balanceAlarming(record.balance)
    }
  }

  static func balanceAlarming(_ balance: Balance?) -> Bool {
    guard let balance, balance.funded > 0 else { return false }
    return balance.remaining / balance.funded <= 0.1
  }

  static func formatMoney(_ value: Double, currency: String) -> String {
    let prefix: String
    switch currency.uppercased() {
    case "USD": prefix = "$"
    case "EUR": prefix = "€"
    case "GBP": prefix = "£"
    default: prefix = currency.uppercased() + " "
    }
    return prefix + value.formatted(.number.precision(.fractionLength(2)))
  }

  static func balanceDetail(_ balance: Balance) -> String {
    guard balance.funded > 0 else { return "" }
    let spent = formatMoney(balance.spent, currency: balance.currency)
    let funded = formatMoney(balance.funded, currency: balance.currency)
    return balance.estimated ? "\(spent) spent of \(funded) funded · estimated" : "\(spent) spent of \(funded) funded"
  }

  // MARK: Summary

  // The hero's line rotates through what the token counts add up to across
  // every agent.
  static func summaryPhrases(_ records: [UsageRecord]) -> [String] {
    var week = 0, today = 0, prompts = 0, sessions = 0
    var byDay: [String: Int] = [:]
    var byModel: [String: Int] = [:]
    for record in records {
      for day in record.recentDays {
        week += day.tokens
        byDay[day.date, default: 0] += day.tokens
      }
      today += record.todayTotalTokens
      if record.hasPromptStats {
        prompts += record.todayPrompts
        sessions += record.todaySessions
      }
      for (id, usage) in record.modelUsage {
        byModel[friendlyModelName(id), default: 0] += usage.total
      }
    }

    var phrases: [String] = []
    if week > 0 { phrases.append(plural(week, "token", formatTokenCount(week)) + " this week") }
    if today > 0 { phrases.append(plural(today, "token", formatTokenCount(today)) + " today") }
    if let top = byModel.max(by: { ($0.value, $1.key) < ($1.value, $0.key) }), top.value > 0 {
      phrases.append("Mostly \(top.key)")
    }
    if let busiest = byDay.max(by: { ($0.value, $1.key) < ($1.value, $0.key) }), busiest.value > 0 {
      phrases.append("Busiest day: \(dayName(busiest.key))")
    }
    if prompts > 0 { phrases.append(plural(prompts, "prompt", prompts.formatted()) + " today") }
    if sessions > 0 { phrases.append(plural(sessions, "session", sessions.formatted()) + " today") }
    return phrases
  }

  static func formatTokenCount(_ n: Int) -> String {
    let value = Double(n)
    let one = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(1))
    if value >= 1e9 { return (value / 1e9).formatted(one) + "B" }
    if value >= 1e6 { return (value / 1e6).formatted(one) + "M" }
    if value >= 1e3 { return (value / 1e3).formatted(one) + "K" }
    return n.formatted()
  }

  // Model ids arrive hyphenated with the version split across segments
  // (`claude-opus-5-5`, `gpt-5.6-sol`): rejoin the numeric run into one
  // version and title-case the words around it.
  static func friendlyModelName(_ id: String) -> String {
    guard !id.isEmpty else { return "Unknown model" }
    let name = id.replacingOccurrences(of: #"^claude-"#, with: "", options: .regularExpression)
      .replacingOccurrences(of: #"-\d{8}$"#, with: "", options: .regularExpression)
    var words: [String] = []
    var version: [String] = []
    for part in name.split(separator: "-").map(String.init) where !part.isEmpty {
      if part.first?.isNumber == true {
        version.append(part)
        continue
      }
      if !version.isEmpty {
        words.append(version.joined(separator: "."))
        version = []
      }
      words.append(modelWordCase(part))
    }
    if !version.isEmpty { words.append(version.joined(separator: ".")) }
    return words.isEmpty ? "Unknown model" : words.joined(separator: " ")
  }

  private static func modelWordCase(_ word: String) -> String {
    if word == "gpt" { return "GPT" }
    if word == "deepseek" { return "DeepSeek" }
    return word.prefix(1).uppercased() + word.dropFirst()
  }

  private static func dayName(_ date: String) -> String {
    let parse = DateFormatter()
    parse.dateFormat = "yyyy-MM-dd"
    parse.locale = Locale(identifier: "en_US_POSIX")
    guard let day = parse.date(from: date) else { return date }
    let name = DateFormatter()
    name.dateFormat = "EEEE"
    return name.string(from: day)
  }

  private static func plural(_ count: Int, _ noun: String, _ shown: String) -> String {
    "\(shown) \(noun)\(count == 1 ? "" : "s")"
  }

  private static func firstNumber(in text: String, pattern: String) -> Double? {
    guard let range = text.range(of: pattern, options: .regularExpression) else { return nil }
    let digits = text[range].prefix { $0.isNumber }
    return Double(digits)
  }
}
