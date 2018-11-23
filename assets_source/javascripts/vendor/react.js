'use strict'

import React from 'react'
import ReactDOM from 'react-dom'
import _merge from 'lodash/merge'

const renderComponent = (components, defaultProps, el) => {
  const params = _merge({}, defaultProps, JSON.parse(el.dataset.params))
  ReactDOM.render(
    React.createElement(components[el.dataset.component], params),
    el
  )
}

export const renderComponents = (components, defaultProps = {}) => {
  window.addEventListener('DOMContentLoaded', () => {
    const nodes = document.getElementsByClassName('react-component')
    for (var i = 0; i < nodes.length; i++) {
      renderComponent(components, defaultProps, nodes[i])
    }
  }, false)
}
