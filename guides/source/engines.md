Getting Started with Engines
============================

In this guide you will learn about engines and how they can be used to provide additional functionality to their host applications through a clean and very easy-to-use interface.

After reading this guide, you will know:

* What makes an engine.
* How to generate an engine.
* Building features for the engine.
* Hooking the engine into an application.
* Overriding engine functionality in the application.

--------------------------------------------------------------------------------

What are engines?
-----------------

Engines can be considered miniature applications that provide functionality to their host applications. A Rails application is actually just a "supercharged" engine, with the `Rails::Application` class inheriting a lot of its behavior from `Rails::Engine`.

Therefore, engines and applications can be thought of almost the same thing, just with subtle differences, as you'll see throughout this guide. Engines and applications also share a common structure.

Engines are also closely related to plugins where the two share a common `lib` directory structure and are both generated using the `rails plugin new` generator. The difference being that an engine is considered a "full plugin" by Rails as indicated by the `--full` option that's passed to the generator command, but this guide will refer to them simply as "engines" throughout. An engine **can** be a plugin, and a plugin **can** be an engine.

The engine that will be created in this guide will be called "blorgh". The engine will provide blogging functionality to its host applications, allowing for new posts and comments to be created. At the beginning of this guide, you will be working solely within the engine itself, but in later sections you'll see how to hook it into an application.

Engines can also be isolated from their host applications. This means that an application is able to have a path provided by a routing helper such as `posts_path` and use an engine also that provides a path also called `posts_path`, and the two would not clash. Along with this, controllers, models and table names are also namespaced. You'll see how to do this later in this guide.

It's important to keep in mind at all times that the application should **always** take precedence over its engines. An application is the object that has final say in what goes on in the universe (with the universe being the application's environment) where the engine should only be enhancing it, rather than changing it drastically.

