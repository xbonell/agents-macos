import Foundation

// One agent's usage record, as docs/agent-usage-collectors.md in Omarchy
// defines it. Every field is read leniently: the format grows over time, and
// a field this version doesn't know, or one of an unexpected type, must not
// cost the rest of the record.
struct UsageRecord: Decodable, Identifiable, Equatable {
  var id: String
  var name: String
  var updatedAt: String
  var ready: Bool
  var tierLabel: String
  var usageStatusText: String
  var authHelpText: String
  var limits: [UsageLimit]
  var limitsStale: Bool
  var limitsFetchedAt: Double
  var retryAdvised: Bool
  var balance: Balance?
  var accounts: [Account]
  var accountSwitch: AccountSwitch?
  var hasLocalStats: Bool
  var hasPromptStats: Bool
  var scope: String

  var todayPrompts: Int
  var todaySessions: Int
  var todayTotalTokens: Int
  var todayTokensByModel: [String: Int]
  var recentDays: [RecentDay]
  var totalPrompts: Int
  var totalSessions: Int
  var activeDays: Int
  var activeDates: [String]
  var modelUsage: [String: ModelUsage]

  private enum CodingKeys: String, CodingKey {
    case id, name, updatedAt, ready, tierLabel, usageStatusText, authHelpText
    case limits, limitsStale, limitsFetchedAt, retryAdvised, balance, accounts, accountSwitch
    case hasLocalStats, hasPromptStats, scope
    case todayPrompts, todaySessions, todayTotalTokens, todayTokensByModel, recentDays
    case totalPrompts, totalSessions, activeDays, activeDates, modelUsage
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = c.lenient(String.self, .id) ?? ""
    name = c.lenient(String.self, .name) ?? id
    updatedAt = c.lenient(String.self, .updatedAt) ?? ""
    ready = c.lenient(Bool.self, .ready) ?? false
    tierLabel = c.lenient(String.self, .tierLabel) ?? ""
    usageStatusText = c.lenient(String.self, .usageStatusText) ?? ""
    authHelpText = c.lenient(String.self, .authHelpText) ?? ""
    limits = c.lenient([UsageLimit].self, .limits) ?? []
    limitsStale = c.lenient(Bool.self, .limitsStale) ?? false
    limitsFetchedAt = c.lenient(Double.self, .limitsFetchedAt) ?? 0
    retryAdvised = c.lenient(Bool.self, .retryAdvised) ?? false
    balance = c.lenient(Balance.self, .balance)
    accounts = c.lenient([Account].self, .accounts) ?? []
    accountSwitch = c.lenient(AccountSwitch.self, .accountSwitch)
    hasLocalStats = c.lenient(Bool.self, .hasLocalStats) ?? false
    hasPromptStats = c.lenient(Bool.self, .hasPromptStats) ?? true
    scope = c.lenient(String.self, .scope) ?? ""
    todayPrompts = c.lenient(Int.self, .todayPrompts) ?? 0
    todaySessions = c.lenient(Int.self, .todaySessions) ?? 0
    todayTotalTokens = c.lenient(Int.self, .todayTotalTokens) ?? 0
    todayTokensByModel = c.lenient([String: Int].self, .todayTokensByModel) ?? [:]
    recentDays = c.lenient([RecentDay].self, .recentDays) ?? []
    totalPrompts = c.lenient(Int.self, .totalPrompts) ?? 0
    totalSessions = c.lenient(Int.self, .totalSessions) ?? 0
    activeDays = c.lenient(Int.self, .activeDays) ?? 0
    activeDates = c.lenient([String].self, .activeDates) ?? []
    modelUsage = c.lenient([String: ModelUsage].self, .modelUsage) ?? [:]
  }

  // Main.qml's providerHasData: an agent earns a section by having produced
  // numbers, not merely by having a record. Unlike Omarchy, whose add-account
  // view covers it, a record with a status also gets one: a collector leaves
  // the status empty for an agent this machine doesn't use, so "Waiting for
  // auth" means one that's installed but signed out, and its card is where
  // to sign back in.
  var hasData: Bool {
    totalPrompts > 0 || totalSessions > 0 || activeDays > 0 || todayPrompts > 0
      || todaySessions > 0 || !limits.isEmpty || !accounts.isEmpty || balance != nil
      || (ready && !tierLabel.isEmpty) || !usageStatusText.isEmpty
  }
}

struct UsageLimit: Decodable, Equatable, Hashable {
  var label: String
  var title: String
  var percent: Double
  var resetsAt: String

