import Foundation
import XCTest

@MainActor
final class IterateUITests: XCTestCase {
  private let app = XCUIApplication()
  private let storage = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)

  override func setUp() {
    super.setUp()
    continueAfterFailure = false
  }

  private func launch() {
    app.launchEnvironment["ITERATE_TEST_STORAGE"] = storage.path
    addTeardownBlock { @MainActor [app, storage] in
      app.terminate()
      if FileManager.default.fileExists(atPath: storage.path) {
        try FileManager.default.removeItem(at: storage)
      }
    }
    app.launch()
  }

  func testKeyboardWorkflowAndPersistence() {
    launch()
    XCTAssertTrue(app.staticTexts["empty-heading"].waitForExistence(timeout: 5))

    app.typeKey("n", modifierFlags: .command)
    let title = app.textFields["task-title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    XCTAssertFalse(app.sheets.firstMatch.exists)
    app.typeText("   ")
    XCTAssertEqual(title.value as? String, "   ")
    XCTAssertFalse(app.buttons["Add Task"].isEnabled)
    app.typeKey(.escape, modifierFlags: [])
    XCTAssertTrue(title.waitForNonExistence(timeout: 5))

    add(" Plan the week ")
    add("Book train")
    add("Water plants")
    assertOrder(["Plan the week", "Book train", "Water plants"])

    app.typeKey(.upArrow, modifierFlags: .command)
    assertOrder(["Plan the week", "Water plants", "Book train"])
    app.typeKey(.upArrow, modifierFlags: .command)
    app.typeKey(.upArrow, modifierFlags: .command)
    assertOrder(["Water plants", "Plan the week", "Book train"])
    app.typeKey(.downArrow, modifierFlags: .command)
    assertOrder(["Plan the week", "Water plants", "Book train"])

    app.typeKey(.upArrow, modifierFlags: [])
    assertInlineRename()
    assertOrder(["Plan next week", "Water plants", "Book train"])

    app.typeKey(.return, modifierFlags: [])
    let status = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "2 of 3 open"))
    XCTAssertTrue(status.firstMatch.waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["Mark “Plan next week” incomplete"].exists)

    app.terminate()
    app.launch()
    assertOrder(["Plan next week", "Water plants", "Book train"])
    XCTAssertTrue(app.buttons["Mark “Plan next week” incomplete"].exists)

    selectLastTaskWithKeyboard()
    app.typeKey(.delete, modifierFlags: [])
    XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 5))
    app.typeKey(.escape, modifierFlags: [])
    XCTAssertTrue(app.buttons["Delete"].waitForNonExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Book train"].exists)

    app.typeKey(.delete, modifierFlags: [])
    XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 5))
    app.buttons["Delete"].click()
    XCTAssertTrue(app.staticTexts["Book train"].waitForNonExistence(timeout: 5))

    app.terminate()
    app.launch()
    assertOrder(["Plan next week", "Water plants"])
    XCTAssertFalse(app.staticTexts["Book train"].exists)
  }

  func testUnreadableListIsPreserved() throws {
    try FileManager.default.createDirectory(at: storage, withIntermediateDirectories: true)
    let file = storage.appending(path: "Tasks.json")
    let unreadable = Data("invalid JSON".utf8)
    try unreadable.write(to: file)

    launch()
    XCTAssertTrue(app.staticTexts["Couldn’t Open Tasks"].waitForExistence(timeout: 5))
    app.typeKey("n", modifierFlags: .command)
    XCTAssertFalse(app.textFields["task-title"].exists)
    XCTAssertEqual(try Data(contentsOf: file), unreadable)
  }

  private func selectLastTaskWithKeyboard() {
    for _ in 0..<3 {
      app.typeKey(.downArrow, modifierFlags: [])
    }
  }

  private func assertInlineRename() {
    app.typeKey("r", modifierFlags: .command)
    let rename = app.textFields["rename-title"]
    XCTAssertTrue(rename.waitForExistence(timeout: 5))
    XCTAssertEqual(rename.value as? String, "Plan the week")
    XCTAssertFalse(app.textFields["task-title"].exists)
    app.typeKey("a", modifierFlags: .command)
    app.typeText("Discard this")
    app.typeKey(.escape, modifierFlags: [])
    XCTAssertTrue(rename.waitForNonExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Plan the week"].exists)

    app.typeKey("r", modifierFlags: .command)
    XCTAssertTrue(rename.waitForExistence(timeout: 5))
    app.typeKey("a", modifierFlags: .command)
    app.typeText("Plan next week")
    app.typeKey(.return, modifierFlags: [])
    XCTAssertTrue(rename.waitForNonExistence(timeout: 5))
  }

  private func add(_ name: String) {
    app.typeKey("n", modifierFlags: .command)
    let title = app.textFields["task-title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    XCTAssertFalse(app.sheets.firstMatch.exists)
    app.typeText(name)
    XCTAssertEqual(title.value as? String, name)
    app.typeKey(.return, modifierFlags: [])
    XCTAssertTrue(title.waitForNonExistence(timeout: 5))
    XCTAssertTrue(
      app.staticTexts[name.trimmingCharacters(in: .whitespaces)].waitForExistence(timeout: 5))
  }

  private func assertOrder(_ titles: [String], file: StaticString = #filePath, line: UInt = #line) {
    var previousY = -CGFloat.infinity
    for title in titles {
      let label = app.staticTexts[title]
      XCTAssertTrue(label.waitForExistence(timeout: 5), file: file, line: line)
      let currentY = label.frame.midY
      XCTAssertGreaterThan(
        currentY, previousY, "Unexpected position for \(title)", file: file, line: line)
      previousY = currentY
    }
  }

}
