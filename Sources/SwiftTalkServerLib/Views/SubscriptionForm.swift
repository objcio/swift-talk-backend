//
//  SubscriptionForm.swift
//  SwiftTalkServerLib
//
//  Created by Florian Kugler on 23-07-2019.
//

import Foundation
import HTML

func subscriptionForm(_ data: SubscriptionFormData, action: Route) -> Node {
    let planRadios: [Node] = data.plans.map { plan in
        var a: [String: String] = ["value": plan.plan_code]
        if plan.plan_code == data.plan {
            a["checked"] = "true"
        }
        return .input(class: "visuallyhidden", name: "plan_id", id: "plan_id\(plan.plan_code)", type: "radio", attributes: a)
    }
    return .withCSRF { csrf in
        Node.div(class: "container", [
            .form(action: action.path, method: .post, attributes: ["id": "cc-form"], planRadios + [
                .input(name: "_method", type: "hidden", attributes: ["value": "POST"]),
                .input(name: "csrf", id: "csrf", type: "hidden", attributes: ["value": csrf.string]),
                .input(name: "billing_info[token]", type: "hidden", attributes: ["value": ""]),
                .div(class: "cols m-|stack++", [
                    .div(class: "col m+|width-2/3", [
                        .p(class: "mb++ bgcolor-invalid color-white ms-1 pa radius-3 bold", attributes: ["id": "errors"], []),
                        data.gift ? giftSection() : .div(),
                        creditCardSection(),
                        billingDetailsSection()
                    ]),
                    .div(class: "col width-full m+|width-1/3", attributes: ["id": "pricingInfo"])
                ])
            ]),
            .script(code: formJS(recurlyPublicKey: env.recurlyPublicKey, data: data))
        ])
    }
}

fileprivate func giftSection() -> Node {
    return .div(class: "mb+++", [
        textField(name: "gifter_name", title: "Your Name"),
        textField(name: "gifter_email", title: "Your Email"),
    ]);
}

fileprivate func field(name: String, title: String, required: Bool = true, input: Node) -> Node {
    return Node.fieldset(class: "input-unit mb+", attributes: ["id": name], [
        .label(class: "input-label block" + (required ? "input-label--required" : ""), attributes: ["for": name], [.text(title)]),
        input
    ])
}

fileprivate func textField(name: String, title: String, required: Bool = true) -> Node {
    return field(name: name, title: title, required: required, input:
        .input(class: "text-input inline-block width-full form-control-danger", name: name, id: name, type: "text", attributes: ["data-recurly": name])
    )
}

fileprivate func recurlyField(name: String, title: String, required: Bool = true) -> Node {
    return field(name: name, title: title, required: required, input: .div(attributes: ["data-recurly": name]))
}

fileprivate func creditCardSection() -> Node {
    return Node.div([
        .h2(class: "ms1 color-blue bold mb+", ["Credit Card"]),
        .div(class: "cols", [
            .div(class: "col width-1/2", [textField(name: "first_name", title: "First name")]),
            .div(class: "col width-1/2", [textField(name: "last_name", title: "Last name")]),
        ]),
        .div(class: "cols", [
            .div(class: "col width-full s+|width-1/2", [recurlyField(name: "number", title: "Number")]),
            .div(class: "col s+|width-1/2", [
                .div(class: "cols", [
                    .div(class: "col width-1/3", [recurlyField(name: "cvv", title: "CVV")]),
                    .div(class: "col width-2/3", [
                        .fieldset(class: "input-unit mb+", attributes: ["id": "expiry"], [
                            .label(class: "input-label input-label--required block", attributes: ["for": "month"], ["Expiration"]),
                            .div(class: "flex items-center", [
                                .div(class: "flex-1", attributes: ["data-recurly": "month"]),
                                .span(class: "ph- color-gray-30 bold", ["/"]),
                                .div(class: "flex-2", attributes: ["data-recurly": "year"]),
                            ])
                        ])
                    ])
                ])
            ])
        ])
    ])
}

