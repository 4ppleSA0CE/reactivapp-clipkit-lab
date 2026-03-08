import SwiftUI
import PhotosUI
import UIKit

// MARK: - Camera capture (UIKit wrapper)

private struct CameraImagePicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    var onCapture: (Data, UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraImagePicker

        init(_ parent: CameraImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage,
               let data = image.jpegData(compressionQuality: 0.85) {
                parent.onCapture(data, image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

struct ReparoClipExperience: ClipExperience {
    static let urlPattern = "example.com/reparo/repair"
    static let clipName = "Reparo"
    static let clipDescription = "Snap a photo of something broken. Get a repair summary, cost estimate, and links to buy parts and tools."
    static let teamName = "Reparo"
    static let touchpoint: JourneyTouchpoint = .utility
    static let invocationSource: InvocationSource = .qrCode

    let context: ClipContext

    private enum FlowStep: Equatable {
        case welcome
        case upload
        case analyzing
        case results(RepairResult)
        case checkout(RepairResult)
        case orderConfirmed
        case error(String)

        static func == (lhs: FlowStep, rhs: FlowStep) -> Bool {
            switch (lhs, rhs) {
            case (.welcome, .welcome), (.upload, .upload), (.analyzing, .analyzing),
                 (.orderConfirmed, .orderConfirmed):
                return true
            case (.results, .results), (.checkout, .checkout), (.error, .error):
                return true
            default:
                return false
            }
        }
    }

    @State private var step: FlowStep = .welcome
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var selectedImage: Image?
    @State private var lastImageData: Data?
    @State private var showCamera = false
    @State private var cartItems: [CheckoutItem] = []
    @State private var checkedRepairStepIndices: Set<Int> = []

    var body: some View {
        ZStack {
            ClipBackground()

            ScrollView {
                VStack(spacing: 20) {
                    switch step {
                    case .welcome:
                        welcomeView
                    case .upload:
                        uploadView
                    case .analyzing:
                        analyzingView
                    case .results(let result):
                        resultsView(result)
                    case .checkout(let result):
                        checkoutView(result)
                    case .orderConfirmed:
                        orderConfirmedView
                    case .error(let message):
                        errorView(message)
                    }
                }
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .animation(.spring(duration: 0.35), value: step)
        .fullScreenCover(isPresented: $showCamera) {
            CameraImagePicker { data, uiImage in
                selectedImageData = data
                selectedImage = Image(uiImage: uiImage)
                selectedItem = nil
            }
        }
    }

    // MARK: - Welcome

    @ViewBuilder
    private var welcomeView: some View {
        ClipHeader(
            title: "Fix it yourself.",
            subtitle: "Snap a photo of something broken. Get a repair summary, cost estimate, and direct links to buy parts and tools.",
            systemImage: "wrench.and.screwdriver"
        )
        .padding(.top, 40)

        VStack(spacing: 16) {
            howItWorksRow(number: "1", title: "Upload a photo", detail: "Chair, phone, appliance — anything that needs a repair.")
            howItWorksRow(number: "2", title: "Get your report", detail: "Repairability, estimated cost, and a short description.")
            howItWorksRow(number: "3", title: "Find parts & tools", detail: "One-click links to search or buy what you need.")
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)

        ClipActionButton(title: "Start a repair", icon: "camera.fill") {
            step = .upload
        }
        .padding(.top, 8)

        Text("Images are analyzed by AI and are not stored.\nAdvice is for informational purposes only.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
    }

    private func howItWorksRow(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(.ultraThinMaterial, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Upload

    @ViewBuilder
    private var uploadView: some View {
        ClipHeader(
            title: "Upload a photo",
            subtitle: "Take a picture or choose from your library",
            systemImage: "photo.badge.plus"
        )
        .padding(.top, 24)

        PhotosPicker(selection: $selectedItem, matching: .images) {
            Group {
                if let selectedImage {
                    selectedImage
                        .resizable()
                        .scaledToFill()
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 40, weight: .thin))
                            .foregroundStyle(.secondary)
                        Text("Tap to choose from library")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .padding(.horizontal, 24)
        .onChange(of: selectedItem) { _, newItem in
            loadImage(from: newItem)
        }

        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            HStack(spacing: 12) {
                Button {
                    showCamera = true
                } label: {
                    Label("Take photo", systemImage: "camera.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
        }


        ClipActionButton(title: "Analyze repair", icon: "magnifyingglass") {
            guard let data = selectedImageData else { return }
            lastImageData = data
            step = .analyzing
        }
        .opacity(selectedImageData == nil ? 0.4 : 1.0)
        .disabled(selectedImageData == nil)

        Button {
            step = .welcome
        } label: {
            Text("← Back")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private func loadImage(from item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let transferable = try? await item.loadTransferable(type: PickedImage.self) {
                selectedImageData = transferable.data
                selectedImage = Image(uiImage: transferable.uiImage)
            }
        }
    }

    // MARK: - Analyzing

    @ViewBuilder
    private var analyzingView: some View {
        Spacer().frame(height: 80)

        VStack(spacing: 20) {
            ProgressView()
                .controlSize(.large)
            Text("Analyzing your photo…")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.secondary)
            Text("This may take a few seconds")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 60)
        .task {
            await runAnalysis()
        }
    }

    private func runAnalysis() async {
        guard let data = lastImageData ?? selectedImageData else {
            step = .error("No image data available.")
            return
        }

        let mime: String
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            mime = "image/png"
        } else if data.count >= 4, data[0] == 0x52, data[1] == 0x49 {
            mime = "image/webp"
        } else {
            mime = "image/jpeg"
        }

        do {
            let result = try await ReparoAPIService.analyze(imageData: data, mimeType: mime)
            step = .results(result)
        } catch {
            step = .error(error.localizedDescription)
        }
    }

    // MARK: - Results

    @ViewBuilder
    private func resultsView(_ r: RepairResult) -> some View {
        resultHeader(r)
            .padding(.top, 16)

        if let desc = r.brief_description, !desc.isEmpty {
            Text(desc)
                .font(.system(size: 15))
                .foregroundStyle(.primary)
                .padding(.horizontal, 24)
        }

        if r.repairability?.lowercased() == "low" {
            lowRepairabilityNote
        }

        if let steps = r.repair_steps, !steps.isEmpty {
            repairStepsSection(steps)
        }

        partsAndToolsLists(r)

        productLinksSection(r.products)

        Text("⚠️ Repair at your own risk. Seek professional help when in doubt.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.top, 4)

        ClipActionButton(title: "Checkout — Buy parts & tools", icon: "cart.fill") {
            cartItems = CheckoutItem.buildCart(from: r)
            step = .checkout(r)
        }
        .padding(.top, 8)

        ClipActionButton(title: "Analyze another", icon: "arrow.clockwise", style: .secondary) {
            resetForNewAnalysis()
        }
    }

    @ViewBuilder
    private func resultHeader(_ r: RepairResult) -> some View {
        GlassEffectContainer {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    badge(label: "Repairability", value: r.repairability, colorFor: repairabilityColor)
                    badge(label: "Difficulty", value: r.difficulty, colorFor: difficultyColor)
                }

                HStack(spacing: 16) {
                    if let cost = r.estimated_cost_usd {
                        Label("$\(String(format: "%.0f", cost))", systemImage: "dollarsign.circle")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    if let time = r.estimated_time, !time.isEmpty {
                        Label(time, systemImage: "clock")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .padding(.horizontal, 24)
    }

    private func badge(label: String, value: String?, colorFor: (String) -> Color) -> some View {
        let display = value ?? "—"
        return HStack(spacing: 4) {
            Circle()
                .fill(colorFor(display.lowercased()))
                .frame(width: 8, height: 8)
            Text("\(label): \(display)")
                .font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private func repairabilityColor(_ value: String) -> Color {
        switch value {
        case "high": return .green
        case "medium": return .yellow
        case "low": return .red
        default: return .gray
        }
    }

    private func difficultyColor(_ value: String) -> Color {
        switch value {
        case "easy": return .green
        case "moderate": return .yellow
        case "hard", "difficult": return .orange
        case "expert": return .red
        default: return .gray
        }
    }

    private var lowRepairabilityNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.orange)
            Text("This item may not be easily repairable. Consider professional repair or replacement. If the image was unclear, try uploading a sharper photo.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 24)
    }

    // MARK: - Repair Steps

    @ViewBuilder
    private func repairStepsSection(_ steps: [String]) -> some View {
        RepairStepsView(steps: steps, checkedIndices: $checkedRepairStepIndices)
            .padding(.horizontal, 24)
    }

    // MARK: - Parts & Tools Lists

    @ViewBuilder
    private func partsAndToolsLists(_ r: RepairResult) -> some View {
        if let parts = r.parts_needed, !parts.isEmpty {
            inlineList(title: "Parts needed", items: parts, icon: "shippingbox")
        }
        if let tools = r.tools_needed, !tools.isEmpty {
            inlineList(title: "Tools needed", items: tools, icon: "wrench")
        }
    }

    private func inlineList(title: String, items: [String], icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .semibold))
            Text(items.joined(separator: ", "))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }

    // MARK: - Product Links

    @ViewBuilder
    private func productLinksSection(_ products: ProductLinks?) -> some View {
        if let products {
            if let parts = products.parts, !parts.isEmpty {
                productLinkGroup(title: "Parts to buy", items: parts)
            }
            if let tools = products.tools, !tools.isEmpty {
                productLinkGroup(title: "Tools to buy", items: tools)
            }
        }
    }

    private func productLinkGroup(title: String, items: [ProductLink]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 24)

            VStack(spacing: 6) {
                ForEach(items.filter { $0.url != nil }) { item in
                    if let urlString = item.url, let url = URL(string: urlString) {
                        Link(destination: url) {
                            HStack {
                                Text(item.title ?? "Product")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.blue)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Checkout

    @ViewBuilder
    private func checkoutView(_ r: RepairResult) -> some View {
        ClipHeader(
            title: "Checkout",
            subtitle: "\(cartItems.count) item\(cartItems.count == 1 ? "" : "s") in your cart",
            systemImage: "cart.fill"
        )
        .padding(.top, 16)

        VStack(spacing: 0) {
            ForEach(cartItems) { item in
                HStack(spacing: 12) {
                    Image(systemName: item.icon)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.system(size: 14, weight: .medium))
                            .lineLimit(1)
                        Text(item.category)
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    Text("$\(String(format: "%.2f", item.price))")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))

                    Button {
                        withAnimation(.spring(duration: 0.25)) {
                            cartItems.removeAll { $0.id == item.id }
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                if item.id != cartItems.last?.id {
                    Divider().padding(.leading, 56)
                }
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 24)

        if cartItems.isEmpty {
            Text("Your cart is empty")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .padding(.top, 12)
        }

        GlassEffectContainer {
            HStack {
                Text("Total")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Text("$\(String(format: "%.2f", cartItems.reduce(0) { $0 + $1.price }))")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
            }
            .padding(.vertical, 4)
        }
        .padding(.horizontal, 24)

        if !cartItems.isEmpty {
            VStack(spacing: 10) {
                checkoutPayButton(
                    label: "Pay with Credit / Debit",
                    icon: "creditcard.fill",
                    color: .blue
                )

                checkoutPayButton(
                    label: "Pay with Solana",
                    icon: "bitcoinsign.circle.fill",
                    color: Color(red: 0.58, green: 0.31, blue: 0.97)
                )

                checkoutPayButton(
                    label: "Pay with Shop Pay",
                    icon: "bag.fill",
                    color: Color(red: 0.35, green: 0.21, blue: 0.83)
                )
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)
        }

        Button {
            step = .results(r)
        } label: {
            Text("← Back to results")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    private func checkoutPayButton(label: String, icon: String, color: Color) -> some View {
        Button {
            step = .orderConfirmed
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Order Confirmed

    @ViewBuilder
    private var orderConfirmedView: some View {
        Spacer().frame(height: 60)

        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)

            Text("Order placed!")
                .font(.system(size: 24, weight: .bold))

            Text("Your parts and tools are on the way.\nYou'll receive a confirmation email shortly.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 40)

        ClipActionButton(title: "Start a new repair", icon: "wrench.and.screwdriver") {
            resetForNewAnalysis()
            step = .welcome
        }
        .padding(.top, 24)
    }

    // MARK: - Error

    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        Spacer().frame(height: 60)

        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44, weight: .thin))
                .foregroundStyle(.orange)

            Text("Something went wrong")
                .font(.system(size: 20, weight: .bold))

            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding(.top, 40)

        ClipActionButton(title: "Try again", icon: "arrow.clockwise") {
            step = .upload
        }

        Button {
            step = .welcome
        } label: {
            Text("← Start over")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private func resetForNewAnalysis() {
        selectedItem = nil
        selectedImageData = nil
        selectedImage = nil
        lastImageData = nil
        checkedRepairStepIndices = []
        step = .upload
    }
}

// MARK: - Repair Steps (collapsible, checkable)

private struct RepairStepsView: View {
    let steps: [String]
    @Binding var checkedIndices: Set<Int>
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.spring(duration: 0.25)) { expanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "list.clipboard")
                    Text(expanded ? "Hide instructions" : "Step-by-step instructions")
                        .font(.system(size: 14, weight: .semibold))
                    if !checkedIndices.isEmpty {
                        Text("(\(checkedIndices.count)/\(steps.count) done)")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }

            if expanded {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { idx, stepText in
                        Button {
                            var next = checkedIndices
                            if next.contains(idx) { next.remove(idx) } else { next.insert(idx) }
                            checkedIndices = next
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: checkedIndices.contains(idx) ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 18))
                                    .foregroundStyle(checkedIndices.contains(idx) ? .green : .secondary)
                                Text("\(idx + 1).")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 24, alignment: .trailing)
                                Text(stepText)
                                    .font(.system(size: 13))
                                    .strikethrough(checkedIndices.contains(idx))
                                    .foregroundStyle(checkedIndices.contains(idx) ? .secondary : .primary)
                                    .multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Photo Transferable

struct PickedImage: Transferable {
    let data: Data
    let uiImage: UIImage

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            guard let uiImage = UIImage(data: data) else {
                throw TransferError.importFailed
            }
            let jpeg = uiImage.jpegData(compressionQuality: 0.85) ?? data
            return PickedImage(data: jpeg, uiImage: uiImage)
        }
    }

    enum TransferError: Error { case importFailed }
}

// MARK: - Checkout Item

struct CheckoutItem: Identifiable {
    let id = UUID()
    let name: String
    let category: String
    let icon: String
    let price: Double

    static func buildCart(from result: RepairResult) -> [CheckoutItem] {
        let parts = result.parts_needed ?? []
        let tools = result.tools_needed ?? []
        let totalItems = parts.count + tools.count
        guard totalItems > 0 else { return [] }

        let budget = result.estimated_cost_usd ?? Double(totalItems) * 12.0
        let partsShare = parts.isEmpty ? 0.0 : 0.7
        let toolsShare = tools.isEmpty ? 0.0 : (parts.isEmpty ? 1.0 : 0.3)

        var items: [CheckoutItem] = []

        if !parts.isEmpty {
            let pool = budget * partsShare
            let prices = distribute(pool, count: parts.count)
            for (i, part) in parts.enumerated() {
                items.append(CheckoutItem(
                    name: part,
                    category: "Replacement part",
                    icon: "shippingbox",
                    price: prices[i]
                ))
            }
        }

        if !tools.isEmpty {
            let pool = budget * toolsShare
            let prices = distribute(pool, count: tools.count)
            for (i, tool) in tools.enumerated() {
                items.append(CheckoutItem(
                    name: tool,
                    category: "Tool",
                    icon: "wrench.and.screwdriver",
                    price: prices[i]
                ))
            }
        }

        let currentTotal = items.reduce(0) { $0 + $1.price }
        if let last = items.last, abs(currentTotal - budget) > 0.01 {
            let adjusted = last.price + (budget - currentTotal)
            items[items.count - 1] = CheckoutItem(
                name: last.name,
                category: last.category,
                icon: last.icon,
                price: (adjusted * 100).rounded() / 100
            )
        }

        return items
    }

    private static func distribute(_ total: Double, count: Int) -> [Double] {
        guard count > 0 else { return [] }
        let base = (total / Double(count) * 100).rounded() / 100
        return (0..<count).map { i in
            let variance = Double(i % 3 == 0 ? 1 : (i % 3 == 1 ? -1 : 0))
            let price = base + variance * (base * 0.15)
            return (price * 100).rounded() / 100
        }
    }
}

// MARK: - RepairResult Codable conformance for Equatable usage

extension RepairResult: Equatable {
    static func == (lhs: RepairResult, rhs: RepairResult) -> Bool {
        lhs.brief_description == rhs.brief_description
            && lhs.repairability == rhs.repairability
            && lhs.difficulty == rhs.difficulty
    }
}
