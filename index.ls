require! {
    \require-ls
    \./send-media.ls
    \./delete-message.ls
    \prelude-ls : { obj-to-pairs, join, keys }
    \./trace.ls
    \express
    \body-parser
    \cors
    \vm
    \livescript
    \handlebars
    \request
    \superagent
    \./merge-images.ls
    \./edit-message.ls
    \./make-bot.ls
    \./make-db-manager.ls
    \greenlock-express : { create }
    \greenlock-store-fs
    \./create-buttons.ls : { unhash, ishash }
    \./telegram-passport.ls : { get-telegram-passport-text, passport-script-proxy, passport-index-proxy, passport-success-proxy, passport-canceled-proxy, proxy-passport-file }
    \fs : { read-file, read-file-sync, write-file-sync } 
}


validate-attachment = (text, validate-error, cb)->
    res = (text ? "").index-of('get-file') > -1
    cb(validate-error ? "Expected Attachment") if res isnt yes
    cb null

process-validator = (validator, validate-error, text, cb)->
    return cb "text is required" if typeof! text isnt \String
    return validate-attachment text, validate-error, cb if validator is \attachment
    return cb(validate-error ? "Expected #{validator}") if not text.match(new RegExp(validator))?
    cb null
process-validators = ([vaidator, ...rest], validate-error, text, cb)->
    return cb null if not validator?
    err <- process-validator validator, validate-error, text
    return cb err if err?
    process-validators rest, validate-error, text, cb
#is-global-menu = (text)->
#     text.index-of('​') is 0
process-text-validators = (step, { text, type } , cb)->
    return cb null if type is \callback_query
    #return cb null if is-global-menu text
    return cb null if not step.on-text?validate?
    { validate, validate-error } = step.on-text
    return process-validators validate, validate-error, text, cb if typeof! validate is \Array
    return process-validator validate, validate-error, text, cb if typeof! validate is \String
    cb null

