
'use strict'

import 'whatwg-fetch'
import React, { Component, PropTypes } from 'react'
import CardNumber from './CardNumber'
import CVV from './CVV'
import Expiry from './Expiry'
import Input from './Input'
import NonRecurlyInput from './NonRecurlyInput'
import Country from './Country'

export default class CreditCard extends Component {
  static propTypes = {
    csrf: PropTypes.string.isRequired,
    public_key: PropTypes.string.isRequired,
    action: PropTypes.string.isRequired,
    method: PropTypes.string,
    loading: PropTypes.bool,
    buttonText: PropTypes.string.isRequired,
    onCountryChange: PropTypes.func,
    month: PropTypes.number,
    year: PropTypes.number,
    first_name: PropTypes.string,
    last_name: PropTypes.string,
    country: PropTypes.string,
    address1: PropTypes.string,
    address2: PropTypes.string,
    city: PropTypes.string,
    state: PropTypes.string,
    zip: PropTypes.string,
    children: PropTypes.node,
	showEmail: PropTypes.bool,
    payment_errors: PropTypes.arrayOf(PropTypes.string)
  }

  state = {
    card: null,
    disabled: false,
    tokenErrors: []
  }

  componentDidMount () {
    recurly.configure({
      publicKey: this.props.public_key,
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
    })
  }

  handleSubmit (e) {
    e.preventDefault()
    this.setState({disabled: true})

    var form = document.getElementById('cc-form')
    recurly.token(form, function (err, token) {
      if (err) {
        this.setState({disabled: false, tokenErrors: err.fields})
      } else {
        this.refs.token_field.value = token.id
        form.submit();
      }
    }.bind(this));
  }

  validate () {
    let valid = true
    let fields = {}
    for (let ref in this.refs) {
      if (this.refs[ref].props.required && !this.refs[ref].state.valid) {
        valid = false
        this.refs[ref].setState({error: true})
      }
      if (ref === 'expiry') {
        fields.month = this.refs[ref].state.month
        fields.year = this.refs[ref].state.year
      } else {
        fields[ref] = this.refs[ref].state.value
      }
    }
    return valid && fields
  }

  showErrors (errors, generic = true) {
    if (errors.length > 0) {
      let message = generic ? 'There were errors in the fields marked in red. Please correct and try again.' : errors.join(' ')
      return(
        <p className='mb++ bgcolor-invalid color-white ms-1 pa radius-3 bold'>
          {message}
        </p>
      )
    }
  }

  render () {
    const { month, year, first_name, last_name,
            country, address1, address2, city, state, zip,
            onCountryChange, buttonText, loading
          } = this.props
    const { disabled } = this.state
    const errors = this.state.tokenErrors

    const cardSection = (
      <div>
        <h2 className="ms1 color-blue bold mb+">
          Credit Card
        </h2>

        { this.showErrors(this.props.payment_errors, false) }

        <div className='cols'>
          <div className='col width-1/2'>
            <Input id='first_name'
                   label='First name'
                   ref='first_name'
                   error={errors.includes('first_name')}
                   defaultValue={first_name}
                   disabled={disabled}
                   required />
          </div>
          <div className='col width-1/2'>
            <Input id='last_name'
                   label='Last name'
                   ref='last_name'
                   error={errors.includes('last_name')}
                   defaultValue={last_name}
                   disabled={disabled}
                   required />
          </div>
        </div>

        <div className="cols">
          <div className="col width-full s+|width-1/2">
            <CardNumber onCardChange={(card) => this.setState({card})}
                        ref='number'
                        error={errors.includes('number')}
                        required />
          </div>
          <div className="col s+|width-1/2">
            <div className="cols">
              <div className="col width-1/3">
                <CVV card={this.state.card}
                     ref='cvv'
                     error={errors.includes("cvv")}
                     disabled={disabled}
                     required />
              </div>
              <div className="col width-2/3">
                <Expiry ref='expiry'
                        errorMonth={errors.includes('month')}
                        errorYear={errors.includes('year')}
                        disabled={disabled}
                        required />
              </div>
            </div>
          </div>
        </div>
      </div>
    )

    const billingSection = (
      <div>
        <h2 className="ms1 color-blue bold mb+ mt++">
          Billing Address
        </h2>

        <Input id='address1'
               label='Street Address'
               ref='address1'
               error={errors.includes('address1')}
               defaultValue={address1}
               disabled={disabled}
               required />
        <Input id='address2'
               label='Street Address (cont.)'
               ref='address2'
               error={errors.includes('address2')}
               defaultValue={address2}
               disabled={disabled} />
        <div className="cols">
          <div className="col width-1/2">
            <Input id='city'
                   label='City'
                   ref='city'
                   error={errors.includes('city')}
                   defaultValue={city}
                   disabled={disabled}
                   required />
          </div>
          <div className="col width-1/2">
            <Input id='state'
                   label='State'
                   ref='state'
                   error={errors.includes('state')}
                   defaultValue={state}
                   disabled={disabled}
                   required />
          </div>
          <div className="col width-1/2">
            <Input id='postal_code'
                   label='Zip/Postal code'
                   ref='zip'
                   error={errors.includes('postal_code')}
                   defaultValue={zip}
                   disabled={disabled}
                   required />
          </div>
          <div className="col width-1/2">
            <Country ref='country'
                     defaultValue={country}
                     error={errors.includes('country')}
                     disabled={disabled}
                     onChange={onCountryChange}
                     required />
          </div>
        </div>
      </div>
    )

    const emailSection = this.props.showEmail ? (
      <div>
        <h2 className="ms1 color-blue bold mb+ mt++">
          Email
        </h2>

        <NonRecurlyInput id='gifter_email'
               label='Your Email'
               ref='gifter_email'
               error={errors.includes('gifter_email')}
               defaultValue=""
               disabled={false}
               required />
      </div>
    ) : <div></div>

    const submitButton = (
      <div>
        <button type='submit'
                className='c-button c-button--wide'
                disabled={disabled || loading}>
          {(disabled || loading)
            ? <span><i className='fa fa-spinner fa-spin fa-fw' />Please wait...</span>
            : <span>{buttonText}</span>
          }
        </button>
      </div>
    )


    return (
      <form id="cc-form" method='POST'
        onSubmit={this.handleSubmit.bind(this)}
        action={this.props.action} >

        <input name="_method" value={this.props.method} type="hidden" />
        <input name="csrf" value={this.props.csrf} type='hidden' />
        <input ref='token_field' name="billing_info[token]" value='' type='hidden' />

        { React.Children.count(this.props.children) ? (
          <div className="cols m-|stack++">
            <div className="col m+|width-2/3">
              { this.showErrors(errors) }
              { cardSection }
              { billingSection }
			  { emailSection }
            </div>
            <div className="col width-full m+|width-1/3">
              { this.props.children }
              { submitButton }
            </div>
          </div>
        ) : (
          <div className="stack++">
            { this.showErrors(errors) }
            { cardSection }
            { billingSection }
            { submitButton }
          </div>
        )
        }
      </form>
    )
  }
}
