require! {
    \./create-buttons.ls
}
empty = ->
module.exports = (bot, chat, text, buttons={}, menu={}, cb=empty)->
    return cb "chat is required" if not chat?
    reply_markup = create-buttons buttons, menu
    err, message <- bot.send-message { chat_id: chat.id , text, reply_markup, parse_mode:"HTML" }
    return cb err if err?
    cb null, message