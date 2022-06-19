**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON https://guides.rubyonrails.org.**

The Asset Pipeline
==================

This guide covers the asset pipeline.

After reading this guide, you will know:

* What the asset pipeline is and what it does;
* The benefits of the asset pipeline;
* The four approaches implementing the asset pipeline;
* How to decide which approach to use in your own application;
* Where to go to read the guide for your chosen approach.

--------------------------------------------------------------------------------

What is the Asset Pipeline?
---------------------------

The asset pipeline is responsible for serving javascript, css and image files
in the most efficient manner possible, from your app, its ruby gems and its node
packages.

### Main Features

### What is Fingerprinting and Why Should I Care?

### What is different between delivering assets in HTTP1 and HTTP2?


The Four Approaches to the Asset Pipeline
-----------------------------------------

### Sprockets
The original asset pipeline gem, built for the HTTP/1 era and low javascript frontends. It handled the bundling and digesting of javascript, css and image files, without relying on node packages.

### Webpacker
Shipped with Rails 5.2, as a wrapper around the complexity of Webpack/Node/Yarn, this gem could completely replace Sprockets or simply take over javascript transpiling and bundling. It provided Rails “out of the box” support for SPA frameworks like React.

### Import Maps
Shipped with Rails 7.0, it replaces Sprockets as the default asset pipeline gem. Although it eliminates the need for node/yarn and other complex tooling, it requires the application using it to be deployed in an environment that supports HTTP/2, otherwise it causes severe performance problems.

### Bundling Gems
Shipped with Rails 7.0, the multiple bundling gems provide a more traditional, if more modern, approach to the asset pipeline than import maps does. They basically break down the “all in one” approach of Sprockets into multiple smaller, specialized pieces. The main gems are propshaft, jsbundling and cssbundling.
