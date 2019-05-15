require! {
    \./create-buttons.ls
}
empty = ->
module.exports = (bot, chat_id, message_id, text, buttons={}, menu={}, cb=empty)->
    #console.log &
    return cb "chat is required" if not chat_id?
    reply_markup = create-buttons buttons, menu
    # disable_web_page_preview: yes
    err, message <- bot.edit-message-caption { message_id, chat_id , caption: text, parse_mode:"HTML" }
    err, message <- bot.edit-message-text { message_id, chat_id , text, parse_mode:"HTML" }
    err, message <- bot.edit-message-reply-markup { message_id, chat_id , reply_markup }
    #console.log { err }
    return cb err if err?
    cb null