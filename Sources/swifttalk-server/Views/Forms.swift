//
//  Forms.swift
//  swifttalk-server
//
//  Created by Chris Eidhof on 08.11.18.
//

import Foundation

typealias ValidationError = (field: String, message: String)

struct Form<A> {
    typealias Render = (A, _ csrf: CSRFToken, [ValidationError]) -> Node
    typealias Parse = ([String:String]) -> A?
    let _parse: Parse
    let render: Render
    init(parse: @escaping Parse, render: @escaping Render) {
        self._parse = parse
        self.render = render
    }

    //
    func parse(csrf: CSRFToken, _ data: [String:String]) -> A? {
        guard data["csrf"] == csrf.stringValue else { return nil } // csrf token failure
        return _parse(data)
    }
}

extension Form {
    func wrap(_ f: @escaping (Node) -> Node) -> Form<A> {
        return Form(parse: _parse, render: { value, csrf, err in
            f(self.render(value, csrf, err))
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
    func renderStacked(csrf: CSRFToken) -> [Node] {
        func field(id: String, description: String, value: String?, note: String?) -> Node {
            let isErr = errors.contains { $0.field == id }
            return Node.fieldset(classes: "input-unit", [
                Node.label(classes: "input-label input-label--required" + (isErr ? "color-invalid" : ""), attributes: ["for": id], [.text(description)]),
                Node.input(classes: "text-input block width-full max-width-6", name: id, attributes: ["required": "required", "value": value ?? ""]),
                note.map { Node.label(classes: "input-note mt-", attributes: ["for": id], [
                    .span(classes: "bold", [.raw("Note: ")]),
                    .raw($0)
                ]) } ?? .none
            ])
        }
        
        return [
            errors.isEmpty ? .none : Node.ul(classes: "mb++ bgcolor-invalid color-white ms-1 pa radius-3 bold", errors.map { Node.li([Node.text($0.message)]) }),
            Node.div(classes: "", [
                Node.form(classes: classes, action: action.path, attributes: ["id": id], [
                    Node.input(name: "csrf", id: "csrf", type: "hidden", attributes: ["value": csrf.stringValue], []),
                    Node.div(classes: "stack+", fields.map {
                        field(id: $0.id, description: $0.title, value: $0.value, note: $0.note)
                        } + [
                            .div([
                                Node.input(classes: "c-button c-button--blue", name: "commit", type: "submit", attributes: ["value": submitTitle, "data-disable-with": submitTitle], []),
                                submitNote.map { Node.p(classes: "ms-1 color-gray-40 mt", [.raw($0)]) } ?? .none
                            ])
                        ])
                    ])
                ])
        ]
    }
}
