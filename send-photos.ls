require! {
    \./create-buttons.ls
}
empty = ->
module.exports = (bot, server-addr, chat, photo, buttons={}, menu={}, cb=empty)->
    return cb "Chat is not provided" if not chat?
    err, message <- bot.send-media-group { chat_id: chat.id , media: photo }
    return cb err if err?
    cb null