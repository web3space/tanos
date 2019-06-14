require! {
    \fs : { read-file-sync, read-file, write-file-sync }
    \telegram-passport
    \superagent
    \handlebars
    \node-genrsa
    \prelude-ls : { keys, map, obj-to-pairs, filter }
    \request
    \node-fetch
}

get-decryptor = (db, cb)->
    err, key <- db.get "keys:telegram-passport"
    return cb err if err?
    decryptor =  new telegram-passport key.private
    cb null, decryptor

get-decrypted = ({ bot, telegram-token, db }, file_id, cb)->
    err, item <- db.get "#{file_id}:telegram-passport-file"
    return cb err if err?
    err, data <- bot.get-file { file_id }
    return cb err if err?
    fileData <- node-fetch("https://api.telegram.org/file/bot#{telegram-token}/#{data.file_path}").then(-> it.buffer!).then
    err, decryptor <- get-decryptor db
    return cb err if err?
    hash = Buffer.from item.hash, \base64
    secret = Buffer.from item.secret, \base64
    res = decryptor.decryptPassportCredentials fileData, hash, secret
    cb null, res
    
export proxy-passport-file = (context)-> (req, res)->
    { file_id } = req.params
    err, file <- get-decrypted context, file_id
    res.end file

gen-keys = (cb)->
    options =
      bits: 2048
      exponent: 65537
    keys <- node-genrsa.default options .then
    return cb "keys are expected" if not keys.private? or not keys.public?
    cb null, keys

create-keys = (db, cb)->
    err, keys <- gen-keys
    return cb err if err?
    err <- db.put "keys:telegram-passport", keys
    return cb err if err?
    console.log "Please goto https://t.me/BotFather then type /setpublickey then put public key for your bot: \n", keys.public
    cb null, keys

get-keys = (db, cb)->
    #err <- db.del "keys:telegram-passport"
    err, data <- db.get "keys:telegram-passport"
    return create-keys db, cb if err?
    cb null, data

get-files = ([item, ...rest], context, cb)->
    console.log item
    { server-addr, db } = context
    return cb null, [] if not item?
    err <- db.put "#{item.file.file_id}:telegram-passport-file", item
    return cb err if err?
    link = """<a href='#{server-addr}/get-decrypted-file/#{item.file.file_id}'>Документ</a>"""
    err, rest <- get-files rest, context
    return cb err if err?
    all = [link] ++ rest
    cb null, all

from-side = (item, context, cb)->
    err, front_side <- get-files [item.front_side], context
    return cb err if err?
    err, selfie <- get-files [item.front_side], context
    return cb err if err?
    all = ["From Side:"] ++ front_side ++ ["Selfie"] ++ selfie
    cb null, all
    
get-data= (item, context, cb)->
    names =
        item.data |> keys
    res =
        names |> map (-> "<b>#{it}</b>: #{item.data[it]}")
    cb null, res

parse-generic = (item, context, cb)->
    return get-files item.files, context, cb if item.files?
    return from-side item, context, cb if item.front_side?
    return get-data item, context, cb if item.data?
    cb "cannot parse item #{item.type}"

utility_bill = (item, context, cb)->
    parse-generic item, context, cb

passport = (item, context, cb)->
    parse-generic item, context, cb
    
phone_number = (item, context, cb)->
    cb null, [item.phone_number]
    
personal_details = (item, context, cb)->
    parse-generic item, context, cb
    
driver_license = (item, context, cb)->
    parse-generic item, context, cb

identity_card = (item, context, cb)->
    parse-generic item, context, cb

internal_passport = (item, context, cb)->
    parse-generic item, context, cb

address = (item, context, cb)->
    parse-generic item, context, cb

bank_statement = (item, context, cb)->
    parse-generic item, context, cb

rental_agreement = (item, context, cb)->
    parse-generic item, context, cb

passport_registration = (item, context, cb)->
    parse-generic item, context, cb

temporary_registration = (item, context, cb)->
    parse-generic item, context, cb

email = (item, context, cb)->
    cb null, [item.email]
    
handlers = { passport, utility_bill, phone_number, email, personal_details, driver_license, identity_card, internal_passport, address, bank_statement, rental_agreement, passport_registration, temporary_registration }

process-telegram-passport = ([pair, ...rest], context,  cb)->
    return cb null, [""] if not pair?
    [type, file] = pair
    handler = handlers[type]
    return cb null, ["cannot process #{type}"] if not handler?
    err, text <- handler { type, ...file }, context
    return cb err if err?
    err, texts <- process-telegram-passport rest, context
    return cb err if err?
    all = ["<b>#{type}</b>:"] ++ text ++ texts
    cb null, all

#content = read-file-sync \./telegram-passport.json , \utf8
#{ data, credentials } =  JSON.parse content

export get-telegram-passport-text = ({ server-addr, db }, message, cb)->
    return cb "message.passport_data isnt object" if typeof! message.passport_data isnt \Object
    err, decryptor <- get-decryptor db
    decrypted_passport_data =  decryptor.decrypt message.passport_data
    #write-file-sync "./message.passport_data.json", JSON.stringify(decrypted_passport_data, null, 4)
    pairs = 
        decrypted_passport_data 
            |> obj-to-pairs
            |> filter (.1?)
    err, text <-  process-telegram-passport pairs, { server-addr, db }
    return cb err if err?
    console.log text.join("\n")
    cb null, text.join("\n")

export passport-script-proxy = (req, res)->
    err, data <- superagent.get \https://raw.githubusercontent.com/TelegramMessenger/TGPassportJsSDK/master/telegram-passport.js .end
    return res.status(400).send("#{err}") if err?
    res.content-type \text/javascript
    res.send data.text

uuidv4 = ->
  'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace //[xy]//g, (c) ->
    r = Math.random! * 16 .|. 0
    v = if c is 'x' then r else r .&. 3 .|. 8
    v.toString 16

get-telegram-passport-index = ( model, cb)->
    return cb "model is required" if not model?
    return cb "model.bot_id is required" if typeof! model.bot_id isnt \String
    return cb "model.callback_url is required" if typeof! model.callback_url isnt \String
    err, keys <- get-keys model.db
    return cb err if err?
    public_key = keys.public.replace(/\n/g, "\\n")
    nonce = uuidv4!
    err, data <- read-file "#{__dirname}/telegram-passport/telegram-passport.html", \utf8
    return cb err if err?
    template = handlebars.compile data
    result = template { public_key, nonce, ...model }
    cb null, result

export passport-index-proxy = ({ server-addr, telegram-token, db, bot-name })-> (req, res)->
    callback_url = "#{server-addr}/telegram-passport"
    bot_id = telegram-token.split(":").0
    { request } = req.query
    request-model = (request ? "").split(".")
    scope-model =
        | request-model.length is 0 => ["id_document", "address_document", "phone_number", "email"]
        | _ => request-model
    scope = JSON.stringify scope-model
    err, data <- get-telegram-passport-index { callback_url, bot_id, db, bot-name, scope }
    return res.status(400).send("#{err}") if err?
    res.content-type \text/html
    res.send data
    
export passport-success-proxy = (model)-> (req, res)->
    err, data <- read-file "#{__dirname}/telegram-passport/telegram-passport-success.html", \utf8
    return cb err if err?
    template = handlebars.compile data
    result = template model
    res.content-type \text/html
    res.send result

export passport-canceled-proxy = (model)-> (req, res)->
    err, data <- read-file "#{__dirname}/telegram-passport/telegram-passport-canceled.html", \utf8
    return cb err if err?
    template = handlebars.compile data
    result = template model
    res.content-type \text/html
    res.send result
    