module.exports = ({ telegram-token, app,layout, db-type, server-address, server-port, server-ssl-port, bot-name }, cb)->
    server-addr =
        | server-ssl-port? => "#{server-address.replace(/^http/, 'https')}:#{server-ssl-port}"
        | _ => "#{server-address}:#{server-port}"
    tanos = {}
    bot = make-bot telegram-token
    tanos.bot = bot
    err, db <- make-db-manager layout, db-type
    return cb err if err?
    
    { get, put, del } = db
    
    tanos.db = db
    
    $app = app tanos

    default-user = (chat_id)-> { chat_id }
    
    get-user = (chat_id, cb)->
        err, item <- get "#{chat_id}:chat_id"
        return cb null, default-user chat_id if err?
        return cb null, item if item?
        return cb null, default-user chat_id
    
    tanos.get-user = get-user
    
    save-user = (chat_id, user, cb)->
        put "#{chat_id}:chat_id", user, cb
    
    save-global = ($global, cb)->
        err <- put \variables:global , $global
        return cb err if err?
        cb null
    
    tanos.save-global = save-global
    
    get-global = (cb)->
        err, data <- get \variables:global
        obj =
            | err? => {}
            | _ => data ? {}
        cb null, obj
        
    tanos.get-global = get-global
    
    send-each-user = ([chat_id, ...rest], current_step, cb)->
        return cb null if not chat_id?
        message =
            from:
                id: chat_id
            text: ""
        err <- goto current_step, message
        return cb err if err?
        send-each-user rest, current_step, cb
    
    tanos.send-user = (chat_id, current_step, cb)->
        chat_ids =
            | typeof! chat_id is \Array => chat_id
            | typeof! chat_id is \Number => [chat_id]
        send-each-user chat_ids, current_step, cb
        
    
    get-localized-text = ($user, text)->
        return "err: wrong text" if typeof! text isnt \Object
        return "err: lang-var is missing" if typeof! text.lang-var isnt \String
        lang = eval text.lang-var
        return "err: lang is not correct" if typeof! lang isnt \String or lang.length is 0
        [ head, ...tail ] = keys text 
        text[lang] ? text[head] ? "text is not declared"
    
    handler-text-user = (chat_id, input-text, cb)->
        #console.log { input-text }
        err, $user <- get-user chat_id
        return cb err if err?
        err, $global <- get-global
        return cb err if err?
        text =
            | typeof! input-text is \Array => input-text |> join \\n
            | typeof! input-text is \String => input-text
            | typeof! input-text is \Object => get-localized-text $user, input-text
            | _ => "err: unsupported type of text"
        template = handlebars.compile text
        result = template { $user, $app, $global }
        err <- save-global $global
        return cb err if err?
        cb null, result
    
    run-commands = (message, text, [command, ...commands], cb)->
        return cb null if not command?
        err <- run-command message, text, command
        return cb err if err?
        err <- run-commands message, text, commands
        return cb err if err?
        cb null
    
    save-store-items = ([item, ...items], cb)->
        return cb null if not item?
        [name, value] = item
        err <- put name, value
        return cb err if err?
        save-store-items items, cb
    
    save-store = ($store, cb)->
        pairs =
            obj-to-pairs $store
        save-store-items pairs, cb
    
    get-chat-id = (message)->
        chat_id = (message.chat ? message.from).id
    
    get-user-by-message = (message, cb)->
        chat_id = get-chat-id message
        err, $user <- get-user chat_id
        return cb err if err?
        cb null, $user
    
    run-javascript = (message, $text, javascript, cb)->
        chat_id = get-chat-id message
        err, $user <- get-user-by-message message
        return cb err if err?
        $chat = message.chat
        $message_id = message.message_id
        
        script = new vm.Script javascript
        $store = {}
        err, $global <- get-global
        return cb err if err?
        context = new vm.create-context { $user, $app, $store, $text, $chat, $global }
        try
            script.run-in-context context
        catch err
            cb err
        err <- save-global $global
        return cb err if err?
        err <- save-user chat_id, $user
        return cb err if err? 
        err <- save-store $store
        return cb err if err
        cb null
    
    run-function = (message, $text, command, cb)->
        chat_id = get-chat-id message
        err, $user <- get-user-by-message message
        return cb err if err?
        $chat = message.chat
        $store = {}
        err, $global <- get-global
        return cb err if err?
        javascript = livescript.compile command, { bare: yes }
        func = eval "t = #{javascript}"
        err <- func { $user, $app, $store, $text, $chat, $global }
        return cb err if err?
        err <- save-global $global
        return cb err if err?
        err <- save-user chat_id, $user
        return cb err if err? 
        err <- save-store $store
        return cb err if err
        cb null
    
    run-livescript = (message, $text, command, cb)->
        return run-function message, $text, command, cb if command.index-of('->') > -1
        javascript = livescript.compile command, { bare: yes }
        run-javascript message, $text, javascript, cb
        
    run-command = (message, $text, command, cb)->
        trace "run command: #{command}"
        run-livescript message, $text, command, cb
        
    get-request-resource = (type, resource)->  ({ chat_id, menu-map, name }, cb)->
        return cb null if not menu-map[type]?
        return cb null, resource if typeof! menu-map[type].lang-var isnt \String and (menu-map[type][name] ? "").to-string!.index-of(resource) is 0
        return cb null if typeof! menu-map[type].lang-var isnt \String
        err, $user <- get-user chat_id
        return cb err if err?
        lang = eval menu-map[type].lang-var
        return cb null, resource if (menu-map[type][lang]?[name] ? "").to-string!.index-of(resource) is 0
        cb null
    
    get-request-location = get-request-resource \menu,    \request_location
    get-request-contact  = get-request-resource \menu,    \request_contact
    get-request-passport = get-request-resource \buttons, \request_passport
    
    build-command-hash = ({chat_id, current_step, previous_step, name, menu-map}, cb)->
        #console.log \dd, { chat_id, menu-map, name }
        err, data <- get-request-location { chat_id, menu-map, name }
        return cb null, data if not err? and data?
        err, data <- get-request-contact { chat_id, menu-map, name }
        return cb null, data if not err? and data?
        err, data <- get-request-passport { chat_id, menu-map, name }
        return cb null, data if not err? and data?
        #return cb null, "goto:#{previous_step}" if menu-map.buttons?[name] is \goto:$previous-step
        #return cb null, "goto:#{previous_step}" if menu-map.menu?[name] is \goto:$previous-step
        cb null, "#{current_step}:#{name}"
    
    generate-commands = ({ chat_id, current_step, previous_step, menu-map } , [button, ...buttons], cb)->
        return cb null, [] if not button?
        [name] = button
        err, result <- build-command-hash { chat_id, current_step, previous_step, name, menu-map }
        return cb err if err?
        err, text <- handler-text-user chat_id, name
        return cb err if err?
        item = [text, result]
        err, rest <- generate-commands { chat_id, current_step, previous_step, menu-map }, buttons
        return cb err if err?
        all = [item] ++ rest
        cb null, all
    
    on-start = (message, cb)->
        on-command { text: '' , from: message.chat }, cb
    
    get-images = (menu-map, cb)->
        result =
            | typeof! menu-map.images is \Array and menu-map.images.length > 0 => menu-map.images
            | typeof! menu-map.images is \String => [menu-map.images]
            | _ => []
        return merge-images menu-map, cb if result.length is 0
        cb null, result
    get-localized-buttons = ({ chat_id, buttons }, cb)->
        return cb null, buttons if typeof! buttons.lang-var isnt \String
        err, $user <- get-user chat_id
        lang = eval buttons.lang-var
        result = buttons[lang] ? {}
        cb null, result
    get-buttons-generic = (name)->  ({chat_id, current_step, menu-map, previous_step }, cb)->
        buttons = menu-map[name] ? {}
        err, buttons <- get-localized-buttons { chat_id, buttons }
        return cb err if err?
        pairs =
            buttons |> obj-to-pairs
        err, commands <- generate-commands { chat_id, current_step, previous_step, menu-map }, pairs
        return cb err if err?
        cb null, commands
    
    get-buttons = get-buttons-generic \buttons
    get-menu = get-buttons-generic \menu
    
    get-previous-step-key = (message)->
        "#{message.from.id}:previous-step"
    
    goto-all = ([current_step, ...steps], message, cb)->
        return cb null if not current_step?
        err <- goto current_step, message
        return cb err if err?
        goto-all steps, message, cb
    
    delete-message-if-exists = ({ chat_id, message_id }, cb)->
        return cb null if not message_id?
        delete-message { bot, chat_id, message_id}, cb
    
    process-condition = (command, message, cb)->
        javascript = livescript.compile command, { bare: yes }
        err, $user <- get-user-by-message message
        return cb err if err?
        err, $global <- get-global
        return cb err if err?
        script = new vm.Script javascript
        $check =
            result: no
        context = new vm.create-context { $user, $app, $check, $global }
        try
            script.run-in-context context
        catch err
            return cb err
        cb null, $check.result
    
    process-conditions = ([condition, ...conditions], message, cb)->
        return cb null if not condition?
        err, data <- process-condition condition.0, message
        return cb err if err?
        return cb null, condition.1 if data is yes
        process-conditions conditions, message, cb
    
    check-regirect-conditions = (current-step, message, cb)->
        return cb null if not current-step?redirect-condition?
        return cb "redirect condition should be an object" if typeof! current-step?redirect-condition isnt \Object
        redirect-conditions =
            current-step?redirect-condition |> obj-to-pairs
        process-conditions redirect-conditions, message, cb
    
    unvar-step = (current_step_guess, message, cb)->
        return cb null, current_step_guess if current_step_guess.index-of('{{') is -1
        err, current_step <- handler-text-user message.from.id, current_step_guess
        return cb err if err?
        cb null, current_step
    
    execute-on-enter = (menu-map, message, cb)->
        on-enter = 
            | typeof! menu-map.on-enter is \Array => menu-map.on-enter
            | typeof! menu-map.on-enter is \String => [menu-map.on-enter]
            | _ => []
        text = \#enter
        err <- run-commands message, text, on-enter
        return cb err if err?
        cb null
    goto = (current_step_guess, message, cb)->
        err, current_step <- unvar-step current_step_guess, message
        return cb err if err?
        err, previous_step <- get-previous-step message
        return cb err if err?
        previous-step-key = get-previous-step-key message
        name-menu = "#{current_step}:bot-step"
        err <- put previous-step-key, current_step
        return cb err if err?
        err, current-map <- get "#{current_step}:bot-step"
        err, regirect_step <- check-regirect-conditions current-map, message
        return cb err if err?
        return goto regirect_step, message, cb if regirect_step?
        return cb err if err?
        err, main-map <- get "main:bot-step"
        return cb err if err?
        menu-map = current-map ? main-map
        err <- execute-on-enter menu-map, message
        return cb err if err?
        chat_id = message.from.id
        err, buttons <- get-buttons { chat_id, current_step, menu-map, previous_step }
        return cb err if err?
        err, menu <- get-menu { chat_id, current_step, menu-map, previous_step }
        return cb err if err?
        err, images <- get-images menu-map
        return cb err if err?
        photo = 
            | typeof! images is \Undefined => null
            | typeof! images is \Array => images.0
            | typeof! images is \String => images
            | _ => null
        chat = message.from
        err, text <- handler-text-user chat_id, menu-map.text
        return cb err if err?
        message-body = { bot, chat, photo, buttons, text, menu, server-addr }
        err, next-message <- send-media message-body
        return cb err, no if err?
        err <- put "#{next-message.message_id}:message", { current_step, ...message-body }
        return cb err if err?
        err, message_id <- get "${chat_id}.#{current_step}"
        <- delete-message-if-exists { chat_id, message_id }
        err <- put "${chat_id}.#{current_step}", next-message.message_id
        return cb err if err?
        cb null, yes
    
    get-previous-step = (message, cb)->
        previous-step-key = get-previous-step-key message
        err, previous_step_guess <- get previous-step-key
        err, previous-message-body <- get "#{message?message?message_id}:message"
        text = message.data ? ""
        previous_step =
            | text.index-of(\:) > -1 and text.index-of(\goto:) is -1 => text.split(\:).0
            | previous-message-body? => previous-message-body.current_step
            | previous_step_guess? => previous_step_guess
            | _ => \main
        cb null, previous_step

    prevent-action = ({ bot, chat, text}, cb)->
        #console.log \FAILED_VALIDATION, text, chat
        err <- send-media { bot, chat, text, server-addr }
        return cb err, no if err?
        return cb null, yes
    
    get-text = (message, cb)->
        return get-telegram-passport-text {server-addr, db }, message, cb if message.passport_data?
        #console.log { message.photo }
        get-last = (message)->
            length = message.photo.length
            message.photo[length - 1]
        text =
            | message.data? => message.data
            | message.text? => message.text
            | message.contact? => "#{message.contact.phone_number} #{message.contact.first_name} #{message.contact.last_name}"
            | message.location? => "<a href='https://www.google.com/maps/@#{message.location.latitude},#{message.location.longitude},15z'>Место на карте</a>"
            | message.document? => "<a href='#{server-addr}/get-file/#{message.document.file_id}'>Документ</a>"
            | message.photo? => "<a href='#{server-addr}/get-file/#{get-last(message).file_id}'>Фотография</a>"
            | message.video? => "<a href='#{server-addr}/get-file/#{message.video.file_id}'>Видео</a>"
            | message.voice? => "<a href='#{server-addr}/get-file/#{message.voice.file_id}'>Запись голоса</a>"
            | _ => message.text
        return cb null, text
    
    no-buttons = (step)-> not step.buttons? and not step.menu?
    extract-localized-buttons = ({ message, buttons }, cb)->
        return cb "message is required" if not message?
        return cb "buttons object is required" if not buttons?
        return cb null, buttons if typeof! buttons.lang-var isnt \String
        err, $user <- get-user-by-message message
        return cb err if err?
        lang = eval buttons.lang-var
        cb null, buttons[lang]    
        
    extract-by-button = ({ message, text }, buttons, cb)->
        err, buttons <- extract-localized-buttons { message, buttons }
        console.log \extract-by-button, text, err, buttons
        return cb err if err?
        name = 
            | (text ? "").index-of(':') > -1 => text.split(':').1
            | _ => text
        res = buttons[name] ? buttons[text]
        cb null, res
    extract-button = ({ text, previous-step, message }, cb)->
        #console.log previous-step
        button =
            | not text? => \goto:main
            | (text ? "").index-of('goto:') > -1 => text
            | previous-step.on-text? and message.type isnt \callback_query => previous-step.on-text
            | no-buttons(previous-step) => null
        console.log \button1, button
        return cb null, button if button?
        return extract-by-button { message, text }, previous-step.menu, cb if previous-step.menu?
        return extract-by-button { message, text }, previous-step.buttons, cb if previous-step.buttons?
        cb null, null
        
        
    on-command = (message, cb)->
        return cb null, no if not message?message?message_id?
        err, previous_step <- get-previous-step message
        
        return cb err, no if err?
        err, text <- get-text message
        return cb err if err?
        
        err, main-step <- get "main:bot-step"
        return cb err if err?
        err, previous-step-guess <- get "#{previous_step}:bot-step"
        previous-step = previous-step-guess ? main-step
        #console.log \BEFORE_VALIDATION, text, message.from
        err <- process-text-validators previous-step, { text, message.type }
        return prevent-action { bot, chat: message.from, text: "#{err}" }, cb if err?
        #console.log \OKKK_VALIDATION, text, message.from
        err, clicked-button <- extract-button { text, previous-step, message }
        return cb err if err?
        return on-command {data: "main:#{message.text}", ...message }, cb if message.text? and not message.data? and clicked-button is null and previous_step isnt \main
        
        clicked-button = clicked-button ? \goto:main
        commands =
                | typeof! clicked-button.store is \String => [clicked-button.store]
                | typeof! clicked-button.store is \Array => clicked-button.store
                | _ => []
        err <- run-commands message, text, commands
        return cb err if err?
        current_step =
                | typeof! clicked-button is \String => clicked-button.split(':').1 ? \main
                | typeof! clicked-button is \Object => clicked-button.goto ? \main
                | _ => \main
        current-steps = current_step.split(',')
        goto-all current-steps, message, cb
    
    handlers =  { on-command, on-start }
    
    handler-keys = Object.keys handlers
    
    store-username = (message, cb)->
        return cb null if not message.chat?
        err <- put "#{message.chat.username}:username", message.chat.id
        return cb err if err?
        cb null
    process-handlers = ([handler, ...rest], message, cb)->
        return cb null, no if not handler?
        chat_id = message.from.id
        err <- store-username message
        return cb err if err?
        { message_id } = message.message
        err, result <- handlers[handler] message
        return cb err, no if err?
        return cb null, yes if result
        err, result <- process-handlers rest, message
        cb err, result
    
    process-messsage = (query, cb)->
        { message } = query
        return cb null if not message?
        result <- process-handlers handler-keys, query
        cb null, result
    
    
    update-previous-messsage = ({ type, message }, cb)->
        return cb null if type is \message
        return cb null if not message?message?
        option =
            | message.data?index-of(':') > -1 => message.data.split(":").1
            | _ => message.data
        err, message-body <- get "#{message.message.message_id}:message"
        return cb err if err?
        chat_id = message.message.chat.id
        message_id = message.message.message_id
        text = "#{message-body.text}\n\n`#{option}`"
        err <- edit-message bot, server-addr, chat_id, message_id, text, {}, {}
        cb null
    
    
    bot.on \update , (result)->
        #console.log result
        message = result.message ? result.callback_query
        #message.text = unhash message.text if message.text?
        message.data = unhash message.data if message.data?
        type =
            | result.callback_query? => \callback_query
            | message.text? and message.text.index-of('​') > -1 => \callback_query
            | _ => \message
        message.text = message.text.replace('​', '') if message.text?
        <- update-previous-messsage { type, message }
        process-messsage { message, type, ...message }, trace
    
    get-from-id = ({ message, token }, cb)->
        err, record <- get "#{token}:access-keys"
        return cb err if err?
        return cb "not found registered record for token" if typeof! record isnt \Object
        { chat_id, steps } = record
        return cb "step is not permitted" if steps.index-of(message) > -1
        err, user <- get "#{chat_id}:chat_id"
        return cb err if err?
        err <- del "#{token}:access-keys"
        return cb err if err?
        cb null, user
    
    process-http-message = (body, cb)->
      { message, token } = req.body
      return cb "message is required" if not message?
      return cb "token is required" if not token?
      err, id <- get-from-id { message, token }
      return cb err if err?
      from = { id }
      err, result <- process-messsage { message, from }
      return cb err if err?
      cb null, result
    
    restify = (res)-> (err, result)->
        return res.status(400).send "#{err.message ? err}" if err?
        res.send result
    
    proxy-file = (req, res)->
        { file_id } = req.params
        err, data <- bot.get-file { file_id }
        return res.status(400).send("cannot get file: #{err}") if err?
        request.get("https://api.telegram.org/file/bot#{telegram-token}/#{data.file_path}").pipe(res)
        
    
    tanos.http = express!
    
    start-with-ssl = (cb)->
        greenlock =
            create do
                email: \a.stegno@gmail.com
                agreeTos: yes          
                config-dir: \./config/acme/
                community-member: no
                telemetry: no
                app: tanos.http
                debug: no
                store: greenlock-store-fs
        greenlock.listen(server-port, server-ssl-port)
        cb err, tanos
    
    start-without-ssl = (cb)->
        err <- tanos.http.listen server-port
        cb err, tanos
        
    tanos.http
        .use body-parser.urlencoded({ extended: true })
        .use body-parser.json!
        .use cors!
        .get \/telegram-passport/script.js , passport-script-proxy
        .get \/telegram-passport/index.html , passport-index-proxy { server-addr, telegram-token, db, bot-name }
        .get \/telegram-passport/tg_passport=success , passport-success-proxy({ bot-name })
        .get \/telegram-passport/tg_passport=canceled , passport-canceled-proxy({ bot-name })
        .get \/telegram-passport , passport-success-proxy({ bot-name })
        .get \/get-file/:file_id, proxy-file
        .get \/get-decrypted-file/:file_id, proxy-passport-file { bot, telegram-token, db }
        #.get \/google8b809baeb12ee9e4.html, (req, res)-> res.sendFile(__dirname+"/google8b809baeb12ee9e4.html") # for excel
        .post \/api/message/:message/:token , (req, res) -> process-http-message req.params, restify(res)
        .get \/api/message/:message/:token , (req, res)-> process-http-message req.params, restify(res)
    start =
        | server-ssl-port? => start-with-ssl
        | _ => start-without-ssl
    start cb