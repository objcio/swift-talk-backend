'use strict'

import React, { Component, PropTypes } from 'react'
import classnames from 'classnames'

export default class CardNumber extends Component {
  static propTypes = {
    error: PropTypes.bool
  }

  render () {
    const formGroupClass = classnames('input-unit mb+', {
      'has-error': this.props.error
    })
    return (
      <fieldset className={formGroupClass}>
        <label htmlFor='number'
               className='input-label input-label--required block'>Number</label>
          <div data-recurly="number" />
      </fieldset>
    )
  }
}
