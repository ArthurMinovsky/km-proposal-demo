export function verification (foo) {
  var config = require('./config')
  var AmazonCognitoIdentity = require('amazon-cognito-identity-js')
  var poolData = {
    UserPoolId: config.userPoolId,
    ClientId: config.userPoolClientId
  }
  if (localStorage) {
    var username = localStorage.getItem('username')
    var email = localStorage.getItem('email')
  }
  var userPool = new AmazonCognitoIdentity.CognitoUserPool(poolData)
  var userData = {
    Username: email,
    Pool: userPool
  }
  var cognitoUser = new AmazonCognitoIdentity.CognitoUser(userData)
  cognitoUser.confirmRegistration(foo, true, function (err, result) {
    if (err) {
      document.getElementById('welcome-note').innerHTML = 'Spooky !!!'
      document.getElementById('msg').innerHTML = err.message
      return
    }
    document.getElementById('welcome-note').innerHTML = 'Congratulations ' + username + '!'
    document.getElementById('msg').innerHTML = ' You are now a registered customer.'
    console.log('call result: ' + result)
  })
}
