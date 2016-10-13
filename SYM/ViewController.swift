// The MIT License (MIT)
//
// Copyright (c) 2016 zqqf16
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.


import Cocoa


extension NSViewController {
    func document() -> Document? {
        if let windowController = self.view.window?.windowController {
            return windowController.document as? Document
        }
        return nil
    }
    
    func window() -> MainWindow? {
        return self.view.window as? MainWindow
    }
}

class ContentViewController: NSViewController {

    @IBOutlet var textView: NSTextView!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupTextView()
    }
    
    fileprivate func setupTextView() {
        self.textView.font = NSFont(name: "Menlo", size: 11)
        self.textView.textContainerInset = CGSize(width: 10, height: 10)
        self.textView.allowsUndo = true
        self.textView.delegate = self
        self.textView.isEditable = true
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        if let document = self.document() {
            self.textView.string = document.content ?? ""
            document.delegate = self
        }
        
        if self.textView.string != nil {
            asyncMain {
                self.symbolicate(nil)
            }
        }
        
        self.view.window?.center()
    }
    
}

extension ContentViewController: DocumentContentDelegate {
    func contentToSave() -> String? {
        return self.textView.string
    }
}

extension ContentViewController: SymDelegate {
    @IBAction func symbolicate(_ sender: AnyObject?) {
        guard let content = self.textView.string else {
            return
        }
        
        guard let type = CrashType.fromContent(content) else {
            return
        }
        
        guard let crash = Parser.parse(content) else {
            return
        }
        
        var sym: Sym?
        switch type {
        case .apple:
            sym = Atos(delegate: self)
        case .umeng:
            sym = Atos(delegate: self)
        default:
            return
        }
        self.window()?.updateProgress(true)
        sym?.symbolicate(crash)
    }
    
    func dsym(forUuid uuid: String) -> String? {
        guard let dsym = DsymManager.sharedInstance.dsym(withUUID: uuid) else {
            return nil
        }
        
        return dsym.path
    }

    
    func didFinish(_ crash: Crash) {
        asyncMain {
            self.textView.setAttributeString(crash.pretty())
            self.textView.scrollToBeginningOfDocument(nil)
            self.window()?.updateProgress(false)
        }
    }
}

extension ContentViewController: TextViewDelegate {
    
    /*
    func textView(_ view: NSTextView, menu: NSMenu, for event: NSEvent, at charIndex: Int) -> NSMenu? {
        let menu = NSMenu(title: "dSYM")
        let showItem = NSMenuItem(title: "Symbolicate", action: #selector(symbolicate), keyEquivalent: "")
        showItem.isEnabled = true
        menu.addItem(showItem)
        menu.allowsContextMenuPlugIns = true
        return menu
    }*/
    
    func textViewDidreadSelectionFromPasteboard() {
        asyncMain {
            self.symbolicate(nil)
        }
    }
}

extension ContentViewController {
    @IBAction func importDsymFile(_ sender: AnyObject?) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.beginSheetModal(for: self.view.window!) {
            (result) in
            if result != NSFileHandlingPanelOKButton {
                return
            }
            
            if panel.urls.count == 0 {
                return
            }
            
            let url = panel.urls[0]
            
            DsymManager.sharedInstance.importDsym(fromURL: url, completion: { (uuids, success) in
                if uuids == nil {
                    let alert = NSAlert()
                    alert.addButton(withTitle: "OK")
                    alert.addButton(withTitle: "Cancel")
                    alert.messageText = "This is not a dSYM file"
                    alert.informativeText = url.path
                    alert.beginSheetModal(for: self.view.window!, completionHandler: nil)
                    return
                }
                
                if (success) {
                    // NSNotificationCenter.defaultCenter().postNotificationName(DidImportDsymNotification, object: uuids)
                }
            })
        }
    }
    
    @IBAction func openCrashFile(_ sender: AnyObject?) {
        
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.beginSheetModal(for: self.view.window!) {
            (result) in
            if result != NSFileHandlingPanelOKButton {
                return
            }
            
            if panel.urls.count == 0 {
                return
            }
            
            let url = panel.urls[0]
            
            
            let content = try! NSString(contentsOf: url, encoding: String.Encoding.utf8.rawValue)
            
            self.textView.string = content as String
        }

    }
    
}
