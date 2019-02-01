//
//  Forms.swift
//  swifttalk-server
//
//  Created by Chris Eidhof on 08.11.18.
//

import Foundation
import HTML

typealias ValidationError = (field: String, message: String)

struct Form<A> {
    typealias Render = (A, [ValidationError]) -> Node
    typealias Parse = ([String:String]) -> A?
    let _parse: Parse
    let render: Render
    init(parse: @escaping Parse, render: @escaping Render) {
        self._parse = parse
        self.render = render
    }

    func parse(_ data: [String:String]) -> A? {
        return _parse(data)
    }
}

extension Form {
    func wrap(_ f: @escaping (Node) -> Node) -> Form<A> {
        return Form(parse: _parse, render: { value, err in
            f(self.render(value, err))
        })
    }
}

struct FormView {
    indirect enum Field {
        case input(id: String, value: String, type: String, placeHolder: String?, otherAttributes: [String:String])
        case textarea(id: String, value: String, placeHolder: String?, lines: Int, otherAttributes: [String:String])
        case fieldSet([Field], required: Bool, title: String, note: String?)
        case flex(Field, amount: Int)
        case custom(Node)


        static func text(id: String, required: Bool = true, title: String, value: String, multiline: Int? = nil, placeHolder: String? = nil, note: String? = nil) -> Field {
            let child: Field
            if let lines = multiline {
                child = .textarea(id: id, value: value, placeHolder: placeHolder, lines: lines, otherAttributes: [:])
            } else {
                child = .input(id: id, value: value, type: "text", placeHolder: placeHolder, otherAttributes: [:])
            }
            return .fieldSet([child], required: required, title: title, note: note)
        }
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

extension Swift.Collection where Element == FormView.Field {
    var firstId: String? {
        for f in self {
            switch f {
            case .input(let t):
                return t.id
            case .fieldSet(let fields, _, _, _):
                if let id = fields.firstId { return id }
            case .flex(let f, _):
                if let id = [f].firstId { return id }
            case .custom(_):
                continue
            case .textarea(let id, _, _, _, _):
                return id
            }
        }
        return nil
    }
}

extension FormView {
    func renderStacked() -> [Node] {
        func renderField(_ field: Field) -> Node {
            switch field {
            case let .fieldSet(fields, required, title, note):
                let id = fields.firstId ?? ""
                let isErr = errors.contains { $0.field == id }
                let children = fields.count == 1 ? renderField(fields[0]) : Node.div(classes: "flex items-center width-full max-width-6", fields.map(renderField))
                return Node.fieldset(classes: "input-unit mb+", [
                    Node.label(classes: "input-label" + (required ? "input-label--required" : "") + (isErr ? "color-invalid" : ""), attributes: ["for": id], [.text(title)]),
                    children,
                    note.map { Node.label(classes: "input-note mt-", attributes: ["for": id], [
                        .span(classes: "bold", [.raw("Note: ")]),
                        .raw($0)
                    ]) } ?? .none
			]
                )
            case let .input(id, value, type, placeHolder, attributes):
                var atts = ["required": "required", "value": value]
                if let p = placeHolder {
                    atts["placeholder"] = p
                }
                return Node.input(classes: "text-input block width-full max-width-6", name: id, type: type, attributes: atts.merging(attributes, uniquingKeysWith: { $1 }))
            case let .flex(field, amount):
                return Node.div(classes: Class(stringLiteral: "flex-\(amount)"), [renderField(field)])
            case let .custom(n): return n
            case .textarea(let id, let value, let placeHolder, let lines, let otherAttributes):
                return Node.textArea(classes: "text-input block width-full max-width-6", name: id, value: value, placeHolder: placeHolder, rows: lines, attributes: otherAttributes)
            }
        }
        
        return [
            errors.isEmpty ? .none : Node.ul(classes: "mb++ bgcolor-invalid color-white ms-1 pa radius-3 bold", errors.map { Node.li([Node.text($0.message)]) }),
            Node.div(classes: "", [
                Node.form(classes: classes, action: action.path, attributes: ["id": id], [
                    Node.withCSRF { csrf in Node.input(name: "csrf", id: "csrf", type: "hidden", attributes: ["value": csrf.stringValue], []) },
                    Node.div(classes: "stack+", fields.map(renderField) + [
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
