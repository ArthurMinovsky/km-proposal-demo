import { formValidation } from './formValidator'
import { verification } from './verification'

var url = window.location.href
if (url.indexOf('<link-to>confirm.html') >= 0) {
  var foo = getParameterByName('code')
  verification(foo)
}
function getParameterByName (name, url) {
  if (!url) url = window.location.href
  name = name.replace(/[\[\]]/g, '\\$&')
  var regex = new RegExp('[?&]' + name + '(=([^&#]*)|&|#|$)'),
    results = regex.exec(url)
  if (!results) return null
  if (!results[2]) return ''
  return decodeURIComponent(results[2].replace(/\+/g, ' '))
}
var theForm = document.querySelector('#registration-form')
formValidation(theForm)
