'use strict'

const defaultFormat = /(\d{1,4})/g
const cards = [{
  type: 'visaelectron',
  patterns: [
    4026, 417500, 4405, 4508, 4844, 4913, 4917
  ],
  format: defaultFormat,
  length: [16],
  cvcLength: [3],
  luhn: true
}, {
  type: 'maestro',
  patterns: [
    5018, 502, 503, 506, 56, 58, 639, 6220, 67
  ],
  format: defaultFormat,
  length: [12, 13, 14, 15, 16, 17, 18, 19],
  cvcLength: [3],
  luhn: true
}, {
  type: 'forbrugsforeningen',
  patterns: [600],
  format: defaultFormat,
  length: [16],
  cvcLength: [3],
  luhn: true
}, {
  type: 'dankort',
  patterns: [5019],
  format: defaultFormat,
  length: [16],
  cvcLength: [3],
  luhn: true
}, {
  type: 'elo',
  patterns: [
    4011, 4312, 4389, 4514, 4573, 4576,
    5041, 5066, 5067, 509,
    6277, 6362, 6363, 650, 6516, 6550
  ],
  format: defaultFormat,
  length: [16],
  cvcLength: [3],
  luhn: true
}, {
  type: 'visa',
  patterns: [4],
  format: defaultFormat,
  length: [13, 16],
  cvcLength: [3],
  luhn: true
}, {
  type: 'mastercard',
  patterns: [
    51, 52, 53, 54, 55,
    22, 23, 24, 25, 26, 27
  ],
  format: defaultFormat,
  length: [16],
  cvcLength: [3],
  luhn: true
}, {
  type: 'amex',
  patterns: [34, 37],
  format: /(\d{1,4})(\d{1,6})?(\d{1,5})?/,
  length: [15],
  cvcLength: [3, 4],
  luhn: true
}, {
  type: 'dinersclub',
  patterns: [30, 36, 38, 39],
  format: /(\d{1,4})(\d{1,6})?(\d{1,4})?/,
  length: [14],
  cvcLength: [3],
  luhn: true
}, {
  type: 'discover',
  patterns: [60, 64, 65, 622],
  format: defaultFormat,
  length: [16],
  cvcLength: [3],
  luhn: true
}, {
  type: 'unionpay',
  patterns: [62, 88],
  format: defaultFormat,
  length: [16, 17, 18, 19],
  cvcLength: [3],
  luhn: false
}, {
  type: 'jcb',
  patterns: [35],
  format: defaultFormat,
  length: [16],
  cvcLength: [3],
  luhn: true
}]

export const cardFromNumber = (num) => {
  num = (num + '').replace(/\D/g, '')
  return cards.find((card) => (
    card.patterns.some((pattern) => {
      const p = pattern + ''
      return num.substr(0, p.length) === p
    })
  ))
}

export const luhnCheck = (num) => {
  const digits = (num + '').split('').reverse()
  const sum = digits.reduce((sum, digit, index) => {
    digit = parseInt(digit, 10)
    if (index % 2) digit *= 2
    if (digit > 9) digit -= 9
    return sum + digit
  }, 0)
  return sum % 10 === 0
}

export const validateCardNumber = (num) => {
  num = (num + '').replace(/\s+|-/g, '')
  if (!/^\d+$/.test(num)) { return false }
  const card = cardFromNumber(num)
  return card && card.length.includes(num.length) && (!card.luhn || luhnCheck(num))
}
