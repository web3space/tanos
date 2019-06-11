require! {
    \prelude-ls : { map, foldl }
    \string-hash
}

request_location = (text)->
    request_location = yes
    [ { text, request_location } ]
request_contact = (text)->
    request_contact = yes
    [ { text, request_contact } ]

dictionary = {}

transform-button = ([text_str, callback_data_str])->
    return request_location(text) if callback_data_str is \request_location
    return request_contact(text) if callback_data_str is \request_contact
    callback_data = "__" + string-hash(callback_data_str)
    dictionary[callback_data] = callback_data_str
    text = "​#{text_str}"
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
    #console.log { inline-keyboard.inline_keyboard } 
    JSON.stringify inline-keyboard


ishash = (hash)->
    console.log hash
    return (hash ? "").index-of('__') is 0
unhash = (hash)->
    return hash if not ishash(hash)?
    dictionary[hash]

module.exports <<<< { ishash, unhash }