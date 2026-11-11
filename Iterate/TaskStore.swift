import Foundation
import Observation

struct TaskItem: Codable, Identifiable {
  var id = UUID()
  var title: String
  var isComplete = false
}

@MainActor
@Observable
final class TaskStore {
  private(set) var tasks: [TaskItem] = []
  private(set) var loadError: (any Error)?
  private let fileURL: URL

  static var defaultFileURL: URL {
    #if DEBUG
      if let directory = ProcessInfo.processInfo.environment["ITERATE_TEST_STORAGE"] {
        return URL(filePath: directory, directoryHint: .isDirectory).appending(path: "Tasks.json")
      }
    #endif
    return URL.applicationSupportDirectory.appending(path: "Iterate/Tasks.json")
  }

  init(fileURL: URL) {
    self.fileURL = fileURL
    do {
      tasks = try JSONDecoder().decode([TaskItem].self, from: Data(contentsOf: fileURL))
    } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
      // A new list has nothing to load.
    } catch {
      loadError = error
    }
  }

  func add(_ title: String) throws -> TaskItem.ID {
    let task = TaskItem(title: title)
    try save(tasks + [task])
    return task.id
  }

  func rename(at index: Int, to title: String) throws {
    guard tasks[index].title != title else { return }
    var updated = tasks
    updated[index].title = title
    try save(updated)
  }

  func move(from index: Int, by offset: Int) throws {
    var updated = tasks
    updated.swapAt(index, index + offset)
    try save(updated)
  }

  func toggleCompletion(at index: Int) throws {
    var updated = tasks
    updated[index].isComplete.toggle()
    try save(updated)
  }

  func delete(at index: Int) throws {
    var updated = tasks
    updated.remove(at: index)
    try save(updated)
  }

  private func save(_ updated: [TaskItem]) throws {
    if let loadError {
      throw loadError
    }

    let data = try JSONEncoder().encode(updated)
    try FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try data.write(to: fileURL, options: .atomic)
    tasks = updated
  }
}
