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

Sprockets, which was designed to be used with Rails, is somewhat simpler to integrate. In particular, code can be added to Sprockets via a Ruby gem. However, webpack is better at integrating with more current JavaScript tools and NPM packages, and allows for a wider range of integration. It is the current practice of Basecamp to use webpack for JavaScript and Sprockets for CSS, although you can do CSS in webpack.

You should choose webpacker over Sprockets on a new project, if you want to use NPM packages, and if you want access to the most current JavaScript features and tools. You should choose Sprockets over Webpacker for legacy applications where migration might be costly, if you want to integrate using Gems, or if you have a very small amount of code to package.

If you are familiar with Sprockets, the following guide might give you some idea of how to translate. Please note that each tool has a slightly different structure, and the concepts don't directly map onto each other

|Task              | Sprockets         | Webpacker         |
|------------------|-------------------|-------------------|
|Attach JavaScript |javascript_link_tag|javascript_pack_tag|
|Attach CSS        |stylesheet_link_tag|stylesheet_pack_tag|
|Link to an image  |image_url          |image_pack_tag     |
|Link to an asset  |asset_url          |asset_pack_tag     |
|Require a script  |//= require        |import or require  |

## Installing Webpacker

In order to use Webpacker you must be using the Yarn package manager, version 1.x or up, and you must have Node.js installed, version 10.13.0 and up.

Webpacker is installed by default in Rails 6.0 and up. In an older version, you can install it when a new project is created by adding `--webpack` to a `rails new` command. In an existing project, webpacker can be added by installing `bundle exec rails webpacker:install`. This installation command creates local files:

|File                    |Location                |Explanation                                                 |
|------------------------|------------------------|------------------------------------------------------------|
|Javascript Folder       | `app/javascript`       |A place for your front-end source                           |
|Webpacker Configuration | `config/webpacker.yml` |Configure the Webpacker gem                                 |
|Babel Configuration     | `babel.config.js`      |Configuration for the https://babeljs.io JavaScript Compiler|
|PostCSS Configuration   | `postcss.config.js`    |Configuration for the https://postcss.org CSS Post-Processor|
|Browserlist             | `.browserslistrc`      |https://github.com/browserslist/browserslist                |


The installation also calls the `yarn` package manager, creates a `package.json` file with a basic set of packages listed, and uses Yarn to install these dependencies.

### Integrating Frameworks with Webpacker

Webpacker also contains support for many popular JavaScript frameworks and tools. Typically, these are installed either when the application is created with something like `rails new myapp --webpack=<framework_name>` or with a separate command line task, like `rails webpacker:install:<framework_name>`.

These integrations typically install the set of NPM packages needed to get started with the framework or tool, a "hello world" page to show that it works, and any other webpack loaders or transformations needed to compile the tool. The supported frameworks and tools are:

INFO. It's possible to install frameworks not included in this list. These are basic integrations of popular choices.

|Framework         |Install command                     |Description                                       |
|------------------|------------------------------------|--------------------------------------------------|
|Angular           |`rails webpacker:install:angular`   |Sets up Angular and Typescript                    |
|CoffeeScript      |`rails webpacker:install:coffee`    |Sets up CoffeeScript                              |
|Elm               |`rails webpacker:install:elm`       |Sets up Elm                                       |
|ERB               |`rails webpacker:install:erb`       |Sets up ERB support on your Javascript files      |
|React             |`rails webpacker:install:react`     |Sets up ReactJS                                   |
|Stimulus          |`rails webpacker:install:stimulus`  |Sets up StimulusJS                                |
|Svelte            |`rails webpacker:install:svelte`    |Sets up Svelte JS                                 |
|TypeScript        |`rails webpacker:install:typescript`|Sets up Typescript for your project using Babel's TypeScript support|
|Vue               |`rails webpacker:install:vue`       |Sets up VueJS                                     |

For More information about the existing integrations, see https://github.com/rails/webpacker/blob/master/docs/integrations.md. 

## Using Webpacker for JavaScript

With Webpacker installed, by default any JavaScript file in the `app/javascripts/packs` directory will get compiled to its own pack file.

