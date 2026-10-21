//
//  PlatypusUITests.swift
//  PlatypusUITests
//
//  Created by Yann Bernard on 07.08.26.
//

import XCTest

final class PlatypusUITests: XCTestCase {
    @MainActor
    func testLaunchShowsSettingsAndDefaultProfile() {
        let app = launchApp()

        XCTAssertTrue(
            app.navigationBars["Available Profiles"].waitForExistence(
                timeout: 10
            )
        )
        XCTAssertTrue(app.buttons["Edit Profile"].exists)
        XCTAssertTrue(app.tabBars.buttons["Settings"].isSelected)
        XCTAssertFalse(app.switches["Profile Profile"].isEnabled)
        XCTAssertFalse(app.buttons["Undo profile deletion"].isEnabled)
    }

    @MainActor
    func testAddAndActivateProfile() {
        let app = launchApp()
        app.buttons["Add profile"].tap()

        XCTAssertTrue(
            app.buttons["Edit Profile - 1"].waitForExistence(timeout: 5)
        )
        let original = app.switches["Profile Profile"]
        let added = app.switches["Profile Profile - 1"]
        XCTAssertTrue(added.isEnabled)
        added.tap()

        waitFor(original, keyPath: "enabled", toEqual: true)
        XCTAssertFalse(added.isEnabled)
        XCTAssertEqual(added.value as? String, "Active")
        XCTAssertEqual(original.value as? String, "Inactive")
    }

    @MainActor
    func testAddingProfilesCreatesUniqueNames() {
        let app = launchApp()
        app.buttons["Add profile"].tap()
        XCTAssertTrue(
            app.buttons["Edit Profile - 1"].waitForExistence(timeout: 5)
        )
        app.buttons["Add profile"].tap()

        XCTAssertTrue(
            app.buttons["Edit Profile - 2"].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.buttons["Edit Profile"].exists)
        XCTAssertEqual(profileSwitches(in: app).count, 3)
        XCTAssertEqual(
            app.switches["Profile Profile"].value as? String,
            "Active"
        )
        XCTAssertEqual(
            app.switches["Profile Profile - 1"].value as? String,
            "Inactive"
        )
        XCTAssertEqual(
            app.switches["Profile Profile - 2"].value as? String,
            "Inactive"
        )
    }

    @MainActor
    func testDeleteInactiveProfileKeepsCurrentProfile() {
        let app = launchApp()
        app.buttons["Add profile"].tap()
        XCTAssertTrue(
            app.buttons["Edit Profile - 1"].waitForExistence(timeout: 5)
        )

        deleteProfile(named: "Profile - 1", in: app)

        XCTAssertEqual(profileSwitches(in: app).count, 1)
        XCTAssertEqual(
            app.switches["Profile Profile"].value as? String,
            "Active"
        )
        XCTAssertFalse(app.switches["Profile Profile"].isEnabled)
        XCTAssertTrue(app.buttons["Undo profile deletion"].isEnabled)
    }

    @MainActor
    func testDeleteActiveProfileActivatesRemainingProfile() {
        let app = launchApp()
        app.buttons["Add profile"].tap()
        XCTAssertTrue(
            app.buttons["Edit Profile - 1"].waitForExistence(timeout: 5)
        )

        deleteProfile(named: "Profile", in: app)

        XCTAssertEqual(profileSwitches(in: app).count, 1)
        XCTAssertEqual(
            app.switches["Profile Profile - 1"].value as? String,
            "Active"
        )
        XCTAssertFalse(app.switches["Profile Profile - 1"].isEnabled)
    }

    @MainActor
    func testUndoDeletionRestoresProfileWithoutChangingActiveProfile() {
        let app = launchApp()
        app.buttons["Add profile"].tap()
        XCTAssertTrue(
            app.buttons["Edit Profile - 1"].waitForExistence(timeout: 5)
        )
        deleteProfile(named: "Profile", in: app)

        let undo = app.buttons["Undo profile deletion"]
        XCTAssertTrue(undo.isEnabled)
        undo.tap()

        XCTAssertTrue(app.buttons["Edit Profile"].waitForExistence(timeout: 5))
        XCTAssertEqual(profileSwitches(in: app).count, 2)
        XCTAssertEqual(
            app.switches["Profile Profile"].value as? String,
            "Inactive"
        )
        XCTAssertEqual(
            app.switches["Profile Profile - 1"].value as? String,
            "Active"
        )
        XCTAssertFalse(undo.isEnabled)
    }

