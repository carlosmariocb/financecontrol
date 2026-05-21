import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Backup + restore + CSV export. Writes a temporary file in the app's tmp directory
/// and hands it to the system share sheet (`.fileExporter`).
///
/// Restore is destructive: the entire store is wiped before the snapshot is inserted.
/// We gate it behind an explicit confirmation dialog.
struct BackupView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var jsonExportDocument: JSONDocument?
    @State private var csvExportDocument: CSVDocument?
    @State private var showRestorePicker: Bool = false
    @State private var pendingRestore: BackupService.Snapshot?
    @State private var showRestoreConfirm: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Button {
                    exportJSON()
                } label: {
                    Label("Exportar respaldo (JSON)", systemImage: "square.and.arrow.up")
                }
                Button {
                    exportCSV()
                } label: {
                    Label("Exportar movimientos (CSV)", systemImage: "tablecells")
                }
            } header: {
                Text("Exportar")
            } footer: {
                Text("El respaldo JSON contiene todos tus datos. Guárdalo en iCloud Drive o un servicio seguro.")
            }

            Section {
                Button {
                    showRestorePicker = true
                } label: {
                    Label("Restaurar desde JSON", systemImage: "square.and.arrow.down")
                }
            } header: {
                Text("Restaurar")
            } footer: {
                Text("Reemplaza todos los datos actuales por los del archivo. Esta acción no se puede deshacer.")
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }
        }
        .navigationTitle("Respaldo")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .fileExporter(
            isPresented: Binding(
                get: { jsonExportDocument != nil },
                set: { if !$0 { jsonExportDocument = nil } }
            ),
            document: jsonExportDocument,
            contentType: .json,
            defaultFilename: "control-financiero-respaldo"
        ) { _ in jsonExportDocument = nil }
        .fileExporter(
            isPresented: Binding(
                get: { csvExportDocument != nil },
                set: { if !$0 { csvExportDocument = nil } }
            ),
            document: csvExportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: "control-financiero-movimientos"
        ) { _ in csvExportDocument = nil }
        .fileImporter(
            isPresented: $showRestorePicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handlePickedRestoreFile(result)
        }
        .confirmationDialog(
            "¿Restaurar y reemplazar todo?",
            isPresented: $showRestoreConfirm,
            titleVisibility: .visible
        ) {
            Button("Restaurar", role: .destructive) { commitRestore() }
            Button("Cancelar", role: .cancel) { pendingRestore = nil }
        } message: {
            if let snapshot = pendingRestore {
                Text("Respaldo del \(snapshot.exportedAt.formatted(date: .abbreviated, time: .shortened)). Reemplaza \(snapshot.transactions.count) movimientos.")
            }
        }
    }

    // MARK: - Export

    private func exportJSON() {
        errorMessage = nil
        do {
            let snapshot = try BackupService.snapshot(from: modelContext)
            let data = try BackupService.jsonData(from: snapshot)
            jsonExportDocument = JSONDocument(data: data)
        } catch {
            errorMessage = String(localized: "No se pudo generar el respaldo.")
        }
    }

    private func exportCSV() {
        errorMessage = nil
        do {
            let transactions = try modelContext.fetch(FetchDescriptor<Transaction>())
            let csv = CSVExportService.csv(for: transactions)
            csvExportDocument = CSVDocument(text: csv)
        } catch {
            errorMessage = String(localized: "No se pudo generar el CSV.")
        }
    }

    // MARK: - Restore

    private func handlePickedRestoreFile(_ result: Result<[URL], Error>) {
        errorMessage = nil
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }
            // Picked documents need security scoping on iOS to be readable.
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            pendingRestore = try BackupService.snapshot(from: data)
            showRestoreConfirm = true
        } catch {
            errorMessage = String(localized: "No se pudo leer el archivo de respaldo.")
        }
    }

    private func commitRestore() {
        guard let snapshot = pendingRestore else { return }
        do {
            try BackupService.restore(snapshot, into: modelContext)
            pendingRestore = nil
        } catch {
            errorMessage = String(localized: "La restauración falló a la mitad. Algunos datos pueden estar incompletos.")
        }
    }
}

// MARK: - FileDocument wrappers

private struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    let text: String
    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws {
        let data = configuration.file.regularFileContents ?? Data()
        text = String(data: data, encoding: .utf8) ?? ""
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
