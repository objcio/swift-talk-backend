'use strict'

import React, { Component, PropTypes } from 'react'
import classnames from 'classnames'

export default class Expiry extends Component {
  static propTypes = {
    disabled: PropTypes.bool,
    errorMonth: PropTypes.bool,
    errorYear: PropTypes.bool
  }

  render () {
    const { disabled, errorMonth, errorYear } = this.props
    const formGroupClass = classnames('input-unit mb+', {
      'has-error': errorMonth || errorYear
    })

    return (
      <fieldset className={formGroupClass}>
        <label htmlFor="month"
               className="input-label input-label--required block">
          Expiration
        </label>
        <div className="flex items-center">
          <div className="flex-1" data-recurly="month"></div>
          <span className="ph- color-gray-30 bold">/</span>
          <div className="flex-2" data-recurly="year"></div>
        </div>
      </fieldset>
    )
  }
}
