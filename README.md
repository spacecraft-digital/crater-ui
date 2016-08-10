Let us begin where all the best things do, with a limerick:

> _If what you desire is data,
> then nothing will pleasure you greater:
> Through the web-based UI
> or the REST API,
> pull your data right out of the Crater_


This is Crater, in t'ya face: a user interface for the [Crater](https://github.com/spacecraft-digital/crater) database.

Reads and writes data from the database, and also gives a centralised integraton UI for all the many tools and platforms we use.

Greater visibility. Greater power. Greater ease.


## Server side

The backend app is CoffeeScript. The entry point is app.coffee (which is currently a bit of a mess and needs a tidy up!).

The backend uses Express to provide a number of APIs:

1. the web app
2. Composer dependencies for a given project tag
3. full REST API powered by `express-restify-mongoose`
4. reverse proxy to Releases app
5. “Easy Query” API

### 1. the web app

Routes: `/`, `/customers`, `/people`

The web app just serves an empty shell, with a few bits of seed data passed in `<script>` tags, and links to CSS and JavaScript resources used to provide the web app front end.

Reading from and writing to the database is via the REST API.

### 2. Composer dependencies for a given project tag

Route: e.g. `/api/v1/customer/london/dependencies/dev`

Returns a JSON hash of the `require`d dependencies read from the `composer.json` of the `dev` branch of the `london` customer's project's repository (where `dev` could be any branch or tag).

### 3. full REST API powered by `express-restify-mongoose`

Implements a full read/write REST API using [express-restify-mongoose](https://florianholzapfel.github.io/express-restify-mongoose/)

Supports filtered queries, searching, PATCHing to update bits of entities, POSTing new entities.


### 4. reverse proxy to Releases app

Routes: e.g `/api/v1/customer/london/releases`

Proxied to the Releases app defined in `config.releases_url`.


### 5. “Easy Query” API

Allows direct access to parts of a individual entity document. URL slugs are mapped onto document properties — with intelligent intepretation and defaults.

Returns JSON for array and objects, and strings for scalar properties

Example:
 - `/api/v1/customer/london` (returns the whole entity object)
 - `/api/v1/customer/london/repos` (returns the array of repo objects)
 - `/api/v1/customer/london/repo` (returns the first from the array of repo objects)
 - `/api/v1/customer/london/intranet/uat/url` (returns a string URL for London Intranet UAT stage website)
 - `/api/v1/customer/london/website/production/cms-version` (return a string of the version of CMS)


## Client side

Crater UI uses [React](https://facebook.github.io/react/) for the interface, which is built dynamically to match the schema provided by Crater. There is no specific knowledge of Crater's schema within Crater UI (with a [couple](https://github.com/spacecraft-digital/crater-ui/blob/ac2cc2b60ee43fccbdb2dc3c5593b86dac55f482/frontend/CraterUi.coffee#L223) of [minor](https://github.com/spacecraft-digital/crater-ui/blob/ac2cc2b60ee43fccbdb2dc3c5593b86dac55f482/app.coffee#L162) exceptions at present to achieve nicer ordering).

If a field is added or changed within Crater, Crater UI will adapt itself to match with no changes required to Crater UI. Like magic, but without needing a smoke machine.

Key features:

1. type anywhere to switch
2. keyboard shortcuts
auto save
double click to edit
edit mode and view mode

For each entity type (currently `Customers` and `People`), Crater UI web app offers three views:

#### 1. Listing of each entity in the database

Type part of a name and press return to switch to that entity. Or click, if that's your kind of thing.

Just start typing any entity name anywhere in the app (when not editing a form field) to trigger Listing View (as an overlay). Or press `Esc` a few times to switch back to Listing View.


#### 2. Single entity in View Mode

Displays all the data for the given entity. The structure is derived from Crater's schema.

The entity's information is displayed according to its structure, with subdocuments visually grouped. Entities with key-value properties will be displayed in compact mode (e.g. Software).

The view is built using the ‘view’ React components (e.g. `react/string/view.coffee`) and the ‘view’ views (e.g. `/views/properties/string/view.rt`).

Click the toggle at the top of the page to enter Edit Mode, or double click any data field to jump straight to edit that field.

To switch to a different entity, just type that entity's name or click the entity name at the top to see a dropdown list.


#### 3. Single entity in Edit Mode

As you might expect, Edit Mode gives access to edit an entity's data. The structure is derived from the Crater schema, but the layout differs somewhat from View Mode due to the different intent of the view.



## Developing

```sh
$ git clone git@github.com:spacecraft-digital/crater-ui.git
$ cd crater-ui
$ npm install
$ npm run start -- --debug
```

The `-- --debug` starts Crater UI in debug mode.

By default this will start the server on port 443. You can change that in `config.coffee` — or override it just for development in `config-dev.coffee`

You'll need to pass some secrets, and have access to a MongoDB instance and a memcache server.

The notes in [Jiri](https://github.com/spacecraft-digital/jiri/blob/develop/docs/developing-jiri.md) documentation regarding secrets and tunnels apply.

It's recommended that you use a local memcached service. You can use a local MongoDB server or connect to a remote one through an SSH tunnel.

## Running in Production

You can use something like [`forever`](https://www.npmjs.com/package/forever) to keep the service alive in production.

```
forever start -c coffee --workingDir=/path/to /path/to/app.coffee
```