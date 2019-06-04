require! {
    \prelude-ls : { map, foldl }
}

request_location = (text)->
    request_location = yes
    [ { text, request_location } ]
request_contact = (text)->
    request_contact = yes
    [ { text, request_contact } ]

transform-button = ([text, callback_data])->
    return request_location(text) if callback_data is \request_location
    return request_contact(text) if callback_data is \request_contact
    [ { text, callback_data } ]

group-button = (collector, button)->
    return collector ++ [button] if collector.length is 0
    [...rest, last] = collector
    change-last = last ++ button
    return [...rest, change-last] if change-last.length is 2
    collector ++ [button]


button-strategy = (buttons, menu)->
    resize_keyboard: yes
    keyboard: menu |> map transform-button |> foldl group-button, []
    inline_keyboard: buttons |> map transform-button |> foldl group-button, []
module.exports = (buttons=[], menu=[])->
    inline-keyboard = button-strategy buttons, menu
    JSON.stringify inline-keyboard