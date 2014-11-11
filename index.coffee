express = require 'express'
config = require('./config').config
http = require 'http'
request = require 'request'
mustache = require 'mustache'
async = require 'async'

rss = '''
<?xml version="1.0" encoding="UTF-8" ?>
    <rss version="2.0">
    <channel>
     <title>SL Reseplanerare</title>
     <description>RSS Feeds for SL buses</description>
     <link>http://reseplanerare.sl.se/</link>
     <lastBuildDate>{{pubDate}}</lastBuildDate>
     <pubDate>{{pubDate}}</pubDate>
     <ttl>300</ttl>
     {{#trip}}
            <item>
              <title>({{departure}} - {{arrival}}) : {{duration}} min</title>
              <description>
Departure: {{departure}}
Arrival: {{arrival}}
Trip time: {{duration}} min
------------------
{{#transports}}
{{name}} ({{Origin.name}} - {{Destination.name}})
{{/transports}}
              </description>
              <link>http://reseplanerare.sl.se/</link>
              <guid>({{departure}} - {{arrival}}) : {{duration}}</guid>
              <pubDate>{{pubDate}}</pubDate>
             </item>
             {{/trip}}
    </channel>
    </rss>
'''

app = express()

app.get('/api', (req, res, next) ->
    from = req.param('start')
    to = req.param('end')

    if !from || !to
        res.status(404)
        res.send('missing either param from or to')
        return

    do ->
        async.waterfall [
          (callback) ->
            request.get config.url + "?key=#{config.apiKey}&originId=#{from}&destId=#{to}", (error, response, body) ->
                if(error)
                    callback(error.error)
                else
                    callback(null, body)
        , (response, callback) ->
            summarize response, callback
        , (summaries, callback) ->
            callback null, mustache.render(rss, {"pubDate": new Date().toISOString(), "trip":summaries})
        ],
        (err, result) ->
        if err
            console.log(err)
            res.status(500)
            res.send(err)
            return

        res.set('Content-Type', 'application/rss+xml')
        res.send(resp)
        next()
)

summarize = (resp, callback) ->
    trips = JSON.parse(resp).TripList.Trip

    if !trips || trips.length < 1
        callback("Could not parse trips. " + resp)

    summaries = trips.map (trip) ->
        {
            duration: trip.dur
            changes: trip.chg
            departure: asArray(trip.LegList.Leg)[0].Origin.time
            arrival: asArray(trip.LegList.Leg)[-1..][0].Destination.time
            startsAt: asArray(trip.LegList.Leg)[0].Origin.name
            endsAt: asArray(trip.LegList.Leg)[-1..][0].Destination.name
            transports: trip.LegList.Leg
        }
    callback(null, summaries)

# Workaround for SL responding with Leg as object if size = 1...
asArray = (obj) ->
  return if Array.isArray(obj) then array else [obj]

httpServer = http.createServer(app)
httpServer.listen(80, () ->
    host = httpServer.address().address
    port = httpServer.address().port

    console.log('App listening at http://%s:%s', host, port)
    )