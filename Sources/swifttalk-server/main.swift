import Foundation
import SwiftTalkServerLib
import Base

while true {
    do {
        try run()
    } catch {
        log(error)
    }
}
