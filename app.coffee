config = require './config'
# jira = new (require './src/Jira') config
ApiUrlGenerator = require './src/ApiUrlGenerator'
uncamelize = require 'uncamelize'
ucfirst = require 'ucfirst'
_ = require 'lodash'


encode = require 'ent/encode'

slug = require 'slug'
inflect = require('i')()

fs = require 'fs'
https = require 'https'
express = require 'express'
bodyParser = require 'body-parser'
methodOverride = require 'method-override'
restify = require 'express-restify-mongoose'
deepfilter = require 'deep-filter'
Twig = require 'twig'
requestProxy = require 'express-request-proxy'
credentials =
    key: fs.readFileSync('/etc/pki/tls/private/crater.key', 'utf8')
    cert: fs.readFileSync('/etc/pki/tls/certs/2_crater.hq.jadu.net.crt', 'utf8')
chain = fs.readFileSync('/etc/pki/tls/certs/startssl-ca-bundle.crt', 'utf8)

credentials.ca = []
chain = chain.split "\n"
cert = []
for line in chain when line.length isnt 0
  cert.push line
  if line.match /-END CERTIFICATE-/
    credentials.ca.push cert.join "\n"
    cert = []

app = express()
router = express.Router()

app.use bodyParser.json()
app.use methodOverride()

# API URL generation
apiRootUrl = '/api/v1'
apiUrlGenerator = new ApiUrlGenerator apiRootUrl
apiUrlGenerator.register 'release', (customer, project, version, objectPath) ->
    ['releases', slug(customer.name.toLowerCase()), project.name, version, objectPath]
apiUrlGenerator.register 'dependencies', (customer, project, repo, tag) ->
    ['customer', slug(customer.name.toLowerCase()), project.name, repo?.name, 'dependencies', tag]

# GUI URL generation
guiUrlGenerator = new ApiUrlGenerator
guiUrlGenerator.register 'customer', (customer) ->
    [slug(customer.name.toLowerCase())]

# if 'mixed' is a string, an object will be returned with this as the value of
# a property named 'property'
Twig.extendFilter 'objectFromString', (mixed, property) ->
    if typeof mixed is 'string'
        o = {}
        o[property] = mixed
        return o
    mixed

Twig.extendFilter 'uncamelize', uncamelize
Twig.extendFilter 'upperFirst', ucfirst
Twig.extendFilter 'slug', slug
# remove the schema and trailing slash from URL
Twig.extendFilter 'cleanUrl', (url) -> url.replace new RegExp('(^https?://|/$)', 'ig'), ''

Twig.extendFunction 'apiUrl', apiUrlGenerator.generateUrl
Twig.extendFunction 'url', guiUrlGenerator.generateUrl

###########################

filterIds = (obj) -> deepfilter obj, (value, prop) -> return prop != '_id'
# takes a Mongoose document and returns an object suitable for API output
prepareForJson = (doc) ->
    data = if doc.toObject then doc.toObject virtuals: false, versionKey: false else doc
    if typeof data is 'object'
        return filterIds data
    else
        return data

# if the slug given in the url doesn't exactly match the entity codename,
# redirect so it does
# This provides feedback on the entity name search, and canonical URLs
#
# slug should _not_ be URI encoded
assertCanonicalPath = (url, slug, entity, res) ->
    # redirect aliases to exact entity name
    if slug isnt entity.codename
        url = url.replace new RegExp("/#{encodeURIComponent slug}(/|$)"), "/#{encodeURIComponent entity.codename}$1"
        res.redirect 302, url
        return false
    return true

# a function to recursive down an object
#
# @param child - string - the name of the property of the target
# @param target - object
findSubtarget = (child, target) ->
    if target[child]
        target = target[child]
    else if target?.findSubtarget
        subtarget = target.findSubtarget child
        return null unless subtarget
        target = subtarget.target
        # if the query wasn't consumed in finding the subtarget
        # (i.e. a default subtarget was used), try and use the child name
        # again to go deeper
        if subtarget.query is child
            target = findSubtarget child, target
    else
        return null
    return target

descendIntoObject = (target, objectPath, res) ->
    parts = objectPath.split '/' if typeof objectPath is 'string'
    for part, i in parts
        continue if part is ''
        throw new Error "Cannot descend into scalar value `#{encode part}`" unless typeof target is 'object'
        previousTarget = target
        target = findSubtarget part, target
        return null if target is previousTarget
        if target is null
            throw new Error "'#{encode part}' not found"
            return null
    return target

sendJsonOrScalar = (o, res) ->
    # object or array
    if typeof o is 'object'
        res.json prepareForJson o
    else
        res.contentType 'text/plain'
        res.send o

###########################

app.set 'views', __dirname + '/views'
app.set 'view engine', 'twig'

app.set 'twig options',
    strict_variables: false


app.use express.static __dirname + '/public'

extractSimpleSchema = (model) ->
    types = {}
    for key, properties of model.schema.paths
        types[key] =
            type: properties?.instance
        if properties?.schema
            types[key].childSchema = extractSimpleSchema properties
            types[key].childType = 'Object'
            # pass the name of the Schema
            types[key].childMeta = properties.schema.options.crater || {}
            # which property functions as the name
            if properties.schema.statics.getNameProperty
                types[key].nameProperty = properties.schema.statics.getNameProperty()
        else if properties?.instance is 'Array'
            types[key].childType = properties.caster?.instance

        if properties?.options?.crater
            _.extend types[key], properties.options.crater
    types

getModel = (db, res, name) ->
    try
        db.model ucfirst inflect.singularize name
    catch e
        res.status(404).send('Unknown Entity type')

require('dev-tunnels') config
.then -> require('crater') config.mongo_url
.then (db) ->

    router.use '*', (req, res, next) ->
        res.setHeader 'Strict-Transport-Security', 'max-age=31536000; includeSubDomains, preload'
        next()

    router.get '/', (req, res) ->
        res.redirect(303, '/customers')

    router.get '/:entity/:name?', (req, res) ->
        Entity = getModel db, res, req.params.entity
        return unless Entity and Entity.find

        Entity.find().select('name _id')
        .then (entities) ->
            order =
                name: undefined
                projects:
                    childSchema:
                        name: undefined
                        defaultProject: undefined
                        notes: undefined
                        projectManager: undefined
                        state: undefined
                        goLiveDate: undefined
                        platform: undefined
                        hostedByJadu: undefined
                        stages:
                            childSchema:
                                name: undefined
                                urls: undefined
                                servers: undefined
                                software: undefined
                        repos: undefined
                aliases: undefined
            schema = extractSimpleSchema Entity
            _.defaultsDeep order, schema
            res.render 'main.twig',
                schema: order
                entities: (name: c.name, id: c.id for c in entities)
                collections: ['customers', 'people']

    # Return schema for Customer
    router.get '/schema/v1/:entity', (req, res) ->
        Entity = getModel db, res, req.params.entity
        return unless Entity and Entity.find

        res.json extractSimpleSchema Entity.schema.paths

    # list dependencies for project tag
    router.get "#{apiRootUrl}/customer/:name/:project?/:repo?/dependencies/:tag?", (req, res) ->
        Customer = db.model 'Customer'
        Customer.findOneByName req.params.name
        .catch (err) ->
            res.status(404).send('Customer not found')
        .then (customer) ->
            # return unless assertCanonicalPath req.path, req.params.name, customer, res

            project = customer.getProject req.params.project
            return res.status(404).send("#{encode customer.name} project '#{encode req.params.project}' not found") unless project

            if req.params.repo
                repo = project.getRepo req.params.repo
                return res.status(404).send("No #{encode req.params.repo} repository information available") unless repo
            else
                repo = project.getRepo()
                return res.status(404).send("No repository available for #{encode customer.name} #{encode project.getName(true)}") unless repo

            url = "#{repo.webUrl}/raw/#{req.params.tag or 'dev'}/composer.json"

            https.get url, (response) ->
                if response.statusCode is 200
                    s = ''
                    response.on 'data', (chunk) ->
                        s += chunk
                    response.on 'end', =>
                        ComposerJson = require './src/ComposerJson'
                        composerJson = new ComposerJson s
                        res.json composerJson.getDependencies()
                else
                    res.status(500).send("Unable to retrieve #{encode url}")

    # REST API for each entity type
    for collection in config.collections
        collectionName = ucfirst inflect.singularize collection
        Entity = db.model collectionName
        restify.serve router, Entity,
            name: collection
            private: [
                '__v'
                'projects._id'
                'projects.stages._id'
                'projects.stages.software._id'
                'projects.stages.servers._id'
            ]
            onError: (err, req, res, next) ->
                console.log if err.stack then err.stack else err
                next "Something went wrong"


    # proxy releases to releases app
    router.get "#{apiRootUrl}/:entity/:name/releases", requestProxy
        url: "#{config.releases_url}/api/v1/:entity/:name/releases"

    # specific customer easy query
    router.get ["#{apiRootUrl}/:entity/:name", "#{apiRootUrl}/:entity/:name/*"], (req, res) ->
        entityType = req.params.entity
        Entity = getModel db, res, entityType
        return unless Entity and Entity.find

        Entity.findOneByName req.params.name.replace /-/g, ' '
        .then (entity) ->
            return res.status(404).send("#{entityType} not found") unless entity

            return unless assertCanonicalPath req.path, req.params.name, entity, res

            target = entity
            target = descendIntoObject target, req.params[0], res if req.params[0]
            return res.status(404).send("#{encode req.params[0]} not found") unless target

            sendJsonOrScalar target, res
        .catch (err) ->
            if err?.message.match /(not found|Cannot descend into scalar value)/
                res.status(404).send(err.message)
            else
                console.log err.stack||err
                res.status(500).send('Something went a bit wrong')

    app.use router

    https.createServer(credentials, app).listen config.port, "0.0.0.0", ->
      console.log("REST API on port #{config.port}")


    if config.redirect80
        httpServer = express()
        httpServer.all '*', (req, res) ->
            res.redirect(301, "https://#{req.hostname}#{req.originalUrl}")

        httpServer.listen 80, "0.0.0.0", ->
            console.log "Listening on port 80 to redirect"

.catch (e) -> console.log e.stack
