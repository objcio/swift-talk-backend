'use strict'

import React, { Component, PropTypes } from 'react'
import classnames from 'classnames'

export default class Input extends Component {
  static propTypes = {
    id: PropTypes.string.isRequired,
    label: PropTypes.string.isRequired,
    defaultValue: PropTypes.string,
    disabled: PropTypes.bool,
    onChange: PropTypes.func,
    error: PropTypes.bool
  }

  handleChange (e) {
    const value = e.target.value
	if(this.props.onChange) {
		this.props.onChange(value)
	}
  }

  render () {
    const { id, error, label, defaultValue, disabled, required } = this.props
    const labelClass = classnames('input-label block', {
      'input-label--required': required
    })
    const formGroupClass = classnames('input-unit mb+', {
      'has-error': error
    })
    const inputClass = classnames('text-input inline-block width-full', {
      'form-control-danger': error
    })

    return (
      <fieldset className={formGroupClass}>
        <label htmlFor={id} className={labelClass}>
          {label}
        </label>
        <input type='text'
               className={inputClass}
               id={id}
               data-recurly={id}
               disabled={disabled}
               defaultValue={defaultValue || ''} 
		       onBlur={this.handleChange.bind(this)}
               onChange={this.handleChange.bind(this)} />
      </fieldset>
    )
  }
}
