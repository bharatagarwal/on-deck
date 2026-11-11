enum TaskInteraction {
  case browsing
  case showingShortcuts
  case editing(Draft)
  case confirmingDeletion(TaskItem)
  case reportingError(String, resume: Draft?)

  enum Target: Equatable {
    case newTask
    case rename(TaskItem.ID)
  }

  struct Draft {
    let target: Target
    var title: String
  }

  enum Event {
    case showShortcuts
    case dismissShortcuts
    case beginEditing(Draft)
    case changeTitle(String)
    case finishEditing
    case requestDeletion(TaskItem)
    case dismissDeletion
    case saveFailed(String)
    case dismissError
  }

  var draft: Draft? {
    guard case .editing(let draft) = self else { return nil }
    return draft
  }

  var pendingDeletion: TaskItem? {
    guard case .confirmingDeletion(let task) = self else { return nil }
    return task
  }

  var errorMessage: String? {
    guard case .reportingError(let message, _) = self else { return nil }
    return message
  }

  var showsShortcuts: Bool {
    if case .showingShortcuts = self { return true }
    return false
  }

  var isBrowsing: Bool {
    if case .browsing = self { return true }
    return false
  }

  mutating func send(_ event: Event) {
    switch (self, event) {
    case (.browsing, .showShortcuts):
      self = .showingShortcuts
    case (.showingShortcuts, .dismissShortcuts):
      self = .browsing
    case (.browsing, .beginEditing(let draft)):
      self = .editing(draft)
    case (.editing(var draft), .changeTitle(let title)):
      draft.title = title
      self = .editing(draft)
    case (.browsing, .requestDeletion(let task)):
      self = .confirmingDeletion(task)
    case (.editing, .finishEditing), (.confirmingDeletion, .dismissDeletion):
      self = .browsing
    case (.reportingError(_, let draft), .dismissError):
      self = draft.map(Self.editing) ?? .browsing
    case (.reportingError, .saveFailed):
      break
    case (_, .saveFailed(let message)):
      self = .reportingError(message, resume: draft)
    default:
      break
    }
  }
}
