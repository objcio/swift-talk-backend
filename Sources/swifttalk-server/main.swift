import Foundation
import SwiftTalkServerLib
import Base
import Backtrace

Backtrace.install()

while true {
    do {
        try run()
    } catch {
        log(error)
    }
}
