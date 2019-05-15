require! {
    \./create-buttons.ls
}
empty = ->
module.exports = (bot, chat_id, from_chat_id, message_id, cb=empty)->
    err, message <- bot.forward-message { chat_id, from_chat_id, message_id }
    return cb err if err?
    cb null