So if you have a file called `app/javascript/packs/application.js`, Webpacker will create a pack called `application`, and you can add it to your Rails application with the code `<%= javascript_pack_tag "application" %>`. With that in place, in development, Rails will re-compile the `application.js` file every time it changes and you you load a page that uses that pack. Typically, the file in the actual `packs` directory will be a manifest that mostly loads other files, but it can also have arbitrary JavaScript code.

The default pack created for you by Webpacker will link to Rails default JavaScript packages if they have been included in the project:

```
require("@rails/ujs").start()
require("turbolinks").start()
require("@rails/activestorage").start()
require("channels")
```

You'll need to include a pack that requires these packages to use them in your Rails application.

Beyond the use of the `app/javascript/packs` directory for packs, Webpacker does not place any restrictions or make any suggestions on how to structure your source code. Typically the pack file itself is largely a manifest that uses `import` or `require` to load the necessary files and may also do some initialization. 

If you want to change these directories, you can adjust the `source_path` (default `app/javascript`) and `source_entry_path` (default `packs`) in the `configuration/webpacker.yml` file.

Within source files, `import` statements are resolved relative to the file doing the import, so `import Bar from "./foo"` finds a `foo.js` file in the same directory as the current file, while `import Bar from "../src/foo"` finds a file in a sibling directory named `src`.

### Babel and TypeScript

## Using Webpacker for CSS

Out of the box, Webpacker supports CSS and SCSS using the PostCSS processor. 

To include CSS code in your packs, first include your CSS files in your top level pack file as though it was a JavaScript file. So if your CSS top-level manifest is in `app/javascript/styles/styles.scss`, you can import it with `import styles/styles`. This tells webpack to include your CSS file in the download. To actually load it in the page, you need to include a `<stylesheet_pack_tag "application">`, where the `application` is the same pack name that you were using. (Note, the docs still say you need to use `stylesheet_pack_tag`, but experimenting suggests that the CSS will load without it.)

If you are using a CSS framework, you can add it to Webpacker by following the instructions to load the framework as an NPM module using `yarn`, typically `yarn add <framework>`. The framework should have instructions on importing it into a CSS or SCSS file.


## Using Webpacker for Static Assets

