uuidv4 = ->
  'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace //[xy]//g, (c) ->
    r = Math.random! * 16 .|. 0
    v = if c is 'x' then r else r .&. 3 .|. 8
    v.toString 16


module.exports = ({ $store, $user, steps}, cb)->
    _id = uuidv4!
    $store["#{_id}:access-keys"] = { $user.chat_id, steps }
    cb null, _id