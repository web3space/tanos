require! {
    \./send-message.ls
    \./send-photo.ls
    \./send-photos.ls
}


module.exports = ({ bot, chat, text, buttons, photo, menu }, cb)->
    return send-photos bot, chat, photo, buttons, menu, cb if typeof! photo is \Array
    return send-message bot, chat, text, buttons, menu, cb if not photo?
    send-photo bot, chat, text, photo, buttons, menu, cb