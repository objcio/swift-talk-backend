'use strict'

import React, { Component, PropTypes } from 'react'
import classnames from 'classnames'

export default class CVV extends Component {
  static propTypes = {
    error: PropTypes.bool
  }
  render () {
    const formGroupClass = classnames('input-unit mb+', {
      'has-error': this.props.error
    })
    return (
      <fieldset className={formGroupClass}>
        <label htmlFor='cvv'
               className='input-label input-label--required block'>CVV</label>
        <div data-recurly='cvv'></div>
      </fieldset>
    )
  }
}
