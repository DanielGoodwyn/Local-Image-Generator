import Cocoa
import WebKit

private let appName = "Local Image Generator"
private let serverURL = URL(string: "http://127.0.0.1:7865/")!
private let sourceRoot = "/Users/danielgoodwyn/src/Local Image Generator"
private let outputRoot = "/Users/danielgoodwyn/Pictures/Local Image Generator"
private let pythonPath = "/Users/danielgoodwyn/src/Local Image Generator/.venv-mvp/bin/python"
private let logPath = "/tmp/local-image-generator.log"
private let launcherLogPath = "/tmp/local-image-generator-launcher.log"

class AppDelegate: NSObject, NSApplicationDelegate, NSSplitViewDelegate, WKNavigationDelegate {
    private var window: NSWindow!
    private var webView: WKWebView!
    private var galleryStack: NSStackView!
    private var statusLabel: NSTextField!
    private var nativePromptField: NSTextField!
    private var nativeFilenameField: NSTextField!
    private var nativeGenerateButton: NSButton!
    private var nativeStatusLabel: NSTextField!
    private var serverProcess: Process?
    private var launchedServer = false
    private var readinessTimer: Timer?
    private var galleryTimer: Timer?
    private var generationStatusTimer: Timer?
    private var generationStartedAt: Date?
    private var generationBaselineFiles: [String: Date] = [:]
    private var generationSubmittedName = ""

    func applicationDidFinishLaunching(_ notification: Notification) {
        appendLauncherLog("applicationDidFinishLaunching")
        NSApp.setActivationPolicy(.regular)
        buildMenu()
        buildWindow()
        appendLauncherLog("window built")
        startOrReuseServer()
        DispatchQueue.main.async { [weak self] in
            self?.refreshGallery()
            self?.appendLauncherLog("gallery refreshed")
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        readinessTimer?.invalidate()
        galleryTimer?.invalidate()
        generationStatusTimer?.invalidate()
        if launchedServer {
            serverProcess?.terminate()
        }
    }

    private func buildMenu() {
        let menu = NSMenu()
        let appMenuItem = NSMenuItem()
        menu.addItem(appMenuItem)

        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        NSApp.mainMenu = menu
    }

    private func buildWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1320, height: 860),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = appName
        window.minSize = NSSize(width: 560, height: 420)
        window.center()

        let splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.delegate = self
        splitView.translatesAutoresizingMaskIntoConstraints = false
        splitView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let webContainer = NSView()
        webContainer.translatesAutoresizingMaskIntoConstraints = false
        webContainer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let webStack = NSStackView()
        webStack.orientation = .vertical
        webStack.spacing = 0
        webStack.translatesAutoresizingMaskIntoConstraints = false

        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        webView.loadHTMLString(startingHTML("Starting local generator..."), baseURL: nil)

        let controlPanel = buildNativeControlPanel()
        webStack.addArrangedSubview(controlPanel)
        webStack.addArrangedSubview(webView)

        webContainer.addSubview(webStack)
        NSLayoutConstraint.activate([
            webStack.leadingAnchor.constraint(equalTo: webContainer.leadingAnchor),
            webStack.trailingAnchor.constraint(equalTo: webContainer.trailingAnchor),
            webStack.topAnchor.constraint(equalTo: webContainer.topAnchor),
            webStack.bottomAnchor.constraint(equalTo: webContainer.bottomAnchor),
            controlPanel.heightAnchor.constraint(equalToConstant: 108),
            webView.heightAnchor.constraint(greaterThanOrEqualToConstant: 250)
        ])

        let galleryPanel = buildGalleryPanel()
        galleryPanel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        splitView.addArrangedSubview(webContainer)
        splitView.addArrangedSubview(galleryPanel)

        let galleryPreferredWidth = galleryPanel.widthAnchor.constraint(equalToConstant: 300)
        galleryPreferredWidth.priority = .defaultLow

