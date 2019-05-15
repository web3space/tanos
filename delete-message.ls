empty = ->
module.exports = ({ bot, chat_id, message_id }, cb=empty)->
    #return if not chat_id?
    err, message <- bot.delete-message { chat_id, message_id }
    return cb err if err?
    cb null