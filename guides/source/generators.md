**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Creating and Customizing Rails Generators & Templates
=====================================================

Rails generators are an essential tool for improving your workflow. With this
guide you will learn how to create generators and customize existing ones.

After reading this guide, you will know:

* How to see which generators are available in your application.
* How to create a generator using templates.
* How Rails searches for generators before invoking them.
* How to customize your scaffold by overriding generator templates.
* How to customize your scaffold by overriding generators.
* How to use fallbacks to avoid overwriting a huge set of generators.
* How to create an application template.

--------------------------------------------------------------------------------

First Contact
-------------

When you create an application using the `rails` command, you are in fact using
a Rails generator. After that, you can get a list of all available generators by
invoking `bin/rails generate`:

```bash
$ rails new myapp
$ cd myapp
$ bin/rails generate
```

NOTE: To create a Rails application we use the `rails` global command which uses
the version of Rails installed via `gem install rails`. When inside the
directory of your application, we use the `bin/rails` command which uses the
version of Rails bundled with the application.

You will get a list of all generators that come with Rails. To see a detailed
description of a particular generator, invoke the generator with the `--help`
option. For example:

```bash
$ bin/rails generate scaffold --help
```

Creating Your First Generator
-----------------------------

Generators are built on top of [Thor](https://github.com/rails/thor), which
provides powerful options for parsing and a great API for manipulating files.

Let's build a generator that creates an initializer file named `initializer.rb`
inside `config/initializers`. The first step is to create a file at
`lib/generators/initializer_generator.rb` with the following content:

```ruby
class InitializerGenerator < Rails::Generators::Base
  def create_initializer_file
    create_file "config/initializers/initializer.rb", <<~RUBY
      # Add initialization content here
    RUBY
  end
end
```

Our new generator is quite simple: it inherits from [`Rails::Generators::Base`][]
and has one method definition. When a generator is invoked, each public method
in the generator is executed sequentially in the order that it is defined. Our
method invokes [`create_file`][], which will create a file at the given
destination with the given content.

To invoke our new generator, we run:

```bash
$ bin/rails generate initializer
```

Before we go on, let's see the description of our new generator:

```bash
$ bin/rails generate initializer --help
```

Rails is usually able to derive a good description if a generator is namespaced,
such as `ActiveRecord::Generators::ModelGenerator`, but not in this case. We can
solve this problem in two ways. The first way to add a description is by calling
[`desc`][] inside our generator:

```ruby
class InitializerGenerator < Rails::Generators::Base
  desc "This generator creates an initializer file at config/initializers"
  def create_initializer_file
    create_file "config/initializers/initializer.rb", <<~RUBY
      # Add initialization content here
    RUBY
  end
end
```

Now we can see the new description by invoking `--help` on the new generator.

The second way to add a description is by creating a file named `USAGE` in the
same directory as our generator. We are going to do that in the next step.

[`Rails::Generators::Base`]: https://api.rubyonrails.org/classes/Rails/Generators/Base.html
[`Thor::Actions`]: https://www.rubydoc.info/gems/thor/Thor/Actions
[`create_file`]: https://www.rubydoc.info/gems/thor/Thor/Actions#create_file-instance_method
[`desc`]: https://www.rubydoc.info/gems/thor/Thor#desc-class_method

Creating Generators with Generators
-----------------------------------

Generators themselves have a generator. Let's remove our `InitializerGenerator`
and use `bin/rails generate generator` to generate a new one:

```bash
$ rm lib/generators/initializer_generator.rb

$ bin/rails generate generator initializer
      create  lib/generators/initializer
      create  lib/generators/initializer/initializer_generator.rb
      create  lib/generators/initializer/USAGE
      create  lib/generators/initializer/templates
      invoke  test_unit
      create    test/lib/generators/initializer_generator_test.rb
```

This is the generator just created:

```ruby
class InitializerGenerator < Rails::Generators::NamedBase
  source_root File.expand_path("templates", __dir__)
end
```

First, notice that the generator inherits from [`Rails::Generators::NamedBase`][]
instead of `Rails::Generators::Base`. This means that our generator expects at
least one argument, which will be the name of the initializer and will be
available to our code via `name`.

We can see that by checking the description of the new generator:

```bash
$ bin/rails generate initializer --help
Usage:
  bin/rails generate initializer NAME [options]
```

Also, notice that the generator has a class method called [`source_root`][].
This method points to the location of our templates, if any. By default it
points to the `lib/generators/initializer/templates` directory that was just
created.

In order to understand how generator templates work, let's create the file
`lib/generators/initializer/templates/initializer.rb` with the following
content:

```ruby
# Add initialization content here
```

And let's change the generator to copy this template when invoked:

```ruby
class InitializerGenerator < Rails::Generators::NamedBase
  source_root File.expand_path("templates", __dir__)

  def copy_initializer_file
    copy_file "initializer.rb", "config/initializers/#{file_name}.rb"
  end
end
```

Now let's run our generator:

```bash
$ bin/rails generate initializer core_extensions
      create  config/initializers/core_extensions.rb

$ cat config/initializers/core_extensions.rb
# Add initialization content here
```

We see that [`copy_file`][] created `config/initializers/core_extensions.rb`
with the contents of our template. (The `file_name` method used in the
destination path is inherited from `Rails::Generators::NamedBase`.)

[`Rails::Generators::NamedBase`]: https://api.rubyonrails.org/classes/Rails/Generators/NamedBase.html
[`copy_file`]: https://www.rubydoc.info/gems/thor/Thor/Actions#copy_file-instance_method
[`source_root`]: https://api.rubyonrails.org/classes/Rails/Generators/Base.html#method-c-source_root

Generator Command Line Options
------------------------------

Generators can support command line options using [`class_option`][]. For
example:

```ruby
class InitializerGenerator < Rails::Generators::NamedBase
  class_option :scope, type: :string, default: "app"
end
```

Now our generator can be invoked with a `--scope` option:

```bash
$ bin/rails generate initializer theme --scope dashboard
```

Option values are accessible in generator methods via [`options`][]:

```ruby
def copy_initializer_file
  @scope = options["scope"]
end
```

[`class_option`]: https://www.rubydoc.info/gems/thor/Thor/Base/ClassMethods#class_option-instance_method
[`options`]: https://www.rubydoc.info/gems/thor/Thor/Base#options-instance_method

Generator Resolution
--------------------

When resolving a generator's name, Rails looks for the generator using multiple
file names. For example, when you run `bin/rails generate initializer core_extensions`,
Rails tries to load each of the following files, in order, until one is found:

* `rails/generators/initializer/initializer_generator.rb`
* `generators/initializer/initializer_generator.rb`
* `rails/generators/initializer_generator.rb`
* `generators/initializer_generator.rb`

If none of these are found, an error will be raised.

We put our generator in the application's `lib/` directory because that
directory is in `$LOAD_PATH`, thus allowing Rails to find and load the file.

Overriding Rails Generator Templates
------------------------------------

Rails will also look in multiple places when resolving generator template files.
One of those places is the application's `lib/templates/` directory. This
behavior allows us to override the templates used by Rails' built-in generators.
For example, we could override the [scaffold controller template][] or the
[scaffold view templates][].

To see this in action, let's create a `lib/templates/erb/scaffold/index.html.erb.tt`
file with the following contents:

```erb
<%% @<%= plural_table_name %>.count %> <%= human_name.pluralize %>
```

Note that the template is an ERB template that renders _another_ ERB template.
So any `<%` that should appear in the _resulting_ template must be escaped as
`<%%` in the _generator_ template.

Now let's run Rails' built-in scaffold generator:

```bash
$ bin/rails generate scaffold Post title:string
      ...
      create      app/views/posts/index.html.erb
      ...
```

The contents of `app/views/posts/index.html.erb` is:

```erb
<% @posts.count %> Posts
```

[scaffold controller template]: https://github.com/rails/rails/blob/main/railties/lib/rails/generators/rails/scaffold_controller/templates/controller.rb.tt
[scaffold view templates]: https://github.com/rails/rails/tree/main/railties/lib/rails/generators/erb/scaffold/templates

Overriding Rails Generators
---------------------------

Rails' built-in generators can be configured via [`config.generators`][],
including overriding some generators entirely.

First, let's take a closer look at how the scaffold generator works.

```bash
$ bin/rails generate scaffold User name:string
      invoke  active_record
      create    db/migrate/20230518000000_create_users.rb
      create    app/models/user.rb
      invoke    test_unit
      create      test/models/user_test.rb
      create      test/fixtures/users.yml
      invoke  resource_route
       route    resources :users
      invoke  scaffold_controller
      create    app/controllers/users_controller.rb
      invoke    erb
      create      app/views/users
      create      app/views/users/index.html.erb
      create      app/views/users/edit.html.erb
      create      app/views/users/show.html.erb
      create      app/views/users/new.html.erb
      create      app/views/users/_form.html.erb
      create      app/views/users/_user.html.erb
      invoke    resource_route
      invoke    test_unit
      create      test/controllers/users_controller_test.rb
      create      test/system/users_test.rb
      invoke    helper
      create      app/helpers/users_helper.rb
      invoke      test_unit
      invoke    jbuilder
      create      app/views/users/index.json.jbuilder
      create      app/views/users/show.json.jbuilder
```

From the output, we can see that the scaffold generator invokes other
generators, such as the `scaffold_controller` generator. And some of those
generators invoke other generators too. In particular, the `scaffold_controller`
generator invokes several other generators, including the `helper` generator.

Let's override the built-in `helper` generator with a new generator. We'll name
the generator `my_helper`:

```bash
$ bin/rails generate generator rails/my_helper
      create  lib/generators/rails/my_helper
      create  lib/generators/rails/my_helper/my_helper_generator.rb
      create  lib/generators/rails/my_helper/USAGE
      create  lib/generators/rails/my_helper/templates
      invoke  test_unit
      create    test/lib/generators/rails/my_helper_generator_test.rb
```

And in `lib/generators/rails/my_helper/my_helper_generator.rb` we'll define
the generator as:

```ruby
class Rails::MyHelperGenerator < Rails::Generators::NamedBase
  def create_helper_file
    create_file "app/helpers/#{file_name}_helper.rb", <<~RUBY
      module #{class_name}Helper
        # I'm helping!
      end
    RUBY
  end
end
```

Finally, we need to tell Rails to use the `my_helper` generator instead of the
built-in `helper` generator. For that we use `config.generators`. In
`config/application.rb`, let's add:

```ruby
config.generators do |g|
  g.helper :my_helper
end
```

Now if we run the scaffold generator again, we see the `my_helper` generator in
action:

```bash
$ bin/rails generate scaffold Article body:text
      ...
      invoke  scaffold_controller
      ...
      invoke    my_helper
      create      app/helpers/articles_helper.rb
      ...
```

NOTE: You may notice that the output for the built-in `helper` generator
includes "invoke test_unit", whereas the output for `my_helper` does not.
Although the `helper` generator does not generate tests by default, it does
provide a hook to do so using [`hook_for`][]. We can do the same by including
`hook_for :test_framework, as: :helper` in the `MyHelperGenerator` class. See
the `hook_for` documentation for more information.

[`config.generators`]: configuring.html#configuring-generators
[`hook_for`]: https://api.rubyonrails.org/classes/Rails/Generators/Base.html#method-c-hook_for

### Generators Fallbacks

Another way to override specific generators is by using _fallbacks_. A fallback
allows a generator namespace to delegate to another generator namespace.

For example, let's say we want to override the `test_unit:model` generator with
our own `my_test_unit:model` generator, but we don't want to replace all of the
other `test_unit:*` generators such as `test_unit:controller`.

First, we create the `my_test_unit:model` generator in
`lib/generators/my_test_unit/model/model_generator.rb`:

```ruby
module MyTestUnit
  class ModelGenerator < Rails::Generators::NamedBase
    source_root File.expand_path("templates", __dir__)

    def do_different_stuff
      say "Doing different stuff..."
    end
  end
end
```

Next, we use `config.generators` to configure the `test_framework` generator as
`my_test_unit`, but we also configure a fallback such that any missing
`my_test_unit:*` generators resolve to `test_unit:*`:

```ruby
config.generators do |g|
  g.test_framework :my_test_unit, fixture: false
  g.fallbacks[:my_test_unit] = :test_unit
end
```

Now when we run the scaffold generator, we see that `my_test_unit` has replaced
`test_unit`, but only the model tests have been affected:

```bash
$ bin/rails generate scaffold Comment body:text
      invoke  active_record
      create    db/migrate/20230518000000_create_comments.rb
      create    app/models/comment.rb
      invoke    my_test_unit
    Doing different stuff...
      invoke  resource_route
       route    resources :comments
      invoke  scaffold_controller
      create    app/controllers/comments_controller.rb
      invoke    erb
      create      app/views/comments
      create      app/views/comments/index.html.erb
      create      app/views/comments/edit.html.erb
      create      app/views/comments/show.html.erb
      create      app/views/comments/new.html.erb
      create      app/views/comments/_form.html.erb
      create      app/views/comments/_comment.html.erb
      invoke    resource_route
      invoke    my_test_unit
      create      test/controllers/comments_controller_test.rb
      create      test/system/comments_test.rb
      invoke    helper
      create      app/helpers/comments_helper.rb
      invoke      my_test_unit
      invoke    jbuilder
      create      app/views/comments/index.json.jbuilder
      create      app/views/comments/show.json.jbuilder
```

Application Templates
---------------------

Application templates are a special kind of generator. They can use all of the
[generator helper methods](#generator-helper-methods), but are written as a Ruby
script instead of a Ruby class. Here is an example:

```ruby
# template.rb

if yes?("Would you like to install Devise?")
  gem "devise"
  devise_model = ask("What would you like the user model to be called?", default: "User")
end

after_bundle do
  if devise_model
    generate "devise:install"
    generate "devise", devise_model
    rails_command "db:migrate"
  end

  git add: ".", commit: %(-m 'Initial commit')
end
```

First, the template asks the user whether they would like to install Devise.
If the user replies "yes" (or "y"), the template adds Devise to the `Gemfile`,
and asks the user for the name of the Devise user model (defaulting to `User`).
Later, after `bundle install` has been run, the template will run the Devise
generators and `rails db:migrate` if a Devise model was specified. Finally, the
template will `git add` and `git commit` the entire app directory.

We can run our template when generating a new Rails application by passing the
`-m` option to the `rails new` command:

```bash
$ rails new my_cool_app -m path/to/template.rb
```

Alternatively, we can run our template inside an existing application with
`bin/rails app:template`:

```bash
$ bin/rails app:template LOCATION=path/to/template.rb
```

Templates also don't need to be stored locally — you can specify a URL instead
of a path:

```bash
$ rails new my_cool_app -m http://example.com/template.rb
$ bin/rails app:template LOCATION=http://example.com/template.rb
```

Generator Helper Methods
------------------------

Thor provides many generator helper methods via [`Thor::Actions`][], such as:

* [`copy_file`][]
* [`create_file`][]
* [`gsub_file`][]
* [`insert_into_file`][]
* [`inside`][]

In addition to those, Rails also provides many helper methods via
[`Rails::Generators::Actions`][], such as:

* [`environment`][]
* [`gem`][]
* [`generate`][]
* [`git`][]
* [`initializer`][]
* [`lib`][]
* [`rails_command`][]
* [`rake`][]
* [`route`][]

Testing Generators
------------------

Rails provides testing helper methods via
[`Rails::Generators::Testing::Behaviour`][], such as:

* [`run_generator`][]

If running tests against generators you will need to set
`RAILS_LOG_TO_STDOUT=true` in order for debugging tools to work.

```sh
RAILS_LOG_TO_STDOUT=true ./bin/test test/generators/actions_test.rb
```

In addition to those, Rails also provides additional assertions via
[`Rails::Generators::Testing::Assertions`][].

[`Rails::Generators::Actions`]: https://api.rubyonrails.org/classes/Rails/Generators/Actions.html
[`environment`]: https://api.rubyonrails.org/classes/Rails/Generators/Actions.html#method-i-environment
[`gem`]: https://api.rubyonrails.org/classes/Rails/Generators/Actions.html#method-i-gem
[`generate`]: https://api.rubyonrails.org/classes/Rails/Generators/Actions.html#method-i-generate
[`git`]: https://api.rubyonrails.org/classes/Rails/Generators/Actions.html#method-i-git
[`gsub_file`]: https://www.rubydoc.info/gems/thor/Thor/Actions#gsub_file-instance_method
[`initializer`]: https://api.rubyonrails.org/classes/Rails/Generators/Actions.html#method-i-initializer
[`insert_into_file`]: https://www.rubydoc.info/gems/thor/Thor/Actions#insert_into_file-instance_method
[`inside`]: https://www.rubydoc.info/gems/thor/Thor/Actions#inside-instance_method
[`lib`]: https://api.rubyonrails.org/classes/Rails/Generators/Actions.html#method-i-lib
[`rails_command`]: https://api.rubyonrails.org/classes/Rails/Generators/Actions.html#method-i-rails_command
[`rake`]: https://api.rubyonrails.org/classes/Rails/Generators/Actions.html#method-i-rake
[`route`]: https://api.rubyonrails.org/classes/Rails/Generators/Actions.html#method-i-route
[`Rails::Generators::Testing::Behaviour`]: https://api.rubyonrails.org/classes/Rails/Generators/Testing/Behavior.html
[`run_generator`]: https://api.rubyonrails.org/classes/Rails/Generators/Testing/Behavior.html#method-i-run_generator
[`Rails::Generators::Testing::Assertions`]: https://api.rubyonrails.org/classes/Rails/Generators/Testing/Assertions.html