        window.contentView = splitView
        NSLayoutConstraint.activate([
            webContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 320),
            galleryPanel.widthAnchor.constraint(greaterThanOrEqualToConstant: 210),
            galleryPreferredWidth
        ])

        window.makeKeyAndOrderFront(nil)
    }

    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        return 320
    }

    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        return max(320, splitView.bounds.width - 210)
    }

    private func buildNativeControlPanel() -> NSView {
        let panel = NSView()
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.wantsLayer = true
        panel.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 8
        root.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 10, right: 12)
        root.translatesAutoresizingMaskIntoConstraints = false

        let promptLabel = NSTextField(labelWithString: "Prompt")
        promptLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)

        nativePromptField = NSTextField()
        nativePromptField.placeholderString = "Describe the image to generate"
        nativePromptField.isEditable = true
        nativePromptField.isSelectable = true
        nativePromptField.lineBreakMode = .byTruncatingTail
        nativePromptField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let filenameLabel = NSTextField(labelWithString: "Filename")
        filenameLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)

        nativeFilenameField = NSTextField()
        nativeFilenameField.placeholderString = "Optional, e.g. snowy-owl"
        nativeFilenameField.isEditable = true
        nativeFilenameField.isSelectable = true
        nativeFilenameField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        nativeGenerateButton = NSButton(title: "Generate image", target: self, action: #selector(generateFromNativeControls))
        nativeGenerateButton.bezelStyle = .rounded
        nativeGenerateButton.keyEquivalent = "\r"

        nativeStatusLabel = NSTextField(labelWithString: "Images save to \(outputRoot)")
        nativeStatusLabel.textColor = .secondaryLabelColor
        nativeStatusLabel.font = NSFont.systemFont(ofSize: 11)
        nativeStatusLabel.lineBreakMode = .byTruncatingMiddle
        nativeStatusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let formRow = NSGridView(views: [
            [promptLabel, nativePromptField],
            [filenameLabel, nativeFilenameField]
        ])
        formRow.translatesAutoresizingMaskIntoConstraints = false
        formRow.rowSpacing = 6
        formRow.columnSpacing = 8
        formRow.column(at: 0).xPlacement = .trailing

        let actionRow = NSStackView()
        actionRow.orientation = .horizontal
        actionRow.spacing = 10
        actionRow.addArrangedSubview(nativeGenerateButton)
        actionRow.addArrangedSubview(nativeStatusLabel)

        root.addArrangedSubview(formRow)
        root.addArrangedSubview(actionRow)
        panel.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            root.topAnchor.constraint(equalTo: panel.topAnchor),
            root.bottomAnchor.constraint(equalTo: panel.bottomAnchor),
            nativePromptField.widthAnchor.constraint(greaterThanOrEqualToConstant: 180),
            nativeFilenameField.widthAnchor.constraint(greaterThanOrEqualToConstant: 140)
        ])

        return panel
    }

    private func buildGalleryPanel() -> NSView {
        let panel = NSView()
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.wantsLayer = true
        panel.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 10
        root.edgeInsets = NSEdgeInsets(top: 14, left: 12, bottom: 12, right: 12)
        root.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "Saved images")
        title.font = NSFont.boldSystemFont(ofSize: 18)
        title.lineBreakMode = .byTruncatingTail

        statusLabel = NSTextField(labelWithString: outputRoot)
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingMiddle
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8

        let refreshButton = NSButton(title: "Refresh", target: self, action: #selector(refreshGalleryAction))
        refreshButton.bezelStyle = .rounded
        let openFolderButton = NSButton(title: "Open folder", target: self, action: #selector(openOutputFolder))
        openFolderButton.bezelStyle = .rounded
        buttonRow.addArrangedSubview(refreshButton)
        buttonRow.addArrangedSubview(openFolderButton)

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        galleryStack = NSStackView()
        galleryStack.orientation = .vertical
        galleryStack.alignment = .leading
        galleryStack.spacing = 12
        galleryStack.translatesAutoresizingMaskIntoConstraints = false

        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(galleryStack)
        scrollView.documentView = documentView

        NSLayoutConstraint.activate([
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            galleryStack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            galleryStack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            galleryStack.topAnchor.constraint(equalTo: documentView.topAnchor),
            galleryStack.bottomAnchor.constraint(lessThanOrEqualTo: documentView.bottomAnchor)
        ])

        root.addArrangedSubview(title)
        root.addArrangedSubview(statusLabel)
        root.addArrangedSubview(buttonRow)
        root.addArrangedSubview(scrollView)
        panel.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            root.topAnchor.constraint(equalTo: panel.topAnchor),
            root.bottomAnchor.constraint(equalTo: panel.bottomAnchor),
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 180)
        ])

        galleryTimer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: true) { [weak self] _ in
            self?.refreshGallery()
        }

        return panel
    }

    private func startOrReuseServer() {
        appendLauncherLog("checking existing server")
        checkServer { [weak self] reachable in
            guard let self else { return }
            self.appendLauncherLog("server check result: \(reachable)")
            if reachable {
                self.loadGenerator()
                return
            }

            self.startServer()
            self.webView.loadHTMLString(self.startingHTML("Loading model. This can take a minute..."), baseURL: nil)
            self.readinessTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
                self?.checkServer { reachable in
                    if reachable {
                        timer.invalidate()
                        self?.loadGenerator()
                    }
                }
            }
        }
    }

    private func startServer() {
        appendLauncherLog("starting backend process")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.currentDirectoryURL = URL(fileURLWithPath: sourceRoot)
        process.arguments = [
            "launch.py",
            "--always-no-vram",
            "--attention-split",
            "--vae-in-cpu",
            "--all-in-fp16",
            "--disable-in-browser"
        ]

        var env = ProcessInfo.processInfo.environment
        env["PYTHONUNBUFFERED"] = "1"
        env["PYTORCH_ENABLE_MPS_FALLBACK"] = "1"
        env["GRADIO_SERVER_PORT"] = "7865"
        env["TOKENIZERS_PARALLELISM"] = "false"
        process.environment = env

        FileManager.default.createFile(atPath: logPath, contents: nil)
        if let handle = FileHandle(forWritingAtPath: logPath) {
            handle.seekToEndOfFile()
            process.standardOutput = handle
            process.standardError = handle
        }

        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                if self?.launchedServer == true {
                    self?.webView.loadHTMLString(self?.startingHTML("The local generator stopped. Reopen the app to start it again.") ?? "", baseURL: nil)
                }
            }
        }

        do {
            try process.run()
            serverProcess = process
            launchedServer = true
            appendLauncherLog("backend process started pid=\(process.processIdentifier)")
        } catch {
            appendLauncherLog("backend process failed: \(error.localizedDescription)")
            webView.loadHTMLString(startingHTML("Could not start local generator: \(error.localizedDescription)"), baseURL: nil)
        }
    }

    private func checkServer(_ completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
            process.arguments = [
                "-fs",
                "--max-time", "1",
                "--output", "/dev/null",
                serverURL.absoluteString
            ]

            do {
                try process.run()
                process.waitUntilExit()
                let ok = process.terminationStatus == 0
                DispatchQueue.main.async { completion(ok) }
            } catch {
                DispatchQueue.main.async { completion(false) }
            }
        }
    }

    private func loadGenerator() {
        appendLauncherLog("loading generator web view")
        webView.load(URLRequest(url: serverURL))
    }

    private func appendLauncherLog(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        if !FileManager.default.fileExists(atPath: launcherLogPath) {
            FileManager.default.createFile(atPath: launcherLogPath, contents: nil)
        }
        guard let handle = FileHandle(forWritingAtPath: launcherLogPath) else { return }
        handle.seekToEndOfFile()
        handle.write(data)
        try? handle.close()
    }

    private func startingHTML(_ message: String) -> String {
        """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <style>
            body {
              margin: 0;
              min-height: 100vh;
              display: grid;
              place-items: center;
              font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
              color: #1f2933;
              background: #f6f7f8;
            }
            .box {
              border: 1px solid #d7dde4;
              border-radius: 8px;
              background: white;
              padding: 22px 26px;
              width: min(520px, calc(100vw - 48px));
              box-shadow: 0 12px 36px rgba(31, 41, 51, 0.10);
            }
            h1 { font-size: 22px; margin: 0 0 8px; }
            p { margin: 0; color: #5b6673; line-height: 1.45; }
          </style>
        </head>
        <body>
          <div class="box">
            <h1>\(appName)</h1>
            <p>\(message)</p>
          </div>
        </body>
        </html>
        """
    }

    @objc private func refreshGalleryAction() {
        refreshGallery()
    }

    @objc private func openOutputFolder() {
        NSWorkspace.shared.open(URL(fileURLWithPath: outputRoot, isDirectory: true))
    }

    @objc private func generateFromNativeControls() {
        let prompt = nativePromptField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let filename = nativeFilenameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !prompt.isEmpty else {
            nativeStatusLabel.stringValue = "Enter a prompt first."
            return
        }

        nativeGenerateButton.isEnabled = false
        nativeStatusLabel.stringValue = "Submitting..."
        let baseline = imageModificationSnapshot()

        let script = """
        (() => {
          const promptValue = \(jsString(prompt));
          const filenameValue = \(jsString(filename));
          const setValue = (element, value) => {
            const proto = element instanceof HTMLTextAreaElement ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
            const setter = Object.getOwnPropertyDescriptor(proto, 'value').set;
            setter.call(element, value);
            element.dispatchEvent(new Event('input', { bubbles: true }));
            element.dispatchEvent(new Event('change', { bubbles: true }));
          };
          const prompt = document.querySelector('textarea[placeholder="Type prompt here or paste parameters."]');
          const filename = Array.from(document.querySelectorAll('input')).find((input) => {
            const label = input.closest('label')?.innerText || input.parentElement?.innerText || '';
            return label.includes('Output Filename') || input.placeholder.includes('koala');
          });
          const button = document.querySelector('#generate_button');
          if (!prompt || !filename || !button) {
            return { ok: false, message: 'Generator page is still loading.' };
          }
          setValue(prompt, promptValue);
          setValue(filename, filenameValue);
          button.click();
          return { ok: true, message: filenameValue ? `Generating ${filenameValue}...` : 'Generating with automatic filename...' };
        })();
        """

        webView.evaluateJavaScript(script) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.nativeGenerateButton.isEnabled = true
                    self.nativeStatusLabel.stringValue = "Could not submit: \(error.localizedDescription)"
                    return
                }
                let response = result as? [String: Any]
                let ok = response?["ok"] as? Bool ?? false
                self.nativeStatusLabel.stringValue = (response?["message"] as? String) ?? (ok ? "Submitted." : "Could not submit.")
                if ok {
                    self.beginGenerationStatusTracking(submittedName: filename, baseline: baseline)
                    self.refreshGallery()
                } else {
                    self.nativeGenerateButton.isEnabled = true
                }
            }
        }
    }

    private func beginGenerationStatusTracking(submittedName: String, baseline: [String: Date]) {
        generationStatusTimer?.invalidate()
        generationStartedAt = Date()
        generationBaselineFiles = baseline
        generationSubmittedName = submittedName
        nativeStatusLabel.stringValue = generatingStatusText(elapsed: 0)

        generationStatusTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateGenerationStatus()
        }
    }

    private func updateGenerationStatus() {
        guard let startedAt = generationStartedAt else { return }
        let elapsed = Date().timeIntervalSince(startedAt)

        if let completedURL = completedImageSinceGenerationStarted() {
            generationStatusTimer?.invalidate()
            generationStatusTimer = nil
            generationStartedAt = nil
            nativeGenerateButton.isEnabled = true
            nativeStatusLabel.stringValue = "Completed in \(formatDuration(elapsed)): \(completedURL.lastPathComponent)"
            refreshGallery()
            return
        }

        nativeStatusLabel.stringValue = generatingStatusText(elapsed: elapsed)
    }

    private func generatingStatusText(elapsed: TimeInterval) -> String {
        let target = generationSubmittedName.isEmpty ? "image" : generationSubmittedName
        return "Generating \(target)... elapsed \(formatDuration(elapsed))"
    }

    private func completedImageSinceGenerationStarted() -> URL? {
        for url in imageFiles() {
            let currentDate = modificationDate(url)
            let previousDate = generationBaselineFiles[url.path]
            if previousDate == nil || abs(currentDate.timeIntervalSince(previousDate!)) > 0.5 {
                return url
            }
        }

        return nil
    }

    private func imageModificationSnapshot() -> [String: Date] {
        var snapshot: [String: Date] = [:]
        for url in imageFiles() {
            snapshot[url.path] = modificationDate(url)
        }
        return snapshot
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let seconds = max(0, seconds)
        if seconds < 60 {
            return String(format: "%.1f seconds", seconds)
        }

        let totalSeconds = Int(seconds.rounded())
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        if minutes < 60 {
            return String(format: "%dm %02ds", minutes, remainingSeconds)
        }

        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return String(format: "%dh %02dm %02ds", hours, remainingMinutes, remainingSeconds)
    }

    @objc private func openImage(_ sender: NSButton) {
        guard let path = (sender as? PathButton)?.path else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    @objc private func revealImage(_ sender: NSButton) {
        guard let path = (sender as? PathButton)?.path else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    private func refreshGallery() {
        let files = imageFiles()
        galleryStack.arrangedSubviews.forEach { view in
            galleryStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        statusLabel.stringValue = files.isEmpty ? "No saved images yet" : "\(files.count) saved image\(files.count == 1 ? "" : "s")"

        if files.isEmpty {
            let empty = NSTextField(labelWithString: "Generated images will appear here.")
            empty.textColor = .secondaryLabelColor
            empty.font = NSFont.systemFont(ofSize: 13)
            galleryStack.addArrangedSubview(empty)
            return
        }

        for url in files.prefix(80) {
            let item = galleryItem(for: url)
            galleryStack.addArrangedSubview(item)
            let itemWidth = item.widthAnchor.constraint(equalTo: galleryStack.widthAnchor, constant: -8)
            itemWidth.priority = .defaultHigh
            itemWidth.isActive = true
        }
    }

    private func imageFiles() -> [URL] {
        let root = URL(fileURLWithPath: outputRoot, isDirectory: true)
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var urls: [URL] = []
        for case let url as URL in enumerator {
            let ext = url.pathExtension.lowercased()
            guard ["png", "jpg", "jpeg", "webp"].contains(ext) else { continue }
            urls.append(url)
        }

        return urls.sorted {
            modificationDate($0) > modificationDate($1)
        }
    }

    private func modificationDate(_ url: URL) -> Date {
        ((try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate) ?? .distantPast
    }

    private func galleryItem(for url: URL) -> NSView {
        let item = NSStackView()
        item.orientation = .vertical
        item.spacing = 6
        item.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        item.translatesAutoresizingMaskIntoConstraints = false
        item.wantsLayer = true
        item.layer?.cornerRadius = 8
        item.layer?.borderWidth = 1
        item.layer?.borderColor = NSColor.separatorColor.cgColor
        item.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        let imageView = NSImageView()
        imageView.image = NSImage(contentsOf: url)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.wantsLayer = true
        imageView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.05).cgColor
        imageView.layer?.cornerRadius = 6

        let name = NSTextField(labelWithString: url.lastPathComponent)
        name.font = NSFont.boldSystemFont(ofSize: 12)
        name.lineBreakMode = .byTruncatingMiddle

        let date = DateFormatter.localizedString(from: modificationDate(url), dateStyle: .short, timeStyle: .short)
        let meta = NSTextField(labelWithString: date)
        meta.textColor = .secondaryLabelColor
        meta.font = NSFont.systemFont(ofSize: 11)

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.spacing = 6
        let open = PathButton(title: "Open", target: self, action: #selector(openImage(_:)))
        open.bezelStyle = .rounded
        open.path = url.path
        let reveal = PathButton(title: "Reveal", target: self, action: #selector(revealImage(_:)))
        reveal.bezelStyle = .rounded
        reveal.path = url.path
        buttons.addArrangedSubview(open)
        buttons.addArrangedSubview(reveal)

        item.addArrangedSubview(imageView)
        item.addArrangedSubview(name)
        item.addArrangedSubview(meta)
        item.addArrangedSubview(buttons)

        NSLayoutConstraint.activate([
            item.widthAnchor.constraint(greaterThanOrEqualToConstant: 150),
            imageView.widthAnchor.constraint(equalTo: item.widthAnchor, constant: -16),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: 0.70)
        ])

        return item
    }

    private func jsString(_ value: String) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let encoded = String(data: data, encoding: .utf8) else {
            return "\"\""
        }
        return encoded
    }
}

private final class PathButton: NSButton {
    var path = ""
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
