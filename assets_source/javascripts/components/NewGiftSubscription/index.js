'use strict'

import 'whatwg-fetch'
import React, { Component, PropTypes } from 'react'
import a from 'accounting-js'
import CreditCard from '../CreditCard'
import classnames from 'classnames'

export default class NewGiftSubscription extends Component {
  static propTypes = {
    csrf: PropTypes.string.isRequired,
    public_key: PropTypes.string.isRequired,
    action: PropTypes.string.isRequired,
    payment_errors: PropTypes.arrayOf(PropTypes.string),
    plans: PropTypes.arrayOf(PropTypes.shape({
      id: PropTypes.string.isRequired,
      base_price: PropTypes.number.isRequired,
      interval: PropTypes.string.isRequired
    })),
  }

  state = {
    tax: null,
    selected_plan_id: null
  }

  taxRequestPromise = null

  constructor(props) {
    super(props)
    this.state =  {
        tax: null,
        selected_plan_id: props.plans[0].id
    }
  }

  fetchTaxRate (country) {
    if (country) {
      const { public_key } = this.props
      // We check whether `currentPromise` is the same as `taxRequestPromise` within the callback.
      // This is to make sure that we only listen to the results of the last `fetch` request we
      // sent, otherwise we might update our component with an old value.

      this.setState({loading: true})

      var currentPromise = window.fetch(`https://api.recurly.com/js/v1/tax?country=${country}&tax_code=digital&version=4.0.4&key=${public_key}`)
        .then((response) => (response.json()))
        .then((json) => {
          if (currentPromise === this.taxRequestPromise) {
            this.setState({tax: json[0] || null, loading: false})
          }
        })
      this.taxRequestPromise = currentPromise
    } else {
      this.setState({tax: null})
    }
  }


  handleSelectedPlanChange(event) {
      this.setState({selected_plan_id: event.target.value})
  }


  render () {
    const { plans } = this.props
    const { tax, selected_plan_id } = this.state
    const selected_plan = plans.find(p => p.id === selected_plan_id)
    const { base_price, interval } = selected_plan
    const taxAmount = base_price * (tax ? tax.rate : 0)
    const total = base_price + taxAmount
    return (
      <CreditCard {...this.props}
                  onCountryChange={this.fetchTaxRate.bind(this)}
                  loading={this.state.loading}
                  buttonText='Buy'>

        <div className="bgcolor-gray-95 color-gray-40 radius-5 overflow-hidden mb">
          <div className="pv ph- border-bottom border-color-white border-2 flex">
            {
              this.props.plans.map((plan) => {
                const key = "plan_id"+plan.id
                const isChecked = plan.id === selected_plan_id
                const optionClasses = classnames({
                  'flex-1 block mh- pv ph-- radius-5 cursor-pointer border border-2 text-center': true,
                  'color-gray-60 border-color-gray-90': !isChecked,
                  'color-white border-color-transparent bgcolor-blue': isChecked
                })
                return (
                  <div key={key} className={optionClasses}>
                    <input type="radio" name="plan_id" value={plan.id} id={key} onChange={this.handleSelectedPlanChange.bind(this)} checked={isChecked} className="visuallyhidden" />
                    <label htmlFor={key} className="block cursor-pointer">
                      <div className="smallcaps mb">{ plan.interval }</div>
                      <div className="ms3 bold">{ a.formatMoney(plan.base_price / 100, {symbol: '$', precision: 0}) }</div>
                    </label>
                  </div>
                )
              })
            }
          </div>
          <div className="pa border-bottom border-color-white border-2 flex justify-between items-center">
            <span className="smallcaps-large">Price</span>
            <span>{a.formatMoney(base_price / 100, '$')}</span>
          </div>
          {tax && (
            <div className="pa border-bottom border-color-white border-2 flex justify-between items-center">
              <span className="smallcaps-large">{tax.type.toUpperCase()} ({tax.rate * 100}%)</span>
              <span>{a.formatMoney(taxAmount / 100, '$')}</span>
            </div>
          )}
          <div className="bgcolor-gray-90 color-gray-15 bold pa flex justify-between items-center">
            <span className="smallcaps-large">Total</span>
            <span>{a.formatMoney(total / 100, '$')}</span>
          </div>
        </div>

      </CreditCard>
    )
  }
}