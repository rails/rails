[![Ruby on Rails Logo](https://upload.wikimedia.org/wikipedia/commons/thumb/6/62/Ruby_On_Rails_Logo.svg/800px-Ruby_On_Rails_Logo.svg.png)](http://guides.rubyonrails.org/index.html)

# Welcome to Rails
Rails is a web application development framework written in the Ruby language. It is designed to make programming web applications easier by making assumptions about what every developer needs to get started. It allows you to write less code while accomplishing more than many other languages and frameworks. Experienced Rails developers also report that it makes web application development more fun.

### prerequisites for running Ruby on Rails:

 - The Ruby language version 2.2.2 or newer.
 - Right version of Development Kit, if you are using Windows.
 - The RubyGems packaging system, which is installed with Ruby by default.
 - A working installation of the SQLite3 Database.

### easy installation
[RailsInstaller](http://railsinstaller.org/) is the quickest way to go from zero to developing Ruby on Rails applications. 

### Verify installation

Verify that you have a current version of Ruby installed, Open up a command line prompt.:

	$ ruby -v

To verify that you have everything installed correctly, you should be able to run the following:

	$ rails --version

To update Rails, use the gem update command provided by RubyGems:

	$ gem update rails

# Getting Started

1. At the command prompt, create a new Rails application:
        $ rails new myapp
   where "myapp" is the application name.

2. Change directory to `myapp` and start the web server:
        $ cd myapp
        $ rails server
   Run with `--help` or `-h` for options.

3. Using a browser, go to `http://localhost:3000` and you'll see:
	"Yay! You’re on Rails!"
[![Ruby on Rails Logo](http://guides.rubyonrails.org/images/getting_started/rails_welcome.png)](http://guides.rubyonrails.org/index.html)

## Documentation

Follow the guidelines to start developing your application. You may find the following resources handy:
  - [Getting Started with Rails](http://guides.rubyonrails.org/getting_started.html)
  - [Ruby on Rails Guides](http://guides.rubyonrails.org)
  - [The API Documentation](http://api.rubyonrails.org)
  - [Ruby on Rails Tutorial](https://www.railstutorial.org/book)

### Architecture
Rails follows Model-View-Controller architectural pattern.Because MVC decouples the various components of an application, developers are able to work in parallel on different components without impacting or blocking one another

[Model layer](http://edgeguides.rubyonrails.org/active_record_basics.html) are classes that talk to the database. Find, create and save models, so no need for SQL statements and its secure. Rails has a class to handle the magic of saving to a database when a model is updated.

[Controllers layer](http://edgeguides.rubyonrails.org/action_controller_overview.html) is responsible for handling incoming HTTP requests and providing a suitable response. Usually this means returning HTML, but Rails controllers can also generate XML, JSON, PDFs, mobile-specific views, and more. Controller decides what to do with the request (show a page, store an item, change a comment) using business logic. Ideally, controllers just take inputs, call model methods, and pass outputs to the view (including error messages).

[View layer](http://edgeguides.rubyonrails.org/action_view_overview.html) display the output, usually HTML. They use ERB and this part of Rails uses HTML templates with some Ruby variables. Rails also makes it easy to create views as XML (for web services/RSS feeds) or JSON (for AJAX calls).
 
 For more magic of rails:
  - Action Mailer ([README](actionmailer/README.rdoc)), a library to generate and send emails.
  - Active Job ([README](activejob/README.md)), a framework for declaring jobs and making them run on a variety of queueing backends.
  - Action Cable ([README](actioncable/README.md)), a framework to integrate WebSockets with a Rails application.
  - Active Storage ([README](activestorage/README.md)), a library to attach cloud and local files to Rails applications.
  - Active Support ([README](activesupport/README.rdoc)), a collection of utility classes and standard library extensions.

Best practices:
 Constantly refactor and move business logic into the model (fat model, skinny controller).

## Contributing

[![Code Triage Badge](https://www.codetriage.com/rails/rails/badges/users.svg)](https://www.codetriage.com/rails/rails)

We encourage you to contribute to Ruby on Rails! Please check out the
[Contributing to Ruby on Rails guide](http://edgeguides.rubyonrails.org/contributing_to_ruby_on_rails.html) for guidelines about how to proceed. [Join us!](http://contributors.rubyonrails.org)

Trying to report a possible security vulnerability in Rails? Please
check out our [security policy](http://rubyonrails.org/security/) for
guidelines about how to proceed.

Everyone interacting in Rails and its sub-projects' codebases, issue trackers, chat rooms, and mailing lists is expected to follow the Rails [code of conduct](http://rubyonrails.org/conduct/).


## Code Status

[![Build Status](https://travis-ci.org/rails/rails.svg?branch=master)](https://travis-ci.org/rails/rails)

## License

Ruby on Rails is released under the [MIT License](https://opensource.org/licenses/MIT).
