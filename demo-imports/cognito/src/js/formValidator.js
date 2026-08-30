import { exportFormData } from './exportFormData'
export function formValidation (theForm) {
  theForm.novalidate = true

  theForm.addEventListener('submit', function (evt) {
    if (validateForm(theForm) === false) {
      evt.preventDefault()
    } else {
      var formData = serializeObject(theForm)
      exportFormData(formData)
      evt.preventDefault()
    }
  }, true)

  function validateForm (theForm) {
    var isError = false
    var elements = theForm.elements
    for (var i = 0; i < elements.length; i += 1) {
      var isValid = isFieldValid(elements[i])
      if (isValid === false) {
        isError = true
      }
    }
    return !isError
  }

  function isFieldValid (field) {
    var errorMessage = ''
    if (!needsToBeValidated(field)) return true
    field.value = sanitize(field)
    field.classList.remove('invalid')
    var errorSpan = document.querySelector('#' + field.id + '-error')
    if (errorSpan) {
      errorSpan.innerHTML = ''
      errorSpan.classList.remove('warning')
    }
    if (field.dataset.text === 'non-digit' && !validText(field.value)) {
      errorMessage = '** Must be a character.'
    }
    if (field.type === 'tel' && !validPhoneNumber(field.value)) {
      errorMessage = '** Provide a valid phone number.'
    }
    if (field.type === 'number' && field.min > 0 && field.value < parseInt(field.min)) {
      errorMessage = '** Must be atleast ' + field.min + ' or greater.'
    }
    if (field.type === 'number' && field.max > 0 && field.value > parseInt(field.max)) {
      errorMessage = '** Must be ' + field.max + ' or less.'
    }
    if (field.minLength > 0 && field.value.length < field.minLength) {
      errorMessage = '** Atleast ' + field.minLength + ' characters.'
    }
    if (field.type === 'email' && !isEmail(field.value)) {
      errorMessage = '** Provide a valid email.'
    }
    if (field.required && field.value.trim() === '') {
      errorMessage = '** This field is required.'
    }
    if (errorMessage !== '') {
      field.classList.add('invalid')
      errorSpan = document.querySelector('#' + field.id + '-error')
      if (errorSpan) {
        errorSpan.innerHTML = errorMessage
        errorSpan.classList.add('warning')
      }
      return false
    }
    return true
  }
  function needsToBeValidated (field) {
    var skipElements = ['button', 'submit']
    return skipElements.indexOf(field.type) === -1
  }
  function isEmail (input) {
    return input.match(/^([a-zA-Z0-9_.+-]+)@([da-z.-]+)\.([a-z.]{2,})$/)
  }
  function validPhoneNumber (input) {
    var pattern = /[^\d+-]/g
    var phonenum = input.replace(pattern, '')
    return phonenum.length > 6 && phonenum.length < 15
  }
  function validText (input) {
    return input.match(/^[a-zA-Z]+$/)
  }
  function sanitize (field) {
    return field.value.replace(/<script[^>]*?>.*?<\/script>/gi, '')
      .replace(/<[\/\!]?*?[^<>]*?>/gi, '')
      .replace(/<style[^>]*?>.*?<\/style>/gi, '')
      .replace(/<![\s\S]*?--[ \t\n\r]*>/gi, '')
  }
  function serializeObject (formElement) {
    var obj = {}
    var a = $(formElement).serializeArray()
    $.each(a, function () {
      if (obj[this.name] !== undefined) {
        if (!obj[this.name].push) {
          obj[this.name] = [obj[this.name]]
        }
        obj[this.name].push(this.value || '')
      } else {
        obj[this.name] = this.value || ''
      }
    })
    return obj
  }
}
