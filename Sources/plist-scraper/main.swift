//
// Scrape for plist files in the project
//

import Foundation
import Commander

let main = command(
    Argument<String>("project", description: "Path to xcode workspace / project"),
    Option<String>("main", default: "<none>", flag: "m", description: "Main target which is considered default"),
    Option<String>("configuration", default: "Debug", flag: "c", description: "Configurarion target to use for scraping")
) { project, main, configuration in
    print("Parsing \(project)")
    
    let config = Config(
        ignoreTests:   true,
        defaultTarget: main == "<none>" ? nil : main,
        configuration: configuration
    )
    
    let scraper = Scraper(path: project, config: config)
    scraper.scrape()
}
main.run()
