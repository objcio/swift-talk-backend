//
//  Forms.swift
//  swifttalk-server
//
//  Created by Chris Eidhof on 08.11.18.
//

import Foundation
import HTML
import WebServer


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

    var `class`: Class? = nil
    var id: String = ""
    var errors: [ValidationError] = []
    var fields: [Field]
    var submitTitle: String = "Submit"
    var submitNote: String?
    var action: Route
    init(fields: [Field], submitTitle: String = "Submit", submitNote: String? = nil, action: Route, errors: [ValidationError], id: String = "", class: Class? = nil) {
        self.fields = fields
        self.submitTitle = submitTitle
        self.submitNote = submitNote
        self.action = action
        self.errors = errors
        self.id = id
        self.class = `class`
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
                let children = fields.count == 1 ? renderField(fields[0]) : Node.div(class: "flex items-center width-full max-width-6", fields.map(renderField))
                return .fieldset(class: "input-unit mb+", [
                    .label(class: "input-label" + (required ? "input-label--required" : "") + (isErr ? "color-invalid" : ""), attributes: ["for": id], [.text(title)]),
                    children,
                    note.map { .label(class: "input-note mt-", attributes: ["for": id], [
                        .span(class: "bold", [.raw("Note: ")]),
                        .raw($0)
                    ]) } ?? .none()
			]
                )
            case let .input(id, value, type, placeHolder, attributes):
                var atts = ["required": "required", "value": value]
                if let p = placeHolder {
                    atts["placeholder"] = p
                }
                return .input(class: "text-input block width-full max-width-6", name: id, type: type, attributes: atts.merging(attributes, uniquingKeysWith: { $1 }))
            case let .flex(field, amount):
                return .div(class: Class(stringLiteral: "flex-\(amount)"), [renderField(field)])
            case let .custom(n): return n
            case .textarea(let id, let value, let placeHolder, let lines, let otherAttributes):
                return .textArea(class: "text-input block width-full max-width-6", name: id, value: value, placeHolder: placeHolder, rows: lines, attributes: otherAttributes)
            }
        }
        
        return [
            errors.isEmpty ? .none() : .ul(class: "mb++ bgcolor-invalid color-white ms-1 pa radius-3 bold", errors.map { .li([.text($0.message)]) }),
            .div(class: "", [
                .form(class: `class`, action: action.path, attributes: ["id": id], [
                    .withCSRF { csrf in .input(name: "csrf", id: "csrf", type: "hidden", attributes: ["value": csrf.string], []) },
                    .div(class: "stack+", fields.map(renderField) + [
                            .div([
                                .input(class: "c-button c-button--blue", name: "commit", type: "submit", attributes: ["value": submitTitle, "data-disable-with": submitTitle], []),
                                submitNote.map { .p(class: "ms-1 color-gray-40 mt", [.raw($0)]) } ?? .none()
                            ])
                        ])
                    ])
                ])
        ]
    }
}
