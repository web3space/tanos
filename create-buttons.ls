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

request_passport= (server-addr, text, callback_data_str)->
    #console.log callback_data_str
    [ head, ...rest ] = (callback_data_str ? "").split(' ')
    request = rest.join \.
    [ { text, url: "#{server-addr}/telegram-passport/index.html?request=#{request}" } ]

dictionary = {}

transform-button = (server-addr)-> ([text_str, callback_data_str])->
    return request_location(text_str) if callback_data_str is \request_location
    return request_contact(text_str) if callback_data_str is \request_contact
    return request_passport(server-addr, text_str, callback_data_str) if (callback_data_str ? "").index-of('request_passport') is 0
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


button-strategy = (server-addr, buttons=[], menu=[])->
    resize_keyboard: yes
    keyboard: menu ? [] |> map transform-button server-addr |> foldl group-button, []
    inline_keyboard: buttons ? [] |> map transform-button server-addr |> foldl group-button, []
module.exports = (server-addr, buttons=[], menu=[])->
    inline-keyboard = button-strategy server-addr, buttons, menu
    #console.log { inline-keyboard.inline_keyboard } 
    JSON.stringify inline-keyboard


ishash = (hash)->
    console.log hash
    return (hash ? "").index-of('__') is 0
unhash = (hash)->
    return hash if not ishash(hash)?
    dictionary[hash]

module.exports <<<< { ishash, unhash }