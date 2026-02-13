import Foundation

enum SidebarSelection: Hashable {
    case terminal(UUID)
    case prompt(String)
    case template(String)
}
