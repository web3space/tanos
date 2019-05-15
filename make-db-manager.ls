module.exports = (config)->
    get = (name, cb)->
        return cb "Not Found Record `#{name}`" if not config[name]?
        cb null, config[name]
    put = (name, value, cb)->
        config[name] = JSON.parse JSON.stringify (value ? "")
        cb null
    del = (name, cb)->
        delete config[name]
        cb null
    { get, put, del }    
