import SwiftUI

struct TaskListView: View {
  let store: TaskStore
  @Binding var zoomStep: Int
  @Environment(\.taskMetrics) private var metrics
  @State private var selectedID: TaskItem.ID?
  @State private var taskToReveal: TaskItem.ID?
  @State private var interaction = TaskInteraction.browsing
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @FocusState private var listFocused: Bool

  private var acceptsCommands: Bool {
    store.loadError == nil && interaction.isBrowsing
  }

  private var isAdding: Bool {
    interaction.draft?.target == .newTask
  }

  private var renamingID: TaskItem.ID? {
    guard case .rename(let id) = interaction.draft?.target else { return nil }
    return id
  }

  private var openCount: Int {
    store.tasks.count { !$0.isComplete }
  }

  private var selectionIndex: Int? {
    store.tasks.firstIndex { $0.id == selectedID }
  }

  private var commands: TaskCommandContext {
    TaskCommandContext(
      index: selectionIndex,
      count: store.tasks.count,
      isComplete: selectionIndex.map { store.tasks[$0].isComplete } ?? false,
      perform: { perform($0, on: selectedID) },
      showShortcuts: { interaction.send(.showShortcuts) },
      goToTask: goToTask
    )
  }

  private var currentZoomStep: Int {
    TaskZoomAction.bounded(zoomStep)
  }

  private var zoomCommands: TaskZoomContext {
    TaskZoomContext(step: currentZoomStep) { zoomStep = $0.target(from: currentZoomStep) }
  }

  var body: some View {
    let pending = interaction.pendingDeletion
    return Group {
      if let error = store.loadError {
        ContentUnavailableView {
          Label("Couldn’t Open Tasks", systemImage: "exclamationmark.triangle")
        } description: {
          Text(error.localizedDescription)
        }
      } else if store.tasks.isEmpty {
        TaskEmptyView {
          if isAdding {
            composer
          } else {
            NewTaskButton { perform(.add, on: nil) }
          }
        }
      } else {
        taskList
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background { QueueBackdrop().ignoresSafeArea() }
    .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: store.tasks.isEmpty)
    .focusedSceneValue(\.taskCommands, acceptsCommands ? commands : nil)
    .focusedSceneValue(
      \.taskZoom,
      interaction.pendingDeletion == nil && interaction.errorMessage == nil ? zoomCommands : nil
    )
    .sheet(isPresented: shortcutsPresented, onDismiss: focusList) {
      TaskShortcutsView()
    }
    .alert("Delete Task?", isPresented: deletionPresented, presenting: pending) { task in
      Button("Cancel", role: .cancel) {}
      Button("Delete", role: .destructive) {
        delete(task)
      }
    } message: { task in
      Text("“\(task.title)” will be removed from the list.")
    }
    .alert("Couldn’t Save Tasks", isPresented: errorPresented) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(interaction.errorMessage ?? "")
    }
  }

  private var taskList: some View {
    VStack(spacing: 0) {
      QueueMasthead(status: "\(openCount) of \(store.tasks.count) open")
        .padding(.horizontal, metrics.length(23))
        .padding(.top, metrics.length(12))
        .padding(.bottom, metrics.length(7))

      if isAdding {
        composer
          .padding(.horizontal, metrics.length(20))
          .padding(.bottom, metrics.length(10))
      }

      ScrollViewReader { scroll in
        List(selection: $selectedID) {
          ForEach(store.tasks.enumerated(), id: \.element.id) { index, task in
            taskRow(task, at: index)
              .tag(task.id)
              .id(task.id)
              .listRowSeparator(.hidden)
              .listRowInsets(
                EdgeInsets(
                  top: metrics.length(4), leading: metrics.length(12), bottom: metrics.length(4),
                  trailing: metrics.length(12)))
          }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .accessibilityIdentifier("priority-list")
        .focused($listFocused)
        .defaultFocus($listFocused, true)
        .onKeyPress(keys: [.space], phases: .down, action: handleSpace)
        .background { TaskListFocus { interaction.isBrowsing }.allowsHitTesting(false) }
        .onChange(of: store.tasks.map(\.id)) {
          if let selectedID {
            scroll.scrollTo(selectedID)
          }
        }
        .onChange(of: renamingID) {
          if let renamingID {
            scroll.scrollTo(renamingID)
          }
        }
        .onChange(of: selectedID) {
          if let renamingID, renamingID != selectedID {
            finishEditing()
          }
        }
        .onChange(of: taskToReveal) {
          if let taskToReveal {
            scroll.scrollTo(taskToReveal)
            self.taskToReveal = nil
          }
        }
        .clipped()
      }

      TaskDock(context: commands)
        .disabled(!acceptsCommands)
        .padding(.vertical, metrics.length(12))
    }
  }

  private func taskRow(_ task: TaskItem, at index: Int) -> some View {
    TaskQueueRow(
      task: task, index: index, isSelected: task.id == selectedID,
      isRenaming: task.id == renamingID,
      toggleCompletion: { perform(.toggleCompletion, on: task.id) },
      renameField: { renameField }
    )
    .contextMenu {
      ForEach([TaskAction.rename, .toggleCompletion, .moveUp, .moveDown, .delete]) { action in
        Button(
          action.title(isComplete: task.isComplete), role: action == .delete ? .destructive : nil
        ) {
          perform(action, on: task.id)
        }
        .disabled(!action.isEnabled(at: index, count: store.tasks.count))
      }
    }
  }

  private var shortcutsPresented: Binding<Bool> {
    Binding(
      get: { interaction.showsShortcuts },
      set: { if !$0 { interaction.send(.dismissShortcuts) } }
    )
  }

  private var deletionPresented: Binding<Bool> {
    Binding(
      get: { interaction.pendingDeletion != nil },
      set: { if !$0 { interaction.send(.dismissDeletion) } }
    )
  }

  private var errorPresented: Binding<Bool> {
    Binding(
      get: { interaction.errorMessage != nil },
      set: { if !$0 { interaction.send(.dismissError) } }
    )
  }

}

extension TaskListView {
  fileprivate func goToTask(_ position: Int) {
    guard acceptsCommands, (1...9).contains(position), position <= store.tasks.count else { return }
    let id = store.tasks[position - 1].id
    selectedID = id
    focusList()
    taskToReveal = id
  }