  private enum CodingKeys: String, CodingKey { case label, title, percent, resetsAt }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    label = c.lenient(String.self, .label) ?? ""
    title = c.lenient(String.self, .title) ?? ""
    percent = min(1, max(0, c.lenient(Double.self, .percent) ?? 0))
    resetsAt = c.lenient(String.self, .resetsAt) ?? ""
  }

  var resetDate: Date? { ISODate.parse(resetsAt) }
}

struct Balance: Decodable, Equatable {
  var remaining: Double
  var funded: Double
  var spent: Double
  var currency: String
  var estimated: Bool

  private enum CodingKeys: String, CodingKey { case remaining, funded, spent, currency, estimated }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    remaining = c.lenient(Double.self, .remaining) ?? 0
    funded = c.lenient(Double.self, .funded) ?? 0
    spent = c.lenient(Double.self, .spent) ?? 0
    currency = c.lenient(String.self, .currency) ?? "USD"
    estimated = c.lenient(Bool.self, .estimated) ?? false
  }
}

struct Account: Decodable, Equatable {
  var id: String
  var label: String
  var email: String
  var plan: String
  var active: Bool
  var limits: [UsageLimit]
  var stale: Bool
  var fetchedAt: Double
  var usageStatusText: String
  var authHelpText: String

  private enum CodingKeys: String, CodingKey {
    case id, label, email, plan, active, limits, stale, fetchedAt, usageStatusText, authHelpText
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = c.lenient(String.self, .id) ?? ""
    label = c.lenient(String.self, .label) ?? ""
    email = c.lenient(String.self, .email) ?? ""
    plan = c.lenient(String.self, .plan) ?? ""
    active = c.lenient(Bool.self, .active) ?? false
    limits = c.lenient([UsageLimit].self, .limits) ?? []
    stale = c.lenient(Bool.self, .stale) ?? false
    fetchedAt = c.lenient(Double.self, .fetchedAt) ?? 0
    usageStatusText = c.lenient(String.self, .usageStatusText) ?? ""
    authHelpText = c.lenient(String.self, .authHelpText) ?? ""
  }
}

struct AccountSwitch: Decodable, Equatable {
  var mode: String
  var threshold: Double

  private enum CodingKeys: String, CodingKey { case mode, threshold }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    mode = c.lenient(String.self, .mode) ?? "manual"
    threshold = c.lenient(Double.self, .threshold) ?? 95
  }
}

struct RecentDay: Decodable, Equatable {
  var date: String
  // The collectors keep tokens in messageCount, for the panel's history.
  var tokens: Int

  private enum CodingKeys: String, CodingKey { case date, messageCount }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    date = c.lenient(String.self, .date) ?? ""
    tokens = c.lenient(Int.self, .messageCount) ?? 0
  }
}

struct ModelUsage: Decodable, Equatable {
  var inputTokens: Int
  var outputTokens: Int
  var cacheReadInputTokens: Int
  var cacheCreationInputTokens: Int

  private enum CodingKeys: String, CodingKey {
    case inputTokens, outputTokens, cacheReadInputTokens, cacheCreationInputTokens
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    inputTokens = c.lenient(Int.self, .inputTokens) ?? 0
    outputTokens = c.lenient(Int.self, .outputTokens) ?? 0
    cacheReadInputTokens = c.lenient(Int.self, .cacheReadInputTokens) ?? 0
    cacheCreationInputTokens = c.lenient(Int.self, .cacheCreationInputTokens) ?? 0
  }

  var total: Int { inputTokens + outputTokens + cacheReadInputTokens + cacheCreationInputTokens }
}

extension KeyedDecodingContainer {
  // A field that is missing, null, or of another type reads as absent.
  func lenient<T: Decodable>(_ type: T.Type, _ key: Key) -> T? {
    (try? decodeIfPresent(type, forKey: key)) ?? nil
  }
}

// Collector times are ISO 8601, sometimes with microseconds, which
// ISO8601DateFormatter's fractional-seconds option doesn't take.
enum ISODate {
  private static let formatter = ISO8601DateFormatter()
  private static let fraction = try! NSRegularExpression(pattern: #"\.\d+"#)

  static func parse(_ value: String) -> Date? {
    guard !value.isEmpty else { return nil }
    let range = NSRange(value.startIndex..., in: value)
    let whole = fraction.stringByReplacingMatches(in: value, range: range, withTemplate: "")
    return formatter.date(from: whole)
  }
}
