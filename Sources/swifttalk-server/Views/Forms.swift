//
//  Forms.swift
//  swifttalk-server
//
//  Created by Chris Eidhof on 08.11.18.
//

import Foundation

typealias ValidationError = (field: String, message: String)

struct Form {
    typealias Field = (id: String, title: String, value: String)
    var classes: Class? = nil
    var id: String = ""
    var errors: [ValidationError] = []
    var fields: [Field]
    var submitTitle: String = "Submit"
    var action: Route
    init(fields: [Field], submitTitle: String = "Submit", action: Route, errors: [ValidationError], id: String = "", classes: Class? = nil) {
        self.fields = fields
        self.submitTitle = submitTitle
        self.action = action
        self.errors = errors
        self.id = id
        self.classes = classes
    }
}

extension Form {
    var renderStacked: [Node] {
        func field(id: String, description: String, value: String?) -> Node {
            let isErr = errors.contains { $0.field == id }
            return Node.fieldset(classes: "input-unit", [
                .p([
                    Node.label(classes: "input-label input-label--required" + (isErr ? "color-invalid" : ""), attributes: ["for": id], [.text(description)])
                    ]),
                .p([
                    Node.input(classes: "text-input width-full", name: id, attributes: ["required": "required", "value": value ?? ""])
                    ])
                ])
        }
        
        return [
            errors.isEmpty ? .none : Node.ul(classes: "mb++ bgcolor-invalid color-white ms-1 pa radius-3 bold", errors.map { Node.li([Node.text($0.message)]) }), // todo
            Node.div(classes: "max-width-6", [
                Node.form(classes: classes, action: action.path, attributes: ["id": id], [
                    // todo utf8?
                    // todo authenticity token (CSRF token)
                    Node.div(classes: "stack+", fields.map {
                        field(id: $0.id, description: $0.title, value: $0.value)
                        } + [
                            .div([
                                Node.input(classes: "c-button c-button--blue", name: "commit", type: "submit", attributes: ["value": submitTitle, "data-disable-with": submitTitle], [])
                                ])
                        ])
                    ])
                ])
        ]
    }
}
