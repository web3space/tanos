require! {
    \./create-buttons.ls
}
empty = ->
module.exports = (bot, server-addr, chat, text, photo, buttons={}, menu={}, cb=empty)->
    return cb "Chat is not provided" if not chat?
    reply_markup = create-buttons server-addr, buttons, menu
    err, message <- bot.send-photo { chat_id: chat.id , caption: text, text, reply_markup, photo, parse_mode:"HTML" }
    return cb err if err?
    cb null, message