//
//  Forms.swift
//  swifttalk-server
//
//  Created by Chris Eidhof on 08.11.18.
//

import Foundation

typealias ValidationError = (field: String, message: String)

struct Form<A> {
    let parse: ([String:String]) -> A?
    let render: (A, [ValidationError]) -> Node
}

extension Form {
    func wrap(_ f: @escaping (Node) -> Node) -> Form<A> {
        return Form(parse: parse, render: { value, err in
            f(self.render(value, err))
        })
    }
}

struct FormView {
    struct Field {
        var id: String
        var title: String
        var value: String
        var note: String?
    }
    var classes: Class? = nil
    var id: String = ""
    var errors: [ValidationError] = []
    var fields: [Field]
    var submitTitle: String = "Submit"
    var submitNote: String?
    var action: Route
    init(fields: [Field], submitTitle: String = "Submit", submitNote: String? = nil, action: Route, errors: [ValidationError], id: String = "", classes: Class? = nil) {
        self.fields = fields
        self.submitTitle = submitTitle
        self.submitNote = submitNote
        self.action = action
        self.errors = errors
        self.id = id
        self.classes = classes
    }
}

extension FormView {
    var renderStacked: [Node] {
        func field(id: String, description: String, value: String?, note: String?) -> Node {
            let isErr = errors.contains { $0.field == id }
            return Node.fieldset(classes: "input-unit", [
                Node.label(classes: "input-label input-label--required" + (isErr ? "color-invalid" : ""), attributes: ["for": id], [.text(description)]),
                Node.input(classes: "text-input block width-full max-width-6", name: id, attributes: ["required": "required", "value": value ?? ""]),
                note.map { Node.label(classes: "input-note mt-", attributes: ["for": id], [
                    .span(classes: "bold", attributes: [:], [.raw("Note: ")]),
                    .raw($0)
                ]) } ?? .none
            ])
        }
        
        return [
            errors.isEmpty ? .none : Node.ul(classes: "mb++ bgcolor-invalid color-white ms-1 pa radius-3 bold", errors.map { Node.li([Node.text($0.message)]) }), // todo
            Node.div(classes: "", [
                Node.form(classes: classes, action: action.path, attributes: ["id": id], [
                    // todo utf8?
                    // todo authenticity token (CSRF token)
                    Node.div(classes: "stack+", fields.map {
                        field(id: $0.id, description: $0.title, value: $0.value, note: $0.note)
                        } + [
                            .div([
                                Node.input(classes: "c-button c-button--blue", name: "commit", type: "submit", attributes: ["value": submitTitle, "data-disable-with": submitTitle], []),
                                submitNote.map { Node.p(classes: "ms-1 color-gray-40 mt", attributes: [:], [.raw($0)]) } ?? .none
                            ])
                        ])
                    ])
                ])
        ]
    }
}
