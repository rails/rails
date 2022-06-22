**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON https://guides.rubyonrails.org.**

The Asset Pipeline
==================

This guide covers the asset pipeline as it was implemented by Sprockets.

After reading this guide, you will know:

* What the asset pipeline is and what it does.
* How to properly organize your application assets.
* The benefits of the asset pipeline.
* How to package assets with a gem.

--------------------------------------------------------------------------------

What is the Asset Pipeline?
---------------------------

The asset pipeline provides a framework to speed-up the delivery of Javascript and 
CSS assets. This is done by leveraging technologies like HTTP/2 and techniques like
concatenation and minification. It also adds the ability to write these assets in 
other languages and pre-processors, such as Sass and ERB. Finally, it allows your
application to be automatically combined with assets from other gems.

The asset pipeline is implemented by the 
[importmaps-rails](https://github.com/rails/importmaps-rails) and 
[sprockets-rails](https://github.com/rails/sprockets-rails) gems,
and is enabled by default. You can disable it while creating a new application by
passing the `--skip-asset-pipeline` option.

```bash
$ rails new appname --skip-asset-pipeline
```

### Main Features

The first feature of the asset pipeline is to insert a SHA256 fingerprinting
into each filename so that the file is cached by the web browser and CDN. This 
fingerprint is automatically updated when you change the file contents, which 
invalidates the cache.

The second feature of the asset pipeline is to use [import maps](https://github.com/WICG/import-maps)
when serving JavaScript files. This lets you build modern applications using
Javascript libraries made for ES modules (ESM) without the need for transpiling
and bundling. In turn, this eliminates the need for Webpack, yarn, node or any
other part of the JavaScript toolchain.

The third feature of the asset pipeline is to concatenate all CSS files into 
one main `.css` file, which is then minified or compressed. 
As you'll learn later in this guide, you  can customize this strategy to group 
files any way you like. In production, Rails inserts an SHA256 fingerprint into 
each filename so that the file is cached by the web browser. You can invalidate 
the cache by altering this fingerprint, which happens automatically whenever you 
change the file contents.

The fourth feature of the asset pipeline is it allows coding assets via a
higher-level language, with precompilation down to the actual assets. Supported
languages include Sass for CSS and ERB for both CSS and Javascript by default.

### What is Fingerprinting and Why Should I Care?

Fingerprinting is a technique that makes the name of a file dependent on the
contents of the file. When the file contents change, the filename is also
changed. For content that is static or infrequently changed, this provides an
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

Rails' old strategy was to append a date-based query string to every asset linked
with a built-in helper. In the source the generated code looked like this:

```
/stylesheets/global.css?1309495796
```

The query string strategy has several disadvantages:

1. **Not all caches will reliably cache content where the filename only differs by
   query parameters**

   [Steve Souders recommends](https://www.stevesouders.com/blog/2008/08/23/revving-filenames-dont-use-querystring/),
   "...avoiding a querystring for cacheable resources". He found that in this
   case 5-20% of requests will not be cached. Query strings in particular do not
   work at all with some CDNs for cache invalidation.

2. **The file name can change between nodes in multi-server environments.**

   The default query string in Rails 2.x is based on the modification time of
   the files. When assets are deployed to a cluster, there is no guarantee that the
   timestamps will be the same, resulting in different values being used depending
   on which server handles the request.

3. **Too much cache invalidation**

   When static assets are deployed with each new release of code, the mtime
   (time of last modification) of _all_ these files changes, forcing all remote
   clients to fetch them again, even when the content of those assets has not changed.

Fingerprinting fixes these problems by avoiding query strings, and by ensuring
that filenames are consistent based on their content.

Fingerprinting is enabled by default for both the development and production
environments. You can enable or disable it in your configuration through the
[`config.assets.digest`][] option.

More reading:

* [Optimize caching](https://developers.google.com/speed/docs/insights/LeverageBrowserCaching)
* [Revving Filenames: don't use querystring](http://www.stevesouders.com/blog/2008/08/23/revving-filenames-dont-use-querystring/)

[`config.assets.digest`]: configuring.html#config-assets-digest

### What are Import Maps and Why Should I Care?

