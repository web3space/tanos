require! {
    \gm
    \prelude-ls : { obj-to-pairs, map, filter }
    \md5
    \fs : { exists }
}

uuidv4 = ->
  'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace //[xy]//g, (c) ->
    r = Math.random! * 16 .|. 0
    v = if c is 'x' then r else r .&. 3 .|. 8
    v.toString 16

get-temp-name = ->
    "./tmp/#{uuidv4!}.png"

get-numbered-images = (number, [image, ...images], cb)->
    return cb null if not image?
    one = get-temp-name!
    two = get-temp-name!
    #x0, y0, x1, y1 [, wc, hc]
    err <- gm(image).region(200, 200, 0, 0).gravity('Center').fill("black").drawRectangle(0, 0, 200, 200).write one
    return cb err if err?
    err <- gm(one).region(200, 200, 0, 0).gravity('Center').fill("white").font-size(150).drawText(0, 0, "#{number}").write two
    return cb err if err?
    err, rest <- get-numbered-images (number + 1), images
    return cb err if err?
    all = [two] ++ rest
    cb null, all

get-hash = (image)->
    res = md5 JSON.stringify image
    "./tmp/#{res}.png"
get-merged-image = (images, cb)->
    return cb null, [] if images.length is 0
    return cb null, images if images.length is 1
    #
    file-name = get-hash images
    is-exists <- exists file-name
    return cb err if err?
    return cb null, file-name if is-exists is yes
    #
    err, numbered-images <- get-numbered-images 1, images.map(-> it.1)
    return cb err if err?
    #console.log numbered-images.length
    [root, ...rest] = numbered-images
    gm-root = gm(root)
    err <- gm-root.append.apply(gm-root, [...rest, true]).write file-name
    return cb err if err?
    cb null, file-name
module.exports = (menu-map, cb)->
    return cb null, [] if typeof! menu-map.buttons isnt \Object
    images =
        menu-map.buttons 
            |> obj-to-pairs
            |> map -> [it.0, it.1.image]
            |> filter ->it.1?
    get-merged-image images, cb
    

#merge(['/body.png', '/eyes.png', '/mouth.png'])
#  .then(b64 => document.querySelector('img').src = b64);