'use strict'

import React, { Component, PropTypes } from 'react'
import classnames from 'classnames'
import countries from './countries'

export default class Country extends Component {
  static propTypes = {
    defaultValue: PropTypes.string,
    onChange: PropTypes.func,
    disabled: PropTypes.bool
  }

  handleChange (e) {
    const value = e.target.value
    this.refs.realCountry.value = value
    this.props.onChange(value)
  }

  render () {
    const { disabled, error, required } = this.props
    const formGroupClass = classnames('input-unit mb+', {
      'has-error': error
    })
    const labelClass = classnames('input-label block', {
      'input-label--required': required
    })
    const inputClass = classnames('text-input inline-block width-full', 'c-select', {
      'form-control-danger': error
    })
    return (
      <fieldset className={formGroupClass}>
        <label htmlFor='country' className={labelClass}>
          Country
        </label>
        <select className={inputClass}
                id='country'
                disabled={disabled}
                defaultValue={this.props.defaultValue}
                onBlur={this.handleChange.bind(this)}
                onChange={this.handleChange.bind(this)}>
          <option value=''>Select country</option>
          {countries.map((country) => (
            <option key={country.code}
                    value={country.code}>
              {country.name}
            </option>
          ))}
        </select>
        <input type='hidden'
          id='realCountry'
          ref='realCountry'
          data-recurly='country'
          value={this.props.defaultValue}
        />
      </fieldset>
    )
  }
}
