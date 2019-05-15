require! {
    \./create-buttons.ls
}
empty = ->
module.exports = (bot, chat, text, photo, buttons={}, menu={}, cb=empty)->
    return cb "Chat is not provided" if not chat?
    reply_markup = create-buttons buttons, menu
    err, message <- bot.send-photo { chat_id: chat.id , caption: text, text, reply_markup, photo, parse_mode:"HTML" }
    return cb err if err?
    cb null, message