require! {
    \levelup
    \leveldown
    \prelude-ls : { obj-to-pairs, each }
}
 
db = levelup leveldown \./tanos-db

memory = (config, cb)->
    get = (name, cb)->
        return cb "Not Found Record `#{name}`" if not config[name]?
        cb null, config[name]
    put = (name, value, cb)->
        config[name] = JSON.parse JSON.stringify (value ? "")
        cb null
    del = (name, cb)->
        delete config[name]
        cb null
    cb null, { get, put, del }  

make-put = (db, name, v, cb)-->
    str = JSON.stringify { v }
    db.put name, str, cb

make-get = (db, name, cb)-->
    err, data <- db.get name
    return cb err if err?
    obj = JSON.parse data.to-string(\utf8)
    cb null, obj.v

init-drive = ([item, ...items], cb)->
    return cb null if not item?
    err <- make-put db, item.0, item.1
    return cb err if err?
    init-drive items, cb

drive = (config, cb)->
    items =
        config
            |> obj-to-pairs
    err <- init-drive items
    return cb err if err?
    get = make-get db
    put = make-put db
    del = (name, cb)->
        db.del name, cb
    cb null, { get, put, del }

module.exports = (config, db-type, cb)->
    return drive config, cb if db-type is \drive
    return memory config, cb

  
