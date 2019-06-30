# Tanos 

### Telegram Bot Builder Framwork


### Install

sh
```
npm i tanos --save
```

Services:

  * Http Service
  * Telegram Service


### Get Started

Create config.json

config.json

```JSON
{
    "telegramToken"  : "881177358:000000000000000000000000",  
    "serverAddress"  : "http://your-domain-for-telegram-passport",
    "serverPort"     : 80,
    "serverSslPort"  : 443,
    "dbType" : "drive",
    "botName" : "your_bot"
}
```

where

* telegramToken - get from @BotFather (required)
* serverAddress - only for telegram passport (optional)
* serverPort - for HTTP API
* serverSslPort - for HTTPS API (optional)
* dbType - could be `memory` or `drive`.
* botName - registered bot name in BotFather 



### layout.ls (KYC bot Example)

```JSON
{
   "main:bot-step":{
      "onEnter":"$global.admins = [$user.chat_id] if not $global.admins?",
      "text":"Please choose the action below",
      "buttons":{
         "Pass KYC Verification":"goto:kyc"
      }
   },
   "kyc:bot-step":{
      "text":"Please enter your email",
      "onText":{
         "goto":"passport",
         "store":"$user.email = $text"
      }
   },
   "passport:bot-step":{
      "text":"Please attach your Passport",
      "onText":{
         "goto":"utility",
         "store":"$user.passport = $text"
      }
   },
   "utility:bot-step":{
      "text":"Please attach your Utility Bill",
      "onText":{
         "goto":"address",
         "store":"$user.utility = $text"
      }
   },
   "address:bot-step":{
      "text":"Please enter your Living Address",
      "onText":{
         "goto":"firstname",
         "store":"$user.address = $text"
      }
   },
   "firstname:bot-step":{
      "text":"Please enter your First Name",
      "onText":{
         "goto":"lastname",
         "store":"$user.firstname = $text"
      }
   },
   "lastname:bot-step":{
      "text":"Please enter your Last Name",
      "onText":{
         "goto":"finish",
         "store":"$user.lastname = $text"
      }
   },
   "finish:bot-step":{
      "onEnter":"({ user, $app }, cb)-> $app.review $user, cb",
      "text":"Your application has been sent. Please wait for review",
      "buttons":{
         "Pass KYC Verification again":"goto:kyc"
      }
   }
}

```

This configuration supports images, text, buttons, menu, text validators, localization. More information are available [here](Layout.md)


### app.js

```Javascript 

module.exports = ({ db, bot, tanos })=>
    
    const review = ($user, cb)=> {
        // Some actions with $user data
        cb(null);
    }
    
    return { review }

```


Create server.js

```Javascript

const tanos  = require('tanos');
const config = require('./config.json');
const layout = require('./layout.json');
const app     = require('./app.js');

tanos({ layout, app, ...config }, (err)=> {
   console.log("Telegram Bot has been started") 
});

```

### Start 

```
node server.js
```