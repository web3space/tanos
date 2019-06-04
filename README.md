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


```Livescript

require! {
    \tanos
    \./layout.ls
    \./app.ls
    \./config.json : { telegram-token, server-address, server-port }
}
db-type = \drive
err, data <- tanos { layout, app, telegram-token, db-type, server-address, server-port }
console.log err, data

```

### layout.ls (KYC bot Example)

```

menu = {}

config =
    "main:bot-step" :
        on-enter:
            "$global.admins = [$user.chat_id] if not $global.admins?"
        text: "Please choose the action below"
        buttons:
            "Pass KYC Verification" : "goto:kyc"
        on-text:
            "({ user, $app }, cb)-> $app.try-add-admin $user, $text, cb"
    "kyc:bot-step":
        text: "Please enter the PIN code from Coinpay"
        on-text:
            goto: "passport"
            store: "$user.pin = $text"
    "passport:bot-step":
        text: "Please attach your Passport"
        on-text:
            goto: "utility"
            store: "$user.passport = $text"
    "utility:bot-step":
        text: "Please attach your Utility Bill"
        on-text:
            goto: "address"
            store: "$user.utility = $text"
    "address:bot-step":
        text: "Please enter your Living Address"
        on-text:
            goto: "firstname"
            store: "$user.address = $text"
    "firstname:bot-step":
        text: "Please enter your First Name"
        on-text:
            goto: "lastname"
            store: "$user.firstname = $text"
    "lastname:bot-step":
        text: "Please enter your Last Name"
        on-text:
            goto: "finish"
            store: "$user.lastname = $text"
    "finish:bot-step":
        on-enter:
            "({ user, $app }, cb)-> $app.send-for-review $user, cb"
        text: "Your application has been sent. Please wait for review"
        buttons:
            "Pass KYC Verification again" : "goto:kyc"
module.exports = config

```

### app.ls

```Livescript 

require! {
    \superagent : { get, post }
    \./config.json : { review-callback }
    \prelude-ls : { keys, map, join }
}

module.exports = ({ db, bot, tanos })->
    inform-generic = (status)-> (chat_id, cb)->
        err, user <- tanos.get-user chat_id
        return cb err if err?
        info = { user, status }
        #console.log info
        err, data <- post review-callback, info .end
        return cb err if err?
        cb null        
    
    export try-add-admin = ($user, text, cb)->
        return cb null if text.index-of('/add-admin') isnt 0
        return cb null if typeof! $global.admins isnt \Array
        err, $global <- tanos.get-global
        return cb err if err?
        return cb "Only admin can add admin" if $global.admins.index-of($user.chat_id) is -1
        chat_id = +text.replace('/add-admin', '')
        return cb null if $global.admins.index-of(chat_id) > -1
        $global.admins.push chat_id
        err <- tanos.save-global $global
        return cb err if err? 
        cb null
        
        
    export inform-accepted = inform-generic \accepted
    export inform-rejected = inform-generic \rejected
    inform-review = inform-generic \review
    
    export send-for-review = ($user, cb)->
        text =
            $user
                |> keys
                |> map -> "<b>#{it}</b> : #{$user[it]}"
                |> join "\n"
        buttons = 
            "Accept KYC" :
                store:
                    "({ user, $app }, cb)-> $app.inform-accepted #{$user.chat_id}, cb"
            "Reject KYC" :
                store:
                    "({ user, $app }, cb)-> $app.inform-rejected #{$user.chat_id}, cb"
        err <- db.put "review_#{$user.chat_id}:bot-step", { text, buttons }
        return cb err if err?
        err, $global <- tanos.get-global
        return cb err if err?
        err <- tanos.send-user $global.admins, "review_#{$user.chat_id}"
        return cb err if err?
        err <- inform-review $user.chat_id
        return cb err if err?
        cb null
    out$

```