  fileprivate func handleSpace(_ press: KeyPress) -> KeyPress.Result {
    guard press.modifiers.isEmpty, acceptsCommands, let selectedID else { return .ignored }
    perform(.toggleCompletion, on: selectedID)
    return .handled
  }

  fileprivate func perform(_ action: TaskAction, on id: TaskItem.ID?) {
    guard acceptsCommands else { return }
    let index = store.tasks.firstIndex { $0.id == id }
    guard action.isEnabled(at: index, count: store.tasks.count) else { return }

    do {
      switch (action, index) {
      case (.add, _): beginEditing(.init(target: .newTask, title: ""))
      case (.rename, let index?): beginRename(store.tasks[index])
      case (.toggleCompletion, let index?): try store.toggleCompletion(at: index)
      case (.moveUp, let index?): try store.move(from: index, by: -1)
      case (.moveDown, let index?): try store.move(from: index, by: 1)
      case (.delete, let index?): interaction.send(.requestDeletion(store.tasks[index]))
      default: break
      }
    } catch {
      interaction.send(.saveFailed(error.localizedDescription))
    }
  }

  fileprivate var draftTitle: Binding<String> {
    Binding(
      get: { interaction.draft?.title ?? "" },
      set: { interaction.send(.changeTitle($0)) }
    )
  }

  fileprivate var cleanedDraft: String {
    draftTitle.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  fileprivate var composer: some View {
    TaskComposer(title: draftTitle, submit: commitEditing, cancel: finishEditing)
  }

  fileprivate var renameField: some View {
    HStack(spacing: metrics.length(4)) {
      TaskInputField(
        title: draftTitle, placeholder: "Task title", identifier: "rename-title",
        submit: commitEditing, cancel: finishEditing
      )
      .frame(maxWidth: .infinity)

      Button("Save Rename", systemImage: "checkmark", action: commitEditing)
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .font(.system(size: metrics.length(13)))
        .disabled(cleanedDraft.isEmpty)
        .help("Save Rename (Return)")
    }
  }

  fileprivate func beginEditing(_ draft: TaskInteraction.Draft) {
    interaction.send(.beginEditing(draft))
    listFocused = false
  }

  fileprivate func beginRename(_ task: TaskItem) {
    selectedID = task.id
    beginEditing(.init(target: .rename(task.id), title: task.title))
  }

  fileprivate func commitEditing() {
    let title = cleanedDraft
    guard !title.isEmpty, let draft = interaction.draft else { return }

    do {
      switch draft.target {
      case .newTask:
        selectedID = try store.add(title)
      case .rename(let id):
        if let index = store.tasks.firstIndex(where: { $0.id == id }) {
          try store.rename(at: index, to: title)
        }
      }
      finishEditing()
    } catch {
      interaction.send(.saveFailed(error.localizedDescription))
    }
  }

  fileprivate func finishEditing() {
    interaction.send(.finishEditing)
    focusList()
  }

  fileprivate func delete(_ task: TaskItem) {
    guard let index = store.tasks.firstIndex(where: { $0.id == task.id }) else { return }
    do {
      try store.delete(at: index)
      if selectedID == task.id {
        selectedID = store.tasks.isEmpty ? nil : store.tasks[min(index, store.tasks.count - 1)].id
      }
    } catch {
      interaction.send(.saveFailed(error.localizedDescription))
    }
  }

  fileprivate func focusList() {
    listFocused = !store.tasks.isEmpty
  }
}
