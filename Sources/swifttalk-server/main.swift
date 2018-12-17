import Foundation
import SwiftTalkServerLib

while true {
    do {
        try run()
    } catch {
        log(error)
    }
}
