**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON https://guides.rubyonrails.org.**

Getting Started with Rails
==========================

This guide covers getting up and running with Ruby on Rails.

After reading this guide, you will know:

* How to install Rails, create a new Rails application, and connect your
  application to a database.
* The general layout of a Rails application.
* The basic principles of MVC (Model, View, Controller) and RESTful design.
* How to quickly generate the starting pieces of a Rails application.

--------------------------------------------------------------------------------

Introduction
------------

Welcome to Ruby on Rails! In this guide, we'll walk through the core concepts of building web applications with Ruby on Rails. You don't need any experience with Ruby on Rails to follow along with this guide.

Ruby on Rails is a web framework built for the Ruby programming language. Rails takes advantage of many features of Ruby so we recommend learning the basics of Ruby.

- [Official Ruby Programming Language website](https://www.ruby-lang.org/en/documentation/)
- [List of Free Programming Books](https://github.com/EbookFoundation/free-programming-books/blob/master/books/free-programming-books-langs.md#ruby)

Rails Philosophy
----------------

Rails is a web application development framework written in the Ruby programming language. It is designed to make programming web applications easier by making assumptions about what every developer needs to get started. It allows you to write less code while accomplishing more than many other languages and frameworks. Experienced Rails developers also report that it makes web application development more fun.

Rails is opinionated software. It makes the assumption that there is a "best" way to do things, and it's designed to encourage that way - and in some cases to discourage alternatives. If you learn "The Rails Way" you'll probably discover a tremendous increase in productivity. If you persist in bringing old habits from other languages to your Rails development, and trying to use patterns you learned elsewhere, you may have a less happy experience.

The Rails philosophy includes two major guiding principles:

- **Don't Repeat Yourself:** DRY is a principle of software development which states that "Every piece of knowledge must have a single, unambiguous, authoritative representation within a system". By not writing the same information over and over again, our code is more maintainable, more extensible, and less buggy.
- **Convention Over Configuration:** Rails has opinions about the best way to do many things in a web application, and defaults to this set of conventions, rather than require that you specify minutiae through endless configuration files.

Creating a new Rails app
------------------------

We're going to build a project called `store` that will be a simple e-commerce example app that showcases several powerful features that Rails includes out of the box.

### Prerequisites

The only requirement to use Rails is having a recent version of Ruby installed.

* Ruby 3.2 or newer

Open a command line prompt and verify that you have Ruby installed:

```bash
$ ruby --version
ruby 3.3.5
```

If you don't have Ruby installed, follow the [Installing Ruby Guide](installing_ruby.html).

### Installing Rails

Use Ruby's `gem` command to install the latest version of Rails. This will download Rails from Rubygems.org and make it available in your shell.

```bash
$ gem install rails
```

To verify that Rails is installed correctly, run the following and you should see a version number printed out:

```bash
$ rails --version
Rails 8.0.0
```

### Creating your first Rails app

Rails comes with several commands to make life easier. `rails new` generates a fresh Rails application for you. You can run `rails --help` to see all of the commands.

To create our `store` application, run the following:

```bash
$ rails new store
```

NOTE: You can use flags to customize the application Rails generates. To see those options, run `rails new --help`.

After your new application is created, switch to it's directory:

```bash
$ cd store
```

### Directory Structure

Let's take a quick glance at the files and directories that are included in a new Rails application.

| File/Folder | Purpose |
| ----------- | ------- |
|app/|Contains the controllers, models, views, helpers, mailers, jobs, and assets for your application. You'll focus on this folder for the remainder of this guide.|
|bin/|Contains the `rails` script that starts your app and can contain other scripts you use to set up, update, deploy, or run your application.|
|config/|Contains configuration for your application's routes, database, and more. This is covered in more detail in [Configuring Rails Applications](configuring.html).|
|config.ru|Rack configuration for Rack-based servers used to start the application. For more information about Rack, see the [Rack website](https://rack.github.io/).|
|db/|Contains your current database schema, as well as the database migrations.|
|Dockerfile|Configuration file for Docker.|
|Gemfile<br>Gemfile.lock|These files allow you to specify what gem dependencies are needed for your Rails application. These files are used by the Bundler gem. For more information about Bundler, see the [Bundler website](https://bundler.io).|
|lib/|Extended modules for your application.|
|log/|Application log files.|
|public/|Contains static files and compiled assets. When your app is running, this directory will be exposed as-is.|
|Rakefile|This file locates and loads tasks that can be run from the command line. The task definitions are defined throughout the components of Rails. Rather than changing `Rakefile`, you should add your own tasks by adding files to the `lib/tasks` directory of your application.|
|README.md|This is a brief instruction manual for your application. You should edit this file to tell others what your application does, how to set it up, and so on.|
|script/|Contains one-off or general purpose [scripts](https://github.com/rails/rails/blob/main/railties/lib/rails/generators/rails/script/USAGE) and [benchmarks](https://github.com/rails/rails/blob/main/railties/lib/rails/generators/rails/benchmark/USAGE).|
|storage/|Active Storage files for Disk Service. This is covered in [Active Storage Overview](active_storage_overview.html).|
|test/|Unit tests, fixtures, and other test apparatus. These are covered in [Testing Rails Applications](testing.html).|
|tmp/|Temporary files (like cache and pid files).|
|vendor/|A place for all third-party code. In a typical Rails application this includes vendored gems.|
|.dockerignore|This file tells Docker which files it should not copy into the container.|
|.gitattributes|This file defines metadata for specific paths in a git repository. This metadata can be used by git and other tools to enhance their behavior. See the [gitattributes documentation](https://git-scm.com/docs/gitattributes) for more information.|
|.github/|Contains GitHub specific files.|
|.gitignore|This file tells git which files (or patterns) it should ignore. See [GitHub - Ignoring files](https://help.github.com/articles/ignoring-files) for more information about ignoring files.|
|.rubocop.yml|This file contains the configuration for RuboCop.|
|.ruby-version|This file contains the default Ruby version.|

### Model-View-Controller Basics

Rails code is organized using the Model-View-Controller (MVC) architecture. With MVC, we have 3 main concepts where the majority of our code lives:

* Model - Manages the data in your application. Typically, your database tables.
* View - Handles rendering responses in different formats like HTML, JSON, XML, etc.
* Controller - Handles user interactions and the logic for each request.

Now that we've got a basic understanding of MVC, let's see how it's used in Rails.

Hello, Rails!
-------------

Let's start easy and boot up our Rails server for the first time.

In your terminal, run the following command in the `store` directory:

```bash
$ bin/rails server
=> Booting Puma
=> Rails 8.0.0 application starting in development
=> Run `bin/rails server --help` for more startup options
Puma starting in single mode...
* Puma version: 6.4.3 (ruby 3.3.5-p100) ("The Eagle of Durango")
*  Min threads: 3
*  Max threads: 3
*  Environment: development
*          PID: 12345
* Listening on http://127.0.0.1:3000
* Listening on http://[::1]:3000
```

This will start up a web server called Puma that will serve static files and your Rails application.

To see your Rails application, open http://localhost:3000 in your browser. You will see this:

![Rails welcome page](images/getting_started/rails_welcome.png)

It works!

This page is the *smoke test* for a new Rails application. It makes sure that everything is working to serve a page.

To stop the Rails server anytime, press `Ctrl-C` in your terminal.

### Automatic Reloading in Development

Developer happiness is a cornerstone philosphy of Rails and one way of achieving that is with automatic code reloading in development.

Once you start the Rails server, new files or changes to existing files are detected and automatically loaded or reloaded as necessary. This allows you to focus on building without having to restart your Rails server after every change.

You may also notice that Rails applications do not use `require` statements hardly ever. Rails uses naming conventions to require files automatically so you can focus on writing your application code.

See [Autoloading and Reloading Constants](autoloading_and_reloading_constants.html) for more details.

Creating a Database Model
-------------------------

Let's start by adding a database table to our Rails application to add products to our simple e-commerce store.

```bash
$ bin/rails generate model Product name:string
      invoke  active_record
      create    db/migrate/20240426151900_create_products.rb
      create    app/models/product.rb
      invoke    test_unit
      create      test/models/product_test.rb
      create      test/fixtures/products.yml
```

This command does several things:
1. It creates a migration in the `db/migrate` folder
2. It creates a Active Record model in `app/models/product.rb`
3. Generates tests and test fixtures for this model

### Database Migrations

A _migration_ is set of changes we want to make to our database.

By defining migrations, we're telling Rails how to change the database to add, change, or remove tables, columns or other attributes of our database. This helps keep track of changes we make in development so they can be deployed to production safely.

Opening the migration Rails created for us, we can see what the migration does.

```ruby
class CreateProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :products do |t|
      t.string :name

      t.timestamps
    end
  end
end
```

Rails looks for a `change` method and executes it when running the migration. This migration is telling rails to create a new database table named `products`. The block then defines which columns and types should be defined in this database table.

`t.string :name` tells Rails to create a column in the products table called `name` and set the type as `string`.

`t.timestamps` is a shortcut for defining two columns your models: `created_at:datetime` and `updated_at:datetime`. You'll see these columns on most Active Record models in Rails and they are automatically set by Active Record when creating or updating records.

### Running Migrations

To run migrations in Rails, you can run the following command:

```bash
$ bin/rails db:migrate
```
This command checks for any new migrations and applies them to your database. It's output looks like this:

```bash
== 20240426151900 CreateProducts: migrating ===================================
-- create_table(:products)
   -> 0.0030s
== 20240426151900 CreateProducts: migrated (0.0031s) ==========================
```

If you make a mistake, you can run `rails db:rollback` to undo the last migration.

Now that we have created our products table, we can interact with it in Rails. Let's try it out.

Rails Console
-------------

The *console* is a helpful tool for testing code in Rails applications. It's an interactive prompt built upon Ruby's IRB that automatically loads your Rails application.

```bash
$ bin/rails console
```

You will be presented with a prompt like the following:

```irb
Loading development environment (Rails 8.0.0)
store(dev)>
```

Here we can type code that will be executed when we hit `Enter`. Let's try printing out the Rails version:

```irb
store(dev)> Rails.version
=> "8.0.0"
```

It works! Let's use the Rails console now to interact with our database using the Active Record model we just created.

To exit the Rails console, type `exit` and hit Enter.

Active Record Model Basics
-------------------------

When we ran the Rails model generator to create the Product model, it created a file at `app/models/product.rb`. This file creates a class that uses Active Record for interacting with our `products` database table.

```ruby
class Product < ApplicationRecord
end
```

You might be surprised that there is no code in this class. How does Rails know columns are in our database?

Let's re-open the Rails console and see what columns Rails detects for the Product model.

```irb
store(dev)> Product.column_names
=> ["id", "name", "created_at", "updated_at"]
```

When the Product model is used, Rails will query the database table for the column names and types and automatically generate code for these attributes. Rails saves us from writing this boilerplate code and instead takes care of it for us behind the scenes so we can focus on our application logic instead.

### Creating Records

Rails asks the database for column information and defines attributes on the Product class dynamically so you don't have to. This is one example of how Rails makes development a breeze.

We can create a new Product record in memory with the following code:

```irb
store(dev)> product = Product.new(name: "T-Shirt")
=> #<Product:0x000000012e616c30
  id: nil,
  name: "T-Shirt",
  created_at: nil,
  updated_at: nil>
```

The `product` variable is an instance of `Product` but only lives in memory. It does not have an ID, created_at, or updated_at timestamps.

We can call `save` to write the record to the database.

```irb
store(dev)> product.save
  TRANSACTION (0.2ms)  begin transaction
  Product Create (5.2ms)  INSERT INTO "products" ("name", "created_at", "updated_at") VALUES (?, ?, ?) RETURNING "id"  [["name", "T-Shirt"], ["created_at", "2024-04-26 15:47:11.466589"], ["updated_at", "2024-04-26 15:47:11.466589"]]
  TRANSACTION (0.7ms)  commit transaction
=> true
```

When `save` is called, Rails takes the attributes in memory and generates an `INSERT` SQL query to insert this record into the database.

Rails also updates the object in memory with the database record `id` along with the `created_at` and `updated_at` timestamps. We can see that by printing out the `product` variable.

```irb
store(dev)> product
=>
#<Product:0x00000001257053e8
 id: 1,
 name: "T-Shirt",
 created_at: Fri, 26 Apr 2024 15:47:11.466589000 UTC +00:00,
 updated_at: Fri, 26 Apr 2024 15:47:11.466589000 UTC +00:00>
```

Similar to `save`, we can use `create` to instantiate and save an Active Record model in a single call.

```irb
store(dev)> Product.create(name: "Pants")
  TRANSACTION (0.0ms)  begin transaction
  Product Create (0.5ms)  INSERT INTO "products" ("name", "created_at", "updated_at") VALUES (?, ?, ?) RETURNING "id"  [["name", "Pants"], ["created_at", "2024-04-26 16:07:48.686955"], ["updated_at", "2024-04-26 16:07:48.686955"]]
  TRANSACTION (0.8ms)  commit transaction
=>
#<Product:0x00000001250e7d08
 id: 2,
 name: "Pants",
 created_at: Fri, 26 Apr 2024 16:07:48.686955000 UTC +00:00,
 updated_at: Fri, 26 Apr 2024 16:07:48.686955000 UTC +00:00>
```

### Querying Records

We can also look up records from the database using our Active Record model.

To find all the Product records in the database, we can use the `all` class method.

```irb
store(dev)> Product.all
  Product Load (0.1ms)  SELECT "products".* FROM "products" /* loading for pp */ LIMIT ?  [["LIMIT", 11]]
=>
[#<Product:0x0000000120a48848
  id: 1,
  name: "T-Shirt",
  created_at: Fri, 26 Apr 2024 15:47:11.466589000 UTC +00:00,
  updated_at: Fri, 26 Apr 2024 15:47:11.466589000 UTC +00:00>,
 #<Product:0x0000000120a48708
  id: 2,
  name: "Pants",
  created_at: Fri, 26 Apr 2024 16:07:48.686955000 UTC +00:00,
  updated_at: Fri, 26 Apr 2024 16:07:48.686955000 UTC +00:00>]
```

This generates a `SELECT` SQL query to load all records from the `products` table. Each record is automatically converted into an instance of our Product Active Record model so we can easily work with them from Ruby.

This returns an `ActiveRecord::Relation` object. A `Relation` is similar to a normal Array in Ruby, but understands that it's working with a database. This makes it easy to filter, sort, and any other operations your database supports while behaving similar to an Array.

### Filtering & Ordering Records

What if we want to filter the results from our database? We can use `where` to filter records by a column.

```irb
store(dev)> Product.where(name: "Pants")
  Product Load (0.7ms)  SELECT "products".* FROM "products" WHERE "products"."name" = ? /* loading for pp */ LIMIT ?  [["name", "Pants"], ["LIMIT", 11]]
=>
[#<Product:0x0000000125e08d48
  id: 2,
  name: "Pants",
  created_at: Fri, 26 Apr 2024 16:07:48.686955000 UTC +00:00,
  updated_at: Fri, 26 Apr 2024 16:07:48.686955000 UTC +00:00>]
```
This generates a `SELECT` SQL query but also adds a `WHERE` clause to filter the records that have a `name` matching `"Pants"`. This also returns an `ActiveRecord::Relation` because multiple records may have the same name.

We can use `order(name: :asc)` to sort records by name in ascending alphabetical order by `name`.

```irb
store(dev)> Product.order(name: :asc)
  Product Load (0.4ms)  SELECT "products".* FROM "products" /* loading for pp */ ORDER BY "products"."name" ASC LIMIT ?  [["LIMIT", 11]]
=>
[#<Product:0x000000013189f3c8
  id: 2,
  name: "Pants",
  created_at: Fri, 26 Apr 2024 16:07:48.686955000 UTC +00:00,
  updated_at: Fri, 26 Apr 2024 16:07:48.686955000 UTC +00:00>,
 #<Product:0x000000013189f008
  id: 1,
  name: "T-Shirt",
  created_at: Fri, 26 Apr 2024 15:47:11.466589000 UTC +00:00,
  updated_at: Fri, 26 Apr 2024 16:34:57.868472000 UTC +00:00>]
```

### Finding Records

What if want to find one specific record? The `find` class method can be used to look up a single record by ID.

```irb
store(dev)> Product.find(1)
  Product Load (4.3ms)  SELECT "products".* FROM "products" WHERE "products"."id" = ? LIMIT ?  [["id", 1], ["LIMIT", 1]]
=>
#<Product:0x0000000125e8ce40
 id: 1,
 name: "T-Shirt",
 created_at: Fri, 26 Apr 2024 15:47:11.466589000 UTC +00:00,
 updated_at: Fri, 26 Apr 2024 15:47:11.466589000 UTC +00:00>
```

This generates a `SELECT` query but specifies a `WHERE` for the `id` column matching the ID of `1` that was passed in. It also adds a `LIMIT` to only return a single record.

This time, we get a `Product` instance instead of an `ActiveRecord::Relation` since we're only retrieving a single record from the database.

### Updating Records

Records can be updated in 2 ways: using `update` or assigning attributes and calling `save`.

We can call `update` on a Product instance and pass in a Hash of new attributes to save to the database. This will assign the attributes, run validations, and save the changes to the database in one method call.

```irb
store(dev)> product = Product.find(1)
store(dev)> product.update(name: "Shoes")
  TRANSACTION (0.0ms)  begin transaction
  Product Update (1.4ms)  UPDATE "products" SET "name" = ?, "updated_at" = ? WHERE "products"."id" = ?  [["name", "Shoes"], ["updated_at", "2024-04-26 16:34:42.929503"], ["id", 1]]
  TRANSACTION (1.3ms)  commit transaction
=> true
```

Alternatively, we can assign attributes in memory and  call `save` when we're ready to validate and save changes to the database.

```irb
store(dev)> product = Product.find(1)
store(dev)> product.name = "T-Shirt"
store(dev)> product.save
  TRANSACTION (0.0ms)  begin transaction
  Product Update (0.4ms)  UPDATE "products" SET "name" = ?, "updated_at" = ? WHERE "products"."id" = ?  [["name", "T-Shirt"], ["updated_at", "2024-04-26 16:34:57.868472"], ["id", 1]]
  TRANSACTION (3.5ms)  commit transaction
=> true
```

### Deleting Records

The `destroy` method can be used to delete a record from the database.

```irb
store(dev)> product = Product.create(name: "Jacket")
store(dev)> product.destroy
  TRANSACTION (0.0ms)  begin transaction
  Product Destroy (1.5ms)  DELETE FROM "products" WHERE "products"."id" = ?  [["id", 3]]
  TRANSACTION (0.0ms)  commit transaction
=>
#<Product:0x0000000122736680
 id: 3,
 name: "Jacket",
 created_at: Fri, 26 Apr 2024 16:35:43.621534000 UTC +00:00,
 updated_at: Fri, 26 Apr 2024 16:35:43.621534000 UTC +00:00>
```

### Validations

Active Record provides *validations* which allows you to ensure data inserted into the database adheres to certain rules.

Let's add a `presence` validation to the Product model to ensure that all products must have a `name`.

```ruby
class Product < ApplicationRecord
  validates :name, presence: true
end
```

Let's try to create a Product without a name in the Rails console.

```irb
store(dev)> product = Product.new
store(dev)> product.save
=> false
```

This time `save` returns `false` because the `name` attribute wasn't specified.

Rails automatically runs validations during create, update, and save operations to ensure valid input. To see a list of errors generated by validations, we can call `errors` on the instance.

```irb
store(dev)> product.errors
=> #<ActiveModel::Errors [#<ActiveModel::Error attribute=name, type=blank, options={}>]>
```

This returns an `ActiveModel::Errors` object that can tell us exactly which errors are present.

It also can generate friendly error messages for us that we can use in our user interface.

```irb
store(dev)> product.errors.full_messages
=> ["Name can't be blank"]
```

Now let's build a web interface for our Products.

Routes
------

A route in Rails is the part of the URL we want to use for "routing" our request to the correct code for processing. First, let's do a quick refresher of URLs and HTTP Request methods.

### Parts of a URL

A URL is made of several parts. Let's look at an example:

```
http://example.org/products?sale=true&sort=asc
```

In this URL, each part has a name:

- `https` is the protocol
- `example.org` is the host
- `/products` is the path
- `?sale=true&sort=asc` is the query parameters

A route in Rails defines which *path* to match and how to process it.

### HTTP Methods

HTTP requests also require a "method" which tells the server what type of action should happen for that URL.

A `GET` request to a URL tells the server to retrieve the data for the page.
A `POST` request will submit data to the URL for processing (usually creating a new record).
A `PUT` or `PATCH` request submits data to a URL for updating a record.
A `DELETE` request to a URL tells the server to delete a record.

### Rails Routes

A `route` in Rails refers to a line of code that matches an HTTP Method  and a URL path. The route also tells Rails which `controller` and `action` should respond to a request that matches.

To define a route in Rails, we can add the following to `config/routes.rb`

```ruby
Rails.application.routes.draw do
  get "/products", to: "products#index"
end
```

This route tells Rails to look for GET requests to the `/products` path. When Rails sees a request that matches, it will send the request to a Controller and Action for handling the request and generating a response.

In this example, we specified `"products#index"` for where to route the request. This translates to a class named `ProductsController` and the `index` action inside of it. This will be responsible for handling the request and returning a response to the browser.

You'll notice that we don't need to specify the protocol, domain, or query params in our routes. That's basically the protocol and domain are for making sure the request reaches your server. From there, Rails picks up the request and knows to use the path for responding to the request. The query params are like options that Rails can use to apply to the request, so they are typically used in the controller for

Let's look at another example. Add this line after the previous route:

```ruby
post "/products", to: "products#create"
```

Here, we're telling Rails to listen to POST requests to "/products" and process those requests in the `ProductsController` with the `create` action.

Routes may also need to dynamically match requests. So how does that work?

```ruby
get "/products/:id", to: "products#show"
```

This route has `:id` in it. This is called a `parameter` and it captures a portion of the URL to be used later for processing the request. If a user visits `/products/1/edit`, the `:id` param is set to `1` and can be used in the controller action for looking up the Product record with ID of 1.

Route parameters don't have to be Integers either. For example, you could have a blog with articles and match `/blog/hello-world` with the following route:

```ruby
get "/blog/:slug", to: "blog#show"
```

#### CRUD Routes

There are 4 common actions you will generally need for a resource: Create, Read, Update, Delete (CRUD). This translates to 7 typical routes:

* Index - Shows all the records
* New - Renders a form for creating a new record
* Create - Processes the new form submission, handling errors and creating the record
* Show - Renders a specific record
* Edit - Renders a form for updating a specific record
* Update - Handles the edit form submission, handling errors and updating the record
* Destroy - Handles deleting a specific record

We can add routes for these CRUD actions with the following:

```ruby
get "/products", to: "products#index"

get "/products/new", to: "products#new"
post "/products", to: "products#create"

get "/products/:id", to: "products#show"

get "/products/:id/edit", to: "products#edit"
patch "/products/:id", to: "products#update"
put "/products/:id", to: "products#update"

delete "/products/:id", to: "products#destroy"
```

#### Resource Routes

Typing out these routes every time is redundant, so Rails provides a shortcut for defining them. To create the same CRUD routes, replace the above routes with this single line:

```ruby
resources :products
```

### Routes Command

Rails provides a command that displays all the routes your application responds to.

In your terminal, run the following command.

```bash
$ bin/rails routes
```

You'll see this in the output which are the routes generated by `resources :products`

```
                                  Prefix Verb   URI Pattern                                                                                       Controller#Action
                                products GET    /products(.:format)                                                                               products#index
                                         POST   /products(.:format)                                                                               products#create
                             new_product GET    /products/new(.:format)                                                                           products#new
                            edit_product GET    /products/:id/edit(.:format)                                                                      products#edit
                                 product GET    /products/:id(.:format)                                                                           products#show
                                         PATCH  /products/:id(.:format)                                                                           products#update
                                         PUT    /products/:id(.:format)                                                                           products#update
                                         DELETE /products/:id(.:format)                                                                           products#destroy
```

You'll also see routes from other built-in Rails features like health checks.

Controllers & Actions
---------------------

Now that we've defined routes for Products, let's implement the controller and actions to handle requests to these URLs.

This command will generate a ProductsController with an index action. Since we've already set up routes, we can skip that part of the generator

```bash
$ bin/rails generate controller Products index --skip-routes
      create  app/controllers/products_controller.rb
      invoke  erb
      create    app/views/products
      create    app/views/products/index.html.erb
      invoke  test_unit
      create    test/controllers/products_controller_test.rb
      invoke  helper
      create    app/helpers/products_helper.rb
      invoke    test_unit
```

This command generates a handful of files for our controller:

* The controller itself
* A views folder for the index action we specified
* A test file for this controller
* A helper file for extracting logic in our views

Let's take a look at the ProductsController defined in `app/controllers/products_controller.rb`. It looks like this:

```ruby
class ProductsController < ApplicationController
  def index
  end
end
```

You may notice the file name is an underscored version of the Class this file defines. This pattern helps Rails to automatically load code without having to use `require`.

The public `index` method here is an Action. Even though it's an empty method, Rails will default to rendering a template with the matching name.

The `index` action will render `app/views/products/index.html.erb`. If we open up that file, we'll see the HTML it renders.

```erb
<h1>Products#index</h1>
<p>Find me in app/views/products/index.html.erb</p>
```

### Making Requests

Let's see this in our browser. First, run `bin/rails server` in your terminal to start the Rails server. Then open http://localhost:3000 and you will see the Rails welcome page.

If we open http://localhost:3000/products in the browser, Rails will render the products index HTML.

Our browser requested `/products` and Rails matched this route to `products#index`. Rails sent the request to the `ProductsController` and called the `index` action. Since this action was empty, Rails rendered the matching template at `app/views/products/index.html.erb` and returned that to our browser. Pretty cool!

If we open `config/routes.rb`, we can tell Rails the root route should render the Products index action by adding this line:

```ruby
root "products#index"
```

Now when you visit http://localhost:3000, Rails will render Products#index.

### Instance Variables

Let's take this a step further and render some records from our database.

In the `index` action, let's add a database query and assign it to an instance variable. Rails uses instance variables (variables that start with an @) to share data with the views.

```ruby
class ProductsController < ApplicationController
  def index
    @products = Product.all
  end
end
```

In `app/views/products/index.html.erb`, we can replace the HTML with this ERB:

```erb
<%= debug @products %>
```

ERB is short for "Embedded Ruby" and allows us to execute Ruby code to dynamically generate HTML with Rails. The `<%= %>` tag tells ERB to execute the ruby code inside and output the return value. In our case, this takes `@products`, converts it to YAML, and outputs the YAML.

Now refresh http://localhost:3000/ in your browser and you'll see that the output has changed. What you're seeing is the records in your database being displayed in YAML format.

The `debug` helper prints out variables in YAML format to help with debugging. For example, if you weren't paying attention and typed singular `@product` instead of plural `@products`, the debug helper could help you identify that the variable was not set correctly in the controller.

Let's update `app/views/products/index.html.erb` to render all of our product names.

```erb
<h1>Products</h1>

<div id="products">
  <% @products.each do |product| %>
    <div>
      <%= product.name %>
    </div>
  <% end %>
</div>
```

Using ERB, this code will loop through each product in the `@products` `ActiveRecord::Relation` object and renders a div containing the product name.

We've used a new ERB tag this time as well. `<% %>` evaluates the Ruby code but does not output the return value. That ignores the output of `@products.each` which would output an array that we don't want in our HTML.

### CRUD Actions

We need to be able to access individual products. This is the R in CRUD to read a resource.

We've already defined the route for individual products with our `resources :products` route. This generates `/products/:id` as a route that points to `products#show`.

### Showing Individual Products

We can add the `show` action like this:

```ruby
class ProductsController < ApplicationController
  def index
    @products = Product.all
  end

  def show
    @product = Product.find(params[:id])
  end
end
```

The `show` action here defines the *singular* `@product` because it's loading a single record from the database. We use plural `@products` in `index` because we're loading multiple products.

To query the database, we use `params` to access the request parameters. In this case, we're using the `:id` from our route `/products/:id`. When we visit `/products/1`, the params hash will contain `{id: 1}` which results in our `show` action calling `Product.find(1)` to load Product with ID of `1` from the database.

We need a view for the show action next. We can create `app/views/products/show.html.erb` and add the following.

```erb
<h1><%= @product.name %></h1>

<%= link_to "Back", products_path %>
```

It would be helpful for the index page to link to the show page for each product so we can click on them to navigate. We can update the `index.html.erb` view to link to this new page to use an anchor tag to the path for the `show` action.

```erb
<h1>Products</h1>

<div id="products">
  <% @products.each do |product| %>
    <div>
      <a href="/products/<%= product.id %>">
        <%= product.name %>
      </a>
    </div>
  <% end %>
</div>
```

Refresh this page in your browser and you'll see that this works, but we can do better.

Rails provides helper methods for generating paths and URLs. When you run `rails routes`, you'll see the Prefix column. This prefix matches the helpers you can use for generating URLs with Ruby code.

```
                                  Prefix Verb   URI Pattern                                                                                       Controller#Action
                                products GET    /products(.:format)                                                                               products#index
                                 product GET    /products/:id(.:format)                                                                           products#show
```

These route prefixes give us helpers like the following:

* `products_path` generates `"/products`"`
* `products_url` generates `"http://localhost:3000/products`"`
* `product_path(1)` generates `"/products/1"`
* `product_url(1)` generates `"http://localhost:3000/products/1"`

`_path` returns a relative path which the browser understands is for the current domain.
`_url` returns a full URL including the protocol, host, and port.

URL helpers are useful for rendering emails that will be viewed outside outside of the browser.

Combined with the `link_to` helper, we can generate anchor tags and use the URL helper to do this cleanly in Ruby. `link_to` accepts the display content for the link and the path or URL to link to for the `href` attribute.

Let's refactor this to use these helpers:

```erb
<h1>Products</h1>

<div id="products">
  <% @products.each do |product| %>
    <div>
        <%= link_to product.name, product %>
    </div>
  <% end %>
</div>
```

### Creating Products

So far we've had to create products in the Rails console, but let's make this work in the browser.

We need to create two actions for create:

1. The new product form
2. The create action to save the product and check for errors

Let's start with our controller actions.

```ruby
class ProductsController < ApplicationController
  def index
    @products = Product.all
  end

  def show
    @product = Product.find(params[:id])
  end

  def new
    @product = Product.new
  end
end
```

The `new` action instantiates a new Product in memory which we will use for rendering the form.

We can update `app/views/products/index.html.erb` to link to the new action.

```erb
<h1>Products</h1>

<%= link_to "New product", new_product_path %>

<div id="products">
  <% @products.each do |product| %>
    <div>
        <%= link_to product.name, product %>
    </div>
  <% end %>
</div>
```

Let's create `app/views/products/new.html.erb` to render the form for this new Product.

```erb
<h1>New product</h1>

<%= form_with model: @product do |form| %>
  <div>
    <%= form.label :name %>
    <%= form.text_field :name %>
  </div>

  <div>
    <%= form.submit %>
  </div>
<% end %>
```

In this view, we are using the Rails `form_with` helper to generate an HTML form to create products. This helper uses a *form builder* to handle things like CSRF tokens, generating the URL based upon the `model:` provided, and even tailoring the submit button text to the model.

```html
<form action="/products" accept-charset="UTF-8" method="post"><input type="hidden" name="authenticity_token" value="UHQSKXCaFqy_aoK760zpSMUPy6TMnsLNgbPMABwN1zpW-Jx6k-2mISiF0ulZOINmfxPdg5xMyZqdxSW1UK-H-Q" autocomplete="off">

  <div>
    <label for="product_name">Name</label>
    <input type="text" name="product[name]" id="product_name">
  </div>

  <div>
    <input type="submit" name="commit" value="Create Product" data-disable-with="Create Product">
  </div>
</form>
```

Since we passed in a new Product, the form builder generated a form that will send a `POST` request to `/products` to create a new one.

To handle this, we need to implement the `create` action in our controller.

```ruby
class ProductsController < ApplicationController
  def index
    @products = Product.all
  end

  def show
    @product = Product.find(params[:id])
  end

  def new
    @product = Product.new
  end

  def create
    @product = Product.new(product_params)
    if @product.save
      redirect_to @product
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

	def product_params
	  params.expect(product: [ :name ])
	end
end
```

#### Strong Parameters

The `create` action handles the data submitted by the form, but it needs to be filtered for security. That's where `product_params` comes into play.

In `product_params`, we tell Rails to inspect the params and ensure there is a key named `:product` with an array of parameters as the value. The only permitted parameters for products is `:name` and Rails will ignore any other parameters. This protects our application from malicious users who might try to hack our application.

#### Handling errors

After assigning these params to the new Product in memory, we can try to save it to the database. `@product.save` tells Active Record to run validations and save the record to the database.

If this is successful, we want to redirect to the new product. The `redirect_to` method takes either a path/URL or can generate a path from an Active Record object. Here we supply `@product` which it sees is a Product object and finds the `products#show` route and inserts the ID to produce `"/products/2"`.

When the save is unsuccessful and the record wasn't valid, we want to re-render the form so the user can fix the invalid data. In the `else` clause, we tell Rails to `render :new`. Rails knows we're in the `Products` controller, so it should render `app/views/products/new.html.erb`. Since we've set the `@product` variable in `create`, we can render that template and the form will be populated with our Product data even though it wasn't able to be saved in the database.

We also set the HTTP status to 422 Unprocessable Entity to tell the browser this POST request failed and to handle it accordingly.

### Editing Products

The process of editing records is very similar to creating records. Instead of `new` and `create` actions, we will have `edit` and `update`.

Let's implement them with the following:

```ruby
class ProductsController < ApplicationController
  def index
    @products = Product.all
  end

  def show
    @product = Product.find(params[:id])
  end

  def new
    @product = Product.new
  end

  def create
    @product = Product.new(product_params)
    if @product.save
      redirect_to @product
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @product = Product.find(params[:id])
  end

  def update
    @product = Product.find(params[:id])
	if @product.update(product_params)
      redirect_to @product
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

	def product_params
	  params.expect(product: [ :name ])
	end
end
```

Next we can add an Edit link to `app/views/products/show.html.erb`:

```erb
<h1><%= @product.name %></h1>

<%= link_to "Back", products_path %>
<%= link_to "Edit", edit_product_path(@product) %>
```

#### Before Actions

Since `edit` and `update` require an existing database record like `show` we can deduplicate this into a `before_action`.

A `before_action` allows you to extract shared code between actions and run it *before* the action.

Extracting the `Product.find` query to a before action called `set_product` cleans up our code for each action:

```ruby
class ProductsController < ApplicationController
  before_action :set_product, only: %i[ show edit update ]

  def index
    @products = Product.all
  end

  def show
  end

  def new
    @product = Product.new
  end

  def create
    @product = Product.new(product_params)
    if @product.save
      redirect_to @product
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
	if @product.update(product_params)
      redirect_to @product
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

    def set_product
      @product = Product.find(params[:id])
    end

    def product_params
      params.expect(product: [ :name ])
    end
end
```

#### Extracting Partials

We've already written a form for creating new products. Wouldn't it be nice if we could reuse that for edit and update? We can using a feature called "partials" that allow you to reuse a view in multiple places.

We can move the form into a file called `app/views/products/_form.html.erb`. The filename starts with an underscore denotes this is a partial.

We also want to replace any instance variables with a local variable. We'll replace `@product` with `product`.

```erb
<%= form_with model: product do |form| %>
  <div>
    <%= form.label :name %>
    <%= form.text_field :name %>
  </div>

  <div>
    <%= form.submit %>
  </div>
<% end %>
```

To use this partial in our new view, we can replace the form with a render call:

```erb
<h1>New product</h1>

<%= render "form", product: @product %>
<%= link_to "Cancel", products_path %>
```

The edit view becomes almost the exact same thing thanks to the form partial.

```erb
<h1>Edit product</h1>

<%= render "form", product: @product %>
<%= link_to "Cancel", @product %>
```

### Deleting Products

The last feature we need to implement is deleting products. We will add a `destroy` action to our `ProductsController` to handle `DELETE /products/:id` requests:

```ruby
class ProductsController < ApplicationController
  before_action :set_product, only: %i[ show edit update destroy ]

  def index
    @products = Product.all
  end

  def show
  end

  def new
    @product = Product.new
  end

  def create
    @product = Product.new(product_params)
    if @product.save
      redirect_to @product
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
	if @product.update(product_params)
      redirect_to @product
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @product.destroy
    redirect_to products_path
  end

  private

    def set_product
      @product = Product.find(params[:id])
    end

	def product_params
	  params.expect(product: [ :name ])
	end
end
```

To make this work, we need to add a Destroy button to `app/views/products/show.html.erb`:

```erb
<h1><%= @product.name %></h1>

<%= link_to "Back", products_path %>
<%= link_to "Edit", edit_product_path(@product) %>
<%= button_to "Destroy", @product, method: :delete, data: { turbo_confirm: "Are you sure?" } %>
```

`button_to` generates a form with a single button in it with the "Destroy" text. When this button is clicked, it submits the form which makes a `DELETE` request to `/products/:id` which triggers the `destroy` action in our controller.

The `turbo_confirm` data attribute tells the Turbo JavaScript library to ask the user to confirm before submitting the form. We'll dig more into that shortly.

Adding Authentication
---------------------

Anyone can edit or delete products which isn't safe. Let's add some security by requiring a a user to be authenticated to manage products.

Rails comes with an authentication generator that we can use. It creates User and Session models and the controllers and views necessary to login to our application.

```bash
$ bin/rails generate authentication
```

Then migrate the database to add the User and Session tables.

```bash
$ bin/rails db:migrate
```

Next, we will create a User using the Rails console. Feel free to user your own email and password instead of the example.

```irb
store(dev)> User.create! email_address: "you@example.org", password: "s3cr3t", password_confirmation: "s3cr3t"
```

Restart your Rails server so it picks up the `bcrypt` gem added by the generator. BCrypt is used for securely hashing passwords for authentication.

When you visit any page, Rails will prompt for a username and password. Enter the email and password you used when creating the User record.

Try it out by visiting http://localhost:3000/products/new

If you enter the correct username and password, it will allow you through. Your browser will also store these credentials for future requests so you don't have to type it in every page view.


### Adding Log Out

To log out of the application, we can add a button to the top of `app/views/layouts/application.html.erb` to show it on every page.

Add a small `<nav>` section inside the `<body>` with a link to Home and a Log out button.

```erb
<!DOCTYPE html>
<html>
  <!-- ... -->
  <body>
    <nav>
      <%= link_to "Home", root_path %>
      <%= button_to "Log out", session_path, method: :delete if authenticated? %>
    </nav>

    <%= yield %>
  </body>
</html>
```

This will display a Log out button only if the user is authenticated. When clicked, it will send a DELETE request to the session path which will log the user out.

### Allowing Unauthenticated Access

However, our store's product index and show pages should be accessible to everyone. By default, theRails authentication generator will restrict all pages to authenticated users only.

To allow guests to view products, we can allow unauthenticated access in our controller.

```ruby
class ProductsController < ApplicationController
  allow_unauthenticated_access only: %i[ index show ]
  # ...
end
```

Log out and visit the products index and show pages to see they're accessible without being authenticated.

### Showing Links For Authenticated Users Only

Since only logged in users can create products, we can modify the index view to only display the new product link if the user is authenticated.

```erb
<%= link_to "New product", new_product_path if authenticated? %>
```

Click the Log out button and you'll see the New link is hidden. Log in at http://localhost:3000/session/new and you'll see the New link on the index page.

Optionally, you can include a link to this route in the navbar to add a Login link if not authenticated.

```erb
<%= link_to "Login", new_session_path unless authenticated? %>
```

You can also update the Edit and Destroy links on the show view to only display if authenticated.

```erb
<% if authenticated? %>
  <%= link_to "Edit", edit_product_path(@product) %>
  <%= button_to "Destroy", @product, method: :delete, data: { turbo_confirm: "Are you sure?" } %>
<% end %>
```

Caching Products
----------------

Sometimes you may need to cache parts of a page for performance and Rails provides functionality to make this easy with Solid Cache, a database-backed cache store, that is included by default.

Using the `cache` method, we can store HTML in the cache. Let's cache the header in `app/views/products/show.html.erb`.

```erb
<% cache @product do %>
  <h1><%= @product.name %></h1>
<% end %>
```

By passing `@product` into `cache`, Rails generates a unique cache key for the product. Active Record objects have a `cache_key` method that returns a String like `"products/1"`. The `cache` helper in the views combines this with the template digest to create a unique key for this HTML.

To enable caching in development, run `rails dev:cache` in your terminal.

When you visit a product's show action, you'll see the new caching lines in your Rails server logs:

```bash
Read fragment views/products/show:a5a585f985894cd27c8b3d49bb81de3a/products/1-20240918154439539125 (1.6ms)
Write fragment views/products/show:a5a585f985894cd27c8b3d49bb81de3a/products/1-20240918154439539125 (4.0ms)
```

The first time we open this page, Rails will generate a cache key and ask the cache store if it exists. This is the `Read fragment` line.

Since this is the first page view, the cache does not exist so the HTML is generated and written to the cache. We can see this as the `Write fragment` line in the logs.

Refresh the page and you'll see the logs no longer contain the `Write fragment`.

```bash
Read fragment views/products/show:a5a585f985894cd27c8b3d49bb81de3a/products/1-20240918154439539125 (1.3ms)
```

The cache entry was written by the last request, so Rails finds the cache entry on the second request. Rails also changes the cache key when records are updated to ensure that it never renders stale cache data.

Learn more in the [Caching with Rails](caching_with_rails.html) guide.

Adding CSS & JavaScript
-----------------------

CSS & JavaScript are core parts of building web applications, so let's learn how to use them with Rails.

### Propshaft

Rails' asset pipeline is called Propshaft. It takes your CSS, JavaScript, images, and other assets and serves them to your browser. In production, Propshaft digests your assets so they can be cached indefinitely for performance.

Let's modify `app/assets/stylesheets/application.css` and change our font to sans-serif.

```css
body {
  font-family: Arial, Helvetica, sans-serif;
}

nav {
  display: flex;
  gap: 0.5rem;
}

img {
  max-width: 800px;
}
```

Refresh your page and you'll see the CSS has been applied.

### Importmaps

Rails uses Importmaps for JavaScript by default. This allows you to write modern JavaScript modules with no build steps.

You can find the JavaScript pins in `config/importmap.rb`

```ruby
# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
```

This file maps the JavaScript package names with the source file which is used to generate the importmap tag in the browser.

### Hotwire

We haven't written any JavaScript yet, but we have been using Hotwire on the frontend.

Hotwire is a JavaScript framework designed to take full advantage of server-side generated HTML. It is comprised of 3 core components:

1. [**Turbo**](https://turbo.hotwired.dev/) handles navigation, form submissions, page components, and updates without writing any custom JavaScript.
2. [**Stimulus**](https://stimulus.hotwired.dev/) provides a framework for when you need custom JavaScript to add functionality to the page.
3. [**Native**](https://native.hotwired.dev/) allows you to make hybrid mobile apps by embedding your web app and progressively enhancing it with native mobile features.

Learn more in the [Asset Pipeline](asset_pipeline.html) and [Working with JavaScript in Rails](working_with_javascript_in_rails.html) guides.

Rich text fields with Action Text
--------------------------------

Many applications need rich text with embeds and Rails provides this functionailty out of the box with Action Text.

To use Action Text, you'll first run the installer:

```bash
$ bin/rails action_text:install
$ bin/rails db:migrate
```

Restart your Rails server to make sure all the new features are loaded.

We can add the following to the `Product` model to add a rich text field named `description`.

```ruby
class Product
  has_rich_text :description
  validates :name, presence: true
end
```

The form can be updated to include a rich text field for editing the description in `app/views/products/_form.html.erb` before the submit button.

```erb
<%= form_with model: product do |form| %>
  <%# ... %>

  <div>
    <%= form.label :description, style: "display: block" %>
    <%= form.rich_text_area :description %>
  </div>

  <div>
    <%= form.submit %>
  </div>
<% end %>
```

Our controller also needs to permit this new parameter when the form is submitted, so we'll update the permitted params to include description in `app/controllers/products_controller.rb`

```ruby
    # Only allow a list of trusted parameters through.
    def product_params
      params.expect(product: [ :name, :description ])
    end
```

We also need to update the show view to display the description in `app/views/products/show.html.erb`:

```erb
<% cache @product do %>
  <h1><%= @product.name %></h1>
  <%= @product.description %>
<% end %>
```

The cache key generated by Rails also changes when the view is modified. This makes sure the cache stays in sync with latest version of the view template.

Create a new product and add a description with bold and italic text. You'll see that the show page displays the formatted text and editing the product retains this rich text in the text area.

Check out the [Action Text Overview](action_text_overview.html) to learn more.

File uploads with Active Storage
-------------------------------

Action Text is built upon another feature of Rails called Active Storage that makes it easy to upload files.

Try editing a product and dragging an image into the rich text editor and update the record. You'll see that Rails uploads this image and renders it inside the rich text editor. Cool, right?!

We can also use Active Storage directly. Let's add a featured image to the `Product` model.

```ruby
class Product
  has_one_attached :featured_image
  has_rich_text :description
  validates :name, presence: true
end
```

Then we can add a file upload field to our product form before the submit button:

```erb
<%= form_with model: product do |form| %>
  <%# ... %>

  <div>
    <%= form.label :featured_image, style: "display: block" %>
    <%= form.file_field :featured_image, accept: "image/*" %>
  </div>

  <div>
    <%= form.submit %>
  </div>
<% end %>
```

Add `:featured_image` as a permitted parameter in `app/controllers/products_controller.rb`

```ruby
    # Only allow a list of trusted parameters through.
    def product_params
      params.expect(product: [ :name, :description, :featured_image ])
    end
```

Lastly, we want to display the featured image for our product in `app/views/products/show.html.erb`. Add the following to the top.

```erb
<%= image_tag @product.featured_image if @product.featured_image.attached? %>
```

Try uploading an image for a product and you'll see the image displayed on the show page after saving.

By default, Active Storage uploads files to disk but you'll want to change this for production. Check out the [Active Storage Overview](active_storage_overview.html) for more details.

Internationalization (I18n)
---------------------------

Rails makes it easy to translate your app into other languages.

The `translate` or `t` helper in our views looks up a translation by name and returns the text for the current locale.

In `app/products/index.html.erb`, let's update the header tag to use a translation.

```erb
<h1><%= t "hello" %></h1>
```

Refreshing the page, we see `Hello world` is the header text now.

Since the default language is in English, Rails looks in `config/locales/en.yml` for a matching key under the locale.

```yaml
en:
  hello: "Hello world"
```

Let's create a new locale file for Spanish and add a translation in `config/locales/es.yml`.

```yaml
es:
  hello: "Hola mundo"
```

We need to tell Rails which locale to use. The simplest option is to look for a locale param in the URL. We can do this in `app/controllers/application_controller.rb` with the following:

```ruby
class ApplicationController < ActionController::Base
  # ...

  around_action :switch_locale

  def switch_locale(&action)
    locale = params[:locale] || I18n.default_locale
    I18n.with_locale(locale, &action)
  end
end
```

This will run every request and look for `locale` in the params or fallback to the default locale. It sets the locale for the request and resets it after it's finished.

* Visit http://localhost:3000/products?locale=en, you will see the English translation.
* Visit http://localhost:3000/products?locale=es, you will see the Spanish translation.
* Visit http://localhost:3000/products without a locale param, it will fallback to English.

Let's update the index header to use a real translation instead of `"Hello world"`.

```erb
<h1><%= t ".title" %></h1>
```

TIP: Notice the `.` before `title`? This tells Rails to use a relative locale lookup. Relative lookups include the controller and action automatically in the key so you don't have to type them every time. For `.title` with the English locale, it will look up `en.products.index.title`.

In `config/locales/en.yml` we want to add the `title` key under `products` and `index` to match our controller, view, and translation name.

```yaml
en:
  hello: "Hello world"
  products:
    index:
	    title: "Products"
```

In the Spanish locales file, we can do the same thing:

```yaml
es:
  hello: "Hola mundo"
  products:
    index:
      title: "Productos"
```

You'll now see "Products" when viewing the English locale and "Productos" when viewing the Spanish locale.

Learn more about the [Rails Internationalization (I18n) API](i18n.html).

Adding In Stock Notifications
-----------------------------

A common feature of e-commerce stores is an email subscription to get notified when a product is back in stock. Now that we've seen the basics of Rails, let's add this feature to our e-commerce store.

### Basic Inventory Tracking

First, let's add an inventory count to the Product model so we can keep track of it. We can generate this migration using the following command:

```bash
$ bin/rails generate migration AddInventoryCountToProducts inventory_count:integer
```

Then let's run the migration.

```bash
$ bin/rails db:migrate
```

We'll need to add the inventory count to the product form in `app/views/products/_form.html.erb`.

```erb
<%= form_with model: product do |form| %>
  <%# ... %>

  <div>
    <%= form.label :inventory_count, style: "display: block" %>
    <%= form.number_field :inventory_count %>
  </div>

  <div>
    <%= form.submit %>
  </div>
<% end %>
```

The controller also needs `:inventory_count` added to the permitted parameters.

```ruby
    def product_params
      params.expect(product: [ :name, :description, :featured_image, :inventory_count ])
    end
```

It would also be helpful to validate that our inventory count is never a negative number, so let's also add a validation for that in our model.

```ruby
class Product < ApplicationRecord
  has_one_attached :featured_image
  has_rich_text :description

  validates :name, presence: true
  validates :inventory_count, numericality: { greater_than_or_equal_to: 0 }
end
```

With these changes, we can now update the inventory count of products in our store.

### Adding Subscribers to Products

In order to notify users that a product is back in stock, we need to keep track of these subscribers.

Let's generate a model called Subscriber to store these email addresses and associate them with the respective product.

```bash
$ bin/rails generate model Subscriber product:belongs_to email
```

Then run the new migration:

```bash
$ bin/rails db:migrate
```

We can add `has_many :subscribers, dependent: :destroy` to our Product model to add an association between the two models. This tells Rails how to join queries between the two database tables.

```ruby
class Product < ApplicationRecord
  has_many :subscribers, dependent: :destroy
  has_one_attached :featured_image
  has_rich_text :description

  validates :name, presence: true
  validates :inventory_count, numericality: { greater_than_or_equal_to: 0 }
end
```

We also need a controller to create these subscribers. Let's create that in `app/controllers/subscribers_controller.rb` with the following code:

```ruby
class SubscribersController < ApplicationController
  before_action :set_product

  def create
    @product.subscribers.where(subscriber_params).first_or_create
    redirect_to @product, notice: "You are now subscribed."
  end

  private

  def set_product
    @product = Product.find(params[:product_id])
  end

  def subscriber_params
    params.expect(subscriber: [ :email ])
  end
end
```

To subscriber users to a specific product, we'll use a nested route so we know which product the subscriber belongs to. In `config/routes.rb` change `resources :products` to the following:

```ruby
  resources :products do
    resources :subscribers, only: [ :create ]
  end
```

On the product show page, we can check if there is inventory and display the amount in stock. Otherwise, we can display an out of stock message with the subscribe form to get notified when it is back in stock.

Add the following between the `cache` block and "Back" link.

```erb
<% if @product.inventory_count? %>
  <p><%= @product.inventory_count %> in stock</p>
<% else %>
  <p>Out of stock</p>
  <p>Email me when available.</p>

  <%= form_with model: [@product, Subscriber.new] do |form| %>
    <%= form.email_field :email, placeholder: "you@example.com", required: true %>
    <%= form.submit "Submit" %>
  <% end %>
<% end %>
```

### In stock email notifications

Action Mailer is a feature of Rails that allows you to send emails. We'll use it to notify subscribers when a product is back in stock.

We can generate a mailer with the following command:

```bash
$ bin/rails g mailer Product in_stock
```

This generates a class at `app/mailers/product_mailer.rb` with an `in_stock` method.

Update this method to mail to a subscriber's email address.

```ruby
class ProductMailer < ApplicationMailer
  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.product_mailer.in_stock.subject
  #
  def in_stock
    @product = params[:product]
    mail to: params[:subscriber].email
  end
end
```

The mailer generator also generates two email templates. One for HTML and one for Text. We can update those to include a message and link to the product.

Change `app/views/product_mailer/in_stock.html.erb` to:

```erb
<h1>Good news!</h1>

<p><%= link_to @product.name, product_url(@product) %> is back in stock.</p>
```

And `app/views/product_mailer/in_stock.text.erb` to:

```erb
Good news!

<%= @product.name %> is back in stock.
<%= product_url(@product) %>
```

We use `product_url` instead of `product_path` in mailers because email clients need to know the full URL to open in the browser when the link is clicked.

We can test an email by opening the Rails console and loading a product and subscriber to send to:

```ruby
product = Product.first
subscriber = product.subscribers.first
ProductMailer.with(product: product, subscriber: subscriber).in_stock.deliver_later
```

You'll see that it prints out an email in the logs.

```
ProductMailer#in_stock: processed outbound mail in 63.0ms
Delivered mail 66a3a9afd5d4a_108b04a4c41443@local.mail (33.1ms)
Date: Fri, 26 Jul 2024 08:50:39 -0500
From: from@example.com
To: subscriber@example.com
Message-ID: <66a3a9afd5d4a_108b04a4c41443@local.mail>
Subject: In stock
Mime-Version: 1.0
Content-Type: multipart/alternative;
 boundary="--==_mimepart_66a3a9afd235e_108b04a4c4136f";
 charset=UTF-8
Content-Transfer-Encoding: 7bit


----==_mimepart_66a3a9afd235e_108b04a4c4136f
Content-Type: text/plain;
 charset=UTF-8
Content-Transfer-Encoding: 7bit

Good news!

T-Shirt is back in stock.
http://localhost:3000/products/1


----==_mimepart_66a3a9afd235e_108b04a4c4136f
Content-Type: text/html;
 charset=UTF-8
Content-Transfer-Encoding: 7bit

<!-- BEGIN app/views/layouts/mailer.html.erb --><!DOCTYPE html>
<html>
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
    <style>
      /* Email styles need to be inline */
    </style>
  </head>

  <body>
    <!-- BEGIN app/views/product_mailer/in_stock.html.erb --><h1>Good news!</h1>

<p><a href="http://localhost:3000/products/1">T-Shirt</a> is back in stock.</p>
<!-- END app/views/product_mailer/in_stock.html.erb -->
  </body>
</html>
<!-- END app/views/layouts/mailer.html.erb -->
----==_mimepart_66a3a9afd235e_108b04a4c4136f--

Performed ActionMailer::MailDeliveryJob (Job ID: 5e2bd5f2-f54f-4088-ace3-3f6eb15aaf46) from Async(default) in 111.34ms
```

To trigger these emails, we can use a callback in the Product model to send emails anytime the inventory count changes from 0 to a positive number.

```ruby
class Product < ApplicationRecord
  has_one_attached :featured_image
  has_rich_text :description
  has_many :subscribers, dependent: :destroy

  validates :name, presence: true
  validates :inventory_count, numericality: { greater_than_or_equal_to: 0 }

  after_update_commit :notify_subscribers, if: :back_in_stock?

  def back_in_stock?
    inventory_count_previously_was == 0 && inventory_count > 0
  end

  def notify_subscribers
    subscribers.each do |subscriber|
      ProductMailer.with(product: self, subscriber: subscriber).in_stock.deliver_later
    end
  end
end
```

`after_update_commit` is a callback that is fired after changes are saved to the database. `if: :back_in_stock?` tells the callback to run only if the `back_in_stock?` method returns true.

Active Record keeps track of changes to attributes so `back_in_stock?` checks the previous value of `inventory_count` using `inventory_count_previously_was`. Then we can compare that against the current inventory count to determine if the product is back in stock.

`notify_subscribers` uses the Active Record association to query the `subscribers` table for all subscribers for this specific product and then queues up the `in_stock` email to be sent to each of them.

### Extracting A Concern

The Product model now has several methods for handling notifications to subscribers. For better organization of our code, we can extract this to an `ActiveSupport::Concern`. A Concern is a Ruby module with some syntactic sugar for including modules into Ruby classes more easily.

Create a file at `app/models/product/notifications.rb` with the following code for product subscribers and notifications.

```ruby
module Product::Notifications
  extend ActiveSupport::Concern

  included do
    has_many :subscribers, dependent: :destroy
    after_update_commit :notify_subscribers, if: :back_in_stock?
  end

  def back_in_stock?
    inventory_count_previously_was == 0 && inventory_count > 0
  end

  def notify_subscribers
    subscribers.each do |subscriber|
      ProductMailer.with(product: self, subscriber: subscriber).in_stock.deliver_later
    end
  end
end
```

The Product model can now be simplified to include the Notifications module.

```ruby
class Product < ApplicationRecord
  include Notifications

  has_one_attached :featured_image
  has_rich_text :description

  validates :name, presence: true
  validates :inventory_count, numericality: { greater_than_or_equal_to: 0 }
end
```

Concerns are a great way to organize features of your Rails application. As you add more features to the Product, the class will become messy. Instead, we can use Concerns to extract each feature out into a self-contained module like `Product::Notifications` which contains all the functionality for handling subscribers and how notifications are sent.

Extracting code into concerns also helps make features reusable. For example, we could introduce  a new model that also needs subscriber notifications. This module could be used in multiple models to provide the same functionality.

### Unsubscribe links

A subscriber may want to unsubscribe at some point. Let's build that next.

First, we'll start by creating a route. This will be the URL we include in emails and will send to a controller for processing the unsubscribe.

```ruby
  resource :unsubscribe, only: [ :show ]
```

In the model, we can use a feature of Rails that generates unique tokens for different purposes. We'll add one for unsubscribing:

```ruby
class Subscriber < ApplicationRecord
  belongs_to :product
  generates_token_for :unsubscribe
end
```

Our controller will be pretty straightforward. It will first look up the Subscriber record from the token in the URL. Once found, it will destroy the record and redirect to the product they were subscribed to.

```ruby
class UnsubscribesController < ApplicationController
  before_action :set_subscriber

  def show
    @subscriber.destroy
    redirect_to @subscriber.product, notice: "Unsubscribed successfully."
  end

  private

  def set_subscriber
    @subscriber = Subscriber.find_by_token_for!(:unsubscribe, params[:token])
  end
end
```

Last but not least, we can add an unsubscribe link to our email template to this route.

```erb
<h1>Good news!</h1>

<p><%= link_to @product.name, product_url(@product) %> is back in stock.</p>

<%= link_to "Unsubscribe", unsubscribe_url(token: params[:subscriber].generate_token_for(:unsubscribe)) %>
```

Now when you click the unsubscribe link in an email, the subscriber record will be deleted from the database.

Testing
-------

Let's write a test to ensure that the correct number of emails are sent when a product is back in stock.

### Fixtures

Tests often rely on records in the database. Rails provides fixtures which are copied into the database and given names to easily look up records in your tests.

```yaml
# test/fixtures/products.yml
tshirt:
  name: T-Shirt
  inventory_count: 15
```

For subscribers, we can add 2 fixtures. You'll notice that we can reference the Product fixture by name here. Rails associates this automatically for us in the database so we don't have to manage record IDs and associations.

```yaml
# test/fixtures/subscribers.yml
one:
  product: tshirt
  email: david@example.org

two:
  product: tshirt
  email: chris@example.org
```

### Testing Emails

In `test/models/product_test.rb`, let's add a test:

```ruby
require "test_helper"

class ProductTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  test "sends email notifications when back in stock" do
    product = products(:tshirt)
    product.update(inventory_count: 0)

    assert_emails 2 do
      product.update(inventory_count: 99)
    end
  end
end
```

In this class, we first include the Action Mailer test helpers so we can monitor emails being sent out during our tests.

Our test loads the tshirt fixture and returns the Active Record object for that record. We then ensure the tshirt as out of stock by updating it's inventory to 0.

Then we tell `assert_emails` to look for 2 emails generated by the code inside the block. Inside that block, we update the product to be in stock. This will trigger the `notify_subscribers` callback in the product model to send emails which is confirmed by `assert_emails`.

We can run the test suite with `bin/rails test`

```bash
$ bin/rails test test/models/product_test.rb
Running 1 tests in a single process (parallelization threshold is 50)
Run options: --seed 3556

# Running:

.

Finished in 0.343842s, 2.9083 runs/s, 5.8166 assertions/s.
1 runs, 2 assertions, 0 failures, 0 errors, 0 skips
```

Everything passes!

You can use this as a starting place to continue building out a test suite with full coverage of the application features.

Learn more about [Testing Rails Applications](testing.html)

Consistently formatted code with Rubocop
----------------------------------------

When writing code we may sometimes use inconsistent formatting. Rails comes with a linter called Rubocop that helps keep our code formatted consistently.

We can check our code for consistency by running:

```bash
$ bin/rubocop
```

This will print out any issues and let us know what is wrong.

Rubocop can automatically fix issues for us. We can do that using the `-a` flag to autocorrect issues as they're found. Run this command to have Rubocop update your files with consistently formatted code.

```
$ bin/rubocop -a
```

Security
--------

Rails includes the Brakeman gem out of the box. It can be used for checking security issues with your application.

If we run `bin/brakeman`, we'll see any security warnings it detects.

```bash
$ bin/brakeman
Loading scanner...
...

== Overview ==

Controllers: 6
Models: 6
Templates: 15
Errors: 0
Security Warnings: 0

== Warning Types ==


No warnings foundd
```

Learn more about [Securing Rails Applications](security.html)

Continuous Integration with GitHub Actions
------------------------------------------

Rails apps generate a `.github` folder that includes a prewritten GitHub Actions configuration that runs rubocop, brakeman, and our test suite.

When we push our code to a GitHub repository with GitHub Actions enabled, it will automatically run these steps and report back success or failure for each. This allows us to monitor our code changes for defects and issues and ensure consistent quality for our work.

Deploying to Production
-----------------------

Rails comes with a zero-downtime deployment tool called Kamal that we can use to deploy our  application directly to a server. Kamal uses Docker containers to run your application and deploy with zero downtime.

Rails comes with a production-ready Dockerfile that Kamal will use to build the image. The Dockerfile uses [Thruster](https://github.com/basecamp/thruster) to compress and serve assets efficiently in production.

To deploy with Kamal, we need:

- A server running Ubuntu LTS with 1GB RAM or more.
  Hetzner, DigitalOcean, and many other hosting services provide servers to get started.
  The server should run the Ubuntu operating system with a Long-Term Support (LTS) version so it receives regular security and bug fixes.
- A [Docker Hub](https://hub.docker.com) account and access token.
  Docker Hub stores the image of the application so it can be downloaded and run on the server.

On Docker Hub, we need to [create a Repository](https://hub.docker.com/repository/create) to store our application image. Use "store" as the name for the repository.

Open `config/deploy.yml` and replace `192.168.0.1` with your server's IP address and `your-user` with your Docker Hub username.

```yaml
# Name of your application. Used to uniquely configure containers.
service: store

# Name of the container image.
image: your-user/store

# Deploy to these servers.
servers:
  web:
    - 192.168.0.1

# Credentials for your image host.
registry:
  # Specify the registry server, if you're not using Docker Hub
  # server: registry.digitalocean.com / ghcr.io / ...
  username: your-user
```

Under the `proxy:` section, you can add a domain to enable SSL for your application too. Make sure your DNS record points to the server and Kamal will use LetsEncrypt to issue an SSL certificate the domain.

```yaml
proxy:
  ssl: true
  host: app.example.com
```

Kamal will looks for an environment variable for the Docker Hub access token. Sign into Docker Hub and [create an access token](https://app.docker.com/settings/personal-access-tokens/create) with Read & Write permissions.

We can export it in the terminal so Kamal can find it.

```bash
export KAMAL_REGISTRY_PASSWORD=your-token
```

Run the following command to set up your server and deploy your application for the first time.

```bash
$ bin/kamal setup
```

To see your Rails app in production, enter your server's IP address in your browser.

When you're ready to deploy new changes, you can run the following:

```bash
$ bin/kamal deploy
```

### Adding a User to Production

Our production database needs a User so we can create and edit products. We'll use Kamal to open a Rails console so we can create a User in our production database.

```bash
$ bin/kamal console
```

```ruby
store(prod)> User.create!(email_address: "you@example.org", password: "s3cr3t", password_confirmation: "s3cr3t")
```

### Background jobs using Solid Queue

In development, Rails will use the `:async` queue adapter to process background jobs with ActiveJob. Async stores pending jobs in memory which works great for development but it will lose pending jobs on restart.

To make background jobs more robust, Rails uses `solid_queue` for production environments. Solid Queue stores jobs in the database and executes them in a separate process.

Solid Queue is enabled for our production Kamal deployment using the `SOLID_QUEUE_IN_PUMA: true` environment variable to `config/deploy.yml`. This tells our web server, Puma, to start and stop the Solid Queue process automatically.

When emails are sent with Action Mailer's `deliver_later`, these emails will be sent to ActiveJob for sending in the background so they don't delay the HTTP request. With Solid Queue in production, emails will be sent in the background, automatically retried if they fail to send, and jobs are kept safe in the database during restarts.

What's Next?
------------

Congratulations on building and deploying your first Rails application!

We recommend continuing to add features and deploy updates to continue learning. Here are some ideas:

* Improve the design with CSS
* Add product reviews
* Finish translating the app into another language
* Add a checkout flow for payments

We also recommend learning more by reading other Ruby on Rails Guides:

* [Active Record Basics](active_record_basics.html)
* [Layouts and Rendering in Rails]()
* [Testing Rails Applications](testing.html)
* [Debugging Rails Applications](debugging_rails_applications.html)
* [Securing Rails Applications](security.html)