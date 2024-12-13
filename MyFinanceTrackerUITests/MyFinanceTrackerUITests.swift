import XCTest

final class MyFinanceTrackerUITests: XCTestCase {
    
    // MARK: - Constants
    private let daysOfWeek = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    
    private var app: XCUIApplication!
    
    // MARK: - Setup and Teardown
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app.terminate()
        try super.tearDownWithError()
    }
    
    // MARK: - Helper Methods
    
    private func enterText(in field: XCUIElement, text: String) {
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Text field \(field.identifier) should exist")
        field.tap()
        field.typeText(text)
    }
    
    private func clearAndEnterText(in field: XCUIElement, text: String) {
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Text field \(field.identifier) should exist")
        field.tap()
        field.clearText()
        field.typeText(text)
    }
    
    private func selectPickerValue(pickerIdentifier: String, value: String) {
        let pickerWheel = app.pickers[pickerIdentifier].pickerWheels.firstMatch
        XCTAssertTrue(pickerWheel.waitForExistence(timeout: 5), "Picker wheel for \(pickerIdentifier) should exist")
        pickerWheel.adjust(toPickerWheelValue: value)
    }
    
    private func selectSegmentedControlOption(segmentedControlIdentifier: String, option: String) {
        let segmentedControl = app.segmentedControls[segmentedControlIdentifier]
        XCTAssertTrue(segmentedControl.waitForExistence(timeout: 5), "Segmented control '\(segmentedControlIdentifier)' should exist.")
        
        let segmentButton = segmentedControl.buttons[option]
        XCTAssertTrue(segmentButton.exists, "The '\(option)' segment should exist in segmented control '\(segmentedControlIdentifier)'.")
        
        if !segmentButton.isSelected {
            segmentButton.tap()
        }
    }
    
    private func tapTab(named name: String) {
        let tabButton = app.buttons[name]
        XCTAssertTrue(tabButton.waitForExistence(timeout: 5), "Tab '\(name)' should exist.")
        tabButton.tap()
    }
    
    private func readDisplayedDayOnNetIncomeView() -> String {
        let currentDayElement = app.staticTexts["selectedDay"]
        XCTAssertTrue(currentDayElement.waitForExistence(timeout: 5), "The current day element should exist but was not found.")
        return currentDayElement.label
    }
    
    private func swipeToDay(targetDay: String) {
        tapTab(named: "Net Income")
        XCTAssertTrue(daysOfWeek.contains(targetDay), "Invalid day: \(targetDay)")
        let displayedDay = readDisplayedDayOnNetIncomeView()
        XCTAssertTrue(daysOfWeek.contains(displayedDay), "Current day is invalid: \(displayedDay)")
        
        guard let targetIndex = daysOfWeek.firstIndex(of: targetDay),
              let currentIndex = daysOfWeek.firstIndex(of: displayedDay) else {
            XCTFail("Failed to determine indices for days.")
            return
        }
        
        let isSwipeLeft = targetIndex > currentIndex
        let swipeCount = min(abs(targetIndex - currentIndex), daysOfWeek.count)
        
        for _ in 0..<swipeCount {
            isSwipeLeft ? app.swipeLeft() : app.swipeRight()
            if readDisplayedDayOnNetIncomeView() == targetDay {
                break
            }
        }
        
        XCTAssertEqual(readDisplayedDayOnNetIncomeView(), targetDay, "Failed to swipe to day \(targetDay).")
    }
    
    private func addTransaction(isIncome: Bool, description: String, amount: String, dayOfWeek: String) {
        let type = isIncome ? "Income" : "Expense"
        tapTab(named: "Net Income")
        
        let addButton = app.buttons["add\(type)Button"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add \(type) button should exist.")
        addButton.tap()
        
        XCTAssertTrue(app.staticTexts["Add \(type)"].waitForExistence(timeout: 5), "The 'Add \(type)' view should be presented")
        
        selectPickerValue(pickerIdentifier: "AddTransaction_DayPicker", value: dayOfWeek)
        enterText(in: app.textFields["descriptionField"], text: description)
        enterText(in: app.textFields["amountField"], text: amount)
        
        let saveButton = app.buttons["saveButton"]
        XCTAssertTrue(saveButton.isEnabled, "Save button should be enabled after valid entries.")
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Save button should exist.")
        saveButton.tap()
    }
    
    private func verifyAndGetTransactionRow(isIncome: Bool, description: String, amount: String, dayOfWeek: String) -> XCUIElement? {
        let type = isIncome ? "Income" : "Expense"
        tapTab(named: "Net Income")
        swipeToDay(targetDay: dayOfWeek)
        
        let transactionList = app.collectionViews["transactionListView"]
        XCTAssertTrue(transactionList.waitForExistence(timeout: 5), "Transaction list should exist.")
        let noTransactionsText = "No transactions for \(dayOfWeek)."
        
        if app.staticTexts[noTransactionsText].exists {
            return nil
        }
        
        XCTAssertTrue(transactionList.cells.count > 0, "There should be at least one transaction.")
        
        // Validate and format the expected amount
        guard let amountDouble = Double(amount) else {
            XCTFail("Invalid amount format: \(amount)")
            return nil
        }
        let expectedAmount = String(format: "$%.2f", type == "Expense" ? -amountDouble : amountDouble)
        
        // Iterate through each transaction cell to find a matching transaction
        for index in 0..<transactionList.cells.count {
            let cell = transactionList.cells.element(boundBy: index)
            
            if cell.staticTexts["transactionDescription"].exists &&
               cell.staticTexts["transactionType"].exists &&
               cell.staticTexts["transactionAmount"].exists {
                
                let cellDescription = cell.staticTexts["transactionDescription"].label
                let cellType = cell.staticTexts["transactionType"].label
                let cellAmount = cell.staticTexts["transactionAmount"].label
                
                if cellDescription == description &&
                   cellType == type &&
                   cellAmount == expectedAmount {
                    XCTAssertTrue(cell.exists, "The expected transaction cell was not found.")
                    return cell
                }
            }
        }
        return nil
    }
    
    private func editTransaction(
        currentIsIncome: Bool,
        currentDescription: String,
        currentAmount: String,
        currentDayOfWeek: String,
        newIsIncome: Bool,
        newDescription: String,
        newAmount: String,
        newDayOfWeek: String
    ) {
        let newType = newIsIncome ? "Income" : "Expense"
        tapTab(named: "Net Income")
        
        // Verify and tap the transaction cell
        guard let transactionCell = verifyAndGetTransactionRow(
            isIncome: currentIsIncome,
            description: currentDescription,
            amount: currentAmount,
            dayOfWeek: currentDayOfWeek
        ) else {
            XCTFail("Failed to find the transaction cell for '\(currentDescription)'.")
            return
        }
        
        XCTAssertTrue(transactionCell.exists, "The transaction cell for '\(currentDescription)' should exist.")
        transactionCell.tap()
        
        // Update form fields with new values
        clearAndEnterText(in: app.textFields["descriptionField"], text: newDescription)
        clearAndEnterText(in: app.textFields["amountField"], text: newAmount)
        selectPickerValue(pickerIdentifier: "EditTransaction_DayPicker", value: newDayOfWeek)
        selectSegmentedControlOption(segmentedControlIdentifier: "editTransactionTypePicker", option: newType)
        
        // Verify and tap the Save button
        let saveButton = app.buttons["saveButton"]
        XCTAssertTrue(saveButton.isEnabled, "Save button should be enabled in the edit view.")
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Save button should exist in the edit view.")
        saveButton.tap()
    }
    
    private func deleteTransaction(isIncome: Bool, description: String, amount: String, dayOfWeek: String) {
        tapTab(named: "Net Income")
        
        // Verify and tap the transaction cell
        guard let transactionCell = verifyAndGetTransactionRow(
            isIncome: isIncome,
            description: description,
            amount: amount,
            dayOfWeek: dayOfWeek
        ) else {
            XCTFail("Failed to find the transaction cell for '\(description)'.")
            return
        }
        
        let deleteButton = transactionCell.descendants(matching: .button).matching(identifier: "deleteButton").firstMatch
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5), "Delete button should exist in the transaction cell.")
        deleteButton.tap()
        
        // Verify that the transaction has been deleted
        let deletedTransaction = verifyAndGetTransactionRow(isIncome: isIncome, description: description, amount: amount, dayOfWeek: dayOfWeek)
        XCTAssertNil(deletedTransaction, "Transaction '\(description)' should have been deleted.")
    }
    
    private func verifyNetIncome(expected: String) {
        let netIncome = app.buttons["netIncomeValue"]
        XCTAssertTrue(netIncome.exists, "Net income value should exist as a button.")
        XCTAssertEqual(netIncome.label, expected, "Net income should be \(expected)")
    }
    
    private func addCashFlowItem(isOwedToMe: Bool, name: String, amount: String) {
        let type = isOwedToMe ? "Owed to Me" : "I Owe"
        tapTab(named: "Cash Flow")
        
        let addButton = app.navigationBars["Cash Flow"].images["Add"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "The 'Add' button should exist in the navigation bar")
        addButton.tap()

        let addTypeButton = app.collectionViews.buttons["Add \(type)"]
        XCTAssertTrue(addTypeButton.waitForExistence(timeout: 5), "The 'Add \(type)' option should exist in the dropdown menu")
        addTypeButton.tap()

        XCTAssertTrue(app.staticTexts["Add Cash Flow Item"].waitForExistence(timeout: 5), "The 'Add Cash Flow Item' view should be presented")

        enterText(in: app.textFields["Enter name"], text: name)
        enterText(in: app.textFields["Enter amount"], text: amount)
        selectSegmentedControlOption(segmentedControlIdentifier: "cashFlowTypePicker", option: type)

        let saveButton = app.buttons["Save"]
        XCTAssertTrue(saveButton.isEnabled, "Save button should be enabled after valid entries.")
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "The 'Save' button should exist")
        saveButton.tap()
    }

    private func verifyAndGetCashFlowItemRow(isOwedToMe: Bool, name: String, amount: String) -> XCUIElement? {
        let type = isOwedToMe ? "Owed to Me" : "I Owe"
        tapTab(named: "Cash Flow")
        
        let cashFlowList = app.collectionViews["cashFlowListView"]
        XCTAssertTrue(cashFlowList.waitForExistence(timeout: 5), "Cash flow list should exist.")
        
        // Update the empty state messages based on the actual UI
        let noItemsText: String
        if type == "I Owe" {
            noItemsText = "You don't owe money to anyone."
        } else if type == "Owed to Me" {
            noItemsText = "No one owes you money."
        } else {
            noItemsText = ""
        }
        
        if !noItemsText.isEmpty && app.staticTexts[noItemsText].exists {
            return nil
        }
        
        XCTAssertTrue(cashFlowList.cells.count > 0, "There should be at least one cash flow item.")
        
        // Validate and format the expected amount
        guard let amountDouble = Double(amount) else {
            XCTFail("Invalid amount format: \(amount)")
            return nil
        }
        let expectedAmount = String(format: "$%.2f", type == "I Owe" ? -amountDouble : amountDouble)
        
        // Iterate through each cash flow cell to find a matching item
        for index in 0..<cashFlowList.cells.count {
            let cell = cashFlowList.cells.element(boundBy: index)
            
            if cell.staticTexts["cashFlowName"].exists &&
               cell.staticTexts["cashFlowType"].exists &&
               cell.staticTexts["cashFlowAmount"].exists {
                
                let cellName = cell.staticTexts["cashFlowName"].label
                let cellType = cell.staticTexts["cashFlowType"].label
                let cellAmount = cell.staticTexts["cashFlowAmount"].label
                
                if cellName == name &&
                   cellType == type &&
                   cellAmount == expectedAmount {
                    XCTAssertTrue(cell.exists, "The expected cash flow item cell was not found.")
                    return cell
                }
            }
        }
        return nil
    }

    private func editCashFlowItem(
        currentIsOwedToMe: Bool,
        currentName: String,
        currentAmount: String,
        newIsOwedToMe: Bool,
        newName: String,
        newAmount: String
    ) {
        let newType = newIsOwedToMe ? "Owed to Me" : "I Owe"
        tapTab(named: "Cash Flow")
        
        // Verify and tap the cash flow item cell
        guard let cashFlowCell = verifyAndGetCashFlowItemRow(
            isOwedToMe: currentIsOwedToMe,
            name: currentName,
            amount: currentAmount
        ) else {
            XCTFail("Failed to find the cash flow item cell for '\(currentName)'.")
            return
        }
        
        XCTAssertTrue(cashFlowCell.exists, "The cash flow item cell for '\(currentName)' should exist.")
        let nameElement = cashFlowCell.staticTexts["cashFlowName"]
        nameElement.tap()
        
        // Update form fields with new values
        clearAndEnterText(in: app.textFields["Enter name"], text: newName)
        clearAndEnterText(in: app.textFields["Enter amount"], text: newAmount)
        selectSegmentedControlOption(segmentedControlIdentifier: "cashFlowTypePicker", option: newType)
        
        // Verify and tap the Save Changes button
        let saveChangesButton = app.buttons["Save Changes"]
        XCTAssertTrue(saveChangesButton.isEnabled, "Save Changes button should be enabled in the edit view.")
        XCTAssertTrue(saveChangesButton.waitForExistence(timeout: 5), "Save Changes button should exist in the edit view.")
        saveChangesButton.tap()
    }

    private func deleteCashFlowItem(isOwedToMe: Bool, name: String, amount: String) {
        tapTab(named: "Cash Flow")
        
        // Verify and tap the cash flow item cell
        guard let cashFlowCell = verifyAndGetCashFlowItemRow(
            isOwedToMe: isOwedToMe,
            name: name,
            amount: amount
        ) else {
            XCTFail("Failed to find the cash flow item cell for '\(name)'.")
            return
        }
        
        XCTAssertTrue(cashFlowCell.exists, "The cash flow item cell for '\(name)' should exist.")
        
        // Swipe to reveal the delete button
        cashFlowCell.swipeLeft()
        
        let deleteButton = app.buttons["Delete"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5), "The 'Delete' button should exist after swiping left")
        deleteButton.tap()
        
        // Verify that the cash flow item has been deleted
        let deletedCashFlowItem = verifyAndGetCashFlowItemRow(isOwedToMe: isOwedToMe, name: name, amount: amount)
        XCTAssertNil(deletedCashFlowItem, "Cash flow item '\(name)' should have been deleted.")
    }
    
    private func addPredefinedTransaction(description: String, amount: String, day: String, isIncome: Bool) {
        let type = isIncome ? "Income" : "Expense"
        tapTab(named: "Settings")
        
        let addButton = app.buttons["AddPredefined_SectionHeader"]
        XCTAssertTrue(addButton.exists, "Add Predefined Transactions button should exist")
        addButton.tap()
        
        XCTAssertTrue(app.staticTexts["Add Predefined Transaction"].waitForExistence(timeout: 5), "The 'Add Predefined Transaction' view should be presented")
        
        enterText(in: app.textFields["AddPredefined_DescriptionTextField"], text: description)
        enterText(in: app.textFields["AddPredefined_AmountTextField"], text: amount)
        selectPickerValue(pickerIdentifier: "AddPredefined_DayPicker", value: day)
        selectSegmentedControlOption(segmentedControlIdentifier: "AddPredefined_TypePicker", option: type)
        
        let saveButton = app.buttons["AddPredefined_SaveButton"]
        XCTAssertTrue(saveButton.isEnabled, "Add Predefined Save button should be enabled")
        saveButton.tap()
    }
    
    private func editPredefinedTransaction(
        currentDescription: String,
        newDescription: String,
        newAmount: String,
        newDay: String,
        newIsIncome: Bool) {
        tapTab(named: "Settings")
        
        let transaction = app.staticTexts[currentDescription]
        XCTAssertTrue(transaction.exists, "Predefined Transaction '\(currentDescription)' should exist.")
        transaction.tap()
        
        clearAndEnterText(in: app.textFields["EditPredefined_DescriptionTextField"], text: newDescription)
        clearAndEnterText(in: app.textFields["EditPredefined_AmountTextField"], text: newAmount)
        selectPickerValue(pickerIdentifier: "EditPredefined_DayPicker", value: newDay)
        
        let typeButton = newIsIncome ? "Income" : "Expense"
        selectSegmentedControlOption(segmentedControlIdentifier: "EditPredefined_TypePicker", option: typeButton)
        
        let saveButton = app.buttons["EditPredefined_SaveButton"]
        XCTAssertTrue(saveButton.isEnabled, "Edit Predefined Save button should be enabled")
        saveButton.tap()
    }
    
    private func deletePredefinedTransaction(description: String) {
        tapTab(named: "Settings")
        
        let cell = app.cells.containing(.staticText, identifier: description).element
        XCTAssertTrue(cell.exists, "Predefined Transaction cell containing '\(description)' should exist before deletion.")
        
        cell.swipeLeft()
        
        XCTAssertTrue(app.buttons["Delete"].exists, "Delete button should appear after swiping left.")
        app.buttons["Delete"].tap()
        
        XCTAssertFalse(app.staticTexts[description].exists, "Predefined Transaction '\(description)' should be deleted.")
    }
    
    private func addQuickAddTransaction(description: String, amount: String, isIncome: Bool) {
        tapTab(named: "Settings")
        
        let addButton = app.buttons["AddQuickAdd_SectionHeader"]
        XCTAssertTrue(addButton.exists, "Add Quick Add Transactions button should exist")
        addButton.tap()
        
        enterText(in: app.textFields["AddQuickAdd_DescriptionTextField"], text: description)
        enterText(in: app.textFields["AddQuickAdd_AmountTextField"], text: amount)
        let typeButton = isIncome ? "Income" : "Expense"
        selectSegmentedControlOption(segmentedControlIdentifier: "AddQuickAdd_TypePicker", option: typeButton)
        
        let saveButton = app.buttons["AddQuickAdd_SaveButton"]
        XCTAssertTrue(saveButton.isEnabled, "Add Quick Add Save button should be enabled")
        saveButton.tap()
        
        XCTAssertTrue(app.staticTexts[description].waitForExistence(timeout: 5), "Added Quick Add Transaction should be visible in the list")
    }
    
    private func editQuickAddTransaction(originalDescription: String, newDescription: String, newAmount: String, newIsIncome: Bool) {
        tapTab(named: "Settings")
        
        let transaction = app.staticTexts[originalDescription]
        XCTAssertTrue(transaction.exists, "Quick Add Transaction '\(originalDescription)' should exist.")
        transaction.tap()
        
        clearAndEnterText(in: app.textFields["EditQuickAdd_DescriptionTextField"], text: newDescription)
        clearAndEnterText(in: app.textFields["EditQuickAdd_AmountTextField"], text: newAmount)
        let typeButton = newIsIncome ? "Income" : "Expense"
        selectSegmentedControlOption(segmentedControlIdentifier: "EditQuickAdd_TypePicker", option: typeButton)
        
        let saveButton = app.buttons["EditQuickAdd_SaveButton"]
        XCTAssertTrue(saveButton.isEnabled, "Edit Quick Add Save button should be enabled")
        saveButton.tap()
        
        XCTAssertTrue(app.staticTexts[newDescription].waitForExistence(timeout: 5), "Updated Quick Add Transaction should be visible in the list")
        XCTAssertTrue(app.staticTexts["$\(newAmount)"].exists, "Updated Quick Add Transaction amount should be $\(newAmount)")
        XCTAssertTrue(app.staticTexts[typeButton].exists, "Updated Quick Add Transaction type should be '\(typeButton)'")
    }
    
    private func deleteQuickAddTransaction(description: String) {
        tapTab(named: "Settings")
        
        let cell = app.cells.containing(.staticText, identifier: description).element
        XCTAssertTrue(cell.exists, "Quick Add Transaction cell containing '\(description)' should exist before deletion.")
        
        cell.swipeLeft()
        XCTAssertTrue(app.buttons["Delete"].exists, "Delete button should appear after swiping left.")
        app.buttons["Delete"].tap()
        
        XCTAssertFalse(app.staticTexts[description].exists, "Quick Add Transaction '\(description)' should be deleted.")
    }
    
    private func performReset() {
        tapTab(named: "Net Income")
        let resetButton = app.buttons["resetButton"]
        XCTAssertTrue(resetButton.exists, "Reset button should exist.")
        resetButton.tap()
        
        let confirmResetAlert = app.alerts["Confirm Reset"]
        XCTAssertTrue(confirmResetAlert.waitForExistence(timeout: 5), "Confirmation alert should appear after tapping reset.")
        
        let resetButtonOnAlert = confirmResetAlert.buttons["Reset"]
        XCTAssertTrue(resetButtonOnAlert.exists, "'Reset' button should exist on the confirmation alert.")
        resetButtonOnAlert.tap()
        
        let successAlert = app.alerts["Operation Successful"]
        XCTAssertTrue(successAlert.waitForExistence(timeout: 5), "Success alert should appear after resetting.")
        
        let okButton = successAlert.buttons["OK"]
        XCTAssertTrue(okButton.exists, "'OK' button should exist on the success alert.")
        okButton.tap()
    }
    
    private func performInitializeWeek() {
        tapTab(named: "Net Income")
        let initializeWeekButton = app.buttons["initializeWeekButton"]
        XCTAssertTrue(initializeWeekButton.exists, "Initialize Week button should exist.")
        initializeWeekButton.tap()
        
        let confirmInitializeWeekAlert = app.alerts["Confirm Initialize Week"]
        XCTAssertTrue(confirmInitializeWeekAlert.waitForExistence(timeout: 5), "Confirmation alert should appear after tapping Initialize Week.")
        
        let initializeButtonOnAlert = confirmInitializeWeekAlert.buttons["Initialize"]
        XCTAssertTrue(initializeButtonOnAlert.exists, "'Initialize' button should exist on the confirmation alert.")
        initializeButtonOnAlert.tap()
        
        let successAlert = app.alerts["Operation Successful"]
        XCTAssertTrue(successAlert.waitForExistence(timeout: 5), "Success alert should appear after resetting.")
        
        let okButton = successAlert.buttons["OK"]
        XCTAssertTrue(okButton.exists, "'OK' button should exist on the success alert.")
        okButton.tap()
    }
    
    // MARK: - Test Methods
    
    func testTabBarItemsExist() throws {
        ["Net Income", "Cash Flow", "Settings"].forEach {
            XCTAssertTrue(app.buttons[$0].exists, "The '\($0)' tab should exist.")
        }
    }
    
    func testSwitchingTabsAndElements() throws {
        XCTAssertTrue(app.staticTexts["Net Income:"].exists, "Net Income view should display 'Net Income:' label.")
        
        ["Cash Flow", "Settings", "Net Income"].forEach { tab in
            tapTab(named: tab)
            if tab == "Net Income" {
                XCTAssertTrue(app.staticTexts["Net Income:"].exists, "Net Income view should display 'Net Income:' label.")
            } else {
                XCTAssertTrue(app.navigationBars[tab].exists, "The '\(tab)' view should display a navigation bar titled '\(tab)'.")
            }
        }
    }

    func testAddEditAndDeleteTransaction() throws {
        addTransaction(isIncome: true, description: "Test Income", amount: "400", dayOfWeek: "Friday")
        verifyNetIncome(expected: "$400.00")
        editTransaction(
            currentIsIncome: true,
            currentDescription: "Test Income",
            currentAmount: "400",
            currentDayOfWeek: "Friday",
            newIsIncome: false,
            newDescription: "Updated Expense",
            newAmount: "500",
            newDayOfWeek: "Saturday"
        )
        verifyNetIncome(expected: "$-500.00")
        deleteTransaction(isIncome: false, description: "Updated Expense", amount: "500", dayOfWeek: "Saturday")
    }

    func testAddModifyAndDeleteMultipleTransactions() throws {
        addTransaction(isIncome: true, description: "Test Income 1", amount: "100", dayOfWeek: "Monday")
        verifyNetIncome(expected: "$100.00")
        addTransaction(isIncome: false, description: "Test Expense 1", amount: "50", dayOfWeek: "Monday")
        verifyNetIncome(expected: "$50.00")

        // Edit Income
        editTransaction(
            currentIsIncome: true,
            currentDescription: "Test Income 1",
            currentAmount: "100",
            currentDayOfWeek: "Monday",
            newIsIncome: true,
            newDescription: "Updated Income 1",
            newAmount: "150",
            newDayOfWeek: "Monday"
        )
        verifyNetIncome(expected: "$100.00")

        // Delete Expense
        deleteTransaction(isIncome: false, description: "Test Expense 1", amount: "50", dayOfWeek: "Monday")
        verifyNetIncome(expected: "$150.00")

        // Delete Income
        deleteTransaction(isIncome: true, description: "Updated Income 1", amount: "150", dayOfWeek: "Monday")
        verifyNetIncome(expected: "$0.00")
    }
    
    func testLandsOnCurrentDayWhenTappingNetIncomeTab() throws {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEEE"
        
        let today = formatter.string(from: Date())
        let displayedDay = readDisplayedDayOnNetIncomeView()
        XCTAssertEqual(displayedDay, today, "The displayed day on the Net Income view does not match today's day.")
    }
    
    func testAddEditDeleteCashFlowItem() throws {
        addCashFlowItem(isOwedToMe: true, name: "Freelance Project", amount: "1500.00")
        let addedItem = verifyAndGetCashFlowItemRow(isOwedToMe: true, name: "Freelance Project", amount: "1500.00")
        XCTAssertNotNil(addedItem, "Cash Flow Item should be present after addition.")
        
        editCashFlowItem(
            currentIsOwedToMe: true,
            currentName: "Freelance Project",
            currentAmount: "1500.00",
            newIsOwedToMe: false,
            newName: "Freelance Project Updated",
            newAmount: "1600.00"
        )
        
        let updatedItem = verifyAndGetCashFlowItemRow(isOwedToMe: false, name: "Freelance Project Updated", amount: "1600.00")
        XCTAssertNotNil(updatedItem, "Cash Flow Item should be updated and present in the list.")
        deleteCashFlowItem(isOwedToMe: false, name: "Freelance Project Updated", amount: "1600.00")
        let deletedItem = verifyAndGetCashFlowItemRow(isOwedToMe: false, name: "Freelance Project Updated", amount: "1600.00")
        XCTAssertNil(deletedItem, "Cash Flow Item should be deleted and no longer present in the list.")
    }
    
    func testPredefinedTransactionAddEditDelete() throws {
        addPredefinedTransaction(description: "Test Predefined Transaction", amount: "150.75", day: "Wednesday", isIncome: true)
        editPredefinedTransaction(currentDescription: "Test Predefined Transaction",
                                  newDescription: "Updated Predefined Transaction",
                                  newAmount: "200.00",
                                  newDay: "Thursday",
                                  newIsIncome: false)
        deletePredefinedTransaction(description: "Updated Predefined Transaction")
    }
    
    func testQuickAddTransactionAddEditDelete() throws {
        addQuickAddTransaction(description: "Test Quick Add Transaction", amount: "200.00", isIncome: false)
        editQuickAddTransaction(originalDescription: "Test Quick Add Transaction",
                                newDescription: "Updated Quick Add Transaction",
                                newAmount: "250.00",
                                newIsIncome: true)
        deleteQuickAddTransaction(description: "Updated Quick Add Transaction")
    }
    
    func testResetButton() throws {
        addTransaction(isIncome: true, description: "Test Income", amount: "100", dayOfWeek: "Monday")
        verifyNetIncome(expected: "$100.00")
        performReset()
    }
    
    func testInitializeWeek() throws {
        verifyNetIncome(expected: "$0.00")
        addPredefinedTransaction(description: "Test Predefined Transaction", amount: "150.75", day: "Wednesday", isIncome: true)
        performInitializeWeek()
        verifyNetIncome(expected: "$150.75")
        let cell = verifyAndGetTransactionRow(isIncome: true, description: "Test Predefined Transaction", amount: "150.75", dayOfWeek: "Wednesday")
        performReset()
        deletePredefinedTransaction(description: "Test Predefined Transaction")
    }
    
    func testQuickAddTransactionReflectOnAddTransactionView() throws {
        addQuickAddTransaction(description: "Test Quick Add Transaction", amount: "100.00", isIncome: true)
        
        tapTab(named: "Net Income")
        let addButton = app.buttons["addIncomeButton"]
        addButton.tap()
        
        let quickAddButtonIdentifier = "quickAdd_Test Quick Add Transaction"
        let quickAddButton = app.buttons[quickAddButtonIdentifier]
        XCTAssertTrue(quickAddButton.exists, "Quick Add Transaction button with identifier \(quickAddButtonIdentifier) should exist")
        quickAddButton.tap()
        
        verifyNetIncome(expected: "$100.00")
        deleteQuickAddTransaction(description: "Test Quick Add Transaction")
        performReset()
    }
    
    func testAdjustNetIncome() throws {
        tapTab(named: "Net Income")
        
        let adjustNetIncomeLink = app.buttons["netIncomeValue"]
        XCTAssertTrue(adjustNetIncomeLink.exists, "Adjust Net Income link does not exist")
        adjustNetIncomeLink.tap()
        let adjustNetIncomeTitle = app.staticTexts["Adjust Net Income"]
        XCTAssertTrue(adjustNetIncomeTitle.exists, "Adjust Net Income view is not displayed")
        selectSegmentedControlOption(segmentedControlIdentifier: "operationPicker", option: "Add")
        let amountField = app.textFields["adjustAmountField"]
                enterText(in: amountField, text: "500.00")
        
        let confirmButton = app.buttons["confirmButton"]
        XCTAssertTrue(confirmButton.exists, "Confirm button does not exist")
        confirmButton.tap()
        
        verifyNetIncome(expected: "$500.00")
        performReset()
    }
    
    func testMarkTransactionComplete() throws {
        addTransaction(isIncome: true, description: "Test Income", amount: "400", dayOfWeek: "Friday")
        
        // Verify and tap the transaction cell
        guard let transactionCell = verifyAndGetTransactionRow(
            isIncome: true,
            description: "Test Income",
            amount: "400",
            dayOfWeek: "Friday"
        ) else {
            XCTFail("Failed to find the transaction cell for '\(description)'.")
            return
        }
        
        let tickButton = transactionCell.descendants(matching: .button).matching(identifier: "markCompleteButton").firstMatch
        XCTAssertTrue(tickButton.waitForExistence(timeout: 5), "Mark Complete button should exist in the transaction cell.")
        tickButton.tap()
        
        // Verify that the transaction has been deleted
        let deletedTransaction = verifyAndGetTransactionRow(isIncome: true, description: "Test Income", amount: "400", dayOfWeek: "Friday")
        XCTAssertNil(deletedTransaction, "Transaction '\(description)' should have been deleted.")
        
        verifyNetIncome(expected: "$400.00")
        performReset()
    }
}

extension XCUIElement {
    func clearText() {
        guard let stringValue = self.value as? String else {
            XCTFail("Cannot clear text because it is not a string.")
            return
        }
        
        let deleteString = stringValue.map { _ in "\u{8}" }.joined()
        self.typeText(deleteString)
    }
}
