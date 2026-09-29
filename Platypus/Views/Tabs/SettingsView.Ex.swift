//
//  SettingsView.swift
//  Platypus
//
//  Created by Yann Bernard on 29.09.26.
//

import SwiftUI

struct Medication: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var dose: String
    var time: Date
    var isTaken = false
}

struct SettingsViewEx: View {
    @State private var meds: [Medication] = [
        .init(name: "Metformin", dose: "500 milligrams", time: .now),
        .init(
            name: "Vitamin D",
            dose: "1 tablet",
            time: .now.addingTimeInterval(3600)
        ),
        .init(
            name: "Ibuprofen",
            dose: "200 milligrams",
            time: .now.addingTimeInterval(7200)
        ),
    ]
    @State private var glasses = 3
    @State private var showAdd = false

    @AccessibilityFocusState private var focusedID: UUID?
    @Namespace private var rotorNS
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    private var takenCount: Int { meds.filter(\.isTaken).count }

    var body: some View {
        NavigationStack {
            List {
                summarySection
                medicationSection
                waterSection
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAdd = true
                    } label: {
                        Label("Add medication", systemImage: "plus")
                    }
                    .labelStyle(.iconOnly)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityHint("Opens a form")
                }
            }
            .sheet(isPresented: $showAdd) {
                AddMedicationView { new in
                    meds.append(new)
                    // Move VoiceOver to the new row once the sheet closes
                    Task {
                        try? await Task.sleep(for: .milliseconds(600))
                        focusedID = new.id
                    }
                    AccessibilityNotification.Announcement("\(new.name) added")
                        .post()
                }
            }
            // Magic Tap (two-finger double-tap): mark next dose as taken
            .accessibilityAction(.magicTap) {
                if let i = meds.firstIndex(where: { !$0.isTaken }) {
                    toggle(at: i)
                }
            }
            .accessibilityRotor("Doses not yet taken") {
                ForEach(meds.filter { !$0.isTaken }) { med in
                    AccessibilityRotorEntry(
                        Text(verbatim: med.name),
                        id: med.id,
                        in: rotorNS
                    )
                }
            }
            .sensoryFeedback(.success, trigger: takenCount)
        }
    }

    // MARK: Summary
    private var summarySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Daily progress").font(.headline)
                ProgressView(
                    value: Double(takenCount),
                    total: Double(max(meds.count, 1))
                )
                Text("\(takenCount) of \(meds.count) taken").font(.subheadline)
            }
            // One clear stop instead of three
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Daily progress")
            .accessibilityValue("\(takenCount) of \(meds.count) doses taken")
        }
    }

    // MARK: Medications
    private var medicationSection: some View {
        Section {
            ForEach(meds) { med in
                MedicationRow(med: med, stacked: typeSize.isAccessibilitySize)
                    .accessibilityRotorEntry(id: med.id, in: rotorNS)
                    .accessibilityFocused($focusedID, equals: med.id)
                    .accessibilityAction(
                        named: med.isTaken
                            ? "Mark as not taken" : "Mark as taken"
                    ) {
                        if let i = meds.firstIndex(of: med) { toggle(at: i) }
                    }
                    .accessibilityAction(named: "Delete") { delete(med) }
                    .swipeActions {  // visual equivalent of the custom action
                        Button("Delete", role: .destructive) { delete(med) }
                    }
                    .onTapGesture {
                        if let i = meds.firstIndex(of: med) { toggle(at: i) }
                    }
            }
        } header: {
            Text("Medications")
                .accessibilityAddTraits(.isHeader)
                .accessibilityHeading(.h2)
        }
    }

    // MARK: Water counter
    private var waterSection: some View {
        Section {
            HStack(spacing: 16) {
                Image(systemName: "drop.fill").accessibilityHidden(true)
                Text("\(glasses) glasses").font(.title3.monospacedDigit())
                Spacer()
                Button {
                    adjust(-1)
                } label: {
                    Image(systemName: "minus.circle")
                }
                Button {
                    adjust(+1)
                } label: {
                    Image(systemName: "plus.circle")
                }
            }
            .buttonStyle(.borderless)
            .font(.title2)
            // A custom control becomes a native adjustable element:
            // swipe up/down changes the value.
            .accessibilityRepresentation {
                Stepper("Water intake", value: $glasses, in: 0...12)
                    .accessibilityValue("\(glasses) glasses")
            }
        } header: {
            Text("Water")
                .accessibilityAddTraits(.isHeader)
                .accessibilityHeading(.h2)
        }
    }

    // MARK: Actions
    private func toggle(at i: Int) {
        withAnimation(reduceMotion ? nil : .spring) { meds[i].isTaken.toggle() }
        let m = meds[i]
        AccessibilityNotification.Announcement(
            m.isTaken
                ? "\(m.name) marked as taken" : "\(m.name) marked as not taken"
        ).post()
    }

    private func delete(_ med: Medication) {
        meds.removeAll { $0.id == med.id }
        AccessibilityNotification.Announcement("\(med.name) deleted").post()
    }

    private func adjust(_ d: Int) { glasses = min(12, max(0, glasses + d)) }
}

// MARK: - Row
struct MedicationRow: View {
    let med: Medication
    let stacked: Bool  // stack vertically at accessibility text sizes
    @ScaledMetric(relativeTo: .title) private var iconSize = 28

    var body: some View {
        let layout =
            stacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 12))
        layout {
            // Shape (not just color) shows state
            Image(systemName: med.isTaken ? "checkmark.circle.fill" : "circle")
                .font(.system(size: iconSize))
                .foregroundStyle(med.isTaken ? Color.green : Color.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text(med.name).font(.headline)
                Text(med.dose).font(.subheadline)
                Text(med.time, style: .time).font(.subheadline)
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(med.name), \(med.dose)")
        .accessibilityValue(
            "\(med.isTaken ? "Taken" : "Not yet taken"), scheduled \(med.time.formatted(date: .omitted, time: .shortened))"
        )
        .accessibilityHint(
            med.isTaken ? "Double-tap to undo" : "Double-tap to mark as taken"
        )
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Add form
struct AddMedicationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var dose = ""
    @State private var time = Date()
    let onSave: (Medication) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Medication name", text: $name)
                    .textContentType(.none)
                TextField("Dose, for example 500 milligrams", text: $dose)
                DatePicker(
                    "Time",
                    selection: $time,
                    displayedComponents: .hourAndMinute
                )
            }
            .navigationTitle("New medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(.init(name: name, dose: dose, time: time))
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
