**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON https://guides.rubyonrails.org.**

The Asset Pipeline
==================

This guide covers the asset pipeline.

After reading this guide, you will know:

* What the asset pipeline is and what it does.
* How to properly organize your application assets.
* The benefits of the asset pipeline.
* How to add a pre-processor to the pipeline.
* How to package assets with a gem.

--------------------------------------------------------------------------------

What is the Asset Pipeline?
---------------------------

The asset pipeline provides a framework to handle the delivery of JavaScript and
CSS assets. This is done by leveraging technologies like HTTP/2 and techniques like
concatenation and minification. Finally, it allows your
application to be automatically combined with assets from other gems.

The asset pipeline is implemented by the [importmap-rails](https://github.com/rails/importmap-rails), [sprockets](https://github.com/rails/sprockets) and [sprockets-rails](https://github.com/rails/sprockets-rails) gems, and is enabled by default. You can disable it while creating a new application by
passing the `--skip-asset-pipeline` option.

```bash
$ rails new appname --skip-asset-pipeline
```

NOTE: This guide is focusing on the default asset pipeline using only `sprockets` for CSS and `importmap-rails` for JavaScript processing. The main limitation of those two is that there is no support for transpiling so you can't use things like `Babel`, `Typescript`, `Sass`, `React JSX format` or `TailwindCSS`. We encourage you to read the [Alternative Libraries section](#alternative-libraries) if you need transpiling for your JavaScript/CSS.

## Main Features

The asset pipeline's first feature is inserting a SHA256 fingerprinting
into each filename so that the file is cached by the web browser and CDN. This
fingerprint is automatically updated when you change the file contents, which
invalidates the cache.

The second feature of the asset pipeline is to use [import maps](https://github.com/WICG/import-maps)
when serving JavaScript files. This lets you build modern applications using
Javascript libraries made for ES modules (ESM) without the need for transpiling
and bundling. In turn, **this eliminates the need for Webpack, yarn, node or any
other part of the JavaScript toolchain**.

The third feature of the asset pipeline is to concatenate all CSS files into
one main `.css` file, which is then minified or compressed.
As you'll learn later in this guide, you can customize this strategy to group
files any way you like. In production, Rails inserts a SHA256 fingerprint into
each filename so that the file is cached by the web browser. You can invalidate
the cache by altering this fingerprint, which happens automatically whenever you
change the file contents.

The fourth feature of the asset pipeline is it allows coding assets via a
higher-level language for CSS.

### What is Fingerprinting and Why Should I Care?

Fingerprinting is a technique that makes the name of a file dependent on the
contents of the file. When the file contents change, the filename is also
changed. For static or infrequently changed content, this provides an
easy way to tell whether two versions of a file are identical, even across
different servers or deployment dates.

When a filename is unique and based on its content, HTTP headers can be set to
encourage caches everywhere (whether at CDNs, at ISPs, in networking equipment,
or in web browsers) to keep their own copy of the content. When the content is
updated, the fingerprint will change. This will cause the remote clients to
request a new copy of the content. This is generally known as _cache busting_.

The technique Sprockets uses for fingerprinting is to insert a hash of the
content into the name, usually at the end. For example a CSS file `global.css`

```
global-908e25f4bf641868d8683022a5b62f54.css
```

This is the strategy adopted by the Rails asset pipeline.

Fingerprinting is enabled by default for both the development and production
environments. You can enable or disable it in your configuration through the
[`config.assets.digest`][] option.

### What are Import Maps and Why Should I Care?

Import maps let you import JavaScript modules using logical names that map to versioned/digested files – directly from the browser. So you can build modern JavaScript applications using JavaScript libraries made for ES modules (ESM) without the need for transpiling or bundling.

With this approach, you'll ship many small JavaScript files instead of one big JavaScript file. Thanks to HTTP/2 that no longer carries a material performance penalty during the initial transport, and in fact offers substantial benefits over the long run due to better caching dynamics.

How to use Import Maps as Javascript Asset Pipeline
-----------------------------

Import Maps are the default Javascript processor, the logic of generating import maps is handled by the [`importmap-rails`](https://github.com/rails/importmap-rails) gem.

WARNING: Import maps are used only for Javascript files and can not be used for CSS delivery. Check the [Sprockets section](#how-to-use-sprockets) to learn about CSS.

You can find detailed usage instructions on the Gem homepage, but it's important to understand the basics of `importmap-rails`.

### How it works

Import maps are essentially a string substitution for what is referred to as "bare module specifiers". They allow you to standardize the names of JavaScript module imports.

Take for example such an import definition, it won't work without an import map:

```javascript
import React from "react"
```

You would have to define it like this to make it work:

```javascript
import React from "https://ga.jspm.io/npm:react@17.0.2/index.js"
```

Here comes the import map, we define the `react` name to be pinned to the `https://ga.jspm.io/npm:react@17.0.2/index.js` address. With such information our browser accepts the simplified `import React from "react"` definition. Think of import map as about an alias for the library source address.

### Usage

With `importmap-rails` you create the importmap configuration file pinning the library path to a name:

```ruby
# config/importmap.rb
pin "application"
pin "react", to: "https://ga.jspm.io/npm:react@17.0.2/index.js"
```

All of the configured import maps should be attached in `<head>` element of your application by adding  `<%= javascript_importmap_tags %>` . The `javascript_importmap_tags` renders a bunch of scripts in the `head` element:

- JSON with all configured import maps:

```html
<script type="importmap">
{
  "imports": {
    "application": "/assets/application-39f16dc3f3....js"
    "react": "https://ga.jspm.io/npm:react@17.0.2/index.js"
  }
}
</script>
```

- [`Es-module-shims`](https://github.com/guybedford/es-module-shims) acting as polyfill ensuring support for `import maps` on older browsers:

```html
<script src="/assets/es-module-shims.min" async="async" data-turbo-track="reload"></script>
```

- Entrypoint for loading JavaScript from `app/javascript/application.js`:

```html
<script type="module">import "application"</script>
```

### Using npm packages via JavaScript CDNs

You can use the `./bin/importmap` command that's added as part of the `importmap-rails` install to pin, unpin, or update npm packages in your import map. The binstub uses [`JSPM.org`](https://jspm.org/).

It works like so:

```sh
./bin/importmap pin react react-dom
Pinning "react" to https://ga.jspm.io/npm:react@17.0.2/index.js
Pinning "react-dom" to https://ga.jspm.io/npm:react-dom@17.0.2/index.js
Pinning "object-assign" to https://ga.jspm.io/npm:object-assign@4.1.1/index.js
Pinning "scheduler" to https://ga.jspm.io/npm:scheduler@0.20.2/index.js

./bin/importmap json

{
  "imports": {
    "application": "/assets/application-37f365cbecf1fa2810a8303f4b6571676fa1f9c56c248528bc14ddb857531b95.js",
    "react": "https://ga.jspm.io/npm:react@17.0.2/index.js",
    "react-dom": "https://ga.jspm.io/npm:react-dom@17.0.2/index.js",
    "object-assign": "https://ga.jspm.io/npm:object-assign@4.1.1/index.js",
    "scheduler": "https://ga.jspm.io/npm:scheduler@0.20.2/index.js"
  }
}
```

As you can see, the two packages react and react-dom resolve to a total of four dependencies, when resolved via the jspm default.

Now you can use these in your `application.js` entrypoint like you would any other module:

```javascript
import React from "react"
import ReactDOM from "react-dom"
```

You can also designate a specific version to pin:

```sh
./bin/importmap pin react@17.0.1
Pinning "react" to https://ga.jspm.io/npm:react@17.0.1/index.js
Pinning "object-assign" to https://ga.jspm.io/npm:object-assign@4.1.1/index.js
```

Or even remove pins:

```sh
./bin/importmap unpin react
Unpinning "react"
Unpinning "object-assign"
```

You can control the environment of the package for packages with separate "production" (the default) and "development" builds:

```sh
./bin/importmap pin react --env development
Pinning "react" to https://ga.jspm.io/npm:react@17.0.2/dev.index.js
Pinning "object-assign" to https://ga.jspm.io/npm:object-assign@4.1.1/index.js
```

You can also pick an alternative, supported CDN provider when pinning, like [`unpkg`](https://unpkg.com/) or [`jsdelivr`](https://www.jsdelivr.com/) ([`jspm`](https://jspm.org/) is the default):

```sh
./bin/importmap pin react --from jsdelivr
Pinning "react" to https://cdn.jsdelivr.net/npm/react@17.0.2/index.js
```

Remember, though, that if you switch a pin from one provider to another, you may have to clean up dependencies added by the first provider that isn't used by the second provider.

Run `./bin/importmap` to see all options.

Note that this command is merely a convenience wrapper to resolving logical package names to CDN URLs. You can also just lookup the CDN URLs yourself, and then pin those. For example, if you wanted to use Skypack for React, you could just add the following to `config/importmap.rb`:

```ruby
pin "react", to: "https://cdn.skypack.dev/react"
```

### Preloading pinned modules

To avoid the waterfall effect where the browser has to load one file after another before it can get to the deepest nested import, importmap-rails supports [modulepreload links](https://developers.google.com/web/updates/2017/12/modulepreload). Pinned modules can be preloaded by appending `preload: true` to the pin.

It's a good idea to preload libraries or frameworks that are used throughout your app, as this will tell the browser to download them sooner.

Example:

```ruby
# config/importmap.rb
pin "@github/hotkey", to: "https://ga.jspm.io/npm:@github/hotkey@1.4.4/dist/index.js", preload: true
pin "md5", to: "https://cdn.jsdelivr.net/npm/md5@2.3.0/md5.js"

# app/views/layouts/application.html.erb
<%= javascript_importmap_tags %>

# will include the following link before the importmap is setup:
<link rel="modulepreload" href="https://ga.jspm.io/npm:@github/hotkey@1.4.4/dist/index.js">
...
```

NOTE: Refer to [`importmap-rails`](https://github.com/rails/importmap-rails) repository for the most up-to-date documentation.

How to Use Sprockets
-----------------------------

The naive approach to expose your application assets to the web would be to store them in
subdirectories of `public` folder such as `images` and `stylesheets`. Doing so manually would be difficult as most of the modern web applications require the assets to be processed in specific way for eg. compressing and adding fingerprints to the assets.

Sprockets is designed to automatically preprocess your assets stored in the configured directories and after processing expose them in the `public/assets` folder with fingerprinting, compression, source maps generation and other configurable features.

Assets can still be placed in the `public` hierarchy. Any assets under `public`
will be served as static files by the application or web server when
[`config.public_file_server.enabled`][] is set to true. You must define `manifest.js` directives
for files that must undergo some pre-processing before they are served.

In production, Rails precompiles these files to `public/assets` by default. The
precompiled copies are then served as static assets by the web server. The files
in the `app/assets` are never served directly in production.

[`config.public_file_server.enabled`]: configuring.html#config-public-file-server-enabled

### Manifest Files and Directives

When compiling assets with Sprockets, Sprockets needs to decide which top-level targets to compile, usually `application.css` and images. The top-level targets are defined in the Sprockets `manifest.js` file, by default it looks like this:

```js
//= link_tree ../images
//= link_directory ../stylesheets .css
//= link_tree ../../javascript .js
//= link_tree ../../../vendor/javascript .js
```

It contains _directives_ - instructions that tell Sprockets
which files to require in order to build a single CSS or JavaScript file.

This is meant to include the contents of all files found in the `./app/assets/images` directory or any subdirectories as well as any file recognized as JS directly at `./app/javascript` or `./vendor/javascript`.

It will load any CSS from the `./app/assets/stylesheets` directory (not including subdirectories). Assuming that you have `application.css` and `marketing.css` files in the `./app/assets/stylesheets` folder it will allow you to load those stylesheets with `<%= stylesheet_link_tag "application" %>` or `<%= stylesheet_link_tag "marketing" %>` from your views.

You might notice that our JavaScript files aren't loaded from the `assets` directory by default, it's because `./app/javascript` is the default entry point for `importmap-rails` gem and the `vendor` folder is the place where downloaded JS packages would be stored.

In the `manifest.js` you could also specify the `link` directive to load a specific file instead of the whole directory. `link` directive requires providing explicit file extension.

Sprockets load the files specified, processes them if
necessary, concatenates them into one single file, and then compresses them
(based on the value of `config.assets.css_compressor` or `config.assets.js_compressor`).
Compression reduces file size, enabling the browser to download the files faster.

### Controller Specific Assets

When you generate a scaffold or a controller, Rails also generates a
Cascading Style Sheet file for that controller. Additionally, when generating a scaffold, Rails generates the file `scaffolds.css`.

For example, if you generate a `ProjectsController`, Rails will also add a new
file at `app/assets/stylesheets/projects.css`. By default, these files will be
ready to use by your application immediately using the `link_directory` directive in the `manifest.js` file.

You can also opt to include controller-specific stylesheets files
only in their respective controllers using the following:

```html+erb
<%= stylesheet_link_tag params[:controller] %>
```

When doing this, ensure you are not using the `require_tree` directive in your `application.css`, as that could result in your controller-specific assets being included more than once.

### Asset Organization

Pipeline assets can be placed inside an application in one of three locations:
`app/assets`, `lib/assets` or `vendor/assets`.

* `app/assets` is for assets that are owned by the application, such as custom images or stylesheets.

* `app/javascript` is for your JavaScript code

* `vendor/[assets|javascript]` is for assets that are owned by outside entities, such as CSS frameworks or Javascript libraries. Keep in mind that third-party code with references to other files also processed by the asset Pipeline (images, stylesheets, etc.), will need to be rewritten to use helpers like `asset_path`.

Other locations could by configured in the `manifest.js` file, refer to the [Manifest Files and Directives](#manifest-files-and-directives).

#### Search Paths

When a file is referenced from a manifest or a helper, Sprockets searches all of the locations specified in `manifest.js` for it. You can view the search path by inspecting
[`Rails.application.config.assets.paths`](configuring.html#config-assets-paths) in the Rails console.

#### Using Index Files as proxies for folders

Sprockets uses files named `index` (with the relevant extensions) for a special
purpose.

For example, if you have a CSS library with many modules, which is stored in
`lib/assets/stylesheets/library_name`, the file `lib/assets/stylesheets/library_name/index.css` serves as
the manifest for all files in this library. This file could include a list of
all the required files in order, or a simple `require_tree` directive.

It is also somewhat similar to the way that a file in `public/library_name/index.html` can be reached by a request to `/library_name`. This means that you cannot directly use an index file.

The library as a whole can be accessed in the `.css` files like so:

```css
/* ...
*= require library_name
*/
```

This simplifies maintenance and keeps things clean by allowing related code to
be grouped before inclusion elsewhere.

### Coding Links to Assets

Sprockets does not add any new methods to access your assets - you still use the
familiar `stylesheet_link_tag`:

```erb
<%= stylesheet_link_tag "application", media: "all" %>
```

If using the [`turbo-rails`](https://github.com/hotwired/turbo-rails) gem, which is included by default in Rails, then
include the `data-turbo-track` option which causes Turbo to check if
an asset has been updated and if so loads it into the page:

```erb
<%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
```

In regular views you can access images in the `app/assets/images` directory
like this:

```erb
<%= image_tag "rails.png" %>
```

Provided that the pipeline is enabled within your application (and not disabled
in the current environment context), this file is served by Sprockets. If a file
exists at `public/assets/rails.png` it is served by the web server.

Alternatively, a request for a file with an SHA256 hash such as
`public/assets/rails-f90d8a84c707a8dc923fca1ca1895ae8ed0a09237f6992015fef1e11be77c023.png`
is treated the same way. How these hashes are generated is covered in the [In
Production](#in-production) section later on in this guide.

Images can also be organized into subdirectories if required, and then can be
accessed by specifying the directory's name in the tag:

```erb
<%= image_tag "icons/rails.png" %>
```

WARNING: If you're precompiling your assets (see [In Production](#in-production)
below), linking to an asset that does not exist will raise an exception in the
calling page. This includes linking to a blank string. As such, be careful using
`image_tag` and the other helpers with user-supplied data.

#### CSS and ERB

The asset pipeline automatically evaluates ERB. This means if you add an
`erb` extension to a CSS asset (for example, `application.css.erb`), then
helpers like `asset_path` are available in your CSS rules:

```css
.class { background-image: url(<%= asset_path 'image.png' %>) }
```

This writes the path to the particular asset being referenced. In this example,
it would make sense to have an image in one of the asset load paths, such as
`app/assets/images/image.png`, which would be referenced here. If this image is
already available in `public/assets` as a fingerprinted file, then that path is
referenced.

If you want to use a [data URI](https://en.wikipedia.org/wiki/Data_URI_scheme) -
a method of embedding the image data directly into the CSS file - you can use
the `asset_data_uri` helper.

```css
#logo { background: url(<%= asset_data_uri 'logo.png' %>) }
```

This inserts a correctly-formatted data URI into the CSS source.

Note that the closing tag cannot be of the style `-%>`.

### Raise an Error When an Asset is Not Found

If you are using sprockets-rails >= 3.2.0 you can configure what happens
when an asset lookup is performed and nothing is found. If you turn off "asset fallback"
then an error will be raised when an asset cannot be found.

```ruby
config.assets.unknown_asset_fallback = false
```

If "asset fallback" is enabled then when an asset cannot be found the path will be
output instead and no error raised. The asset fallback behavior is disabled by default.

### Turning Digests Off

You can turn off digests by updating `config/environments/development.rb` to
include:

```ruby
config.assets.digest = false
```

When this option is true, digests will be generated for asset URLs.

### Turning Source Maps On

You can turn on source maps by updating `config/environments/development.rb` to
include:

```ruby
config.assets.debug = true
```

When debug mode is on, Sprockets will generate a Source Map for each asset. This
allows you to debug each file individually in your browser's developer tools.

Assets are compiled and cached on the first request after the server is started.
Sprockets sets a `must-revalidate` Cache-Control HTTP header to reduce request
overhead on subsequent requests - on these the browser gets a 304 (Not Modified)
response.

If any of the files in the manifest change between requests, the server
responds with a new compiled file.

In Production
-------------

In the production environment Sprockets uses the fingerprinting scheme outlined
above. By default Rails assumes assets have been precompiled and will be
served as static assets by your web server.

During the precompilation phase a SHA256 is generated from the contents of the
compiled files, and inserted into the filenames as they are written to disk.
These fingerprinted names are used by the Rails helpers in place of the manifest
name.

For example this:

```erb
<%= stylesheet_link_tag "application" %>
```

generates something like this:

```html
<link href="/assets/application-4dd5b109ee3439da54f5bdfd78a80473.css" rel="stylesheet" />
```

The fingerprinting behavior is controlled by the [`config.assets.digest`][]
initialization option (which defaults to `true`).

NOTE: Under normal circumstances the default `config.assets.digest` option
should not be changed. If there are no digests in the filenames, and far-future
headers are set, remote clients will never know to refetch the files when their
content changes.

[`config.assets.digest`]: configuring.html#config-assets-digest

### Precompiling Assets

Rails comes bundled with a command to compile the asset manifests and other
files in the pipeline.

Compiled assets are written to the location specified in [`config.assets.prefix`][].
By default, this is the `/assets` directory.

You can call this command on the server during deployment to create compiled
versions of your assets directly on the server. See the next section for
information on compiling locally.

The command is:

```bash
$ RAILS_ENV=production rails assets:precompile
```

This links the folder specified in `config.assets.prefix` to `shared/assets`.
If you already use this shared folder you'll need to write your own deployment
command.

It is important that this folder is shared between deployments so that remotely
cached pages referencing the old compiled assets still work for the life of
the cached page.

NOTE. Always specify an expected compiled filename that ends with `.js` or `.css`.

The command also generates a `.sprockets-manifest-randomhex.json` (where `randomhex` is
a 16-byte random hex string) that contains a list with all your assets and their respective
fingerprints. This is used by the Rails helper methods to avoid handing the
mapping requests back to Sprockets. A typical manifest file looks like this:

```json
{"files":{"application-<fingerprint>.js":{"logical_path":"application.js","mtime":"2016-12-23T20:12:03-05:00","size":412383,
"digest":"<fingerprint>","integrity":"sha256-<random-string>"}},
"assets":{"application.js":"application-<fingerprint>.js"}}
```

In your application, there will be more files and assets listed in the manifest,
`<fingerprint>` and `<random-string>` will also be generated.

The default location for the manifest is the root of the location specified in
`config.assets.prefix` ('/assets' by default).

NOTE: If there are missing precompiled files in production you will get a
`Sprockets::Helpers::RailsHelper::AssetPaths::AssetNotPrecompiledError`
exception indicating the name of the missing file(s).

[`config.assets.prefix`]: configuring.html#config-assets-prefix

#### Far-future Expires Header

Precompiled assets exist on the file system and are served directly by your web
server. They do not have far-future headers by default, so to get the benefit of
fingerprinting you'll have to update your server configuration to add those
headers.

For Apache:

```apache
# The Expires* directives requires the Apache module
# `mod_expires` to be enabled.
<Location /assets/>
  # Use of ETag is discouraged when Last-Modified is present
  Header unset ETag
  FileETag None
  # RFC says only cache for 1 year
  ExpiresActive On
  ExpiresDefault "access plus 1 year"
</Location>
```

For NGINX:

```nginx
location ~ ^/assets/ {
  expires 1y;
  add_header Cache-Control public;

  add_header ETag "";
}
```

### Local Precompilation

Sometimes, you may not want or be able to compile assets on the production
server. For instance, you may have limited write access to your production
filesystem, or you may plan to deploy frequently without making any changes to
your assets.

In such cases, you can precompile assets _locally_ — that is, add a finalized
set of compiled, production-ready assets to your source code repository before
pushing to production. This way, they do not need to be precompiled separately
on the production server upon each deployment.

As above, you can perform this step using

```bash
$ RAILS_ENV=production rails assets:precompile
```

Note the following caveats:

* If precompiled assets are available, they will be served — even if they no
  longer match the original (uncompiled) assets, _even on the development
  server._

    To ensure that the development server always compiles assets on-the-fly (and
    thus always reflects the most recent state of the code), the development
    environment _must be configured to keep precompiled assets in a different
    location than production does._ Otherwise, any assets precompiled for use in
    production will clobber requests for them in development (_i.e.,_ subsequent
    changes you make to assets will not be reflected in the browser).

    You can do this by adding the following line to
    `config/environments/development.rb`:

    ```ruby
    config.assets.prefix = "/dev-assets"
    ```

* The asset precompile task in your deployment tool (_e.g.,_ Capistrano) should
  be disabled.
* Any necessary compressors or minifiers must be available on your development
  system.

You can also set `ENV["SECRET_KEY_BASE_DUMMY"]` to trigger the use of a randomly
generated `secret_key_base` that's stored in a temporary file. This is useful
when precompiling assets for production as part of a build step that otherwise
does not need access to the production secrets.

```bash
$ SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile
```

### Live Compilation

In some circumstances you may wish to use live compilation. In this mode all
requests for assets in the pipeline are handled by Sprockets directly.

To enable this option set:

```ruby
config.assets.compile = true
```

On the first request the assets are compiled and cached as outlined in [Assets
Cache Store](#assets-cache-store), and the manifest names used in the helpers
are altered to include the SHA256 hash.

Sprockets also sets the `Cache-Control` HTTP header to `max-age=31536000`. This
signals all caches between your server and the client browser that this content
(the file served) can be cached for 1 year. The effect of this is to reduce the
number of requests for this asset from your server; the asset has a good chance
of being in the local browser cache or some intermediate cache.

This mode uses more memory, performs more poorly than the default, and is not
recommended.

### CDNs

CDN stands for [Content Delivery
Network](https://en.wikipedia.org/wiki/Content_delivery_network), they are
primarily designed to cache assets all over the world so that when a browser
requests the asset, a cached copy will be geographically close to that browser.
If you are serving assets directly from your Rails server in production, the
best practice is to use a CDN in front of your application.

A common pattern for using a CDN is to set your production application as the
"origin" server. This means when a browser requests an asset from the CDN and
there is a cache miss, it will grab the file from your server on the fly and
then cache it. For example if you are running a Rails application on
`example.com` and have a CDN configured at `mycdnsubdomain.fictional-cdn.com`,
then when a request is made to `mycdnsubdomain.fictional-cdn.com/assets/smile.png`,
the CDN will query your server once at
`example.com/assets/smile.png` and cache the request. The next request to the
CDN that comes in to the same URL will hit the cached copy. When the CDN can
serve an asset directly the request never touches your Rails server. Since the
assets from a CDN are geographically closer to the browser, the request is
faster, and since your server doesn't need to spend time serving assets, it can
focus on serving application code as fast as possible.

#### Set up a CDN to Serve Static Assets

To set up your CDN you have to have your application running in production on
the internet at a publicly available URL, for example `example.com`. Next
you'll need to sign up for a CDN service from a cloud hosting provider. When you
do this you need to configure the "origin" of the CDN to point back at your
website `example.com`. Check your provider for documentation on configuring the
origin server.

The CDN you provisioned should give you a custom subdomain for your application
such as `mycdnsubdomain.fictional-cdn.com` (note fictional-cdn.com is not a
valid CDN provider at the time of this writing). Now that you have configured
your CDN server, you need to tell browsers to use your CDN to grab assets
instead of your Rails server directly. You can do this by configuring Rails to
set your CDN as the asset host instead of using a relative path. To set your
asset host in Rails, you need to set [`config.asset_host`][] in
`config/environments/production.rb`:

```ruby
config.asset_host = 'mycdnsubdomain.fictional-cdn.com'
```

NOTE: You only need to provide the "host", this is the subdomain and root
domain, you do not need to specify a protocol or "scheme" such as `http://` or
`https://`. When a web page is requested, the protocol in the link to your asset
that is generated will match how the webpage is accessed by default.

You can also set this value through an [environment
variable](https://en.wikipedia.org/wiki/Environment_variable) to make running a
staging copy of your site easier:

```ruby
config.asset_host = ENV['CDN_HOST']
```

NOTE: You would need to set `CDN_HOST` on your server to `mycdnsubdomain
.fictional-cdn.com` for this to work.

Once you have configured your server and your CDN, asset paths from helpers such
as:

```erb
<%= asset_path('smile.png') %>
```

Will be rendered as full CDN URLs like `http://mycdnsubdomain.fictional-cdn.com/assets/smile.png`
(digest omitted for readability).

If the CDN has a copy of `smile.png`, it will serve it to the browser, and your
server doesn't even know it was requested. If the CDN does not have a copy, it
will try to find it at the "origin" `example.com/assets/smile.png`, and then store
it for future use.

If you want to serve only some assets from your CDN, you can use custom `:host`
option your asset helper, which overwrites value set in
[`config.action_controller.asset_host`][].

```erb
<%= asset_path 'image.png', host: 'mycdnsubdomain.fictional-cdn.com' %>
```

[`config.action_controller.asset_host`]: configuring.html#config-action-controller-asset-host
[`config.asset_host`]: configuring.html#config-asset-host

#### Customize CDN Caching Behavior

A CDN works by caching content. If the CDN has stale or bad content, then it is
hurting rather than helping your application. The purpose of this section is to
describe general caching behavior of most CDNs. Your specific provider may
behave slightly differently.

##### CDN Request Caching

While a CDN is described as being good for caching assets, it actually caches the
entire request. This includes the body of the asset as well as any headers. The
most important one being `Cache-Control`, which tells the CDN (and web browsers)
how to cache contents. This means that if someone requests an asset that does
not exist, such as `/assets/i-dont-exist.png`, and your Rails application returns a 404,
then your CDN will likely cache the 404 page if a valid `Cache-Control` header
is present.

##### CDN Header Debugging

One way to check the headers are cached properly in your CDN is by using [curl](
https://explainshell.com/explain?cmd=curl+-I+http%3A%2F%2Fwww.example.com). You
can request the headers from both your server and your CDN to verify they are
the same:

```bash
$ curl -I http://www.example/assets/application-
d0e099e021c95eb0de3615fd1d8c4d83.css
HTTP/1.1 200 OK
Server: Cowboy
Date: Sun, 24 Aug 2014 20:27:50 GMT
Connection: keep-alive
Last-Modified: Thu, 08 May 2014 01:24:14 GMT
Content-Type: text/css
Cache-Control: public, max-age=2592000
Content-Length: 126560
Via: 1.1 vegur
```

Versus the CDN copy:

```bash
$ curl -I http://mycdnsubdomain.fictional-cdn.com/application-
d0e099e021c95eb0de3615fd1d8c4d83.css
HTTP/1.1 200 OK Server: Cowboy Last-
Modified: Thu, 08 May 2014 01:24:14 GMT Content-Type: text/css
Cache-Control:
public, max-age=2592000
Via: 1.1 vegur
Content-Length: 126560
Accept-Ranges:
bytes
Date: Sun, 24 Aug 2014 20:28:45 GMT
Via: 1.1 varnish
Age: 885814
Connection: keep-alive
X-Served-By: cache-dfw1828-DFW
X-Cache: HIT
X-Cache-Hits:
68
X-Timer: S1408912125.211638212,VS0,VE0
```

Check your CDN documentation for any additional information they may provide
such as `X-Cache` or for any additional headers they may add.

##### CDNs and the Cache-Control Header

The [`Cache-Control`][] header describes how a request can be cached. When no CDN is used, a
browser will use this information to cache contents. This is very helpful for
assets that are not modified so that a browser does not need to re-download a
website's CSS or JavaScript on every request. Generally we want our Rails server
to tell our CDN (and browser) that the asset is "public". That means any cache
can store the request. Also we commonly want to set `max-age` which is how long
the cache will store the object before invalidating the cache. The `max-age`
value is set to seconds with a maximum possible value of `31536000`, which is one
year. You can do this in your Rails application by setting

```ruby
config.public_file_server.headers = {
  'Cache-Control' => 'public, max-age=31536000'
}
```

Now when your application serves an asset in production, the CDN will store the
asset for up to a year. Since most CDNs also cache headers of the request, this
`Cache-Control` will be passed along to all future browsers seeking this asset.
The browser then knows that it can store this asset for a very long time before
needing to re-request it.

[`Cache-Control`]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Cache-Control

##### CDNs and URL-based Cache Invalidation

Most CDNs will cache contents of an asset based on the complete URL. This means
that a request to

```
http://mycdnsubdomain.fictional-cdn.com/assets/smile-123.png
```

Will be a completely different cache from

```
http://mycdnsubdomain.fictional-cdn.com/assets/smile.png
```

If you want to set far future `max-age` in your `Cache-Control` (and you do),
then make sure when you change your assets that your cache is invalidated. For
example when changing the smiley face in an image from yellow to blue, you want
all visitors of your site to get the new blue face. When using a CDN with the
Rails asset pipeline `config.assets.digest` is set to true by default so that
each asset will have a different file name when it is changed. This way you
don't have to ever manually invalidate any items in your cache. By using a
different unique asset name instead, your users get the latest asset.

Customizing the Pipeline
------------------------

### CSS Compression

One of the options for compressing CSS is YUI. The [YUI CSS
compressor](https://yui.github.io/yuicompressor/css.html) provides
minification.

The following line enables YUI compression, and requires the `yui-compressor`
gem.

```ruby
config.assets.css_compressor = :yui
```

### JavaScript Compression

Possible options for JavaScript compression are `:terser`, `:closure` and
`:yui`. These require the use of the `terser`, `closure-compiler` or
`yui-compressor` gems, respectively.

Take the `terser` gem, for example.
This gem wraps [Terser](https://github.com/terser/terser) (written for
Node.js) in Ruby. It compresses your code by removing white space and comments,
shortening local variable names, and performing other micro-optimizations such
as changing `if` and `else` statements to ternary operators where possible.

The following line invokes `terser` for JavaScript compression.

```ruby
config.assets.js_compressor = :terser
```

NOTE: You will need an [ExecJS](https://github.com/rails/execjs#readme)
supported runtime in order to use `terser`. If you are using macOS or
Windows you have a JavaScript runtime installed in your operating system.

NOTE: The JavaScript compression will also work for your JavaScript files when you are loading your assets through `importmap-rails` or `jsbundling-rails` gems.

### GZipping your assets

By default, gzipped version of compiled assets will be generated, along with
the non-gzipped version of assets. Gzipped assets help reduce the transmission
of data over the wire. You can configure this by setting the `gzip` flag.

```ruby
config.assets.gzip = false # disable gzipped assets generation
```

Refer to your web server's documentation for instructions on how to serve gzipped assets.

### Using Your Own Compressor

The compressor config settings for CSS and JavaScript also take any object.
This object must have a `compress` method that takes a string as the sole
argument and it must return a string.

```ruby
class Transformer
  def compress(string)
    do_something_returning_a_string(string)
  end
end
```

To enable this, pass a new object to the config option in `application.rb`:

```ruby
config.assets.css_compressor = Transformer.new
```

### Changing the _assets_ Path

The public path that Sprockets uses by default is `/assets`.

This can be changed to something else:

```ruby
config.assets.prefix = "/some_other_path"
```

This is a handy option if you are updating an older project that didn't use the
asset pipeline and already uses this path or you wish to use this path for
a new resource.

### X-Sendfile Headers

The X-Sendfile header is a directive to the web server to ignore the response
from the application, and instead serve a specified file from disk. This option
is off by default, but can be enabled if your server supports it. When enabled,
this passes responsibility for serving the file to the web server, which is
faster. Have a look at [send_file](https://api.rubyonrails.org/classes/ActionController/DataStreaming.html#method-i-send_file)
on how to use this feature.

Apache and NGINX support this option, which can be enabled in
`config/environments/production.rb`:

```ruby
# config.action_dispatch.x_sendfile_header = "X-Sendfile" # for Apache
# config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for NGINX
```

WARNING: If you are upgrading an existing application and intend to use this
option, take care to paste this configuration option only into `production.rb`
and any other environments you define with production behavior (not
`application.rb`).

TIP: For further details have a look at the docs of your production web server:

- [Apache](https://tn123.org/mod_xsendfile/)
- [NGINX](https://www.nginx.com/resources/wiki/start/topics/examples/xsendfile/)

Assets Cache Store
------------------

By default, Sprockets caches assets in `tmp/cache/assets` in development
and production environments. This can be changed as follows:

```ruby
config.assets.configure do |env|
  env.cache = ActiveSupport::Cache.lookup_store(:memory_store,
                                                { size: 32.megabytes })
end
```

To disable the assets cache store:

```ruby
config.assets.configure do |env|
  env.cache = ActiveSupport::Cache.lookup_store(:null_store)
end
```

Adding Assets to Your Gems
--------------------------

Assets can also come from external sources in the form of gems.

A good example of this is the `jquery-rails` gem.
This gem contains an engine class which inherits from `Rails::Engine`.
By doing this, Rails is informed that the directory for this
gem may contain assets and the `app/assets`, `lib/assets` and
`vendor/assets` directories of this engine are added to the search path of
Sprockets.

Making Your Library or Gem a Pre-Processor
------------------------------------------

Sprockets uses Processors, Transformers, Compressors, and Exporters to extend
Sprockets functionality. Have a look at
[Extending Sprockets](https://github.com/rails/sprockets/blob/master/guides/extending_sprockets.md)
to learn more. Here we registered a preprocessor to add a comment to the end
of text/css (`.css`) files.

```ruby
module AddComment
  def self.call(input)
    { data: input[:data] + "/* Hello From my sprockets extension */" }
  end
end
```

Now that you have a module that modifies the input data, it's time to register
it as a preprocessor for your MIME type.

```ruby
Sprockets.register_preprocessor 'text/css', AddComment
```


Alternative Libraries
------------------------------------------

Over the years there have been multiple default approaches for handling the assets. The web evolved and we started to see more and more Javascript-heavy applications. In The Rails Doctrine we believe that [The Menu Is Omakase](https://rubyonrails.org/doctrine#omakase) so we focused on the default setup: **Sprockets with Import Maps**.

We are aware that there are no one-size-fits-it-all solutions for the various JavaScript and CSS frameworks/extensions available. There are other bundling libraries in the Rails ecosystem that should empower you in the cases where the default setup isn't enough.

### jsbundling-rails

[`jsbundling-rails`](https://github.com/rails/jsbundling-rails) is a Node.js dependent alternative to the `importmap-rails` way of bundling JavaScript with [esbuild](https://esbuild.github.io/), [rollup.js](https://rollupjs.org/), or [Webpack](https://webpack.js.org/).

The gem provides `yarn build --watch` process to automatically generate output in development. For production, it automatically hooks `javascript:build` task into `assets:precompile` task to ensure that all your package dependencies have been installed and JavaScript has been built for all entry points.

**When to use instead of `importmap-rails`?** If your JavaScript code depends on transpiling so if you are using [Babel](https://babeljs.io/), [TypeScript](https://www.typescriptlang.org/) or React `JSX` format then `jsbundling-rails` is the correct way to go.

### Webpacker/Shakapacker

[`Webpacker`](webpacker.html) was the default JavaScript pre-processor and bundler for Rails 5 and 6. It has now been retired. A successor called [`shakapacker`](https://github.com/shakacode/shakapacker) exists, but is not maintained by the Rails team or project.

Unlike other libraries in this list `webpacker`/`shakapacker` is completely independent of Sprockets and could process both JavaScript and CSS files. Read the [Webpacker guide](https://guides.rubyonrails.org/webpacker.html) to learn more.

NOTE: Read the [Comparison with Webpacker](https://github.com/rails/jsbundling-rails/blob/main/docs/comparison_with_webpacker.md) document to understand the differences between `jsbundling-rails` and `webpacker`/`shakapacker`.

### cssbundling-rails

[`cssbundling-rails`](https://github.com/rails/cssbundling-rails) allows bundling and processing of your CSS using [Tailwind CSS](https://tailwindcss.com/), [Bootstrap](https://getbootstrap.com/), [Bulma](https://bulma.io/), [PostCSS](https://postcss.org/), or [Dart Sass](https://sass-lang.com/), then delivers the CSS via the asset pipeline.

It works in a similar way to `jsbundling-rails` so adds the Node.js dependency to your application with `yarn build:css --watch` process to regenerate your stylesheets in development and hooks into `assets:precompile` task in production.

**What's the difference between Sprockets?** Sprockets on their own is not able to transpile the Sass into CSS, Node.js is required to generate the `.css` files from your `.sass`  files. Once the `.css` files are generated then `Sprockets` is able to deliver them to your clients.

NOTE: `cssbundling-rails` relies on Node to process the CSS. The `dartsass-rails` and `tailwindcss-rails` gems use standalone versions of Tailwind CSS and Dart Sass, meaning no Node dependency. If you are using `importmap-rails` to handle your Javascripts and `dartsass-rails` or `tailwindcss-rails` for CSS you could completely avoid the Node dependency resulting in a less complex solution.

### dartsass-rails

If you want to use [`Sass`](https://sass-lang.com/) in your application, [`dartsass-rails`](https://github.com/rails/dartsass-rails) comes as a replacement for the legacy `sassc-rails` gem. `dartsass-rails` uses the `Dart Sass` implementation in favour of deprecated in 2020 [`LibSass`](https://sass-lang.com/blog/libsass-is-deprecated) used by `sassc-rails`.

Unlike `sassc-rails` the new gem is not directly integrated with `Sprockets`. Please refer to the [gem homepage](https://github.com/rails/dartsass-rails) for installation/migration instructions.

WARNING: The popular `sassc-rails` gem is unmaintained since 2019.

### tailwindcss-rails

[`tailwindcss-rails`](https://github.com/rails/tailwindcss-rails) is a wrapper gem for [the standalone executable version](https://tailwindcss.com/blog/standalone-cli) of Tailwind CSS v3 framework. Used for new applications when `--css tailwind` is provided to the `rails new` command. Provides a `watch` process to automatically generate Tailwind output in development. For production it hooks into `assets:precompile` task.
