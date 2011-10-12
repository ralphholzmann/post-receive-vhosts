# Modules
http =      require "http"
fs =        require "fs"
util =      require "util"
qs =        require "querystring"
express =   require "express"
cs =        require "coffee-script"
exec =      require('child_process').exec
sites =     {}
vhosts =    {}

# Process commit
update = ( commit ) =>

    @server.close()
    site = sites[ commit.repository?.name ]
    
    if site? and commit.ref is site.ref
        process.chdir "./repos/#{ commit.repository.name }"
        exec "git fetch", ->
            exec "git checkout #{ commit.after }", ->
                process.chdir "./../.."
                startVhosts()
         

# Vhost servers
startVhosts = =>
        
    @server = express.createServer()
    @server.configure =>
        for own remote, props of sites
            @server.use( express.vhost( props.domain, require( "./repos/#{ props.remote }/#{ props.index }" )))
        @server.listen 80
        console.log "Vhost server listening on 80"

# Post Receive Server
prServer= ( req, res ) ->

    data = []

    if req.method isnt "POST"
        res.end "Access denied"
    else
        req.on "data", (chunk) ->
            data.push chunk

        req.on "end", ->
            res.end "Thanks!"
            body = data.join ""
            payload = qs.parse body
            commit = JSON.parse payload.payload
            update commit
       

# Load up configurations
fs.readdir "./config", (err, files) ->

    # Deferreds-ish
    numFiles = files.length 
    numLoadedFiles = 0


    # Load up our configs
    for file in files
        fs.readFile "./config/#{ file }", "utf8", (err, data) ->

            site = JSON.parse data
            sites[ site.remote ] = site;

            numLoadedFiles++
            if numLoadedFiles is numFiles
                http.createServer(prServer).listen 6166
                console.log "Post receive server listening on 6166"
                startVhosts();
