import Foundation
import Observation

@Observable
class SidebarViewModel {
    var selection: SidebarSelection?

    let prompts: [String] = [
        "Default Prompt",
        "Minimal Prompt",
    ]

    let templates: [String] = [
        "SSH Remote",
        "Development",
    ]
}
