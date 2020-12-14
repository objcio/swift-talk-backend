import Foundation
import SwiftTalkServerLib
import Base
import Backtrace

Backtrace.install()

do {
    try run()
} catch {
    log(error)
    throw error
}
