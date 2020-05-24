# Webpacker

This guide will show you how to install and use Webpacker to package  JavaScript, CSS, and other assets for the client-side of your Rails application.

After reading this guide, you will know:

* What Webpacker does and why it is different from Sprockets.
* How to install Webpacker and integrate it with your framework of choice.
* How to use Webpacker for JavaScript assets.
* How to use Webpacker for CSS assets.
* How to use Webpacker for static assets.
* How to deploy a site that uses Webpacker.
* How to use Webpacker in alternate Rails contexts, such as engines or Docker containers.

## What Is Webpacker?

Webpacker is a Rails wrapper around the [webpack](https://webpack.js.org) build system that provides a standard webpack configuration and reasonable defaults.

### What is webpack?

The goal of webpack, or any front-end build system, is to allow you to write your front-end code in a way that is convenient for developers and then package that code in a way that is convenient for browsers. With webpack, you can manage JavaScript, CSS, and static assets like files or fonts. Webpack will allow you to write your code, reference other code in your application, transform you code, and combine your code into easily downloadable packs.

## How is Webpacker Different from Sprockets?

Rails also ships with Sprockets, an asset-packaging tool whose features overlap with Webpacker. Both tools will compile your JavaScript into into browser-friendly files, and minify and fingerprint them in production. Both tools allow you to incrementally change files in development.

Sprockets, which was designed to be used with Rails, is somewhat simpler to integrate. In particular, code can be added to Sprockets via a Ruby gem. However, webpack is better at integrating with more current JavaScript tools and NPM packages, and allows for a wider range of integration.

You should choose webpacker over Sprockets on a new project, if you want to use NPM packages, and if you want access to the most current JavaScript features and tools. You should choose Sprockets over Webpacker for legacy applications where migration might be costly, if you want to integrate using Gems, or if you have a very small amount of code to package.

If you are familiar with Sprockets, the following guide might give you some idea of how to translate. Please note that each tool has a slightly different structure, and the concepts don't directly map onto each other

|Task              | Sprockets         | Webpacker         |
|------------------|-------------------|-------------------|
|Attach JavaScript |javascript_link_tag|javascript_pack_tag|
|Attach CSS        |stylesheet_link_tag|stylesheet_pack_tag|
|Link to an image  |image_url          |image_pack_tag     |
|Link to an asset  |asset_url          |asset_pack_tag     |
|Require a script  |//= require        |require or include |

## Installing Webpacker

In order to use Webpacker you must be using the Yarn package manager, version 1.x or up, and you must have Node.js installed, version 10.13.0 and up.

Webpacker is installed by default in Rails 6.0 and up. In an older version, you can install it when a new project is created by adding `--webpack` to a `rails new` command. In an existing project, webpacker can be added by installing `bundle exec rails webpacker:install`. This installation command creates local files:

* The Webpacker configuration at `config/webpacker.html`
* Configuration files for Babel, PostCSS, and Browserslist
* A place for your front-end source at `app/javascript`

The installation also calls the `yarn` package manager, creates a `package.json` file with a basic set of packages listed, and uses Yarn to install these dependencies.

### Integrating Frameworks with Webpacker

Webpacker also contains support for many popular JavaScript frameworks and tools. Typically, these are installed either when the application is created with something like `rails new myapp --webpack=whatever` or with a separate command line task, like `rails:install:whatever`.

These integrations typically install the set of NPM packages needed to get started with the framework or tool, a "hello world" page to show that it works, and any other webpack loaders or transformations needed to compile the tool. The supported frameworks and tools are (use the tool name in all lowercase in the installation command):

* Angular (also installs TypeScript)
* CoffeeScript
* Elm
* ERB
* React
* Stimulus
* Svelte
* TypeScript
* Vue

## Using Webpacker for JavaScript

With Webpacker installed, by default any JavaScript file in the `app/javascripts/packs` directory will get compiled to its own pack file.

So if you have a file called `javascript/packs/application.js`, Webpacker will create a pack called `application`, and you can add it to your Rails application with the code `<%= javascript_pack_tag "application" %>`. With that in place, in development, Rails will re-compile the `application.js` file every time it changes and you you load a page that uses that pack. Typically, the file in the actual `packs` directory will be a manifest that mostly loads other files, but it can also have arbitrary JavaScript code.

The default pack created for you by Webpacker will link to Rails default JavaScript packages if they have been included in the project:

```
require("@rails/ujs").start()
require("turbolinks").start()
require("@rails/activestorage").start()
require("channels")
```

You'll need to include a pack that requires these packages to use them in your Rails application.

### Where to Place Files

### Linking Files

### Babel and TypeScript

## Using Webpacker for CSS

## Using Webpacker for Static Assets

## Webpacker in Rails Engines

## Running Webpacker in Development

Webpacker ships with two binstubs: `./bin/webpack` and `./bin/webpack-dev-server`. Both are thin wrappers around the standard `webpack.js` and `webpack-dev-server.js` executables to ensure that the right configuration files and environmental variables are loaded based on your environment.

In development, Webpacker compiles on demand rather than upfront by default from `compile: true` in the `config/webpacker.yml` file. This happens when you refer to any of the pack assets using the Webpacker helper methods. This means that you don't have to run any separate processes. Compilation errors are logged to the standard Rails log.

### webpack-dev-server

If you want to use live code reloading, or you have enough JavaScript that on-demand compilation is too slow, you'll need to run `./bin/webpack-dev-server` or `ruby ./bin/webpack-dev-server`. Windows users will need to run these commands in a terminal separate from `bundle exec rails s`. This process will watch for changes in the `app/javascript/packs/*.js` files and automatically reload the browser to match.

```bash
# webpack dev server
./bin/webpack-dev-server

# watcher
./bin/webpack --watch --colors --progress

# standalone build
./bin/webpack
```

Once you start this development server, Webpacker will automatically start proxying all webpack asset requests to this server. When you stop the server, it'll revert back to on-demand compilation.

You can use environment variables as options supported by [webpack-dev-server](https://webpack.js.org/configuration/dev-server/) in the form `WEBPACKER_DEV_SERVER_<OPTION>`. Please note that these environmental variables will always take precedence over the ones already set in the configuration file, and that the _same_ environmental variables must be available to the `rails server` process.

```bash
WEBPACKER_DEV_SERVER_HOST=example.com WEBPACKER_DEV_SERVER_INLINE=true WEBPACKER_DEV_SERVER_HOT=false ./bin/webpack-dev-server
```

### Hot module replacement

Webpacker out-of-the-box supports HMR with webpack-dev-server and you can toggle it by setting dev_server/hmr option inside webpacker.yml.

Checkout this guide for more information:

https://webpack.js.org/configuration/dev-server/#devserver-hot
To support HMR with React you would need to add react-hot-loader. Checkout this guide for more information:

https://gaearon.github.io/react-hot-loader/getstarted/

Don't forget to disable HMR if you are not running webpack-dev-server otherwise you will get not found error for stylesheets.

### Notes

* By default, the webpack dev server listens on `localhost` in development for security purposes. However, if you want your app to be available over local LAN IP or a VM instance like vagrant, you can set the `host` when running `./bin/webpack-dev-server` binstub:
    ```bash
    WEBPACKER_DEV_SERVER_HOST=0.0.0.0 ./bin/webpack-dev-server
    ```
* You need to allow webpack-dev-server host as an allowed origin for `connect-src` if you are running your application in a restrict CSP environment (like Rails 5.2+). This can be done in Rails 5.2+ in the CSP initializer `config/initializers/content_security_policy.rb` with a snippet like this:
    ```ruby
      Rails.application.config.content_security_policy do |policy|
        policy.connect_src :self, :https, 'http://localhost:3035', 'ws://localhost:3035' if Rails.env.development?
      end
    ```
* Don't forget to prefix `ruby` when running these binstubs on Windows
* See additional notes in the [rails/webpacker docs on the webpack-dev-server usage](https://github.com/rails/webpacker/blob/master/docs/webpack-dev-server.md).

## Webpacker in Production

### Deploying Webpacker

### Webpacker and Docker

## Extending and Customizing Webpacker

## Troubleshooting Common Problems

## Upgrading Webpacker

## Credits

* [Webpacker Documentation](https://github.com/rails/webpacker)
* Noel Rappin
* Niklas Häusele
* [The React-Rails Sprockets or Wepbacker Page](https://github.com/reactjs/react-rails/wiki/Choosing-Sprockets-or-Webpacker), edited by Greg Myers, was useful.
