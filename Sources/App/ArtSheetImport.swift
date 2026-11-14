import Console
import Editors
import JavaScriptEventLoop
import JavaScriptKit

nonisolated(unsafe) private let document = JSObject.global.document
nonisolated(unsafe) private let artView = JSObject.global.fesArtView
nonisolated(unsafe) private let importButton = document.getElementById("art-import")
nonisolated(unsafe) private let importInput = document.getElementById("art-import-file")
nonisolated(unsafe) private let report = document.getElementById("art-import-report")
nonisolated(unsafe) private let reportHeading = document.getElementById("art-import-report-heading")
nonisolated(unsafe) private let reportHint = document.getElementById("art-import-report-hint")
nonisolated(unsafe) private let reportImage = document.getElementById("art-import-report-image")
nonisolated(unsafe) private let reportProblems = document.getElementById("art-import-report-problems")

private let largestSheetFileBytes = 1 << 20
// 401 px is the sheet at zoom 3 (16 × 25 + 1), which still fits beside the problem list on an iPad mini in portrait.
private let reportSheetSide = 401

nonisolated(unsafe) private let importClicked = JSClosure { _ in
    _ = importInput.click()
    return .undefined
}

nonisolated(unsafe) private let importFileChosen = JSClosure { _ in
    let file = importInput.files[0]
    guard file.object != nil else {
        return .undefined
    }
    importInput.value = ""
    Task { await importSheet(from: file) }
    return .undefined
}

nonisolated(unsafe) private let reportClosed = JSClosure { _ in
    _ = importButton.focus()
    return .undefined
}

func startArtSheetImport() {
    _ = importButton.addEventListener("click", importClicked)
    _ = importInput.addEventListener("change", importFileChosen)
    _ = report.addEventListener("close", reportClosed)
}

private func importSheet(from file: JSValue) async {
    let fileName = string(from: file.name) ?? ""
    guard let size = file.size.number, size <= Double(largestSheetFileBytes) else {
        showStatus("Can't import \(fileName): larger than 1 MiB.")
        return
    }
    let bytes: [UInt8]
    do {
        bytes = try await fileBytes(file)
    } catch {
        showStatus("Can't import \(fileName): \(error.thrownValue)")
        return
    }
    guard let header = ImageFileHeader(fileBytes: bytes) else {
        showStatus("Can't import \(fileName): it isn't a PNG or JPEG image.")
        return
    }
    let isJPEG = header.type == .jpeg
    let sizeProblems = sheetSizeProblems(width: header.width, height: header.height)
    guard sizeProblems.isEmpty else {
        showSheetReport(fileName: fileName, isJPEG: isJPEG, problems: sizeProblems, image: nil)
        return
    }

    let imageData: JSValue
    do {
        imageData = try await JSPromise(artView.decodeImage(JSTypedArray<UInt8>(bytes)).object!)!.value
    } catch {
        showStatus("Can't import \(fileName): the browser couldn't decode it.")
        return
    }
    guard let width = imageData.width.number.flatMap({ Int(exactly: $0) }),
          let height = imageData.height.number.flatMap({ Int(exactly: $0) })
    else {
        showStatus("Can't import \(fileName): the browser couldn't decode it.")
        return
    }
    let pixels = JSTypedArray<UInt8>(unsafelyWrapping: JSObject.global.Uint8Array.function!.new(imageData.data.buffer))
    let rgba = pixels.withUnsafeBytes { Array($0) }

    let bank = artSelection.bank
    let bankName = bank.displayName.lowercased()
    switch cart.sheetImport(width: width, height: height, rgba: rgba, bank: bank, preferredPalette: artSelection.previewPalette) {
    case .refused(let problems):
        let namesATile = problems.contains { $0.tile != nil }
        let layout = tileSheetLayout(fittingWidth: reportSheetSide, height: reportSheetSide)
        let image = namesATile ? sheetReportImage(width: width, height: height, rgba: rgba, problems: problems, layout: layout) : nil
        showSheetReport(fileName: fileName, isJPEG: isJPEG, problems: problems, image: image)
    case .imported(let art):
        let question = "Replace all \(TileBank.tileCount) \(bankName) tiles with \(fileName)? Undo puts them back."
        guard JSObject.global.confirm!(question) == .boolean(true) else { return }
        dropArtStroke()
        let artBefore = cart.art
        cart.art = art
        showStatus("Imported \(fileName) into the \(bankName) tiles.")
        recordArtEdit("sheet import", before: artBefore)
        redrawArtView()
    }
}

private func showSheetReport(fileName: String, isJPEG: Bool, problems: [SheetProblem], image: RGBAImage?) {
    reportHeading.textContent = .string("Can't import \(fileName)")
    reportHint.hidden = .boolean(!isJPEG)
    reportImage.hidden = .boolean(image == nil)
    if let image {
        blit(image, into: reportImage)
    }
    _ = reportProblems.replaceChildren()
    for problem in problems {
        let item = document.createElement("li")
        item.textContent = .string(problem.message)
        _ = reportProblems.append(item)
    }
    _ = report.showModal()
}
