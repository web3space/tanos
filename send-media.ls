require! {
    \./send-message.ls
    \./send-photo.ls
    \./send-photos.ls
}


module.exports = ({ bot, server-addr, chat, text, buttons, photo, menu }, cb)->
    return send-photos bot, server-addr, chat, photo, buttons, menu, cb if typeof! photo is \Array
    return send-message bot, server-addr, chat, text, buttons, menu, cb if not photo?
    send-photo bot, server-addr, chat, text, photo, buttons, menu, cb