The default Webpacker [configuration](https://github.com/rails/webpacker/blob/master/lib/install/config/webpacker.yml#L21) should work out of the box for static assets.
The configuration includes a number of image and font file format extentions, allowing Webpack to include them in the generated `manifest.json` file.

With webpack, static assets can be imported directly in JavaScript files. The imported value represents the url to the asset. For example:

```javascript
import myImageUrl from '../images/my-image.jpg'

// ...
let myImage = new Image();
myImage.src = myImageUrl;
myImage.alt = "I'm a Webpacker-bundled image";
document.body.appendChild(myImage);
```

To reference Webpacker static assets from a Rails view, the assets need to be explicitly required from Webpacker-bundled JavaScript files. Unlike Sprockets, Webpacker does not import your static assets by default. The default `app/javascript/packs/application.js` file has a template for importing files from a given directory, which you can uncomment for every directory you want to have static files in. The directories are relative to `app/javascript`. The template uses the directory `images`, but you can use anything in `app/javascript`:

```
const images = require.context("../images", true)
const imagePath = name => images(name, true)
```
 
Static assets will be output into a directory under `public/packs/media`. For example, an image located and imported at `app/javascript/images/my-image.jpg` will be output at `public/packs/media/images/my-image-abcd1234.jpg`. To render an image tag for this image in a Rails view, use `image_pack_tag 'media/images/my-image.jpg`.

The Webpacker ActionView helpers for static assets correspond to asset pipeline helpers according to the following table:

|ActionView helper | Webpacker helper |
|------------------|------------------|
|favicon_link_tag  |favicon_pack_tag  |
|image_tag         |image_pack_tag    |

Also the generic helper `asset_pack_path` takes the local location of a file and returns its webpacker location for use in Rails views.

You can also access the image by directly referencing the file from a CSS file in `app/javascript`.

## Webpacker in Rails Engines

## Running Webpacker in Development

Webpacker ships with two binstub files to run in development: `./bin/webpack` and `./bin/webpack-dev-server`. Both are thin wrappers around the standard `webpack.js` and `webpack-dev-server.js` executables and ensure that the right configuration files and environmental variables are loaded based on your environment.

By default, Webpacker compiles automatically on demand in development when a Rails page loads. You can change this by changing to `compile: false` in the `config/webpacker.yml` file. This means that you don't have to run any separate processes. Compilation errors are logged to the standard Rails log. You can, however, run `bin/webpack` to force compilation of your packs.

If you want to use live code reloading, or you have enough JavaScript that on-demand compilation is too slow, you'll need to run `./bin/webpack-dev-server` or `ruby ./bin/webpack-dev-server`. This process will watch for changes in the `app/javascript/packs/*.js` files and automatically recompile and reload the browser to match.

Windows users will need to run these commands in a terminal separate from `bundle exec rails s`. 

Once you start this development server, Webpacker will automatically start proxying all webpack asset requests to this server. When you stop the server, it'll revert back to on-demand compilation.

The Webpacker [Documentation](https://github.com/rails/webpacker) gives information on environment variables you can use to control `webpack-dev-server`. See additional notes in the [rails/webpacker docs on the webpack-dev-server usage](https://github.com/rails/webpacker/blob/master/docs/webpack-dev-server.md).

### Hot module replacement

Webpacker out-of-the-box supports HMR with webpack-dev-server and you can toggle it by setting dev_server/hmr option inside webpacker.yml.

Checkout this guide for more information:

https://webpack.js.org/configuration/dev-server/#devserver-hot
To support HMR with React you would need to add react-hot-loader. Checkout this guide for more information:

https://gaearon.github.io/react-hot-loader/getstarted/

Don't forget to disable HMR if you are not running webpack-dev-server otherwise you will get not found error for stylesheets.

## Webpacker in Different Environments

Webpacker has three environments by default `development`, `test`, and `production`. You can add additional environment configurations in the `webpacker.yml` file and set different defaults for each environment, Webpacker will also load the file `config/webpack/<environment>.js` for additional environment setup.

### Deploying Webpacker

Webpacker adds a `Webpacker:compile` task to the `assets:precompile` rake task, so any existing deploy pipeline that was using `assets:precompile` should work. The compile task will compile the packs and place them in `public/packs`.

### Webpacker and Docker

# Docker

To setup webpacker with a dockerized Rails application for local development using docker-compose.

Ensure nodejs and yarn are installed as dependencies in the Dockerfile:

```dockerfile
FROM ruby:2.7.1

RUN curl -sL https://deb.nodesource.com/setup_12.x | bash \
 && apt-get update && apt-get install -y nodejs && rm -rf /var/lib/apt/lists/* \
 && curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
 && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
 && apt-get update && apt-get install -y yarn && rm -rf /var/lib/apt/lists/*

# Rest of the commands....
```

Add a new service for the webpack-dev-server in docker-compose.yml:

```Dockerfile
version: '3'
services:
  webpacker:
    build: .
    environment:
      - NODE_ENV=${NODE_ENV:-development}
      - RAILS_ENV=${RAILS_ENV:-development}
      - WEBPACKER_DEV_SERVER_HOST=webpacker
    command: ./bin/webpack-dev-server
    volumes:
      - .:/app
    ports:
      - "3035:3035"
```

Ensure the rails app service specifies the WEBPACKER_DEV_SERVER_HOST=webpacker environment variable:

```Dockerfile
  web:
    build:
      context: .
    command: bash -c "rm -f tmp/pids/server.pid && bundle exec rails s -p 3000 -b '0.0.0.0'"
    volumes:
      - .:/app
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=${NODE_ENV:-development}
      - RAILS_ENV=${RAILS_ENV:-development}
      - WEBPACKER_DEV_SERVER_HOST=webpacker
```

Lastly, rebuild your container:

```bash
docker-compose up --build
```

For production dockerized setup, make sure `rake asssets:precompile` is run in the Dockerfile to ensure assets, including the webpacker manifest.json file, are built in the container.


## Extending and Customizing Webpacker

## Troubleshooting Common Problems

## Upgrading Webpacker

## Credits

* [Webpacker Documentation](https://github.com/rails/webpacker)
* Niklas Häusele
* [The React-Rails Sprockets or Webpacker Page](https://github.com/reactjs/react-rails/wiki/Choosing-Sprockets-or-Webpacker), edited by Greg Myers, was useful.
