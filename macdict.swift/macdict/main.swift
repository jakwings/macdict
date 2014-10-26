//
//  main.swift
//  macdict
//
//  Created by Jak Wings on 2014-10-26.
//
//

import Foundation
import CoreServices

protocol ExtendedOutputStreamType: OutputStreamType {
    mutating func writeln(string: String)
}

class StandardOutputStream: ExtendedOutputStreamType {
    let stdout = NSFileHandle.fileHandleWithStandardOutput()

    func write(string: String) {
        stdout.writeData(string.dataUsingEncoding(NSUTF8StringEncoding)!)
    }
    func writeln(string: String) {
        write(string + "\n")
    }
}
var stdout = StandardOutputStream()

class StandardErrorOutputStream: ExtendedOutputStreamType {
    let stderr = NSFileHandle.fileHandleWithStandardError()

    func write(string: String) {
        stderr.writeData(string.dataUsingEncoding(NSUTF8StringEncoding)!)
    }
    func writeln(string: String) {
        write(string + "\n")
    }
}
var stderr = StandardErrorOutputStream()

func help(toStderr: Bool = false) {
    var stream: ExtendedOutputStreamType = toStderr ? stderr : stdout
    let macdict: String = Process.arguments[0]

    if toStderr {
        stream.writeln("")
    }
    stream.writeln("Usage: \(macdict) [-h] [-l] [-d <dictionary name>]... [-i <dictionary indexes>]... [word]...")
    stream.writeln("  -h    Display this help message.")
    stream.writeln("  -l    Show indexed list of names of all available dictionaries.")
    stream.writeln("  -d    Specify a dictionary to search in.")
    stream.writeln("        Use 'all' to select all available dictionaries.")
    stream.writeln("        If no dictionary is specified, it will look up the word or phrase in all available dictionaries and only return the first definition found.")
    stream.writeln("  -i    Specify dictionary indexes to search in, using ',' as delimiters.")
    stream.writeln("        If indexes contain 0 then all available dictionaries are selected.")
}

var dictionariesKeyedByName = [String: DCSDictionary]()
var dictionariesKeyedByIndex = [DCSDictionary]()
func setupDictionaries() {
    let availableDictionaries: NSArray = DCSCopyAvailableDictionaries().takeUnretainedValue()
    for dictionary in availableDictionaries {
        let dict = dictionary as DCSDictionary
        let name: String = DCSDictionaryGetName(dict).takeUnretainedValue()
        dictionariesKeyedByIndex.append(dict)
        dictionariesKeyedByName[name] = dict
    }
    dictionariesKeyedByIndex.sort {
        let nameA: String = DCSDictionaryGetName($0).takeUnretainedValue()
        let nameB: String = DCSDictionaryGetName($1).takeUnretainedValue()
        return nameA.compare(nameB) == .OrderedAscending
    }
}
func listDictionaries() {
    for (index, dictionary) in enumerate(dictionariesKeyedByIndex) {
        let name: String = DCSDictionaryGetName(dictionary).takeUnretainedValue()
        println("[\(index + 1)]\t\(name)")
    }
}

func lookUp(string: NSString, dictionaries: NSMutableSet) {
    if dictionaries.count < 1 {
        let range: CFRange = DCSGetTermRangeInString(nil, string, 0)
        if range.location != kCFNotFound {
            let term: NSString = string.substringWithRange(NSMakeRange(range.location, range.length))
            let definition: String = DCSCopyTextDefinition(nil, string, range).takeUnretainedValue()
            stdout.writeln("Definition of \"\(term)\":\n\(definition)")
        } else {
            stderr.writeln("Definition of \"\(string)\":\n(none)")
        }
    } else {
        var i = 0
        for dictionary in dictionaries {
            if i > 0 {
                stdout.writeln("%")
            }
            let dict = dictionary as DCSDictionary
            let name = DCSDictionaryGetName(dict).takeUnretainedValue()
            let range: CFRange = DCSGetTermRangeInString(dict, string, 0)
            if range.location != kCFNotFound {
                let term: NSString = string.substringWithRange(NSMakeRange(range.location, range.length))
                let definition: String = DCSCopyTextDefinition(dict, term, range).takeUnretainedValue()
                stdout.writeln("Definition of \"\(term)\" in \(name):\n\(definition)")
            } else {
                stderr.writeln("Definition of \"\(string)\" in \(name):\n(none)")
            }
            ++i
        }
    }
}

func parseOptions() {
    var inputWords = [String]()
    var selectedDictionaries = NSMutableSet()
    var allDictionariesSelected = false
    var toHelp = false
    var toListDictionaries = false

    let acceptedArgs = "+d:i:lh".cStringUsingEncoding(NSUTF8StringEncoding)!
    var char: CInt = getopt(C_ARGC, C_ARGV, acceptedArgs)
    while char != -1 {
        switch char {
        case 104:  // 'h'
            toHelp = true
        case 108:  // 'l'
            toListDictionaries = true
        case 100:  // 'd'
            if allDictionariesSelected {
                break
            }
            if let name = String.fromCString(optarg) {
                if name == "all" {
                    allDictionariesSelected = true
                } else if let dictionary = dictionariesKeyedByName[name] {
                    selectedDictionaries.addObject(dictionary)
                }
            }
        case 105:  // 'i'
            if allDictionariesSelected {
                break
            }
            if let indexes = String.fromCString(optarg) {
                for index in indexes.componentsSeparatedByString(",") {
                    if let i = index.toInt() {
                        if i == 0 {
                            allDictionariesSelected = true
                        } else if i > 0 && i <= dictionariesKeyedByIndex.count {
                            selectedDictionaries.addObject(dictionariesKeyedByIndex[i-1])
                        }
                    }
                }
            }
        case 63:  // '?'
            help(toStderr: true)
            exit(-1)
        default:
            if let word = String.fromCString(optarg) {
                inputWords.append(word)
            }
        }
        char = getopt(C_ARGC, C_ARGV, acceptedArgs)
    }
    let argv: [String] = Process.arguments
    let argc: Int = argv.count
    let optIndex = "\(optind)".toInt()!
    if optIndex < argc {
        for i in optIndex ..< argc {
            inputWords.append(argv[i])
        }
    }

    if toHelp {
        help()
    } else if toListDictionaries {
        listDictionaries()
    } else {
        if inputWords.count == 0 {
            stderr.writeln("Error: Please provide a word for searching.\n")
            help(toStderr: true)
            exit(-1)
        }
        if allDictionariesSelected {
            selectedDictionaries.removeAllObjects()
            for dictionary in dictionariesKeyedByIndex {
                selectedDictionaries.addObject(dictionary)
            }
        }
        let searchString: NSString = (inputWords as NSArray).componentsJoinedByString(" ")
        lookUp(searchString, selectedDictionaries)
    }
}


/// Let' start.

if C_ARGC < 2 {
    help()
    exit(0)
}
setupDictionaries()
parseOptions()