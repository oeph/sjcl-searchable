express = require 'express'
cons = require 'consolidate'
caesar = require 'caesar'
logger = require 'morgan'
bodyParser = require 'body-parser'

app = express()
app.engine 'html', cons.handlebars
app.set 'view engine', 'html'
app.set 'views', __dirname
app.use logger 'dev'
app.use express.static __dirname + '/../'
app.use bodyParser.urlencoded {extended:false}

exports.server = new caesar.searchable.Server {}
exports.entries = {}
exports.keystore = ''

db = {}

app.get '/', (req, res) ->
    view =
        keystore: escape exports.keystore
        entries: exports.entries

    console.log view
    
    res.render './index.html', view

app.post '/post', (req, res) ->
    id = req.param 'id'
    domain = req.param 'domain'
    replaces = req.param 'replaces'
    entry = req.param 'entry'
    keystore = req.param 'keystore'
    index = req.param 'index'
    
    # Verify and decode data.
    if (entry? and not id?) or not keystore? or not index?
        return res.send 'Missing data!'
    
    if entry? and typeof id isnt 'string' then return res.send 'Bad data!'
    if entry? and typeof entry isnt 'string' then return res.send 'Bad data!'
    if typeof keystore isnt 'string' then return res.send 'Bad data!'
    if exports.entries[id]? then return res.send 'Bad data!'
    
    try
        index = JSON.parse index
        replaces = JSON.parse replaces
    catch e then return res.send 'Bad data!'
    
    # Attempt to merge the index.
    #out = exports.server.update domain, index, replaces
    out = update domain, index, replaces

    console.log "domain: ", domain
    console.log "index: ", index
    console.log "replaces: ", replaces
    
    if entry? then exports.entries[id] = entry
    exports.keystore = keystore

    console.log "keystore: ", exports.keystore
    console.log "entries: ", exports.entries
    
    # Route the user back to the homepage; the merge was successful.
    if out is true then res.redirect '/'
    else # Ask the user to re-attempt the merge with new data.
        replaces.push out[0]
        corpus = {}
        
        if entry? then corpus[id] = entry
        corpus[id] =  exports.entries[id] for id in index.docs
        corpus[id] = exports.entries[id] for id in out[1]
        
        view =
            replaces: escape JSON.stringify replaces
            corpus: escape JSON.stringify corpus
        
        res.render './merge.html', view

app.post '/search', (req, res) ->
    # Get and verify query.
    queries = req.param 'query'

    console.log "----> query: ", queries

    console.log "<---- query END"
    
    if not queries? or typeof queries isnt 'string'
        return res.send 'Missing data!'
    
    try queries = JSON.parse queries
    catch e then return res.send 'Bad data!'
    

    # Run query.
    results = []
    for query in queries
        #out = exports.server.search query
        out = search query
        results.push id for id in out when -1 is results.indexOf id
    
    results[i] = exports.entries[id] for i, id of results
    
    view =
        keystore: escape exports.keystore
        entries: results

    console.log view
    
    res.render './index.html', view

search = (query) ->
    out = []
    for dn, trpdrs of query
        if not db[dn]? then return
        domain = db[dn].index
        
        good = (entry) -> entry? and -1 is out.indexOf entry
        out.push domain[trpdr] for trpdr in trpdrs when good domain[trpdr]
    
    out.sort (a, b) -> b[1] - a[1]

update = (domain, index, reps = []) ->
        for dn, cand of db
            if cand.docs.length <= index.docs.length and reps.indexOf(dn) is -1
                return [dn, cand.docs]
        
        delete db[dn] for dn in reps
        db[domain] = index
        
        true

app.listen 3000