fileprivate func billingDetailsSection() -> Node {
    return .div([
        .h2(class: "ms1 color-blue bold mb+ mt++", ["Billing Address"]),
        textField(name: "address1", title: "Street Address"),
        textField(name: "address2", title: "Street Address (cont.)", required: false),
        .div(class: "cols", [
            .div(class: "col width-1/2", [textField(name: "city", title: "City")]),
            .div(class: "col width-1/2", [textField(name: "state", title: "State")]),
            .div(class: "col width-1/2", [textField(name: "postal_code", title: "Zip/Postal code")]),
            .div(class: "col width-1/2", [
                field(name: "country", title: "Country", input: Node.select(class: "text-input inline-block width-full c-select", name: "country", attributes: ["id": "country"], options: countries)),
                .input(name: "realCountry", id: "realCountry", type: "hidden", attributes: ["data-recurly": "country"])
            ]),
        ]),
        .div(class: "cols", [
            .div(class: "col width-1/2", [textField(name: "company", title: "Company", required: false)]),
            .div(class: "col width-1/2", [textField(name: "vat_number", title: "EU VAT ID (if applicable)", required: false)]),
        ])
    ])
}

fileprivate struct JSONOptional<A: Encodable>: Encodable, ExpressibleByNilLiteral {
    var value: A?
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let v = value {
            try container.encode(v)
        } else {
            try container.encodeNil()
        }
    }
    
    init(_ value: A?) {
        self.value = value
    }
    
    init(nilLiteral: ()) {
        self.value = nil
    }
}

fileprivate struct FormPlan: Codable {
    var id: String
    var base_price: Int
    var interval: String
    var plan_code: String
    
    init(_ plan: Plan) {
        id = plan.plan_code
        base_price = plan.unit_amount_in_cents.usdCents
        interval = plan.prettyDuration
        plan_code = plan.plan_code
    }
}

fileprivate struct FormCoupon: Encodable {
    var code: String
    var discount_type: String
    var discount_percent: JSONOptional<Int>
    var description: String
    var discount_in_cents: JSONOptional<Amount>
    var free_trial_amount: JSONOptional<Int>
    var free_trial_unit: JSONOptional<TemporalUnit>

    init(_ coupon: Coupon) {
        code = coupon.coupon_code
        discount_type = coupon.discount_type.rawValue
        description = coupon.description
        discount_percent = JSONOptional(coupon.discount_percent)
        discount_in_cents = JSONOptional(coupon.discount_in_cents)
        free_trial_amount = JSONOptional(coupon.free_trial_amount)
        free_trial_unit = JSONOptional(coupon.free_trial_unit)
    }
}

struct SubscriptionFormData: Encodable {
    fileprivate var gift: Bool = false
    fileprivate var plans: [FormPlan]
    fileprivate var errors: [String] = []
    fileprivate var paymentErrors: [String]
    fileprivate var loading: Bool = false
    fileprivate var plan: String
    fileprivate var vatRate: JSONOptional<Double> = nil
    fileprivate var country: JSONOptional<String> = nil
    fileprivate var coupon: JSONOptional<FormCoupon> = nil
    fileprivate var belowButtonText: String = ""
    
    init(giftPlan: Plan, startDate: String, paymentErrors: [String] = []) {
        self.gift = true
        self.plans = [FormPlan(giftPlan)]
        self.plan = giftPlan.plan_code
        self.paymentErrors = paymentErrors
        self.belowButtonText = "Your card will be billed on \(startDate)."
    }
    
    init(plans: [Plan], selectedPlan: Plan, coupon: SwiftTalkServerLib.Coupon? = nil, paymentErrors: [String] = []) {
        self.plans = plans.map { .init($0) }
        self.plan = selectedPlan.plan_code
        self.paymentErrors = paymentErrors
        self.coupon = JSONOptional(coupon.map { .init($0) })
    }
}