    @MainActor
    func testLastProfileCannotBeDeleted() {
        let app = launchApp()
        let row = app.cells.containing(.button, identifier: "Edit Profile")
            .firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeLeft()

        XCTAssertTrue(
            app.textFields["Profile name"].waitForExistence(timeout: 5)
        )
    }

    @MainActor
    func testRenameProfile() {
        let app = launchApp()
        app.buttons["Edit Profile"].tap()
        renameProfile(in: app, to: "Walking")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        XCTAssertTrue(app.buttons["Edit Walking"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Edit Profile"].exists)
    }

    @MainActor
    func testDuplicateProfileNameIsRejected() {
        let app = launchApp()
        app.buttons["Add profile"].tap()
        let edit = app.buttons["Edit Profile - 1"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        renameProfile(in: app, to: "Profile")

        XCTAssertTrue(
            app.alerts["Profile already exists"].waitForExistence(timeout: 5)
        )
        app.alerts.buttons["OK"].tap()
        XCTAssertEqual(
            app.textFields["Profile name"].value as? String,
            "Profile - 1"
        )
    }

    @MainActor
    func testLocationSettingsCanBeEnabledAndDisabled() {
        let app = launchApp()
        app.buttons["Edit Profile"].tap()
        let toggle = app.switches["Enable Inside settings"]
        let edit = app.buttons["Edit Inside settings"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertFalse(edit.exists)

        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
            .tap()
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        XCTAssertTrue(
            app.navigationBars["Inside detection settings"].waitForExistence(
                timeout: 5
            )
        )
        app.navigationBars.buttons.element(boundBy: 0).tap()

        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
            .tap()
        waitFor(edit, keyPath: "exists", toEqual: false)
        XCTAssertTrue(app.buttons["Default detection settings"].exists)
    }

    @MainActor
    func testGermanProfileNavigation() {
        let app = launchApp(language: "de")

        XCTAssertTrue(
            app.navigationBars["Verfügbare Profile"].waitForExistence(
                timeout: 10
            )
        )
        XCTAssertTrue(app.tabBars.buttons["Einstellungen"].exists)
        app.buttons["Profile bearbeiten"].tap()
        XCTAssertTrue(app.textFields["Profilname"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.switches["Einstellungen für Drinnen aktivieren"].exists
        )
    }

    @MainActor
    private func launchApp(language: String = "en") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing", "-AppleLanguages", "(\(language))",
            "-AppleLocale", language == "de" ? "de_DE" : "en_GB",
        ]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        return app
    }

    @MainActor
    private func profileSwitches(in app: XCUIApplication) -> XCUIElementQuery {
        // SwiftUI also exposes an unlabeled native switch inside each labeled toggle.
        app.switches.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Profile ")
        )
    }

    @MainActor
    private func deleteProfile(named name: String, in app: XCUIApplication) {
        let edit = app.buttons["Edit \(name)"]
        let row = app.cells.containing(.button, identifier: "Edit \(name)")
            .firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        // A partial swipe reveals Delete without relying on full-swipe deletion.
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
            .press(
                forDuration: 0.1,
                thenDragTo:
                    row.coordinate(
                        withNormalizedOffset: CGVector(dx: 0.4, dy: 0.5)
                    )
            )
        let delete = app.buttons["Delete"].firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()
        waitFor(edit, keyPath: "exists", toEqual: false)
    }

    @MainActor
    private func renameProfile(in app: XCUIApplication, to name: String) {
        let field = app.textFields["Profile name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.press(forDuration: 1.2)
        let selectAll = app.menuItems["Select All"]
        if selectAll.waitForExistence(timeout: 2) {
            selectAll.tap()
        } else {
            let button = app.buttons["Select All"]
            XCTAssertTrue(button.waitForExistence(timeout: 3))
            button.tap()
        }
        field.typeText(name)
        XCTAssertEqual(
            field.value as? String,
            name,
            "Replace the entire profile name before submitting"
        )
        field.typeText("\n")
    }

    @MainActor
    private func waitFor(
        _ element: XCUIElement,
        keyPath: String,
        toEqual value: Bool
    ) {
        let predicate = NSPredicate(
            format: "%K == %@",
            keyPath,
            NSNumber(value: value)
        )
        let expectation = XCTNSPredicateExpectation(
            predicate: predicate,
            object: element
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: 5),
            .completed
        )
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.terminate()
            app.launch()
        }
    }
}
