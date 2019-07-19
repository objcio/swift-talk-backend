const recurlyPublicKey = 'ewr1-ROWzE5cnTqZOhaaWVJNKY2';

const plans = [{
    id: "monthly-test",
    base_price: 1900,
    interval: 'monthly'
}, {
    id: 'yearly-test',
    base_price: 15000,
    interval: 'yearly'
}];

var state = {
    loading: false,
    plan: 'monthly-test',
    vatRate: null,
    country: null,
    coupon: {
        code: 'code',
        discount_type: 'percent',
        discount_percent: 30,
        description: '30% off!',
        discount_in_cents: { USD: 500 },
        free_trial_amount: null,
        free_trial_unit: null
    }
};

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
    console.log(state);

    const selectedPlan = plans.find((plan) => {
        return plan.id === state.plan;
    });
    
    html = [
        `<div class="pv ph- border-bottom border-color-white border-2 flex">
            ${
                plans.map((plan) => {
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
        </div>`,
        `<div class="pa border-bottom border-color-white border-2 flex justify-between items-center">
            <span class="smallcaps-large">Price</span>
            <span>${formatAmount(selectedPlan.base_price, true)}</span>
        </div>`
    ];
    
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
    const vatNumber = (document.getElementById('vat_number').value || "")
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
    
    document.getElementById('pricingInfo').innerHTML = `
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
            ${false ? '<p className="mt color-gray-60 ms-1 text-center">Below button text</p>' : '<br/>'}
        </div>
    `;
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
    document.getElementById('country').addEventListener('change', (event) => {
        const country = event.target.value;
        fetchTaxRate(country, function(taxInfo) {
            setState({
                vatRate: taxInfo !== null ? Number.parseFloat(taxInfo.rate) : null,
                country: country
            });
        });
    });
    document.getElementById('vat_number').addEventListener('change', (event) => {
        update()
    });
    addPlanListeners();
});