fileprivate func formJS(recurlyPublicKey: String, data: SubscriptionFormData) -> String {
    let data = try! JSONEncoder().encode(data)
    let json = String(data: data, encoding: .utf8)!
    return """
const recurlyPublicKey = '\(recurlyPublicKey)';
var state = \(json);

function setState(newState) {
    Object.keys(newState).forEach((key) => {
        state[key] = newState[key];
    });
    update();
}

function formatAmount(amount, forcePadding) {
    if (!forcePadding && Math.floor(amount/100) == amount/100) {
        return `$${amount/100}`
    } else {
        return `$${(amount / 100).toFixed(2)}`;
    }
};

function computeDiscountedPrice (basePrice, coupon) {
    if (coupon == null) {
        return basePrice
    }
    let price = basePrice
    switch (coupon.discount_type) {
        case "dollars":
            price = basePrice - coupon.discount_in_cents.USD
            if (price < 0) { price = 0 }
            break
        case "percent":
            price = basePrice * (100 - coupon.discount_percent) / 100
            break
    }
    return price
}


function update() {
    function removeErrors() {
        document.querySelectorAll('fieldset.input-unit').forEach((fs) => {
            fs.classList.remove('has-error');
        });
    }
    
    function showErrors() {
        const errorContainer = document.getElementById('errors');
        if (state.errors.length > 0 || state.paymentErrors.length > 0) {
            let message = [
                'There were errors in the fields marked in red. Please correct and try again.'
            ].concat(state.paymentErrors).join('<br/>');
            errorContainer.innerHTML = message;
            errorContainer.hidden = false

            state.errors.forEach((fieldName) => {
                if (fieldName == "year" || fieldName == "month") {
                    fieldName = "expiry";
                }
                const fieldSet = document.querySelector('fieldset#' + fieldName);
                if (fieldSet) {
                    fieldSet.classList.add('has-error');
                }
            });
        } else {
            errorContainer.hidden = true
        }
    }
    
    function updatePricingInfo() {
        const pricingContainer = document.getElementById('pricingInfo');
        if (!pricingContainer) return;
    
        const selectedPlan = state.plans.find((plan) => {
            return plan.id === state.plan;
        });
    
        let html = [];
    
        if (state.gift) {
            html.push(`
                <div class="pa border-bottom border-color-white border-2 flex justify-between items-center">
                    <span class="smallcaps-large">Gift</span>
                    <span class="bold">${selectedPlan.interval} of Swift Talk</span>
                </div>
            `);
        } else {
            html.push(`
                <div class="pv ph- border-bottom border-color-white border-2 flex">
                    ${
                        state.plans.map((plan) => {
                            return `
                                <div class="flex-1 block mh- pv ph-- radius-5 cursor-pointer border border-2 text-center ${plan.id === state.plan ? 'color-white border-color-transparent bgcolor-blue' : 'color-gray-60 border-color-gray-90'}">
                                    <input type="radio" name="plan_id" value="${plan.id}" id="plan_id${plan.id}" class="visuallyhidden">
                                    <label for="plan_id${plan.id}" class="block cursor-pointer">
                                        <div class="smallcaps mb">${plan.interval}</div>
                                        <div class="ms3 bold">${formatAmount(plan.base_price)}</div>
                                    </label>
                                </div>
                            `;
                        }).join('')
                    }
                </div>
            `);
        }
    
        html.push(`
            <div class="pa border-bottom border-color-white border-2 flex justify-between items-center">
                <span class="smallcaps-large">Price</span>
                <span>${formatAmount(selectedPlan.base_price, true)}</span>
            </div>
        `);
    
        var discountedPrice = selectedPlan.base_price;
        if (state.coupon !== null && state.coupon.discount_type) {
            html.push(`
                <div class="pa border-bottom border-color-white border-2">
                    <span class="ms-1">${state.coupon.description}</span>
                </div>
            `);
            if (state.coupon.discount_type !== 'free_trial') {
                discountedPrice = computeDiscountedPrice(selectedPlan.base_price, state.coupon);
                html.push(`
                    <div class="pa border-bottom border-color-white border-2 flex justify-between items-center">
                        <span class="smallcaps-large">Discount</span>
                        <span>${formatAmount(selectedPlan.base_price - discountedPrice)}</span>
                    </div>
                `);
            }
        }

        var taxAmount = 0;
        const vatNumber = (document.querySelector('input#vat_number').value || "")
        const vatExempt = vatNumber.length > 0 && state.country != "DE"
        if (state.vatRate !== null) {
            if (vatExempt) {
                html.push(`
                    <div class="pa border-bottom border-color-white border-2 flex justify-between items-center">
                        <span>VAT Exempt</span>
                    </div>
                `)
            } else {
                taxAmount = discountedPrice * state.vatRate;
                html.push(`
                    <div class="pa border-bottom border-color-white border-2 flex justify-between items-center">
                      <span className="smallcaps-large">VAT (${state.vatRate * 100}%)</span>
                      <span>${formatAmount(taxAmount, true)}</span>
                    </div>
                `);
            }
        }
    
        html.push(`
            <div class="bgcolor-gray-90 color-gray-15 bold pa flex justify-between items-center">
                <span class="smallcaps-large">Total</span>
                <span>${formatAmount(discountedPrice + taxAmount, true)}</span>
            </div>
        `);
    
        pricingContainer.innerHTML = `
            <div class="bgcolor-gray-95 color-gray-40 radius-5 overflow-hidden mb">
                ${html.join('')}
            </div>
            <div>
                <button type='submit' class='c-button c-button--wide' ${state.loading ? 'disabled' : ''}>
                    ${state.loading
                        ? "<span><i class='fa fa-spinner fa-spin fa-fw'></i>Please wait...</span>"
                        : "<span>Subscribe</span>"
                    }
                </button>
                <p class="mt color-gray-60 ms-1 text-center">${state.belowButtonText}</p>
            </div>
        `;
    }
    
    removeErrors();
    showErrors();
    updatePricingInfo();
    addPlanListeners();
}

var taxRequestPromise = null;

function fetchTaxRate(country, callback) {
    if (country) {
        setState({ loading: true });
        var currentPromise = window.fetch('https://api.recurly.com/js/v1/tax?country=' + country + '&tax_code=digital&version=4.0.4&key=' + recurlyPublicKey).then(function(response) {
            return response.json();
        }).then(function(json) {
            if (currentPromise === taxRequestPromise) {
                setState({ loading: false });
                callback(json[0] || null);
            }
        });
        taxRequestPromise = currentPromise;
    } else {
        callback(null);
    }
}

function configureRecurly() {
    recurly.configure({
        publicKey: recurlyPublicKey,
        style: {
            all: {
                fontFamily: 'Cousine',
                fontSize: '20px',
                fontColor: '#4d4d4d',
                placeholder: {
                    fontColor: '#bfbfbf !important'
                }
            },
            number: {
                placeholder: {
                    content: '•••• •••• •••• ••••'
                }
            },
            month: {
                placeholder: {
                    content: 'MM'
                }
            },
            year: {
                placeholder: {
                    content: 'YYYY'
                }
            },
            cvv: {
                placeholder: {
                    content: '•••',
                }
            }
        }
    });
}

function handleSubmit(e) {
    e.preventDefault()
    setState({ loading: true })

    var form = document.querySelector('form#cc-form');
    recurly.token(form, function (err, token) {
        if (err) {
            setState({ loading: false, errors: err.fields })
        } else {
            setState({ errors: [] });
            document.querySelector('input[name="billing_info[token]"]').value = token.id
            form.submit();
        }
    });
}

function handleCountryChange(event) {
    const country = event.target.value;
    document.querySelector('input#realCountry').value = country;
    fetchTaxRate(country, function(taxInfo) {
        setState({
            vatRate: taxInfo !== null ? Number.parseFloat(taxInfo.rate) : null,
            country: country
        });
    });
}

function addPlanListeners() {
    const planButtons = document.querySelectorAll('input[name="plan_id"]');
    planButtons.forEach(function(button) {
        button.addEventListener('change', (event) => {
            setState({ plan: event.target.value });
        });
    });
}

window.addEventListener('DOMContentLoaded', (event) => {
    update();
    document.querySelector('form#cc-form').addEventListener('submit', handleSubmit);
    const countryField = document.querySelector('select#country');
    countryField.addEventListener('change', handleCountryChange);
    countryField.addEventListener('blur', handleCountryChange);
    document.querySelector('input#vat_number').addEventListener('change', update);
    addPlanListeners();
    configureRecurly();
});
"""
}


