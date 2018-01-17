//
//  Scraper.swift
//  plist-scraper
//
//  Created by Albert Varaksin on 15/01/2018.
//

import Foundation
import xcproj
import PathKit

struct Config {
    let ignoreTests: Bool
    let defaultTarget: String?
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
        for (_, target) in objects.nativeTargets {
            if config.ignoreTests, target.name.range(of: "Tests") != nil {
                continue
            }
            print("Process \(target.name)")
            let files = getResources(in: target, ext: "plist")
            for file in files {
                let path = getFullPath(of: file)
                guard let plist = loadPlist(path: path) else {
                    continue
                }
                process(plist: plist, target: target, file: file)
            }
            break
        }
        print(map as AnyObject)
    }
    
    var map: [String:AnyObject] = [:]
    
    /// Process the plist and prepare data for CVS output
    ///
    /// - Parameters:
    ///   - plist: data
    ///   - target: build target
    ///   - file: plist file
    func process(plist: [String: AnyObject], target: PBXTarget, file: PBXFileElement) {
        for (key, value) in plist {
            map[key] = value
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
