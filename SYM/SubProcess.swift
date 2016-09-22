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


import Foundation


// MARK: - Global task queue

let globalTaskQueue = OperationQueue().then {
    $0.maxConcurrentOperationCount = 4
}


// MARK: - Sub process task operation

class SubProcess: Operation {
    
    var cmd: String
    var arguments: [String]?
    var result: String?

    init(cmd: String, arguments: [String]?) {
        self.cmd = cmd
        self.arguments = arguments
        super.init()
    }

    override func main() {
        if self.isCancelled {
            return
        }

        let pipe = Pipe()

        let task = Process().then {
            $0.launchPath = cmd
            $0.arguments = arguments
            $0.standardOutput = pipe
        }

        task.launch()
        
        let output = pipe.fileHandleForReading
        let data = output.readDataToEndOfFile()
        self.result = String(data: data, encoding: String.Encoding.utf8)
    }
}


// MARK: atos

extension SubProcess {
    convenience init(loadAddress: String, addressess: [String], dsym: String,
         binary: String, arch: String = "x86_64") {
        let cmd = "/usr/bin/xcrun"
        let arguments = ["atos", "-arch", "x86_64", "-o", dsym, "-l", loadAddress] + addressess
        
        
        //xcrun atos -o Alimail.app.dSYM/Contents/Resources/DWARF/Alimail -arch x86_64 -l 0x109cf5000 0x000000010a12a942 0x000000010a129b4e 0x000000010a0e848e 0x000000010a12d329 0x000000010a0dee7c 0x000000010a135b8c 0x000000010a088e29 0x0000000109e56bcb

        
        self.init(cmd: cmd, arguments: arguments)
    }
    
    func atosResult() -> [String]? {
        guard let result = self.result else {
            return nil
        }

        let lines = result.components(separatedBy: "\n").filter {
            (content) -> Bool in
            return content.characters.count > 0
        }

        return lines
    }
}


// MARK: dwarfdump

extension SubProcess {
    convenience init(dsymPath: String) {
        let cmd = "/usr/bin/dwarfdump"
        let arguments = ["--uuid", dsymPath]
        self.init(cmd: cmd, arguments: arguments)
    }
    
    func dwarfResult() -> [String]? {
        guard let result = self.result else {
            return nil
        }
        
        let lines = result.components(separatedBy: "\n").filter {
            (content) -> Bool in
            if content.characters.count == 0 {
                return false
            }
            
            return content.hasPrefix("UUID: ")
        }
        
        return lines.map({ (line) -> String in
            return line.components(separatedBy: " ")[1]
        })
    }
}


// MARK: symbolicatecrash

extension SubProcess {
    convenience init(crashPath: String) {
        let cmd = Bundle.main.path(forResource: "symbolicatecrash", ofType: nil)
        assert(cmd != nil)

        let arguments = [crashPath]
        self.init(cmd: cmd!, arguments: arguments)
    }
}

// MARK: - GCD

func asyncGlobal(_ block: @escaping ()->()) {
    
    DispatchQueue.global(qos: .userInteractive).async(execute: block)
}

func asyncMain(_ block: @escaping ()->()) {
    DispatchQueue.main.async(execute: block)
}
