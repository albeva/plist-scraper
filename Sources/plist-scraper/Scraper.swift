//
//  Scraper.swift
//  plist-scraper
//
//  Created by Albert Varaksin on 15/01/2018.
//

import Foundation
import xcproj
import PathKit
import CSV

struct Config {
    let ignoreTests: Bool
    let defaultTarget: String
    let configuration: String
}

class Scraper {
    
    let project: XcodeProj
    let objects: PBXProj.Objects
    let path: String
    let config: Config
    
    init(path: String, config: Config) {
        self.path = path
        self.config = config
        project = try! XcodeProj(pathString: path)
        objects = project.pbxproj.objects
    }
    
    
    func scrape() {
        targets.append(config.defaultTarget)

        for (_, target) in objects.nativeTargets {
            if config.ignoreTests, target.name.range(of: "Tests") != nil {
                continue
            }
            print("Process \(target.name)")
            if target.name != config.defaultTarget {
                targets.append(target.name)
            }
            let files = getResources(in: target, ext: "plist")
            for file in files {
                let path = getFullPath(of: file)
                guard let plist = loadPlist(path: path) else {
                    continue
                }
                process(plist: plist, target: target, file: file)
            }
        }

        let stream = OutputStream(toFileAtPath: "output.csv", append: false)!
        let csv = try! CSVWriter(stream: stream)

        var row = ["section", "key", "type"]
        for target in targets {
            if target == config.defaultTarget {
                row.append(config.defaultTarget + " (default)")
            } else {
                row.append(target)
            }
        }
        try! csv.write(row: row)
        for (name, section) in map {
            for (key, values) in section {
                csv.beginNewRow()
                try! csv.write(field: name)

                try! csv.write(field: key)
                for (_, value) in values {
                    if value is String {
                        try! csv.write(field: "string")
                    } else if value is Int || value is Double || value is Float {
                        try! csv.write(field: "number")
                    } else if let _ = value as? NSArray {
                        try! csv.write(field: "array")
                    } else if let _ = value as? NSDictionary {
                        try! csv.write(field: "dictionary")
                    } else if value is Bool {
                        try! csv.write(field: "bool")
                    } else {
                        continue
                    }
                    break
                }

                for target in targets {
                    if let value = values[target] {
                        if target != config.defaultTarget, let def = values[config.defaultTarget] {
                            if "\(value)" == "\(def)" {
                                try! csv.write(field: "")
                                continue
                            }
                        }
                        if let val = value as? NSArray {
                            let data = try! JSONSerialization.data(withJSONObject: val, options: [.prettyPrinted])
                            let string = String(data: data, encoding: .utf8)!
                            try! csv.write(field: "\(string)", quoted: true)
                        } else if let val = value as? NSDictionary {
                            let data = try! JSONSerialization.data(withJSONObject: val, options: [.prettyPrinted])
                            let string = String(data: data, encoding: .utf8)!
                            try! csv.write(field: "\(string)", quoted: true)
                        } else {
                            try! csv.write(field: "\"\(value)\"")
                        }
                    } else {
                        try! csv.write(field: "")
                    }
                }
            }
        }
        csv.stream.close()
    }

    var map: [String:[String:[String:AnyObject]]] = [:]
    var targets: [String] = []
    
    /// Process the plist and prepare data for CVS output
    ///
    /// - Parameters:
    ///   - plist: data
    ///   - target: build target
    ///   - file: plist file
    func process(plist: [String: AnyObject], target: PBXTarget, file: PBXFileElement) {
        let name = String(file.path!.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false).first!)
        for (key, value) in plist {
            map[name, default:[:]][key, default:[:]][target.name] = value
        }
    }
    
    
    //    /// Find Info.plist file for the given target
    //    ///
    //    /// - Parameter target: target
    //    func getInfoPlist(for target: PBXTarget) -> String? {
    //        guard let ref = target.buildConfigurationList else {
    //            return nil
    //        }
    //
    //        guard let conf = getConfig(for: ref) else {
    //            return nil
    //        }
    //
    //        let plist = conf.buildSettings["INFOPLIST_FILE"] as? String
    //        if plist == nil || plist == "" || plist == "$(inherited)" {
    //            // find out config - check plist setting in there
    //            // find out project level settings
    //            /*
    //            guard let projectRef = (objects.projects.first{$0.value.targets.contains(target.reference)}) else {
    //                return nil
    //            }
    //            guard let conf = getConfig(for: projectRef.value.buildConfigurationList) else {
    //                return nil
    //            }
    //
    //            dump(conf)
    //            dump(projectRef.value)
    //            */
    //            return nil
    //        }
    //        return plist!.replacingOccurrences(of: "$(TARGET_NAME)", with: target.name)
    //    }
    
    
    func getConfig(for reference: String) -> XCBuildConfiguration? {
        guard let list = objects.configurationLists[reference] else {
            return nil
        }
        
        guard let conf = (objects.buildConfigurations.first{list.buildConfigurations.contains($0.key) && $0.value.name == config.configuration}) else {
            return nil
        }
        
        return conf.value
    }
    
    
    /// Get full path for given file
    ///
    /// - Parameter file: file
    /// - Returns: path
    func getFullPath(of file: PBXFileElement) -> String {
        guard var filename = file.path else {
            return ""
        }
        
        var ref = file.reference
        let groups = objects.groups
        while let group = (groups.first{ $0.value.children.contains(ref) }) {
            ref = group.key
            filename = (group.value.path ?? "") + "/" + filename
        }
        
        let basePath = Path(path)
        return basePath.parent().string + filename
    }
    
    
    /// Fetch target resources matching given file extensioon
    ///
    /// - Parameters:
    ///   - in: target
    ///   - ext: matching file extension
    /// - Returns: target resources
    func getResources(in target: PBXTarget, ext: String) -> [PBXFileElement] {
        guard let resourcesRef = (objects.resourcesBuildPhases.first{target.buildPhases.contains($0.key)}) else {
            return []
        }
        
        var files: [PBXFileElement] = []
        let resources = resourcesRef.value
        for buildFileRef in resources.files {
            guard let buildFile = objects.buildFiles[buildFileRef],
                let fileRef = buildFile.fileRef else {
                    continue
            }
            guard let file = objects.getFileElement(reference: fileRef) else {
                continue
            }
            
            guard let path = file.path else {
                continue
            }
            
            if path.suffix(ext.count + 1) == ".\(ext)" {
                files.append(file)
            }
        }
        
        return files
    }
}
