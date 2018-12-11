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
    start_date: PropTypes.string.isRequired,
    action: PropTypes.string.isRequired,
    start_date: PropTypes.string.isRequired,
    payment_errors: PropTypes.arrayOf(PropTypes.string),
    plan: PropTypes.shape({
      id: PropTypes.string.isRequired,
      base_price: PropTypes.number.isRequired,
      interval: PropTypes.string.isRequired
    }),
  }

  state = {
    tax: null,
  }

  taxRequestPromise = null

  constructor(props) {
    super(props)
    this.state =  {
        tax: null
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



  render () {
    const { plan } = this.props
    const { tax } = this.state
    const { base_price, interval } = plan
    const taxAmount = base_price * (tax ? tax.rate : 0)
    const total = base_price + taxAmount
    return (
      <CreditCard {...this.props}
                  onCountryChange={this.fetchTaxRate.bind(this)}
                  loading={this.state.loading}
		          showEmailAndName={true}
                  buttonText='Buy'
		          belowButtonText={"Your card will be billed on " + this.props.start_date + "."}>

        <div className="bgcolor-gray-95 color-gray-40 radius-5 overflow-hidden mb">
          <div className="pa border-bottom border-color-white border-2 flex justify-between items-center">
            <span className="smallcaps-large">Gift</span>
            <span className="bold">{interval} of Swift Talk</span>
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
