//
//  ContentView.swift
//  Platypus
//
//  Created by Yann Bernard on 07.08.26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    
    let fib = fibonacci(n: 11)
    let wow = greatAdd(a: 3, b: 10)

    var body: some View {
        NavigationViewWrapper {
            List {
                if items.isEmpty {
                    ContentUnavailableView(
                        "No Items",
                        systemImage: "tray",
                        description: Text("Tap + to create one. num: \(fib), great add: \(wow)")
                    )
                }

                ForEach(items) { item in
                    NavigationLink {
                        Text(
                            "Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))"
                        )
                        .navigationTitle("Item")
                    } label: {
                        Text(
                            item.timestamp,
                            format: Date.FormatStyle(date: .numeric, time: .standard)
                        )
                    }
                }
                .onDelete(perform: deleteItems)
            }
#if os(macOS)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
#endif
            .navigationTitle("Items")
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
#endif

                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

private struct NavigationViewWrapper<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
#if os(macOS)
        NavigationSplitView {
            content
        } detail: {
            Text("Select an item")
        }
#else
        NavigationStack {
            content
        }
#endif
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
