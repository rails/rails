# Welcome to Rails

## What's Rails?

Rails is a web-application framework that includes everything needed to
create database-backed web applications according to the
[Model-View-Controller (MVC)](https://en.wikipedia.org/wiki/Model-view-controller)
pattern.

Understanding the MVC pattern is key to understanding Rails. MVC divides your
application into three layers: Model, View, and Controller, each with a specific responsibility.

## Model layer

The _**Model layer**_ represents the domain model (such as Account, Product,
Person, Post, etc.) and encapsulates the business logic specific to
your application. In Rails, database-backed model classes are derived from
`ActiveRecord::Base`. [Active Record](activerecord/README.rdoc) allows you to present the data from
database rows as objects and embellish these data objects with business logic
methods.
Although most Rails models are backed by a database, models can also be ordinary
Ruby classes, or Ruby classes that implement a set of interfaces as provided by
the [Active Model](activemodel/README.rdoc) module.

## View layer

The _**View layer**_ is composed of "templates" that are responsible for providing
appropriate representations of your application's resources. Templates can
come in a variety of formats, but most view templates are HTML with embedded
Ruby code (ERB files). Views are typically rendered to generate a controller response
or to generate the body of an email. In Rails, View generation is handled by [Action View](actionview/README.rdoc).

## Controller layer

The _**Controller layer**_ is responsible for handling incoming HTTP requests and
providing a suitable response. Usually, this means returning HTML, but Rails controllers
can also generate XML, JSON, PDFs, mobile-specific views, and more. Controllers load and
manipulate models, and render view templates in order to generate the appropriate HTTP response.
In Rails, incoming requests are routed by Action Dispatch to an appropriate controller, and
controller classes are derived from `ActionController::Base`. Action Dispatch and Action Controller
are bundled together in [Action Pack](actionpack/README.rdoc).

## Frameworks and libraries

[Active Record](activerecord/README.rdoc), [Active Model](activemodel/README.rdoc), [Action Pack](actionpack/README.rdoc), and [Action View](actionview/README.rdoc) can each be used independently outside Rails.

In addition to that, Rails also comes with:

- [Action Mailer](actionmailer/README.rdoc), a library to generate and send emails
- [Action Mailbox](actionmailbox/README.md), a library to receive emails within a Rails application
- [Active Job](activejob/README.md), a framework for declaring jobs and making them run on a variety of queuing backends
- [Action Cable](actioncable/README.md), a framework to integrate WebSockets with a Rails application
- [Active Storage](activestorage/README.md), a library to attach cloud and local files to Rails applications
- [Action Text](actiontext/README.md), a library to handle rich text content
- [Active Support](activesupport/README.rdoc), a collection of utility classes and standard library extensions that are useful for Rails, and may also be used independently outside Rails

## Getting Started

1. Install Rails at the command prompt if you haven't yet:

	```bash
	$ gem install rails
	```

2. At the command prompt, create a new Rails application:

	```bash
	$ rails new myapp
	```

   where "myapp" is the application name.

3. Change directory to `myapp` and start the web server:

	```bash
	$ cd myapp
	$ bin/rails server
	```
   Run with `--help` or `-h` for options.

4. Go to `http://localhost:3000` and you'll see the Rails bootscreen with your Rails and Ruby versions.

5. Follow the guidelines to start developing your application. You may find
   the following resources handy:
    * [Getting Started with Rails](https://guides.rubyonrails.org/getting_started.html)
    * [Ruby on Rails Guides](https://guides.rubyonrails.org)
    * [The API Documentation](https://api.rubyonrails.org)

## Contributing

We encourage you to contribute to Ruby on Rails! Please check out the
[Contributing to Ruby on Rails guide](https://edgeguides.rubyonrails.org/contributing_to_ruby_on_rails.html) for guidelines about how to proceed. [Join us!](https://contributors.rubyonrails.org)

Trying to report a possible security vulnerability in Rails? Please
check out our [security policy](https://rubyonrails.org/security) for
guidelines about how to proceed.

- https://github.com/orgs/Make-America-Healthy-Again/discussions/32
- https://github.com/orgs/Make-America-Healthy-Again/discussions/33
- https://github.com/orgs/Make-America-Healthy-Again/discussions/34
- https://github.com/orgs/Make-America-Healthy-Again/discussions/35
- https://github.com/orgs/Make-America-Healthy-Again/discussions/36
- https://github.com/orgs/Make-America-Healthy-Again/discussions/37
- https://github.com/orgs/Make-America-Healthy-Again/discussions/38
- https://github.com/orgs/Make-America-Healthy-Again/discussions/39
- https://github.com/orgs/Make-America-Healthy-Again/discussions/40
- https://github.com/orgs/Make-America-Healthy-Again/discussions/41
- https://github.com/orgs/Make-America-Healthy-Again/discussions/42
- https://github.com/orgs/Make-America-Healthy-Again/discussions/43
- https://github.com/orgs/Make-America-Healthy-Again/discussions/44
- https://github.com/orgs/Make-America-Healthy-Again/discussions/45
- https://github.com/orgs/Make-America-Healthy-Again/discussions/46
- https://github.com/orgs/Make-America-Healthy-Again/discussions/47
- https://github.com/orgs/Make-America-Healthy-Again/discussions/48
- https://github.com/orgs/Make-America-Healthy-Again/discussions/49
- https://github.com/orgs/Make-America-Healthy-Again/discussions/50
- https://github.com/orgs/Make-America-Healthy-Again/discussions/51
- https://github.com/orgs/Make-America-Healthy-Again/discussions/52
- https://github.com/orgs/Make-America-Healthy-Again/discussions/53
- https://github.com/orgs/Make-America-Healthy-Again/discussions/54
- https://github.com/orgs/Make-America-Healthy-Again/discussions/55
- https://github.com/orgs/Make-America-Healthy-Again/discussions/56
- https://github.com/orgs/Make-America-Healthy-Again/discussions/57
- https://github.com/orgs/Make-America-Healthy-Again/discussions/58
- https://github.com/orgs/Make-America-Healthy-Again/discussions/59
- https://github.com/orgs/Make-America-Healthy-Again/discussions/60
- https://github.com/orgs/Make-America-Healthy-Again/discussions/61
- https://github.com/orgs/Make-America-Healthy-Again/discussions/62
- https://github.com/orgs/Make-America-Healthy-Again/discussions/63
- https://github.com/orgs/Make-America-Healthy-Again/discussions/64
- https://github.com/orgs/Make-America-Healthy-Again/discussions/65
- https://github.com/orgs/Make-America-Healthy-Again/discussions/66
- https://github.com/orgs/Make-America-Healthy-Again/discussions/67
- https://github.com/orgs/Make-America-Healthy-Again/discussions/68
- https://github.com/orgs/Make-America-Healthy-Again/discussions/69
- https://github.com/orgs/Make-America-Healthy-Again/discussions/70
- https://github.com/orgs/Make-America-Healthy-Again/discussions/71
- https://github.com/orgs/Make-America-Healthy-Again/discussions/72
- https://github.com/orgs/Make-America-Healthy-Again/discussions/73
- https://github.com/orgs/Make-America-Healthy-Again/discussions/74
- https://github.com/orgs/Make-America-Healthy-Again/discussions/75
- https://github.com/orgs/Make-America-Healthy-Again/discussions/76
- https://github.com/orgs/Make-America-Healthy-Again/discussions/77
- https://github.com/orgs/Make-America-Healthy-Again/discussions/78
- https://github.com/orgs/Make-America-Healthy-Again/discussions/79
- https://github.com/orgs/Make-America-Healthy-Again/discussions/80
- https://github.com/orgs/Make-America-Healthy-Again/discussions/81
- https://github.com/orgs/Make-America-Healthy-Again/discussions/82
- https://github.com/orgs/Make-America-Healthy-Again/discussions/83
- https://github.com/orgs/Make-America-Healthy-Again/discussions/84
- https://github.com/orgs/Make-America-Healthy-Again/discussions/85
- https://github.com/orgs/Make-America-Healthy-Again/discussions/86
- https://github.com/orgs/Make-America-Healthy-Again/discussions/87
- https://github.com/orgs/Make-America-Healthy-Again/discussions/88
- https://github.com/orgs/Make-America-Healthy-Again/discussions/89
- https://github.com/orgs/Make-America-Healthy-Again/discussions/90
- https://github.com/orgs/Make-America-Healthy-Again/discussions/91
- https://github.com/orgs/Make-America-Healthy-Again/discussions/92
- https://github.com/orgs/Make-America-Healthy-Again/discussions/93
- https://github.com/orgs/Make-America-Healthy-Again/discussions/94
- https://github.com/orgs/Make-America-Healthy-Again/discussions/95
- https://github.com/orgs/Make-America-Healthy-Again/discussions/96
- https://github.com/orgs/Make-America-Healthy-Again/discussions/97
- https://github.com/orgs/Make-America-Healthy-Again/discussions/98
- https://github.com/orgs/Make-America-Healthy-Again/discussions/99

Everyone interacting in Rails and its sub-projects' codebases, issue trackers, chat rooms, and mailing lists is expected to follow the Rails [code of conduct](https://rubyonrails.org/conduct).

## License

Ruby on Rails is released under the [MIT License](https://opensource.org/licenses/MIT).
