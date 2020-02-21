//
//  Admin.swift
//  Base
//
//  Created by Chris Eidhof on 25.03.19.
//

import Foundation

extension Array where Element == TaskData {
    var show: Node {
        return LayoutConfig(contents: [
            .table([
                Node.thead([
                    Node.tr([
                        Node.td(["Date"]),
//                        Node.td(["Key"]),
                        Node.td(["JSON"]),
                        Node.td(["State"]),
                        Node.td(["Error"]),
                        Node.td(["Sent Failure Email"]),
                    ])
                ])]
                + self.map { task in
                Node.tr([
                    Node.td([Node.text(DateFormatter.iso8601.string(from: task.date))]),
//                    Node.td([Node.text(task.key)]),
                    Node.td([Node.pre(task.json)]),
                    Node.td([Node.text(task.failed ? "failed" : "pending")]),
                    Node.td([task.errorMessage.map { Node.pre($0) } ?? Node.none]),
                    Node.td([Node.text(task.sentErrorNotification ? "yes" : "")]),
                ])
            })
        ]).layoutForCheckout
    }
}

