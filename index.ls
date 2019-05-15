require! {
    \./send-media.ls
    \./delete-message.ls
    \prelude-ls : { obj-to-pairs, join }
    \./trace.ls
    \express
    \body-parser
    \cors
    \vm
    \livescript
    \handlebars
    \request
    \./merge-images.ls
    \./edit-message.ls
    \./make-bot.ls
    \./make-db-manager.ls
    
}

module.exports = ( { telegram-token, providers, config }, cb)->
    
    bot = make-bot telegram-token
    
    { get, put, del } = make-db-manager config

    default-user = (chat_id)-> { chat_id }
    
    get-user = (chat_id, cb)->
        err, item <- get "#{chat_id}:chat_id"
        return cb null, default-user chat_id if err?
        return cb null, item if item?
        return cb null, default-user chat_id
    
    save-user = (chat_id, user, cb)->
        put "#{chat_id}:chat_id", user, cb
    
    handler-text-user = (chat_id,input-text, cb)->
        err, $user <- get-user chat_id
        return cb err if err?
        text =
            | typeof! input-text is \Array => input-text |> join \\n
            | typeof! input-text is \String => input-text
            | _ => "ERR: Unsupported type of text"
        template = handlebars.compile text
        result = template { $user }
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
        $store = {}
        script = new vm.Script javascript
        context = new vm.create-context { $user, $providers: providers, $store, $text, $chat }
        script.run-in-context context
        err <- save-user chat_id, $user
        return cb err if err? 
        err <- save-store $store
        return cb err if err
        cb null
    
    
    
    run-livescript = (message, $text, command, cb)->
        javascript = livescript.compile command, { bare: yes }
        run-javascript message, $text, javascript, cb
        
    run-command = (message, $text, command, cb)->
        trace "run command: #{command}"
        run-livescript message, $text, command, cb
        
    build-command-hash = ({current_step, previous_step, name, menu-map}, cb)->
        return cb null, "request_location" if menu-map.buttons?[name] is \request_location
        return cb null, "request_location" if menu-map.menu?[name] is \request_location
        return cb null, "request_contact" if menu-map.buttons?[name] is \request_contact
        return cb null, "request_contact" if menu-map.menu?[name] is \request_contact
        return cb null, "goto:#{previous_step}" if menu-map.buttons?[name] is \goto:$previous-step
        return cb null, "goto:#{previous_step}" if menu-map.menu?[name] is \goto:$previous-step
        cb null, "#{current_step}:#{name}"
    
    generate-commands = ({ chat_id, current_step, previous_step, menu-map } , [button, ...buttons], cb)->
        return cb null, [] if not button?
        [name] = button
        err, result <- build-command-hash { current_step, previous_step, name, menu-map}
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
    get-buttons-generic = (name)->  ({chat_id, current_step, menu-map, previous_step }, cb)->
        buttons = 
            menu-map[name] ? {} |> obj-to-pairs
        err, commands <- generate-commands { chat_id, current_step, previous_step, menu-map }, buttons
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
        script = new vm.Script javascript
        $check =
            result: no
        context = new vm.create-context { $user, $providers: providers, $check }
        result = script.run-in-context context
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
        message-body = { bot, chat, photo, buttons, text, menu }
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
    
    on-command = (message, cb)->
        return cb null, no if not message?message?message_id?
        err, previous_step <- get-previous-step message
        #console.log { previous_step }
        return cb err, no if err?
        server-address = \http://95.179.164.233:3000
        #console.log message.photo if message.photo?
        text = 
            | message.data? => message.data
            | message.text? => message.text
            | message.contact? => "#{message.contact.phone_number} #{message.contact.first_name} #{message.contact.last_name}"
            | message.location? => "<a href='https://www.google.com/maps/@#{message.location.latitude},#{message.location.longitude},15z'>Место на карте</a>"
            | message.photo?0? => "<a href='#{server-address}/get-file/#{message.photo.0.file_id}'>Фотография</a>"
            | message.video? => "<a href='#{server-address}/get-file/#{message.video.file_id}'>Видео</a>"
            | message.voice? => "<a href='#{server-address}/get-file/#{message.voice.file_id}'>Запись голоса</a>"
            | _ => message.text
        err, previous-step <- get "#{previous_step}:bot-step"
        return cb err if err?
        clicked-button =
            | not text? => \goto:main
            | (text ? "").index-of('goto:') > -1 => text
            | (text ? "").index-of(':') > -1 and previous-step.buttons?[text.split(':').1]? => previous-step.buttons[text.split(':').1]
            | (text ? "").index-of(':') > -1 and previous-step.menu?[text.split(':').1]? => previous-step.menu[text.split(':').1]
            | previous-step.buttons?[text]? => previous-step.buttons[text]
            | previous-step.menu?[text]? => previous-step.menu[text]
            | previous-step.on-text? => previous-step.on-text
            | _ => null
        return on-command {data: "main:#{message.text}", ...message }, cb if message.text? and not message.data? and clicked-button is null and previous_step isnt \main
        #console.log { previous_step, clicked-button, previous-step.buttons, text }
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
        option =
            | message.data?index-of(':') > -1 => message.data.split(":").1
            | _ => message.data
        err, message-body <- get "#{message.message.message_id}:message"
        return cb err if err?
        chat_id = message.message.chat.id
        message_id = message.message.message_id
        text = "#{message-body.text}\n\nВабрана опция: `#{option}`"
        err <- edit-message bot, chat_id, message_id, text, {}, {}
        cb null
    
    
    bot.on \update , (result)->
        message = result.message ? result.callback_query
        type =
            | result.callback_query? => \callback_query
            | _ => \message
        <- update-previous-messsage { type, message }
        process-messsage { message, ...message }, trace
    
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
        return res.status(400).send("#{err}") if err?
        request.get("https://api.telegram.org/file/bot#{telegram-token}/#{data.file_path}").pipe(res)
    express!
        .use body-parser.urlencoded({ extended: true })
        .use body-parser.json!
        .use cors!
        .get \/get-file/:file_id, proxy-file
        .get \/google8b809baeb12ee9e4.html, (req, res)-> res.sendFile(__dirname+"/google8b809baeb12ee9e4.html") # for excel
        .post \/api/message/:message/:token , (req, res) -> process-http-message req.params, restify(res)
        .get \/api/message/:message/:token , (req, res)-> process-http-message req.params, restify(res)  
        .listen 3000, cb