**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Working with JavaScript in Rails
================================

This guide covers the integration of JavaScript into your Rails application.

After reading this guide, you will know:

* The techniques to deliver and integrate JavaScript with Rails.
* How to use an Import Map to deliver JavaScript in your Rails app.
* How to integrate JavaScript bundlers like `esbuild` or `rollup` with Rails.
* The JavaScript libraries included with Rails.
* How to make HTTP requests using JavaScript with the `request.js` library.

--------------------------------------------------------------------------------

Introduction
------------

Rails applications typically deliver server-rendered HTML to the browser. In this
setup, JavaScript is used mainly to add a layer of user interactivity over the HTML
document.

JavaScript files can be delivered individually using an import map, or bundled together
and shipped as a single file. This guide will cover the pros and cons of each approach,
as well as Rails' default JavaScript stack composed of
[Turbo](using_hotwire_with_rails.html#turbo) and [Stimulus](using_hotwire_with_rails.html#stimulus)
(which are part of the [Hotwire](https://hotwired.dev) suite).

NOTE: Rails can also be [used in API-mode](api_app.html) where it speaks JSON or XML,
but in such a setup, the front-end JavaScript application is usually transmitted independently
from the Rails app. As such, this guide covers the usage of JavaScript for server-rendered
applications only.

Modern JavaScript has a standard structure for packaging called
[ECMAScript modules (ESM)](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Modules).
Rails provides two mechanisms to deliver JavaScript written for ESM: an
[import map](#using-a-javascript-import-map), or a
[JavaScript bundler](#using-a-javascript-bundler).

Legacy JavaScript applications may use another structure such as
[`CommonJS`](https://en.wikipedia.org/wiki/CommonJS). In such setups, JavaScript
needs to be compiled and bundled into a single file before transmission to the browser.
Common bundlers for this approach include [Babel](https://babeljs.io)
and [Webpack](https://webpack.js.org), but Rails doesn't integrate tightly with these
tools. You can, however, [deliver pre-built or bespoke JavaScript files](#delivering-bespoke-javascript-files)
using Rails.

Rails uses the [Asset Pipeline](asset_pipeline.html) to deliver all assets,
including JavaScript files, to the browser.

Using a JavaScript Import Map
-----------------------------

A JavaScript
[import map](https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/script/type/importmap)
allows JavaScript files to be delivered separately without bundling and still be
able to reference each other.

It is a JSON object which defines the mapping between the module specifier
passed to an `import` statement, and the path to the actual file to be imported.
Here's an example:

```html
<script type="importmap" data-turbo-track="reload">
{
  "imports": {
    "animations": "/assets/scripts/animations.js",
    "utilities": "/assets/scripts/utilities.js"
  }
}
</script>
```

Scripts can now invoke `import "animations"` or `import "utilities"` and the
browser will import the corresponding file and the module it contains.

In Rails, the import map is constructed using the
[importmap-rails](https://github.com/rails/importmap-rails) gem.

This technique doesn't require an additional build step for your JavaScript.
Your files are delivered as-is, and hence no JavaScript runtime such as Node.js
is required.

### Installing `importmap-rails`

The `importmap-rails` gem is included by default in all new Rails applications.
In older applications, you can install it using:

```bash
$ bundle add importmap-rails
$ bin/rails importmap:install
```

### Declaring JavaScript Files

All your JavaScript files need to be declared in `config/importmap.rb` so Rails
knows to include them in the import map object.

```ruby
# config/importmap.rb

# Declare JavaScript files from your application
pin "application" # app/javascript/application.js
pin "utilities"   # app/javascript/utilities.js

# Declare all files inside a folder
pin_all_from "app/javascript/controllers", under: "controllers"
```

NOTE: All files declared in your `config/importmap.rb` must exist within your
[asset pipeline's load paths](asset_pipeline.html#load_paths).

This will create an import map object similar to:

```html
<script type="importmap" data-turbo-track="reload">
{
  "imports": {
    "application": "/assets/application-d8a8613a.js",
    "utilities": "/assets/utilities-e8dc057d.js",
    "controllers/application": "/assets/controllers/application-3affb389.js",
    "controllers/hello_controller": "/assets/controllers/hello_controller-708796bd.js",
    "controllers": "/assets/controllers/index-ee64e1f1.js"
  }
}
</script>
```

which is rendered in your HTML document's `<head>` using:

```erb
<%= javascript_importmap_tags %>
```

It's worth reiterating that the import map only defines the mapping
between a module specifier and a file. It doesn't execute or import any code.
As part of the above declaration, Rails also renders:

```
<script type="module">import "application"</script>
```

This is the default entry-point for your JavaScript application
(located at `app/javascript/application.js`). Use this file to import
additional JavaScript files such as your Stimulus controllers or
the `utilities` file shown in the above examples.

NOTE: You'll notice that the filenames contain a _hash_. This is added by
[Rails' Asset Pipeline](asset_pipeline.html). It is calculated based on the
file's contents and used to version the files.

See the [Asset Pipeline guide](asset_pipeline.html#javascript-import-map) and
the [`importmap-rails` Readme](https://github.com/rails/importmap-rails) for
further information.

Using a JavaScript Bundler
--------------------------

You can integrate a JavaScript bundler into Rails using the
[`jsbundling-rails`](https://github.com/rails/jsbundling-rails) gem. It supports
a number of bundlers such as [ESBuild](https://esbuild.github.io/),
[Rollup](https://rollupjs.org/guide/en/), [Bun](https://bun.sh), and
[Webpack](https://webpack.js.org/).

`jsbundling-rails` requires a JavaScript runtime. For all bundlers
except Bun, you'll need Node.js. For Bun, you'll just
need to install that as it is both a JavaScript runtime and a bundler.
`jsbundling-rails` will automatically detect the JavaScript bundler, so
you may use alternatives such as Yarn without additional configuration.

### Installing Node.js and Yarn

Find the installation instructions on the
[Node.js website](https://nodejs.org/en/download/) and verify it’s installed
correctly:

```bash
$ node --version
v23.6.1
```

To install Yarn, follow the installation instructions at the
[Yarn website](https://classic.yarnpkg.com/en/docs/install). Verify it's
installed using:

```bash
$ yarn --version
1.22.19
```

### Installing Bun

Follow the installation instructions at the [Bun website](https://bun.sh) and
verify it’s installed:

```bash
$ bun --version
v1.3.13
```

### Installing `jsbundling-rails`

When creating a new Rails app, setup a JavaScript bundler using the `-j` or
`--javascript` flag:

```bash
$ rails new my_new_app -j esbuild
```

```bash
$ rails new my_new_app --javascript=esbuild
```

Add the `jsbundling-rails` gem in an existing Rails app using:

```bash
$ bundle add jsbundling-rails
```

Then configure your chosen bundler with:

```bash
$ bin/rails javascript:install:[bun|esbuild|rollup|webpack]
```

When using `jsbundling-rails`, use `bin/dev` to start the JavaScript bundler
along with Rails server in development. Further information is available in the
[Asset Pipeline guide](asset_pipeline.html#bundling-and-transpiling-javascript).

Delivering Bespoke JavaScript Files
-----------------------------------

You may wish to use Rails to deliver a pre-built or bespoke JavaScript file. This is useful
if your JavaScript application doesn't use ESM, or requires a bundler such as
[Babel](https://babeljs.io) which isn't natively supported within Rails.

You can reference any JavaScript files in the
[asset pipeline's load path](asset_pipeline.html#load_paths) using `javascript_include_tag`:

```erb
<%= javascript_include_tag "application" %>
```

which will render

```html
<script src="/assets/application-5bcb24fe.js"></script>
```

A common setup in this case would be to write your built JavaScript files to `app/assets/builds`
(which is in the asset pipeline's load path), and load them into your HTML document
using `javascript_include_tag`.

Configuring your chosen bundler within Rails is out of scope for this guide. All supported bundlers
are designed to work with ESM and are covered in the previous
section: [Using a JavaScript Bundler](#using-a-javascript-bundler).

NOTE: Files within `app/assets/builds` are excluded from source control by default.

Adding npm Packages
-------------------

### Vendoring npm Packages with `importmap-rails`

When using `importmap-rails`, npm packages are downloaded into the `vendor`
folder in your app and checked into source control.

Add a package to your application using `bin/importmap pin`:

```bash
$ bin/importmap pin ahoy.js
```

This will download the package into your `vendor` folder and declare them in
your `config/importmap.rb`. You can then import the package wherever required:

```javascript
// app/javascript/application.js

import ahoy from "ahoy.js";
```

Or in a Stimulus controller:

```js
import { Controller } from "@hotwired/stimulus"
import ahoy from "ahoy.js";

// Connects to data-controller="ahoy"
export default class extends Controller {
  connect() {
    ahoy.trackView()
  }
}
```

Further information is available in the
[`importmap-rails` Readme](https://github.com/rails/importmap-rails?tab=readme-ov-file#using-npm-packages-via-javascript-cdns).

### Installing npm Packages with a JavaScript Bundler

When using Bun, the Bun package manager installs npm packages:

```bash
$ bun add ahoy.js
```

See the [Bun documentation](https://bun.com/docs/pm/cli/install) for more
information.

For all other bundlers, use Yarn to manage your dependencies:

```bash
$ yarn add ahoy.js
```

Further details are available in the
[Yarn documentation](https://yarnpkg.com/getting-started/usage).

Choosing Between an Import Map and a JavaScript Bundler
-------------------------------------------------------

In all new Rails apps, JavaScript is delivered using an import map. The Rails
team believes that using an import map reduces complexity, improves developer
experience, and delivers performance gains.

For many applications, especially those that rely primarily on
[Hotwire](https://hotwired.dev/), an import map will be the right option for the
long term. You can read more about the reasoning behind making import maps the
default in Rails 7
[here](https://world.hey.com/dhh/rails-7-will-have-three-great-answers-to-javascript-in-2021-8d68191b).

However, there may be use cases that call for a JavaScript bundler. Listed below
are a few considerations where a JavaScript bundler may be more suited to your
app than an import map:

* You cannot serve your assets over HTTP/2.
* Your code requires a transpilation step, such as JSX or TypeScript.
* You need to use JavaScript libraries that include CSS or otherwise rely on
  [Webpack loaders](https://webpack.js.org/loaders/).
* Your JavaScript architecture requires
  [tree-shaking](https://en.wikipedia.org/wiki/Tree_shaking).
* You're using the
  [`cssbundling-rails` gem](https://github.com/rails/cssbundling-rails) to
  manage your CSS.

Rails' JavaScript Libraries
---------------------------

Rails's default front-end stack is [Hotwire](https://hotwired.dev) which is
installed by default in all new Rails apps. A utility library called
[`request.js`](https://github.com/rails/request.js) can be optionally
installed to simplify HTTP requests using JavaScript.

### Hotwire

Hotwire consists of the libraries [Turbo][] and [Stimulus][]
which integrate with Rails via the gems [`turbo-rails`][] and [`stimulus-rails`][].
Refer to the [Using Hotwire in Rails](using_hotwire_in_rails.html) guide for details.

[Turbo]: https://turbo.hotwired.dev/
[Stimulus]: https://stimulus.hotwired.dev/
[`turbo-rails`]: https://github.com/hotwired/turbo-rails
[`stimulus-rails`]: https://github.com/hotwired/stimulus-rails

### `request.js`

Rails protects against
[CSRF attacks](security.html#cross-site-request-forgery-csrf) by
[validating non-`GET` requests with a token](security.html#required-security-token).
The [`request.js`](https://github.com/rails/request.js) library automatically
adds the CSRF token to HTTP requests, making it easier to trigger HTTP requests
using JavaScript.

This library is maintained by the Rails team but it isn't included in Rails by
default, so you'll need to install it:

```bash
$ bundle add requestjs-rails
$ bin/rails requestjs:install
```

Here's an example of a Stimulus controller that uses `request.js` to make a
`POST` request:

```js
import { post } from "@rails/request.js"
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "input" ]

  async fetchSuggestions() {
    const response = await post("/users/suggestions", {
      body: JSON.stringify({
        input: this.inputTarget.value
      })
    })

    if (response.ok) {
      // Do something with the response
    }
  }
}
```

`request.js` will automatically activate JavaScript responses which have a
`content-type` response header of `application/javascript` or
`application/ecmascript`. It will also automatically execute Turbo Stream
responses.

See the [Readme](https://github.com/rails/request.js) for advanced usage and
further installation information.

NOTE: Prior to Rails 7, a JavaScript library called Rails UJS was used to
enhance Rails on the front-end. This library has now been removed from Rails,
and all its functionality has been replaced by Turbo, Stimulus, and request.js.
You can find information about Rails UJS in an
[older version of the guides](/v6.1/working_with_javascript_in_rails.html#unobtrusive-javascript).
