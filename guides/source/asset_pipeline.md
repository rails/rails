**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON https://guides.rubyonrails.org.**

The Asset Pipeline
==================

This guide covers the asset pipeline.

After reading this guide, you will know:

* What the asset pipeline is and what it does.
* The main features of Propshaft, and how to set it up.
* Migrating from Sprockets to Propshaft.
* Alternative libraries for more advanced asset management.

--------------------------------------------------------------------------------

What is an Asset Pipeline?
---------------------------

The Rails Asset Pipeline is a framework designed to for organizing, caching, and
serving static assets. Assets typically include JavaScript, CSS, images, and
other static files that are served to the user. It streamlines and optimizes the
management of these assets to enhance the performance and maintainability of the
application.

The Rails Asset Pipeline is managed by **Propshaft** in Rails 8. Propshaft is
built for an era where transpilation, bundling and compression are less critical
for basic applications, thanks to better browser support and faster networks and
HTTP/2 capabilities. You can read more about [Evolution of techniques to manage
assets](#evolution-of-techniques-to-manage-assets) in the above section.

The simplified design of Propshaft, compared to its predecessor Sprockets,
focuses on essential asset management tasks, and it leaves more complex tasks,
such as JavaScript and CSS bundling and minification, to specialized tools like
`js-bundling-rails` and `css-bundling-rails`, which can be added separately to
your application. Propshaft focuses on fingerprinting and emphasizes
generating digest-based URLs for assets, allowing browsers to cache them, thus
minimizing the need for intricate compilation and bundling.

The asset pipeline uses the [Propshaft](https://github.com/rails/propshaft) gem
and is enabled by default in new Rails 8 applications.

If ,for some reason, you want to disable it during setup, you can use the
`--skip-asset-pipeline` option:

```bash
$ rails new app_name --skip-asset-pipeline
```

NOTE: Prior to version 8, the asset pipeline was powered by Sprockets. You can
read more about the [Sprockets Asset
Pipeline](https://guides.rubyonrails.org/v7.2/asset_pipeline.html) in the Rails
Guides.

Evolution of techniques to manage assets
----------------------------------------

Within the last few years, the evolution of the web has led to significant
changes that have influenced how assets are managed in web applications. These include:

1. **Browser Support**: Modern browsers have improved support for new features
   and syntax, reducing the need for transpilation and polyfills.
2. **HTTP/2**: The introduction of HTTP/2 has made it easier to serve multiple
   files in parallel, reducing the need for bundling.
3. **ES6+**: Modern JavaScript syntax (ES6+) is supported by most modern
   browsers, reducing the need for transpilation and minification.

Therefore, in Rails 8, the asset pipeline powered by Propshaft, no longer
includes Transpilation, Bundling, or Compression by default. However,
Fingerprinting remains an integral part of Propshaft. You can learn more about
it below.

### Transpilation ❌

Transpilation involves converting code from one language or format to another.

For example, converting CoffeeScript to JavaScript.

```javascript
alert "Hello, world!"
```

After transpilation, this code becomes:

```javascript
alert("Hello, world!");
```

In the past, pre-processors like Sass and Less were essential for CSS features
such as variables and nesting. Today, modern CSS supports these natively,
reducing the need for transpilation.

### Bundling ❌

Bundling combines multiple files into one to reduce the number of HTTP requests
a browser needs to make to render a page.

For example, if your application has three JavaScript files:
- menu.js
- cart.js
- checkout.js

Bundling will merge these into a single application.js file.

```javascript
// Contents of menu.js, cart.js, and checkout.js are combined here
```

This was crucial with HTTP/1.1, which limited 6-8 simultaneous connections per
domain. With HTTP/2, browsers fetch multiple files in parallel, making bundling
less critical for modern applications.


### Compression ❌

Compression encodes files in a more efficient format to reduce their size
further when delivered to users. A common technique is Gzip compression.

For example, a CSS file that's 200KB may compress to just 50KB when Gzipped.
Browsers automatically decompress such files upon receipt, saving bandwidth and
improving speed.

Minification is a form of compression that removes unnecessary characters (like
whitespace, comments, and newlines).

Before minification:

```javascript
function add(a, b) {
    // Adds two numbers
    return a + b;
}
```

After minification:

```javascript
function add(a,b){return a+b;}
```

Modern ES6+ syntax is supported by modern browsers,thus reducing the reliance on
minification.

### Fingerprinting ✔️


Fingerprinting is a technique that makes the name of a file dependent on the
contents of the file. A digest of the content is generated and appended to the
name so that when the file contents changes, so does the digest, and therefore
the filename is also changed. For static or infrequently changed content, this
provides an easy way to tell whether two versions of a file are identical, even
across different servers or deployment dates.

When a filename is unique and based on its content, HTTP headers can be set to
encourage caches everywhere (whether at CDNs, at ISPs, in networking equipment,
or in web browsers) to keep their own copy of the content. When the content is
updated, the fingerprint will change. This will cause the remote clients to
request a new copy of the content. This is generally known as _cache busting_.

Without fingerprinting a filename might look like this `styles.css`. However,
with fingerprinting, the filename becomes `styles-a1b2c3d4e5f6.css`.

With fingerprinting, if styles.css is updated, the filename will change, forcing
the browser to fetch the latest version instead of relying on a cached copy.

The manifest is a file that maps logical asset paths to their corresponding
fingerprinted filenames. The manifest is used to look up the correct filename
for an asset. The manifest is typically a JSON file that looks like this:

```json
{
  "application.js": "application-1a2b3c4d5e6f.js",
  "application.css": "application-1a2b3c4d5e6f.css"
}
```

Fingerprinting is enabled by default for both the development and production
environments. When you reference an asset in your application, Rails uses the
manifest to find the correct fingerprinted filename to include in the HTML
output.

Features
--------

Propshaft expects that your assets are already in a browser-ready format—like
plain CSS, JavaScript, or preprocessed images (like JPEGs or PNGs). Propshaft’s
job is simply to organize, version, and serve those assets efficiently. If you
want to use advanced features, like Sass for styles or modern JavaScript
features, you’d usually handle those with a separate tool (like Webpack, Vite,
or esbuild) alongside Propshaft.

In this section, we’ll cover the main features of Propshaft and how it works and
compare it with its predecessor, Sprockets. Sprockets is a more comprehensive
asset management tool that was used in earlier versions of Rails, and handled
tasks like transpilation, bundling, and compression.

### No dependency chains

In Sprockets, you could link files together so they were loaded in the correct
order. For example, you may have had a main JavaScript file that relied on other
files to be loaded first. Sprockets managed this for you automatically, checking
dependencies and loading everything in the correct order.

With Propshaft, it doesn’t automatically understand these dependencies. So, if
you have files that depend on each other, you’ll need to manage the order in
which they load by organizing the files yourself or making sure they’re included
in the right sequence in your HTML or layout files. By specifying each file
manually in your layout, Propshaft lets you control the load order, making sure
dependencies are managed and loaded correctly without needing any automated
dependency management. Below are some strategies to manage dependencies with
Propshaft:

1. Manually include assets in the correct order:

    In your HTML layout (usually application.html.erb for Rails apps) you can
    specify the exact order for loading CSS and JavaScript files by including
    each file individually.

    For example, in the `application.html.erb` layout file you can load each CSS
    or JavaScript in a specific order.

    ```erb
    <head>
      <%= stylesheet_link_tag "reset" %>
      <%= stylesheet_link_tag "base" %>
      <%= stylesheet_link_tag "main" %>
    </head>
    <body>
      <%= javascript_include_tag "jquery" %>
      <%= javascript_include_tag "utilities" %>
      <%= javascript_include_tag "main" %>
    </body>
    ```

    This is important if, for instance, `main.js` relies on `jquery.js` or `utilities.js` to be
    loaded first.

2. Use Modules in JavaScript (ES6)

    If you have dependencies within JavaScript files, ES6 modules can help. By
    using import statements, you can explicitly control dependencies within
    JavaScript code. Just make sure your JavaScript files are set up as modules
    using `<script type="module">` in your HTML:

    ```
    // main.js
    import { initUtilities } from "./utilities.js";
    import { setupFeature } from "./feature.js";

    initUtilities();
    setupFeature();
    ```

    Then in your layout:

    ```
    <script type="module" src="main.js"></script>
    ```

    This way, you can manage dependencies within JavaScript files without relying on
    Propshaft to understand them. By importing modules, you can control the order in
    which files are loaded and ensure dependencies are met.

3. Combine Files when necessary

    If you have several JavaScript or CSS files that must always load together,
    you can combine them into a single file. For example, you could create a
    `combined.js` file that imports or copies code from other scripts. Then,
    just include `combined.js` in your layout to avoid dealing with individual
    file ordering. This can be useful for files that always load together, like
    a set of utility functions or a group of styles for a specific component.
    While this approach can work for small projects or simple use cases, it
    can become tedious and error-prone for larger applications.


4. Consider bundling your JavaScript or CSS using a bundler

    If, for some reason, your project requires advanced features like dependency
    chaining, modern JavaScript syntax, or CSS pre-processing (e.g., Sass or
    PostCSS), consider using `js-bundling-rails` or `css-bundling-rails`. These gems
    integrate tools like Webpack, esbuild, or Vite into your Rails application,
    enabling you to handle complex asset requirements alongside Propshaft.


    Use `js-bundling-rails` with Webpack, esbuild, or Vite to bundle
    JavaScript files, manage dependencies, and transpile modern JavaScript for
    browser compatibility. For more details, check the [js-bundling-rails
    documentation](https://github.com/rails/jsbundling-rails).

    Use `css-bundling-rails` to pre-process stylesheets using tools like Sass
    or Tailwind CSS, making it easier to work with advanced CSS features. For
    more details, check the [css-bundling-rails
    documentation](https://github.com/rails/cssbundling-rails).

    To read more about how to use these gems you can see the [alternative
    libraries](#alternative-libraries) section. These tools complement Propshaft
    by handling the complex processing, while Propshaft efficiently organizes
    and serves the final assets.

### Versioning with digest-based URLs

In Rails, asset versioning helps manage cache behavior by adding unique
identifiers to asset filenames. This ensures that whenever an asset is updated,
the browser sees it as a new file and loads the latest version instead of using
an older, cached one.

Sprockets automatically handled asset fingerprinting, by appending a hash to
filenames whenever assets are updated. Propshaft also uses content-based
fingerprinting and will automatically convert asset paths in CSS to use digested
file names. However, for JavaScript files, you'll have to manually trigger the
transformation of use a bundler.

You can read more about how to use asset versioning in the [Fingerprinting section](#fingerprinting).

### Asset Precompilation

In Propshaft, all assets from the paths configured in `config.assets.paths` are
available for serving and will be copied into `public/assets` when precompiling.
Unlike Sprockets, which only copied assets that were explicitly included in a
bundle, Propshaft automatically processes all assets from the specified paths.
This includes images, stylesheets, JavaScript files, and more.

If you want to exclude certain directories from this process, you can use
`config.assets.excluded_paths`. Read more about this in the [Fingerprinting
section](#fingerprinting).

Once precompiled, these assets can be referenced by their logical path using
helpers like `asset_path`, `image_tag`, and `javascript_include_tag`. In production,
when `assets:precompile` is run, these references are automatically turned into
digest-aware paths. This is done using a `manifest.json` file that is
automatically generated in` public/assets/.manifest.json`. This file maps logical
asset paths to their precompiled file paths.

Using Propshaft in your app
----------------------------------

Propshaft is the default asset pipeline in Rails 8, so you don’t need to install
it separately. When you create a new Rails 8 application, Propshaft is included
by default.

To use Propshaft, you need to configure it properly and organize your assets in
a way that Rails can serve them efficiently.

### Setup

To use Propshaft in your Rails application, you can follow these steps:

1. Create a new Rails 8 application:

    ```bash
    $ rails new myapp
    ```
    This command generates a new Rails application with Propshaft included by
    default.

2. Organize your assets:

      Propshaft expects your assets to be in the `app/assets` directory. You can
      organize your assets into subdirectories like `app/assets/javascripts` for
      JavaScript files, `app/assets/stylesheets` for CSS files, and
      `app/assets/images` for images.

      For example, you can create a new JavaScript file in `app/assets/javascripts`:

      ```javascript
      // app/assets/javascripts/main.js
      console.log("Hello, world!");
      ```

      And a new CSS file in `app/assets/stylesheets`:

      ```css
      /* app/assets/stylesheets/main.css */
      body {
        background-color: red;
      }
      ```

3. Link Assets in Your Application Layout

      In your application layout file (usually `app/views/layouts/application.html.erb`),
      you can include your assets using the `stylesheet_link_tag` and
      `javascript_include_tag` helpers:

      ```erb
      <!-- app/views/layouts/application.html.erb -->
      <!DOCTYPE html>
      <html>
        <head>
          <title>MyApp</title>
          <%= stylesheet_link_tag "main" %>
        </head>
        <body>
          <%= yield %>
          <%= javascript_include_tag "main" %>
        </body>
      </html>
      ```

      This layout includes the `main.css` stylesheet and `main.js` JavaScript file
      in your application.

4. Precompile Assets for Production
    While in development, assets are served
    directly from the source. However, in production, you must precompile
    assets. Run the following command to generate the precompiled assets:

    ```bash
    $ rails assets:precompile
    ```

    This step bundles and optimizes your assets for faster delivery in production.

5. Start your Rails server:

      ```bash
      $ rails server
      ```
      This command starts your Rails server, and you can view your application in a
      web browser.

6. View your application in a web browser:

      Open your web browser and navigate to `http://localhost:3000`. You should see
      your Rails application with the included assets.


Additional Notes
- Propshaft automatically appends a fingerprint to asset filenames (e.g.,
  main-<checksum>.css) to ensure proper caching in production environments.
- If you need to include static files (e.g., fonts, PDFs), place
  them in app/assets or public. Files in public are served directly without
  preprocessing.
- Use the Rails console to inspect asset paths with
  `Rails.application.assets_manifest` or view logs during development for
  asset-related issues.



### Manifest Files

In Propshaft, the `manifest.json` file is automatically created for you when you
create a new Rails application. This file serves as the entry point for your
application’s assets, helping Rails compile and manage files like JavaScript,
CSS, and images. The default `manifest.json` automatically links the main assets,
such as `application.js` and `application.css`, as well as directories for
images and is located in `public/assets/.manifest.json`

Here’s an example of what the json looks like:

```json
{
  "application.css": "application-6d58c9e6e3b5d4a7c9a8e3.css",
  "application.js": "application-2d4b9f6c5a7c8e2b8d9e6.js",
  "logo.png": "logo-f3e8c9b2a6e5d4c8.png",
  "favicon.ico": "favicon-d6c8e5a9f3b2c7.ico"
}
```

### Asset Organization

Propshaft organizes assets within the `app/assets` directory, which includes
subdirectories like `images`, `javascripts`, and `stylesheets`. You can place
your JavaScript, CSS, and image files into these directories, and Propshaft will
automatically manage them during the precompilation process.

However, you can add additional asset paths for Propshaft to search by modifying
`config.assets.paths` in your `config/assets.rb` file.

For example, to add a custom directory, you can do:

```ruby
# Add additional assets to the asset load path.
Rails.application.config.assets.paths << Emoji.images_path
```

Propshaft makes all assets from all the paths it has been configured with
available for serving. During the precompilation process, Propshaft will **copy
all of these assets into `public/assets`**, ensuring that every asset in the
configured paths is available for production use. This is unlike Sprockets,
which did not automatically copy assets into the public folder unless they were
explicitly included in one of the bundled assets. With Propshaft, assets from
any configured path are ready for serving without extra configuration.

These assets can be referenced through their logical path using the normal
helpers like `asset_path`, `image_tag`, `javascript_include_tag`, and all the other
asset helper tags. These logical references are automatically converted into
digest-aware paths in production when `assets:precompile` has been run through the
JSON mapping file found in` public/assets/.manifest.json`.

#### CSS and ERB

Propshaft allows you to include CSS files, and you can also use ERB templates in
your assets. This allows you to include dynamic content in your CSS files, like
configuration values or environment-specific variables, just like in JavaScript
files.

For example, you can include ERB within a CSS file like so:

```css
/* app/assets/stylesheets/application.css.erb */
body {
  background-color: <%= Rails.env.production? ? 'black' : 'white' %>;
}
```

This will evaluate the ERB code and inject the appropriate color based on the
environment.

### Coding Links to Assets

Propshaft does not add any new methods to access your assets - you still use the
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
in the current environment context), this file is served by Propshaft. If a file
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

### Raise an Error When an Asset is Not Found

By default, Propshaft will raise an error if an asset is missing during
precompilation or when trying to serve it in production. This behavior ensures
that missing assets are caught early and makes it easier to debug issues related
to asset loading.

Development vs. Production
--------------------------

### Development Mode

In development mode, Rails and Propshaft are configured for flexibility,
allowing rapid iteration without manual intervention. This setup makes it easier
to manage assets as they change frequently during development.

#### No Caching in Development

In development, Rails is configured to bypass asset caching. This means that
when you modify assets (e.g., CSS, JavaScript), Rails will serve the most
up-to-date version directly from the file system. There's no need to worry
about versioning or file renaming because caching is skipped entirely.
Browsers will automatically pull in the latest version each time you reload
the page.

#### Automatic Reloading of Assets

Rails ensures that asset changes are immediately reflected in the browser. It
will checks for updates with every request, so that when you edit an asset
like a JavaScript or CSS file, simply reloading the page will display the
changes instantly without needing to restart the server.

#### Propshaft Integration in Development

The integration of Propshaft in a Rails application is handled by running
`./bin/dev` instead of the usual `rails s` command. This is part of the process
where the bundlers are instructed to watch for changes in the source files. When
a change is detected, the bundlers will compile the file and place the output in
the designated builds folder.

Propshaft, which is configured to watch this folder, will detect when new or
updated files are placed there. It will then serve the compiled assets to the
browser, ensuring that the latest changes are reflected without the need for
manual intervention

#### Improving Performance with File Watchers

In development, Propshaft checks if any assets have been updated before each
request, using the application's file watcher (by default,
`ActiveSupport::FileUpdateChecker`). If you have a large number of assets, you
can improve performance by using the listen gem and configuring the following
setting in `config/environments/development.rb`:

``ruby
config.file_watcher = ActiveSupport::EventedFileUpdateChecker
``

This will reduce the overhead of checking for file updates and improve
performance during development.

### Production Mode

In production, Rails serves assets with caching enabled to optimize performance,
ensuring that your application can handle high traffic efficiently.

#### Asset Caching and Versioning in Production

In production Rails serves assets with caching enabled to optimize
performance. It compiles assets into a single location and uses the asset
fingerprinting method to ensure that users receive the most up-to-date version
of the asset. You can precompile assets using the `rails:assets:precompile`
task. You can read ore about this is the [Fingerprinting
section](#fingerprinting).

In the production environment Propshaft uses the [fingerprinting
scheme](#fingerprinting). By default Rails assumes assets have been precompiled
and will be served as static assets by your web server.

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
<link rel="stylesheet" href="/assets/application-abcdef1234567890.css">
```

#### Precompiling Assets

Rails comes bundled with a command to compile asset manifests and other files in
the asset pipeline.

Precompilation converts source asset files (e.g., SASS, TypeScript, CSS, or any
other preprocessed files) into files ready to be served to clients. This can
include tasks like compilation, minification, or uglification, depending on the
application's needs. The resulting files are then placed in the `public/assets`
directory, from where they are delivered by the server.

In development mode, precompilation is usually not necessary because the Rails
application server can serve the files directly, often with live reloading
enabled.

In production, precompilation is typically run during deployment to ensure that
the latest versions of the assets are served. To manually run precompilation:

```bash
$ RAILS_ENV=production rails assets:precompile
```

By default, assets are served from the `/assets` directory.

WARNING: Do not run the precompile command in development mode. Running it in
development generates a marker file named `.manifest.json`, which tells the
application that it can serve the compiled assets. As a result, any changes you
make to your source assets won't be reflected in the browser until the
precompiled assets are updated. If your assets stop updating in development
mode, the solution is to remove the .manifest.json file located in
public/assets/. This will force Rails to recompile the assets on the fly,
reflecting the latest changes.

NOTE: Always ensure that the expected compiled filenames end with `.js` or
`.css`.

##### Far-future Expires Header

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

#### CDNs

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

##### Set up a CDN to Serve Static Assets

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
config.asset_host = "mycdnsubdomain.fictional-cdn.com"
```

NOTE: You only need to provide the "host", this is the subdomain and root
domain, you do not need to specify a protocol or "scheme" such as `http://` or
`https://`. When a web page is requested, the protocol in the link to your asset
that is generated will match how the webpage is accessed by default.

You can also set this value through an [environment
variable](https://en.wikipedia.org/wiki/Environment_variable) to make running a
staging copy of your site easier:

```ruby
config.asset_host = ENV["CDN_HOST"]
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

##### Customize CDN Caching Behavior

A CDN works by caching content. If the CDN has stale or bad content, then it is
hurting rather than helping your application. The purpose of this section is to
describe general caching behavior of most CDNs. Your specific provider may
behave slightly differently.

**CDN Request Caching**

While a CDN is described as being good for caching assets, it actually caches the
entire request. This includes the body of the asset as well as any headers. The
most important one being `Cache-Control`, which tells the CDN (and web browsers)
how to cache contents. This means that if someone requests an asset that does
not exist, such as `/assets/i-dont-exist.png`, and your Rails application returns a 404,
then your CDN will likely cache the 404 page if a valid `Cache-Control` header
is present.

**CDN Header Debugging**

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

**CDNs and the Cache-Control Header**

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
  "Cache-Control" => "public, max-age=31536000"
}
```

Now when your application serves an asset in production, the CDN will store the
asset for up to a year. Since most CDNs also cache headers of the request, this
`Cache-Control` will be passed along to all future browsers seeking this asset.
The browser then knows that it can store this asset for a very long time before
needing to re-request it.

[`Cache-Control`]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Cache-Control

**CDNs and URL-based Cache Invalidation**

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

Migrating from Sprockets to Propshaft
-------------------------------------

Propshaft is intentionally simpler than Sprockets, which may make migrating from
Sprockets a fair amount of work. This is especially true if you rely on
Sprockets for tasks like transpiling CoffeeScript or Sass, or if you're using
gems that provide this functionality. In such cases, you'll either need to stop
transpiling or switch to a Node-based transpiler, such as those provided by
`jsbundling-rails` or `cssbundling-rails`.

However, if you're already using a Node-based setup to bundle JavaScript and
CSS, Propshaft should integrate smoothly into your workflow. Since you won’t
need an additional tool for bundling or transpiling, Propshaft will primarily
handle asset digesting and serving.

Some key steps in the migration include:

1. Remove several sprocket gems using the `bundle remove <gem name>` :

  ```bash
  bundle remove sprockets
  bundle remove sprockets-rails
  bundle remove sass-rails
  ```

2. Delete the `config/assets.rb` and `assets/config/manifest.js` files from your
   project.

3. If you've already upgraded to Rails 8, then Propshaft is already included in
   your application, otherwise, install it using `bundle add propshaft`.

4. Remove the `config.assets.paths << Rails.root.join('app', 'assets')` line
   from your `application.rb` file.

5. Migrate asset helpers by replacing all instances of asset helpers (e.g.,
`image_url`) with standard URLs because Propshaft utilizes relative paths. For
example, image_url("logo.png") will become url("/logo.png).

6. If you're relying on Sprockets for transpiling, you'll need to switch to a
   Node-based transpiler like Webpack, esbuild, or Vite. You can use the
   `jsbundling-rails` and `cssbundling-rails` gems to integrate these tools into
   your Rails application.


For more information, you can read the [detailed guide on
how to migrate from Sprockets to
Propshaft](https://github.com/rails/propshaft/blob/main/UPGRADING.md).

Fingerprinting
--------------

As mentioned earlier, fingerprinting is a technique that makes the name of a
file dependent on the contents of the file. A digest of the content is generated
and appended to the name so that when the file contents changes, so does the
digest, and therefore the filename is also changed. This ensures that assets are
properly cached and updated when the content changes, improving cacheability and
performance.

### Asset Precompilation and Digesting

In Propshaft, all assets from the paths configured in `config.assets.paths` are
available for serving and will be copied into public/assets when precompiling.
Unlike Sprockets, which only copied assets that were explicitly included in a
bundle, Propshaft automatically processes all assets from the specified paths.
This includes images, stylesheets, JavaScript files, and more.

When precompiling assets, Propshaft generates digested filenames for all the
assets. For example, a file like `bg/pattern.svg` could become
`bg/pattern-2169cbef.svg`, where `2169cbef` is a digest of the file content. This
allows browsers to efficiently cache assets, since the filename will change
whenever the file content changes.

### Digested Assets in Views
You can reference these digested assets in your views using standard Rails asset
helpers like `asset_path`, `image_tag`, `javascript_include_tag`, and others. For
example, if you reference an image in your CSS like:

```css
 background: url("/bg/pattern.svg");
```
Propshaft will automatically convert this to:

```css
url("/assets/bg/pattern-2169cbef.svg");
```

This ensures that the browser will always fetch the correct version of the asset.

### Digested Assets in JavaScript

In JavaScript, you'll need to manually trigger this transformation by using the `RAILS_ASSET_URL` pseudo-method. Here's an example:

```javascript
export default class extends Controller {
  init() {
    this.img = RAILS_ASSET_URL("/icons/trash.svg");
  }
}
```

This will transform into:

```javascript
export default class extends Controller {
  init() {
    this.img = "/assets/icons/trash-54g9cbef.svg";
  }
}
```

This ensures that the correct, digested file is used in your JavaScript code.

Additionally, if you are using bundlers for your JavaScript, such as Webpacker
or esbuild, you should let the bundlers handle the digest. If Propshaft detects
that a file already has a digest in the name (for example, `script-2169cbef.js`),
it will skip digesting it again. This avoids unnecessary reprocessing of assets
that have already been digested by the bundler.

For managing assets with `import maps`, which is a hash where the names are keys
and the locations are the values, Propshaft will ensure that the assets
referenced in the import map are appropriately handled and mapped to their
digested paths during the precompilation process. This integration allows
seamless management of assets between JavaScript bundlers and Propshaft while
ensuring that the digested file names are respected across the entire stack.

### Bypassing the Digest Step

If you need to reference files that refer to each other, like a JavaScript file
and its source map, and you want to avoid the digesting process, you can
pre-digest these files manually. Propshaft recognizes files with the pattern
`-[digest].digested.js` as files that have already been digested and will retain
their stable file names.

### Excluding Directories from Digestion

You can exclude directories from the precompilation and digestion process by
adding them to `config.assets.excluded_paths`. This is useful if, for example,
you're using `app/assets/stylesheets` as input to a compiler like Dart Sass, and
you don’t want these files to be part of the asset load path.

```ruby
config.assets.excluded_paths = [Rails.root.join("app/assets/stylesheets")]
```

This prevents the specified directories from being processed by Propshaft while
still allowing them to be part of the precompilation process.

We use asset_helpers to make sprockets adjust the name for us.

<!-- - We don't want asset helpers anymore so that node packages work out of the box
  - We did that by taking the cSS compiler and scan for every way that a CSS file can reference an asset
  -  We then generate a manifest file that maps the logical path to the fingerprinted path
  -  If you are using something like bootstrap from node it will work out of the box
 -->

Advanced Asset Management
-------------------------

Over the years there have been multiple default approaches for handling the
assets. The web evolved and we started to see more and more JavaScript-heavy
applications.

There are no one-size-fits-it-all solutions for the various JavaScript and CSS
frameworks/extensions available, and there are other bundling libraries in the
Rails ecosystem that should empower you in the cases where the default setup
isn't enough.

### `jsbundling-rails`

[`jsbundling-rails`](https://github.com/rails/jsbundling-rails) is a gem that
integrates modern JavaScript bundlers into your Rails application. It allows you
to manage and bundle JavaScript assets with tools like [Bun](https://bun.sh),
[esbuild](https://esbuild.github.io/), [rollup.js](https://rollupjs.org/), or
[Webpack](https://webpack.js.org/), offering a runtime-dependent approach for
developers seeking flexibility and performance.

#### How `jsbundling-rails` Works

1. After installation, it sets up your Rails app to use your chosen JavaScript
   bundler.
2. It creates a `build` script in your `package.json` file to compile your
   JavaScript assets.
3. During development, the `build:watch` script ensures live updates to your
   assets as you make changes.
4. In production, the gem ensures that JavaScript is built and included during
   the precompilation step, reducing manual intervention. It does this by
  hooking into Rails' `assets:precompile` task to build JavaScript for all entry
  points during deployment. This integration ensures that your JavaScript is
  production-ready with minimal configuration.

The gem automatically handles entry-point discovery and configuration. By
adhering to Rails conventions, `jsbundling-rails` simplifies the process of
integrating complex JavaScript workflows into Rails projects.

#### When Should You Use It?

`jsbundling-rails` is ideal for Rails applications that:

- Require modern JavaScript features like ES6+, TypeScript, or JSX.

- Need to leverage bundler-specific optimizations like tree-shaking, code
  splitting, or minification.
- Use `Propshaft` for asset management and need a reliable way to integrate
  precompiled JavaScript with the broader Rails asset pipeline.
- Utilize libraries or frameworks that depend on a build step. For example,
  projects requiring transpilation—such as those using
  [Babel](https://babeljs.io/), [TypeScript](https://www.typescriptlang.org/),
  or React JSX—benefit greatly from `jsbundling-rails`. These tools rely on a
  build step, which the gem seamlessly supports.

By offering deep integration with Rails tools like `Propshaft` and simplifying
JavaScript workflows, `jsbundling-rails` empowers you to build rich, dynamic
front-ends while staying productive and adhering to Rails conventions.


### cssbundling-rails

[`cssbundling-rails`](https://github.com/rails/cssbundling-rails) allows
bundling and processing of your CSS using [Tailwind
CSS](https://tailwindcss.com/), [Bootstrap](https://getbootstrap.com/),
[Bulma](https://bulma.io/), [PostCSS](https://postcss.org/), or [Dart
Sass](https://sass-lang.com/), then delivers the CSS via the asset pipeline.

It works in a similar way to `jsbundling-rails` so adds the Node.js dependency
to your application with `yarn build:css --watch` process to regenerate your
stylesheets in development and hooks into `assets:precompile` task in
production.

**What's the difference between Sprockets?** Sprockets on its own is not able to
transpile the Sass into CSS, Node.js is required to generate the `.css` files
from your `.sass`  files. Once the `.css` files are generated then Sprockets is
able to deliver them to your clients.

NOTE: `cssbundling-rails` relies on Node to process the CSS. The
`dartsass-rails` and `tailwindcss-rails` gems use standalone versions of
Tailwind CSS and Dart Sass, meaning no Node dependency. If you are using
`importmap-rails` to handle your JavaScripts and `dartsass-rails` or
`tailwindcss-rails` for CSS you could completely avoid the Node dependency
resulting in a less complex solution.

### `tailwindcss-rails`

[`tailwindcss-rails`](https://github.com/rails/tailwindcss-rails) is a wrapper
gem that integrates [Tailwind CSS](https://tailwindcss.com/) into your Rails
application. By bundling Tailwind CSS with a [standalone
executable](https://tailwindcss.com/blog/standalone-cli), it eliminates the need
for Node.js or additional JavaScript dependencies. This makes it a lightweight
and efficient solution for styling Rails applications.

#### How `tailwindcss-rails` Works

1. When installed, by providing `--css tailwind` to the
  `rails new` command, the gem generates a `tailwind.config.js` file for customizing
   your Tailwind setup and a `stylesheets/application.tailwind.css` file for
   managing your CSS entry points.

2. Instead of relying on Node.js, the gem uses a precompiled Tailwind CSS
   binary. This standalone approach allows you to process and compile CSS
   without adding a JavaScript runtime to your project.

3. During development, changes to your Tailwind configuration or CSS files are
   automatically detected and processed. The gem rebuilds your stylesheets and
  provides a `watch` process to automatically generate Tailwind output in
  development.

4. In production, the gem hooks into the `assets:precompile` task. It processes
   your Tailwind CSS files and generates optimized, production-ready
   stylesheets, which are then included in the asset pipeline. The output is
   fingerprinted and cached for efficient delivery.

#### When Should You Use It?

`tailwindcss-rails` is ideal for Rails applications that:

- Want to use [Tailwind CSS](https://tailwindcss.com/) without introducing a
  Node.js dependency or JavaScript build tools.
- Require a minimal setup for managing utility-first CSS frameworks.
- Need to take advantage of Tailwind's powerful features like custom themes,
  variants, and plugins without complex configuration.

The gem works seamlessly with Rails' asset pipeline tools, like Propshaft,
ensuring that your CSS is preprocessed, digested, and efficiently served in
production environments.

### `importmap-rails`

[`importmap-rails`](https://github.com/rails/importmap-rails) enables a
Node.js-free approach to managing JavaScript in Rails applications. It leverages
modern browser support for [ES
Modules](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Modules)
to load JavaScript directly in the browser without requiring bundling or
transpilation. This approach aligns with Rails' commitment to simplicity and
convention over configuration.

#### How `importmap-rails` Works

-  After installation, `importmap-rails` configures your Rails app to use
  `<script type="module">` tags to load JavaScript modules directly in the
  browser.
- JavaScript dependencies are managed using the `bin/importmap` command, which
  pins modules to URLs, typically hosted on CDNs like
  [jsDelivr](https://www.jsdelivr.com/) that host pre-bundled, browser-ready
  versions of libraries. This eliminates the need for `node_modules` or a
  package manager.
- During development, there’s no bundling step, so updates to your JavaScript
  are instantly available, streamlining the workflow.
- In production, the gem integrates with Propshaft to serve JavaScript files as
  part of the asset pipeline. Propshaft ensures files are digested, cached, and
  production-ready. Dependencies are versioned, fingerprinted, and efficiently
  delivered without manual intervention.

NOTE: While Propshaft ensures proper asset handling, it does not handle
JavaScript processing or transformations — `importmap-rails` assumes your
JavaScript is already in a browser-compatible format. This is why it works best
for projects that don't require transpiling or bundling.

By eliminating the need for a build step and Node.js, `importmap-rails`
simplifies JavaScript management while adhering to Rails conventions.

#### When Should You Use It?

`importmap-rails` is ideal for Rails applications that:

- Do not require complex JavaScript features like transpiling or bundling.
- Use modern JavaScript without relying on tools like
  [Babel](https://babeljs.io/), [TypeScript](https://www.typescriptlang.org/),
  or [React](https://react.dev/).
- Seek a lightweight, dependency-free workflow without Node.js or npm.
- Leverage Rails' built-in tools for managing simple JavaScript needs.

Unlike other JavaScript solutions, `importmap-rails` provides a straightforward,
out-of-the-box approach for Rails developers who want to avoid the complexity of
a JavaScript build pipeline while still utilizing modern JavaScript
capabilities.

TIP: While `importmap-rails` is perfect for simpler JavaScript requirements, it may
not suit applications requiring advanced optimizations like code splitting,
tree-shaking, or minification. For those scenarios, consider using
[`jsbundling-rails`](https://github.com/rails/jsbundling-rails), which
integrates with popular JavaScript bundlers such as Webpack, esbuild, or Bun.
