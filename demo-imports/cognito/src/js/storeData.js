export function storeData (formdata) {
  var bucket = '<link-to-S3-bucket-to-store-form-data>'
  var id = window.uuid.v4()
  var path = bucket + id + '.json'
  localStorage.setItem('email', formdata['customer-email'])
  localStorage.setItem('username', formdata['firstname'])
  $.when(uploadData(path, formdata))
    .done(function (r1) {
      console.log('Upload complete!')
    })
    .fail(err => {
      console.error('RESPONSE ERROR', err)
    })
}
var uploadData = function (url, formData) {
  return $.ajax({
    type: 'PUT',
    url: url,
    contentType: 'application/json',
    data: JSON.stringify(formData)
  })
}
