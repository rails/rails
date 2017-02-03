# Welcome to Rails

Rails is a web-application framework that includes everything needed to
create database-backed web applications according to the
[Model-View-Controller (MVC)](http://en.wikipedia.org/wiki/Model-view-controller)
pattern.

Understanding the MVC pattern is key to understanding Rails. MVC divides your
application into three layers, each with a specific responsibility.

The _Model layer_ represents your domain model (such as Account, Product,
Person, Post, etc.) and encapsulates the business logic that is specific to
your application. In Rails, database-backed model classes are derived from
`ActiveRecord::Base`. Active Record allows you to present the data from
database rows as objects and embellish these data objects with business logic
methods. You can read more about Active Record in its [README](activerecord/README.rdoc).
Although most Rails models are backed by a database, models can also be ordinary
Ruby classes, or Ruby classes that implement a set of interfaces as provided by
the Active Model module. You can read more about Active Model in its [README](activemodel/README.rdoc).

The _Controller layer_ is responsible for handling incoming HTTP requests and
providing a suitable response. Usually this means returning HTML, but Rails controllers
can also generate XML, JSON, PDFs, mobile-specific views, and more. Controllers load and
manipulate models, and render view templates in order to generate the appropriate HTTP response.
In Rails, incoming requests are routed by Action Dispatch to an appropriate controller, and
controller classes are derived from `ActionController::Base`. Action Dispatch and Action Controller
are bundled together in Action Pack. You can read more about Action Pack in its
[README](actionpack/README.rdoc).

The _View layer_ is composed of "templates" that are responsible for providing
appropriate representations of your application's resources. Templates can
come in a variety of formats, but most view templates are HTML with embedded
Ruby code (ERB files). Views are typically rendered to generate a controller response,
or to generate the body of an email. In Rails, View generation is handled by Action View.
You can read more about Action View in its [README](actionview/README.rdoc).

Active Record, Active Model, Action Pack, and Action View can each be used independently outside Rails.
In addition to that, Rails also comes with Action Mailer ([README](actionmailer/README.rdoc)), a library
to generate and send emails; Active Job ([README](activejob/README.md)), a
framework for declaring jobs and making them run on a variety of queueing
backends; Action Cable ([README](actioncable/README.md)), a framework to
integrate WebSockets with a Rails application;
and Active Support ([README](activesupport/README.rdoc)), a collection
of utility classes and standard library extensions that are useful for Rails,
and may also be used independently outside Rails.

## Getting Started

1. Install Rails at the command prompt if you haven't yet:

        $ gem install rails

2. At the command prompt, create a new Rails application:

        $ rails new myapp

   where "myapp" is the application name.

3. Change directory to `myapp` and start the web server:

        $ cd myapp
        $ rails server

   Run with `--help` or `-h` for options.

4. Using a browser, go to `http://localhost:3000` and you'll see:
"Yay! You’re on Rails!"

5. Follow the guidelines to start developing your application. You may find
   the following resources handy:
    * [Getting Started with Rails](http://guides.rubyonrails.org/getting_started.html)
    * [Ruby on Rails Guides](http://guides.rubyonrails.org)
    * [The API Documentation](http://api.rubyonrails.org)
    * [Ruby on Rails Tutorial](http://www.railstutorial.org/book)

## Contributing

We encourage you to contribute to Ruby on Rails! Please check out the
[Contributing to Ruby on Rails guide](http://edgeguides.rubyonrails.org/contributing_to_ruby_on_rails.html) for guidelines about how to proceed. [Join us!](http://contributors.rubyonrails.org)

Everyone interacting in Rails and its sub-projects' codebases, issue trackers, chat rooms, and mailing lists is expected to follow the Rails [code of conduct](http://rubyonrails.org/conduct/).

## Code Status

[![Build Status](https://travis-ci.org/rails/rails.svg?branch=master)](https://travis-ci.org/rails/rails)

## License

Ruby on Rails is released under the [MIT License](http://www.opensource.org/licenses/MIT).