fileprivate let countries: [(String, String)] = [
    ("", "Select Country"),
    ("AX", "Åland Islands"),
    ("AL", "Albania"),
    ("DZ", "Algeria"),
    ("AS", "American Samoa"),
    ("AD", "Andorra"),
    ("AO", "Angola"),
    ("AI", "Anguilla"),
    ("AQ", "Antarctica"),
    ("AG", "Antigua and Barbuda"),
    ("AR", "Argentina"),
    ("AM", "Armenia"),
    ("AW", "Aruba"),
    ("AU", "Australia"),
    ("AT", "Austria"),
    ("AZ", "Azerbaijan"),
    ("BS", "Bahamas"),
    ("BH", "Bahrain"),
    ("BD", "Bangladesh"),
    ("BB", "Barbados"),
    ("BY", "Belarus"),
    ("BE", "Belgium"),
    ("BZ", "Belize"),
    ("BJ", "Benin"),
    ("BM", "Bermuda"),
    ("BT", "Bhutan"),
    ("BO", "Bolivia"),
    ("BA", "Bosnia and Herzegovina"),
    ("BW", "Botswana"),
    ("BV", "Bouvet Island"),
    ("BR", "Brazil"),
    ("IO", "British Indian Ocean Territory"),
    ("BN", "Brunei Darussalam"),
    ("BG", "Bulgaria"),
    ("BF", "Burkina Faso"),
    ("BI", "Burundi"),
    ("KH", "Cambodia"),
    ("CM", "Cameroon"),
    ("CA", "Canada"),
    ("CV", "Cape Verde"),
    ("KY", "Cayman Islands"),
    ("CF", "Central African Republic"),
    ("TD", "Chad"),
    ("CL", "Chile"),
    ("CN", "China"),
    ("CX", "Christmas Island"),
    ("CC", "Cocos (Keeling) Islands"),
    ("CO", "Colombia"),
    ("KM", "Comoros"),
    ("CG", "Congo"),
    ("CD", "Congo, The Democratic Republic of the"),
    ("CK", "Cook Islands"),
    ("CR", "Costa Rica"),
    ("CI", "Cote D'Ivoire"),
    ("HR", "Croatia"),
    ("CU", "Cuba"),
    ("CY", "Cyprus"),
    ("CZ", "Czech Republic"),
    ("DK", "Denmark"),
    ("DJ", "Djibouti"),
    ("DM", "Dominica"),
    ("DO", "Dominican Republic"),
    ("EC", "Ecuador"),
    ("EG", "Egypt"),
    ("SV", "El Salvador"),
    ("GQ", "Equatorial Guinea"),
    ("ER", "Eritrea"),
    ("EE", "Estonia"),
    ("ET", "Ethiopia"),
    ("FK", "Falkland Islands (Malvinas)"),
    ("FO", "Faroe Islands"),
    ("FJ", "Fiji"),
    ("FI", "Finland"),
    ("FR", "France"),
    ("GF", "French Guiana"),
    ("PF", "French Polynesia"),
    ("TF", "French Southern Territories"),
    ("GA", "Gabon"),
    ("GM", "Gambia"),
    ("GE", "Georgia"),
    ("DE", "Germany"),
    ("GH", "Ghana"),
    ("GI", "Gibraltar"),
    ("GR", "Greece"),
    ("GL", "Greenland"),
    ("GD", "Grenada"),
    ("GP", "Guadeloupe"),
    ("GU", "Guam"),
    ("GT", "Guatemala"),
    ("GG", "Guernsey"),
    ("GN", "Guinea"),
    ("GW", "Guinea-Bissau"),
    ("GY", "Guyana"),
    ("HT", "Haiti"),
    ("HM", "Heard Island and Mcdonald Islands"),
    ("VA", "Holy See (Vatican City State)"),
    ("HN", "Honduras"),
    ("HK", "Hong Kong"),
    ("HU", "Hungary"),
    ("IS", "Iceland"),
    ("IN", "India"),
    ("ID", "Indonesia"),
    ("IR", "Iran, Islamic Republic Of"),
    ("IQ", "Iraq"),
    ("IE", "Ireland"),
    ("IM", "Isle of Man"),
    ("IL", "Israel"),
    ("IT", "Italy"),
    ("JM", "Jamaica"),
    ("JP", "Japan"),
    ("JE", "Jersey"),
    ("JO", "Jordan"),
    ("KZ", "Kazakhstan"),
    ("KE", "Kenya"),
    ("KI", "Kiribati"),
    ("KP", "Democratic People's Republic of Korea"),
    ("KR", "Korea, Republic of"),
    ("XK", "Kosovo"),
    ("KW", "Kuwait"),
    ("KG", "Kyrgyzstan"),
    ("LA", "Lao People's Democratic Republic"),
    ("LV", "Latvia"),
    ("LB", "Lebanon"),
    ("LS", "Lesotho"),
    ("LR", "Liberia"),
    ("LY", "Libyan Arab Jamahiriya"),
    ("LI", "Liechtenstein"),
    ("LT", "Lithuania"),
    ("LU", "Luxembourg"),
    ("MO", "Macao"),
    ("MK", "Macedonia, The Former Yugoslav Republic of"),
    ("MG", "Madagascar"),
    ("MW", "Malawi"),
    ("MY", "Malaysia"),
    ("MV", "Maldives"),
    ("ML", "Mali"),
    ("MT", "Malta"),
    ("MH", "Marshall Islands"),
    ("MQ", "Martinique"),
    ("MR", "Mauritania"),
    ("MU", "Mauritius"),
    ("YT", "Mayotte"),
    ("MX", "Mexico"),
    ("FM", "Micronesia, Federated States of"),
    ("MD", "Moldova, Republic of"),
    ("MC", "Monaco"),
    ("MN", "Mongolia"),
    ("ME", "Montenegro"),
    ("MS", "Montserrat"),
    ("MA", "Morocco"),
    ("MZ", "Mozambique"),
    ("MM", "Myanmar"),
    ("NA", "Namibia"),
    ("NR", "Nauru"),
    ("NP", "Nepal"),
    ("NL", "Netherlands"),
    ("AN", "Netherlands Antilles"),
    ("NC", "New Caledonia"),
    ("NZ", "New Zealand"),
    ("NI", "Nicaragua"),
    ("NE", "Niger"),
    ("NG", "Nigeria"),
    ("NU", "Niue"),
    ("NF", "Norfolk Island"),
    ("MP", "Northern Mariana Islands"),
    ("NO", "Norway"),
    ("OM", "Oman"),
    ("PK", "Pakistan"),
    ("PW", "Palau"),
    ("PS", "Palestinian Territory, Occupied"),
    ("PA", "Panama"),
    ("PG", "Papua New Guinea"),
    ("PY", "Paraguay"),
    ("PE", "Peru"),
    ("PH", "Philippines"),
    ("PN", "Pitcairn"),
    ("PL", "Poland"),
    ("PT", "Portugal"),
    ("PR", "Puerto Rico"),
    ("QA", "Qatar"),
    ("RE", "Reunion"),
    ("RO", "Romania"),
    ("RU", "Russian Federation"),
    ("RW", "Rwanda"),
    ("SH", "Saint Helena"),
    ("KN", "Saint Kitts and Nevis"),
    ("LC", "Saint Lucia"),
    ("PM", "Saint Pierre and Miquelon"),
    ("VC", "Saint Vincent and the Grenadines"),
    ("WS", "Samoa"),
    ("SM", "San Marino"),
    ("ST", "Sao Tome and Principe"),
    ("SA", "Saudi Arabia"),
    ("SN", "Senegal"),
    ("RS", "Serbia"),
    ("SC", "Seychelles"),
    ("SL", "Sierra Leone"),
    ("SG", "Singapore"),
    ("SK", "Slovakia"),
    ("SI", "Slovenia"),
    ("SB", "Solomon Islands"),
    ("SO", "Somalia"),
    ("ZA", "South Africa"),
    ("GS", "South Georgia and the South Sandwich Islands"),
    ("ES", "Spain"),
    ("LK", "Sri Lanka"),
    ("SD", "Sudan"),
    ("SR", "Suriname"),
    ("SJ", "Svalbard and Jan Mayen"),
    ("SZ", "Swaziland"),
    ("SE", "Sweden"),
    ("CH", "Switzerland"),
    ("SY", "Syrian Arab Republic"),
    ("TW", "Taiwan"),
    ("TJ", "Tajikistan"),
    ("TZ", "Tanzania, United Republic of"),
    ("TH", "Thailand"),
    ("TL", "Timor-Leste"),
    ("TG", "Togo"),
    ("TK", "Tokelau"),
    ("TO", "Tonga"),
    ("TT", "Trinidad and Tobago"),
    ("TN", "Tunisia"),
    ("TR", "Turkey"),
    ("TM", "Turkmenistan"),
    ("TC", "Turks and Caicos Islands"),
    ("TV", "Tuvalu"),
    ("UG", "Uganda"),
    ("UA", "Ukraine"),
    ("AE", "United Arab Emirates"),
    ("GB", "United Kingdom"),
    ("US", "United States"),
    ("UM", "United States Minor Outlying Islands"),
    ("UY", "Uruguay"),
    ("UZ", "Uzbekistan"),
    ("VU", "Vanuatu"),
    ("VE", "Venezuela"),
    ("VN", "Viet Nam"),
    ("VG", "Virgin Islands, British"),
    ("VI", "Virgin Islands, U.S."),
    ("WF", "Wallis and Futuna"),
    ("EH", "Western Sahara"),
    ("YE", "Yemen"),
    ("ZM", "Zambia"),
    ("ZW", "Zimbabwe")
]

