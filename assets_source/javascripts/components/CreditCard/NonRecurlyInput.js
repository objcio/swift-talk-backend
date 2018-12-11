'use strict'

import React, { Component, PropTypes } from 'react'
import classnames from 'classnames'

export default class NonRecurlyInput extends Component {
  static propTypes = {
    id: PropTypes.string.isRequired,
    label: PropTypes.string.isRequired,
    defaultValue: PropTypes.string,
    disabled: PropTypes.bool,
    error: PropTypes.bool
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
               name={id}
               disabled={disabled}
               defaultValue={defaultValue || ''} />
      </fieldset>
    )
  }
}

// todo we can definitely share code between these two...