To see demonstrations of other engines, check out [Devise](https://github.com/plataformatec/devise), an engine that provides authentication for its parent applications, or [Forem](https://github.com/radar/forem), an engine that provides forum functionality. There's also [Spree](https://github.com/spree/spree) which provides an e-commerce platform, and [RefineryCMS](https://github.com/refinery/refinerycms), a CMS engine.

Finally, engines would not have been possible without the work of James Adam, Piotr Sarnacki, the Rails Core Team, and a number of other people. If you ever meet them, don't forget to say thanks!

Generating an engine
--------------------

To generate an engine, you will need to run the plugin generator and pass it options as appropriate to the need. For the "blorgh" example, you will need to create a "mountable" engine, running this command in a terminal:

```bash
$ rails plugin new blorgh --mountable
```

The full list of options for the plugin generator may be seen by typing:

```bash
$ rails plugin --help
```

The `--full` option tells the generator that you want to create an engine, including a skeleton structure by providing the following:

  * An `app` directory tree
  * A `config/routes.rb` file:

    ```ruby
    Rails.application.routes.draw do
    end
    ```
  * A file at `lib/blorgh/engine.rb` which is identical in function to a standard Rails application's `config/application.rb` file:

    ```ruby
    module Blorgh
      class Engine < ::Rails::Engine
      end
    end
    ```

The `--mountable` option tells the generator that you want to create a "mountable" and namespace-isolated engine. This generator will provide the same skeleton structure as would the `--full` option, and will add:

  * Asset manifest files (`application.js` and `application.css`)
  * A namespaced `ApplicationController` stub
  * A namespaced `ApplicationHelper` stub
  * A layout view template for the engine
  * Namespace isolation to `config/routes.rb`:

    ```ruby
    Blorgh::Engine.routes.draw do
    end
    ```

  * Namespace isolation to `lib/blorgh/engine.rb`:

    ```ruby
    module Blorgh
      class Engine < ::Rails::Engine
        isolate_namespace Blorgh
      end
    end
    ```

Additionally, the `--mountable` option tells the generator to mount the engine inside the dummy testing application located at `test/dummy` by adding the following to the dummy application's routes file at `test/dummy/config/routes.rb`:

```ruby
mount Blorgh::Engine, at: "blorgh"
```

### Inside an engine

#### Critical files

At the root of this brand new engine's directory lives a `blorgh.gemspec` file. When you include the engine into an application later on, you will do so with this line in the Rails application's `Gemfile`:

```ruby
gem 'blorgh', path: "vendor/engines/blorgh"
```

By specifying it as a gem within the `Gemfile`, Bundler will load it as such, parsing this `blorgh.gemspec` file and requiring a file within the `lib` directory called `lib/blorgh.rb`. This file requires the `blorgh/engine.rb` file (located at `lib/blorgh/engine.rb`) and defines a base module called `Blorgh`.

```ruby
require "blorgh/engine"

module Blorgh
end
```

TIP: Some engines choose to use this file to put global configuration options for their engine. It's a relatively good idea, and so if you want to offer configuration options, the file where your engine's `module` is defined is perfect for that. Place the methods inside the module and you'll be good to go.

Within `lib/blorgh/engine.rb` is the base class for the engine:

```ruby
module Blorgh
  class Engine < Rails::Engine
    isolate_namespace Blorgh
  end
end
```

By inheriting from the `Rails::Engine` class, this gem notifies Rails that there's an engine at the specified path, and will correctly mount the engine inside the application, performing tasks such as adding the `app` directory of the engine to the load path for models, mailers, controllers and views.

The `isolate_namespace` method here deserves special notice. This call is responsible for isolating the controllers, models, routes and other things into their own namespace, away from similar components inside the application. Without this, there is a possibility that the engine's components could "leak" into the application, causing unwanted disruption, or that important engine components could be overridden by similarly named things within the application. One of the examples of such conflicts are helpers. Without calling `isolate_namespace`, engine's helpers would be included in an application's controllers.

NOTE: It is **highly** recommended that the `isolate_namespace` line be left within the `Engine` class definition. Without it, classes generated in an engine **may** conflict with an application.

What this isolation of the namespace means is that a model generated by a call to `rails g model` such as `rails g model post` won't be called `Post`, but instead be namespaced and called `Blorgh::Post`. In addition, the table for the model is namespaced, becoming `blorgh_posts`, rather than simply `posts`. Similar to the model namespacing, a controller called `PostsController` becomes `Blorgh::PostsController` and the views for that controller will not be at `app/views/posts`, but `app/views/blorgh/posts` instead. Mailers are namespaced as well.

Finally, routes will also be isolated within the engine. This is one of the most important parts about namespacing, and is discussed later in the [Routes](#routes) section of this guide.

#### `app` directory

Inside the `app` directory are the standard `assets`, `controllers`, `helpers`, `mailers`, `models` and `views` directories that you should be familiar with from an application. The `helpers`, `mailers` and `models` directories are empty and so aren't described in this section. We'll look more into models in a future section, when we're writing the engine.

Within the `app/assets` directory, there are the `images`, `javascripts` and `stylesheets` directories which, again, you should be familiar with due to their similarity to an application. One difference here however is that each directory contains a sub-directory with the engine name. Because this engine is going to be namespaced, its assets should be too.

Within the `app/controllers` directory there is a `blorgh` directory and inside that a file called `application_controller.rb`. This file will provide any common functionality for the controllers of the engine. The `blorgh` directory is where the other controllers for the engine will go. By placing them within this namespaced directory, you prevent them from possibly clashing with identically-named controllers within other engines or even within the application.

NOTE: The `ApplicationController` class inside an engine is named just like a Rails application in order to make it easier for you to convert your applications into engines.

Lastly, the `app/views` directory contains a `layouts` folder which contains a file at `blorgh/application.html.erb` which allows you to specify a layout for the engine. If this engine is to be used as a stand-alone engine, then you would add any customization to its layout in this file, rather than the application's `app/views/layouts/application.html.erb` file.

If you don't want to force a layout on to users of the engine, then you can delete this file and reference a different layout in the controllers of your engine.

#### `bin` directory

This directory contains one file, `bin/rails`, which enables you to use the `rails` sub-commands and generators just like you would within an application. This means that you will very easily be able to generate new controllers and models for this engine by running commands like this:

```bash
rails g model
```

Keeping in mind, of course, that anything generated with these commands inside an engine that has `isolate_namespace` inside the `Engine` class will be namespaced.

#### `test` directory

The `test` directory is where tests for the engine will go. To test the engine, there is a cut-down version of a Rails application embedded within it at `test/dummy`. This application will mount the engine in the `test/dummy/config/routes.rb` file:

```ruby
Rails.application.routes.draw do
  mount Blorgh::Engine => "/blorgh"
end
```

This line mounts the engine at the path `/blorgh`, which will make it accessible through the application only at that path.

In the test directory there is the `test/integration` directory, where integration tests for the engine should be placed. Other directories can be created in the `test` directory as well. For example, you may wish to create a `test/models` directory for your models tests.

Providing engine functionality
------------------------------

The engine that this guide covers provides posting and commenting functionality and follows a similar thread to the [Getting Started Guide](getting_started.html), with some new twists.

### Generating a post resource

The first thing to generate for a blog engine is the `Post` model and related controller. To quickly generate this, you can use the Rails scaffold generator.

```bash
$ rails generate scaffold post title:string text:text
```

This command will output this information:

```
invoke  active_record
create    db/migrate/[timestamp]_create_blorgh_posts.rb
create    app/models/blorgh/post.rb
invoke    test_unit
create      test/models/blorgh/post_test.rb
create      test/fixtures/blorgh/posts.yml
 route  resources :posts
invoke  scaffold_controller
create    app/controllers/blorgh/posts_controller.rb
invoke    erb
create      app/views/blorgh/posts
create      app/views/blorgh/posts/index.html.erb
create      app/views/blorgh/posts/edit.html.erb
create      app/views/blorgh/posts/show.html.erb
create      app/views/blorgh/posts/new.html.erb
create      app/views/blorgh/posts/_form.html.erb
invoke    test_unit
create      test/controllers/blorgh/posts_controller_test.rb
invoke    helper
create      app/helpers/blorgh/posts_helper.rb
invoke      test_unit
create        test/helpers/blorgh/posts_helper_test.rb
invoke  assets
invoke    js
create      app/assets/javascripts/blorgh/posts.js
invoke    css
create      app/assets/stylesheets/blorgh/posts.css
invoke  css
create    app/assets/stylesheets/scaffold.css
```

The first thing that the scaffold generator does is invoke the `active_record` generator, which generates a migration and a model for the resource. Note here, however, that the migration is called `create_blorgh_posts` rather than the usual `create_posts`. This is due to the `isolate_namespace` method called in the `Blorgh::Engine` class's definition. The model here is also namespaced, being placed at `app/models/blorgh/post.rb` rather than `app/models/post.rb` due to the `isolate_namespace` call within the `Engine` class.

Next, the `test_unit` generator is invoked for this model, generating a model test at `test/models/blorgh/post_test.rb` (rather than `test/models/post_test.rb`) and a fixture at `test/fixtures/blorgh/posts.yml` (rather than `test/fixtures/posts.yml`).

After that, a line for the resource is inserted into the `config/routes.rb` file for the engine. This line is simply `resources :posts`, turning the `config/routes.rb` file for the engine into this:

```ruby
Blorgh::Engine.routes.draw do
  resources :posts
end
```

Note here that the routes are drawn upon the `Blorgh::Engine` object rather than the `YourApp::Application` class. This is so that the engine routes are confined to the engine itself and can be mounted at a specific point as shown in the [test directory](#test-directory) section. It also causes the engine's routes to be isolated from those routes that are within the application. The [Routes](#routes) section of
this guide describes it in details.

Next, the `scaffold_controller` generator is invoked, generating a controller called `Blorgh::PostsController` (at `app/controllers/blorgh/posts_controller.rb`) and its related views at `app/views/blorgh/posts`. This generator also generates a test for the controller (`test/controllers/blorgh/posts_controller_test.rb`) and a helper (`app/helpers/blorgh/posts_controller.rb`).

Everything this generator has created is neatly namespaced. The controller's class is defined within the `Blorgh` module:

```ruby
module Blorgh
  class PostsController < ApplicationController
    ...
  end
end
```

NOTE: The `ApplicationController` class being inherited from here is the `Blorgh::ApplicationController`, not an application's `ApplicationController`.

The helper inside `app/helpers/blorgh/posts_helper.rb` is also namespaced:

```ruby
module Blorgh
  class PostsHelper
    ...
  end
end
```

This helps prevent conflicts with any other engine or application that may have a post resource as well.

Finally, two files that are the assets for this resource are generated, `app/assets/javascripts/blorgh/posts.js` and `app/assets/stylesheets/blorgh/posts.css`. You'll see how to use these a little later.

By default, the scaffold styling is not applied to the engine as the engine's layout file, `app/views/layouts/blorgh/application.html.erb` doesn't load it. To make this apply, insert this line into the `<head>` tag of this layout:

```erb
<%= stylesheet_link_tag "scaffold" %>
```

You can see what the engine has so far by running `rake db:migrate` at the root of our engine to run the migration generated by the scaffold generator, and then running `rails server` in `test/dummy`. When you open `http://localhost:3000/blorgh/posts` you will see the default scaffold that has been generated. Click around! You've just generated your first engine's first functions.

If you'd rather play around in the console, `rails console` will also work just like a Rails application. Remember: the `Post` model is namespaced, so to reference it you must call it as `Blorgh::Post`.

```ruby
>> Blorgh::Post.find(1)
=> #<Blorgh::Post id: 1 ...>
```

One final thing is that the `posts` resource for this engine should be the root of the engine. Whenever someone goes to the root path where the engine is mounted, they should be shown a list of posts. This can be made to happen if this line is inserted into the `config/routes.rb` file inside the engine:

```ruby
root to: "posts#index"
```

Now people will only need to go to the root of the engine to see all the posts, rather than visiting `/posts`. This means that instead of `http://localhost:3000/blorgh/posts`, you only need to go to `http://localhost:3000/blorgh` now.

### Generating a comments resource

Now that the engine can create new blog posts, it only makes sense to add commenting functionality as well. To do this, you'll need to generate a comment model, a comment controller and then modify the posts scaffold to display comments and allow people to create new ones.

Run the model generator and tell it to generate a `Comment` model, with the related table having two columns: a `post_id` integer and `text` text column.

```bash
$ rails generate model Comment post_id:integer text:text
```

This will output the following:

```
invoke  active_record
create    db/migrate/[timestamp]_create_blorgh_comments.rb
create    app/models/blorgh/comment.rb
invoke    test_unit
create      test/models/blorgh/comment_test.rb
create      test/fixtures/blorgh/comments.yml
```

This generator call will generate just the necessary model files it needs, namespacing the files under a `blorgh` directory and creating a model class called `Blorgh::Comment`.

To show the comments on a post, edit `app/views/blorgh/posts/show.html.erb` and add this line before the "Edit" link:

```html+erb
<h3>Comments</h3>
<%= render @post.comments %>
```

This line will require there to be a `has_many` association for comments defined on the `Blorgh::Post` model, which there isn't right now. To define one, open `app/models/blorgh/post.rb` and add this line into the model:

```ruby
has_many :comments
```

Turning the model into this:

```ruby
module Blorgh
  class Post < ActiveRecord::Base
    has_many :comments
  end
end
```

NOTE: Because the `has_many` is defined inside a class that is inside the `Blorgh` module, Rails will know that you want to use the `Blorgh::Comment` model for these objects, so there's no need to specify that using the `:class_name` option here.

Next, there needs to be a form so that comments can be created on a post. To add this, put this line underneath the call to `render @post.comments` in `app/views/blorgh/posts/show.html.erb`:

```erb
<%= render "blorgh/comments/form" %>
```

Next, the partial that this line will render needs to exist. Create a new directory at `app/views/blorgh/comments` and in it a new file called `_form.html.erb` which has this content to create the required partial:

```html+erb
<h3>New comment</h3>
<%= form_for [@post, @post.comments.build] do |f| %>
  <p>
    <%= f.label :text %><br />
    <%= f.text_area :text %>
  </p>
  <%= f.submit %>
<% end %>
```

When this form is submitted, it is going to attempt to perform a `POST` request to a route of `/posts/:post_id/comments` within the engine. This route doesn't exist at the moment, but can be created by changing the `resources :posts` line inside `config/routes.rb` into these lines:

```ruby
resources :posts do
  resources :comments
end
```

This creates a nested route for the comments, which is what the form requires.

The route now exists, but the controller that this route goes to does not. To create it, run this command:

```bash
$ rails g controller comments
```

This will generate the following things:

```
create  app/controllers/blorgh/comments_controller.rb
invoke  erb
 exist    app/views/blorgh/comments
invoke  test_unit
create    test/controllers/blorgh/comments_controller_test.rb
invoke  helper
create    app/helpers/blorgh/comments_helper.rb
invoke    test_unit
create      test/helpers/blorgh/comments_helper_test.rb
invoke  assets
invoke    js
create      app/assets/javascripts/blorgh/comments.js
invoke    css
create      app/assets/stylesheets/blorgh/comments.css
```

The form will be making a `POST` request to `/posts/:post_id/comments`, which will correspond with the `create` action in `Blorgh::CommentsController`. This action needs to be created and can be done by putting the following lines inside the class definition in `app/controllers/blorgh/comments_controller.rb`:

```ruby
def create
  @post = Post.find(params[:post_id])
  @comment = @post.comments.create(params[:comment])
  flash[:notice] = "Comment has been created!"
  redirect_to posts_path
end
```

This is the final part required to get the new comment form working. Displaying the comments however, is not quite right yet. If you were to create a comment right now you would see this error:

```
Missing partial blorgh/comments/comment with {:handlers=>[:erb, :builder], :formats=>[:html], :locale=>[:en, :en]}. Searched in:
  * "/Users/ryan/Sites/side_projects/blorgh/test/dummy/app/views"
  * "/Users/ryan/Sites/side_projects/blorgh/app/views"
```

The engine is unable to find the partial required for rendering the comments. Rails looks first in the application's (`test/dummy`) `app/views` directory and then in the engine's `app/views` directory. When it can't find it, it will throw this error. The engine knows to look for `blorgh/comments/comment` because the model object it is receiving is from the `Blorgh::Comment` class.

This partial will be responsible for rendering just the comment text, for now. Create a new file at `app/views/blorgh/comments/_comment.html.erb` and put this line inside it:

```erb
<%= comment_counter + 1 %>. <%= comment.text %>
```

The `comment_counter` local variable is given to us by the `<%= render @post.comments %>` call, as it will define this automatically and increment the counter as it iterates through each comment. It's used in this example to display a small number next to each comment when it's created.

That completes the comment function of the blogging engine. Now it's time to use it within an application.

Hooking into an application
---------------------------

Using an engine within an application is very easy. This section covers how to mount the engine into an application and the initial setup required, as well as linking the engine to a `User` class provided by the application to provide ownership for posts and comments within the engine.

### Mounting the engine

First, the engine needs to be specified inside the application's `Gemfile`. If there isn't an application handy to test this out in, generate one using the `rails new` command outside of the engine directory like this:

```bash
$ rails new unicorn
```

Usually, specifying the engine inside the Gemfile would be done by specifying it as a normal, everyday gem.

```ruby
gem 'devise'
```

However, because you are developing the `blorgh` engine on your local machine, you will need to specify the `:path` option in your `Gemfile`:

```ruby
gem 'blorgh', path: "/path/to/blorgh"
```

As described earlier, by placing the gem in the `Gemfile` it will be loaded when Rails is loaded, as it will first require `lib/blorgh.rb` in the engine and then `lib/blorgh/engine.rb`, which is the file that defines the major pieces of functionality for the engine.

To make the engine's functionality accessible from within an application, it needs to be mounted in that application's `config/routes.rb` file:

```ruby
mount Blorgh::Engine, at: "/blog"
```

This line will mount the engine at `/blog` in the application. Making it accessible at `http://localhost:3000/blog` when the application runs with `rails server`.

NOTE: Other engines, such as Devise, handle this a little differently by making you specify custom helpers such as `devise_for` in the routes. These helpers do exactly the same thing, mounting pieces of the engines's functionality at a pre-defined path which may be customizable.

### Engine setup

The engine contains migrations for the `blorgh_posts` and `blorgh_comments` table which need to be created in the application's database so that the engine's models can query them correctly. To copy these migrations into the application use this command:

```bash
$ rake blorgh:install:migrations
```

If you have multiple engines that need migrations copied over, use `railties:install:migrations` instead:

```bash
$ rake railties:install:migrations
```

This command, when run for the first time, will copy over all the migrations from the engine. When run the next time, it will only copy over migrations that haven't been copied over already. The first run for this command will output something such as this:

```bash
Copied migration [timestamp_1]_create_blorgh_posts.rb from blorgh
Copied migration [timestamp_2]_create_blorgh_comments.rb from blorgh
```

The first timestamp (`[timestamp_1]`) will be the current time and the second timestamp (`[timestamp_2]`) will be the current time plus a second. The reason for this is so that the migrations for the engine are run after any existing migrations in the application.

To run these migrations within the context of the application, simply run `rake db:migrate`. When accessing the engine through `http://localhost:3000/blog`, the posts will be empty. This is because the table created inside the application is different from the one created within the engine. Go ahead, play around with the newly mounted engine. You'll find that it's the same as when it was only an engine.

If you would like to run migrations only from one engine, you can do it by specifying `SCOPE`:

```bash
rake db:migrate SCOPE=blorgh
```

This may be useful if you want to revert engine's migrations before removing it. In order to revert all migrations from blorgh engine you can run such code:

```bash
rake db:migrate SCOPE=blorgh VERSION=0
```

### Using a class provided by the application

#### Using a model provided by the application

When an engine is created, it may want to use specific classes from an application to provide links between the pieces of the engine and the pieces of the application. In the case of the `blorgh` engine, making posts and comments have authors would make a lot of sense.

A typical application might have a `User` class that would be used to represent authors for a post or a comment. But there could be a case where the application calls this class something different, such as `Person`. For this reason, the engine should not hardcode associations specifically for a `User` class.

To keep it simple in this case, the application will have a class called `User` which will represent the users of the application. It can be generated using this command inside the application:

```bash
rails g model user name:string
```

The `rake db:migrate` command needs to be run here to ensure that our application has the `users` table for future use.

Also, to keep it simple, the posts form will have a new text field called `author_name` where users can elect to put their name. The engine will then take this name and create a new `User` object from it or find one that already has that name, and then associate the post with it.

First, the `author_name` text field needs to be added to the `app/views/blorgh/posts/_form.html.erb` partial inside the engine. This can be added above the `title` field with this code:

```html+erb
<div class="field">
  <%= f.label :author_name %><br />
  <%= f.text_field :author_name %>
</div>
```

The `Blorgh::Post` model should then have some code to convert the `author_name` field into an actual `User` object and associate it as that post's `author` before the post is saved. It will also need to have an `attr_accessor` setup for this field so that the setter and getter methods are defined for it.

To do all this, you'll need to add the `attr_accessor` for `author_name`, the association for the author and the `before_save` call into `app/models/blorgh/post.rb`. The `author` association will be hard-coded to the `User` class for the time being.

```ruby
attr_accessor :author_name
belongs_to :author, class_name: "User"

before_save :set_author

private
  def set_author
    self.author = User.find_or_create_by(name: author_name)
  end
```

By defining that the `author` association's object is represented by the `User` class a link is established between the engine and the application. There needs to be a way of associating the records in the `blorgh_posts` table with the records in the `users` table. Because the association is called `author`, there should be an `author_id` column added to the `blorgh_posts` table.

To generate this new column, run this command within the engine:

```bash
$ rails g migration add_author_id_to_blorgh_posts author_id:integer
```

NOTE: Due to the migration's name and the column specification after it, Rails will automatically know that you want to add a column to a specific table and write that into the migration for you. You don't need to tell it any more than this.

This migration will need to be run on the application. To do that, it must first be copied using this command:

```bash
$ rake blorgh:install:migrations
```

Notice here that only _one_ migration was copied over here. This is because the first two migrations were copied over the first time this command was run.

```
NOTE Migration [timestamp]_create_blorgh_posts.rb from blorgh has been skipped. Migration with the same name already exists.
NOTE Migration [timestamp]_create_blorgh_comments.rb from blorgh has been skipped. Migration with the same name already exists.
Copied migration [timestamp]_add_author_id_to_blorgh_posts.rb from blorgh
```

Run this migration using this command:

```bash
$ rake db:migrate
```

Now with all the pieces in place, an action will take place that will associate an author — represented by a record in the `users` table — with a post, represented by the `blorgh_posts` table from the engine.

Finally, the author's name should be displayed on the post's page. Add this code above the "Title" output inside `app/views/blorgh/posts/show.html.erb`:

```html+erb
<p>
  <b>Author:</b>
  <%= @post.author %>
</p>
```

By outputting `@post.author` using the `<%=` tag, the `to_s` method will be called on the object. By default, this will look quite ugly:

```
#<User:0x00000100ccb3b0>
```

This is undesirable and it would be much better to have the user's name there. To do this, add a `to_s` method to the `User` class within the application:

```ruby
def to_s
  name
end
```

Now instead of the ugly Ruby object output the author's name will be displayed.

#### Using a controller provided by the application

Because Rails controllers generally share code for things like authentication and accessing session variables, by default they inherit from `ApplicationController`. Rails engines, however are scoped to run independently from the main application, so each engine gets a scoped `ApplicationController`. This namespace prevents code collisions, but often engine controllers should access methods in the main application's `ApplicationController`. An easy way to provide this access is to change the engine's scoped `ApplicationController` to inherit from the main application's `ApplicationController`. For our Blorgh engine this would be done by changing `app/controllers/blorgh/application_controller.rb` to look like:

```ruby
class Blorgh::ApplicationController < ApplicationController
end
```

By default, the engine's controllers inherit from `Blorgh::ApplicationController`. So, after making this change they will have access to the main applications `ApplicationController` as though they were part of the main application.

This change does require that the engine is run from a Rails application that has an `ApplicationController`.

### Configuring an engine

This section covers how to make the `User` class configurable, followed by general configuration tips for the engine.

#### Setting configuration settings in the application

The next step is to make the class that represents a `User` in the application customizable for the engine. This is because, as explained before, that class may not always be `User`. To make this customizable, the engine will have a configuration setting called `user_class` that will be used to specify what the class representing users is inside the application.

To define this configuration setting, you should use a `mattr_accessor` inside the `Blorgh` module for the engine, located at `lib/blorgh.rb` inside the engine. Inside this module, put this line:

```ruby
mattr_accessor :user_class
```

This method works like its brothers `attr_accessor` and `cattr_accessor`, but provides a setter and getter method on the module with the specified name. To use it, it must be referenced using `Blorgh.user_class`.

The next step is switching the `Blorgh::Post` model over to this new setting. For the `belongs_to` association inside this model (`app/models/blorgh/post.rb`), it will now become this:

```ruby
belongs_to :author, class_name: Blorgh.user_class
```

The `set_author` method also located in this class should also use this class:

```ruby
self.author = Blorgh.user_class.constantize.find_or_create_by(name: author_name)
```

To save having to call `constantize` on the `user_class` result all the time, you could instead just override the `user_class` getter method inside the `Blorgh` module in the `lib/blorgh.rb` file to always call `constantize` on the saved value before returning the result:

```ruby
def self.user_class
  @@user_class.constantize
end
```

This would then turn the above code for `set_author` into this:

```ruby
self.author = Blorgh.user_class.find_or_create_by(name: author_name)
```

Resulting in something a little shorter, and more implicit in its behavior. The `user_class` method should always return a `Class` object.

Since we changed the `user_class` method to no longer return a
`String` but a `Class` we must also modify our `belongs_to` definition
in the `Blorgh::Post` model:

```ruby
belongs_to :author, class_name: Blorgh.user_class.to_s
```

To set this configuration setting within the application, an initializer should be used. By using an initializer, the configuration will be set up before the application starts and calls the engine's models which may depend on this configuration setting existing.

Create a new initializer at `config/initializers/blorgh.rb` inside the application where the `blorgh` engine is installed and put this content in it:

```ruby
Blorgh.user_class = "User"
```

WARNING: It's very important here to use the `String` version of the class, rather than the class itself. If you were to use the class, Rails would attempt to load that class and then reference the related table, which could lead to problems if the table wasn't already existing. Therefore, a `String` should be used and then converted to a class using `constantize` in the engine later on.

Go ahead and try to create a new post. You will see that it works exactly in the same way as before, except this time the engine is using the configuration setting in `config/initializers/blorgh.rb` to learn what the class is.

There are now no strict dependencies on what the class is, only what the API for the class must be. The engine simply requires this class to define a `find_or_create_by` method which returns an object of that class to be associated with a post when it's created. This object, of course, should have some sort of identifier by which it can be referenced.

#### General engine configuration

Within an engine, there may come a time where you wish to use things such as initializers, internationalization or other configuration options. The great news is that these things are entirely possible because a Rails engine shares much the same functionality as a Rails application. In fact, a Rails application's functionality is actually a superset of what is provided by engines!

If you wish to use an initializer — code that should run before the engine is loaded — the place for it is the `config/initializers` folder. This directory's functionality is explained in the [Initializers section](http://guides.rubyonrails.org/configuring.html#initializers) of the Configuring guide, and works precisely the same way as the `config/initializers` directory inside an application. Same goes for if you want to use a standard initializer.

For locales, simply place the locale files in the `config/locales` directory, just like you would in an application.

Testing an engine
-----------------

When an engine is generated there is a smaller dummy application created inside it at `test/dummy`. This application is used as a mounting point for the engine to make testing the engine extremely simple. You may extend this application by generating controllers, models or views from within the directory, and then use those to test your engine.

The `test` directory should be treated like a typical Rails testing environment, allowing for unit, functional and integration tests.

### Functional tests

A matter worth taking into consideration when writing functional tests is that the tests are going to be running on an application — the `test/dummy` application — rather than your engine. This is due to the setup of the testing environment; an engine needs an application as a host for testing its main functionality, especially controllers. This means that if you were to make a typical `GET` to a controller in a controller's functional test like this:

```ruby
get :index
```

It may not function correctly. This is because the application doesn't know how to route these requests to the engine unless you explicitly tell it **how**. To do this, you must pass the `:use_route` option (as a parameter) on these requests also:

```ruby
get :index, use_route: :blorgh
```

This tells the application that you still want to perform a `GET` request to the `index` action of this controller, just that you want to use the engine's route to get there, rather than the application.

Improving engine functionality
------------------------------

This section explains how to add and/or override engine MVC functionality in the main Rails application.

### Overriding Models and Controllers

Engine model and controller classes can be extended by open classing them in the main Rails application (since model and controller classes are just Ruby classes that inherit Rails specific functionality). Open classing an Engine class redefines it for use in the main application. This is usually implemented by using the decorator pattern.

For simple class modifications use `Class#class_eval`, and for complex class modifications, consider using `ActiveSupport::Concern`.

#### Implementing Decorator Pattern Using Class#class_eval

**Adding** `Post#time_since_created`,

```ruby
# MyApp/app/decorators/models/blorgh/post_decorator.rb

Blorgh::Post.class_eval do
  def time_since_created
    Time.current - created_at
  end
end
```

```ruby
# Blorgh/app/models/post.rb

class Post < ActiveRecord::Base
  has_many :comments
end
```


**Overriding** `Post#summary`

```ruby
# MyApp/app/decorators/models/blorgh/post_decorator.rb

Blorgh::Post.class_eval do
  def summary
    "#{title} - #{truncate(text)}"
  end
end
```

```ruby
# Blorgh/app/models/post.rb

class Post < ActiveRecord::Base
  has_many :comments
  def summary
    "#{title}"
  end
end
```

#### Implementing Decorator Pattern Using ActiveSupport::Concern

Using `Class#class_eval` is great for simple adjustments, but for more complex class modifications, you might want to consider using [`ActiveSupport::Concern`](http://edgeapi.rubyonrails.org/classes/ActiveSupport/Concern.html). ActiveSupport::Concern manages load order of interlinked dependent modules and classes at run time allowing you to significantly modularize your code.

**Adding** `Post#time_since_created` and **Overriding** `Post#summary`

```ruby
# MyApp/app/models/blorgh/post.rb

class Blorgh::Post < ActiveRecord::Base
  include Blorgh::Concerns::Models::Post

  def time_since_created
    Time.current - created_at
  end

  def summary
    "#{title} - #{truncate(text)}"
  end
end
```

```ruby
# Blorgh/app/models/post.rb

class Post < ActiveRecord::Base
  include Blorgh::Concerns::Models::Post
end
```

```ruby
# Blorgh/lib/concerns/models/post

module Blorgh::Concerns::Models::Post
  extend ActiveSupport::Concern

  # 'included do' causes the included code to be evaluated in the
  # context where it is included (post.rb), rather than be
  # executed in the module's context (blorgh/concerns/models/post).
  included do
    attr_accessor :author_name
    belongs_to :author, class_name: "User"

    before_save :set_author

    private

      def set_author
        self.author = User.find_or_create_by(name: author_name)
      end
  end

  def summary
    "#{title}"
  end

  module ClassMethods
    def some_class_method
      'some class method string'
    end
  end
end
```

### Overriding views

When Rails looks for a view to render, it will first look in the `app/views` directory of the application. If it cannot find the view there, then it will check in the `app/views` directories of all engines which have this directory.

In the `blorgh` engine, there is a currently a file at `app/views/blorgh/posts/index.html.erb`. When the engine is asked to render the view for `Blorgh::PostsController`'s `index` action, it will first see if it can find it at `app/views/blorgh/posts/index.html.erb` within the application and then if it cannot it will look inside the engine.

You can override this view in the application by simply creating a new file at `app/views/blorgh/posts/index.html.erb`. Then you can completely change what this view would normally output.

Try this now by creating a new file at `app/views/blorgh/posts/index.html.erb` and put this content in it:

```html+erb
<h1>Posts</h1>
<%= link_to "New Post", new_post_path %>
<% @posts.each do |post| %>
  <h2><%= post.title %></h2>
  <small>By <%= post.author %></small>
  <%= simple_format(post.text) %>
  <hr>
<% end %>
```

### Routes

Routes inside an engine are, by default, isolated from the application. This is done by the `isolate_namespace` call inside the `Engine` class. This essentially means that the application and its engines can have identically named routes and they will not clash.

Routes inside an engine are drawn on the `Engine` class within `config/routes.rb`, like this:

```ruby
Blorgh::Engine.routes.draw do
  resources :posts
end
```

By having isolated routes such as this, if you wish to link to an area of an engine from within an application, you will need to use the engine's routing proxy method. Calls to normal routing methods such as `posts_path` may end up going to undesired locations if both the application and the engine both have such a helper defined.

For instance, the following example would go to the application's `posts_path` if that template was rendered from the application, or the engine's `posts_path` if it was rendered from the engine:

```erb
<%= link_to "Blog posts", posts_path %>
```

To make this route always use the engine's `posts_path` routing helper method, we must call the method on the routing proxy method that shares the same name as the engine.

```erb
<%= link_to "Blog posts", blorgh.posts_path %>
```

If you wish to reference the application inside the engine in a similar way, use the `main_app` helper:

```erb
<%= link_to "Home", main_app.root_path %>
```

If you were to use this inside an engine, it would **always** go to the application's root. If you were to leave off the `main_app` "routing proxy" method call, it could potentially go to the engine's or application's root, depending on where it was called from.

If a template is rendered from within an engine and it's attempting to use one of the application's routing helper methods, it may result in an undefined method call. If you encounter such an issue, ensure that you're not attempting to call the application's routing methods without the `main_app` prefix from within the engine.

### Assets

Assets within an engine work in an identical way to a full application. Because the engine class inherits from `Rails::Engine`, the application will know to look up in the engine's `app/assets` and `lib/assets` directories for potential assets.

Much like all the other components of an engine, the assets should also be namespaced. This means if you have an asset called `style.css`, it should be placed at `app/assets/stylesheets/[engine name]/style.css`, rather than `app/assets/stylesheets/style.css`. If this asset wasn't namespaced, then there is a possibility that the host application could have an asset named identically, in which case the application's asset would take precedence and the engine's one would be all but ignored.

Imagine that you did have an asset located at `app/assets/stylesheets/blorgh/style.css` To include this asset inside an application, just use `stylesheet_link_tag` and reference the asset as if it were inside the engine:

```erb
<%= stylesheet_link_tag "blorgh/style.css" %>
```

You can also specify these assets as dependencies of other assets using the Asset Pipeline require statements in processed files:

```
/*
 *= require blorgh/style
*/
```

INFO. Remember that in order to use languages like Sass or CoffeeScript, you should add the relevant library to your engine's `.gemspec`.

### Separate Assets & Precompiling

There are some situations where your engine's assets are not required by the host application. For example, say that you've created
an admin functionality that only exists for your engine. In this case, the host application doesn't need to require `admin.css`
or `admin.js`. Only the gem's admin layout needs these assets. It doesn't make sense for the host app to include `"blorg/admin.css"` in it's stylesheets. In this situation, you should explicitly define these assets for precompilation.
This tells sprockets to add your engine assets when `rake assets:precompile` is ran.

You can define assets for precompilation in `engine.rb`

```ruby
initializer "blorgh.assets.precompile" do |app|
  app.config.assets.precompile += %w(admin.css admin.js)
end
```

For more information, read the [Asset Pipeline guide](http://guides.rubyonrails.org/asset_pipeline.html)

### Other gem dependencies

Gem dependencies inside an engine should be specified inside the
`.gemspec` file at the root of the engine. The reason is that the engine may
be installed as a gem. If dependencies were to be specified inside the `Gemfile`,
these would not be recognized by a traditional gem install and so they would not
be installed, causing the engine to malfunction.

To specify a dependency that should be installed with the engine during a
traditional `gem install`, specify it inside the `Gem::Specification` block
inside the `.gemspec` file in the engine:

```ruby
s.add_dependency "moo"
```

To specify a dependency that should only be installed as a development
dependency of the application, specify it like this:

```ruby
s.add_development_dependency "moo"
```

Both kinds of dependencies will be installed when `bundle install` is run inside
the application. The development dependencies for the gem will only be used when
the tests for the engine are running.

Note that if you want to immediately require dependencies when the engine is
required, you should require them before the engine's initialization. For example:

```ruby
require 'other_engine/engine'
require 'yet_another_engine/engine'

module MyEngine
  class Engine < ::Rails::Engine
  end
end
```
