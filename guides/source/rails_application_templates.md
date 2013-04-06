Rails Application Templates
===========================

Application templates are simple Ruby files containing DSL for adding gems/initializers etc. to your freshly created Rails project or an existing Rails project.

After reading this guide, you will know:

* How to use templates to generate/customize Rails applications.
* How to write your own reusable application templates using the Rails template API.

--------------------------------------------------------------------------------

Usage
-----

To apply a template, you need to provide the Rails generator with the location of the template you wish to apply using the -m option. This can either be a path to a file or a URL.

```bash
$ rails new blog -m ~/template.rb
$ rails new blog -m http://example.com/template.rb
```

You can use the rake task `rails:template` to apply templates to an existing Rails application. The location of the template needs to be passed in to an environment variable named LOCATION. Again, this can either be path to a file or a URL.

```bash
$ rake rails:template LOCATION=~/template.rb
$ rake rails:template LOCATION=http://example.com/template.rb
```

Template API
------------

The Rails templates API is easy to understand. Here's an example of a typical Rails template:

```ruby
# template.rb
generate(:scaffold, "person name:string")
route "root to: 'people#index'"
rake("db:migrate")

git :init
git add: "."
git commit: %Q{ -m 'Initial commit' }
```

The following sections outline the primary methods provided by the API:

### gem(*args)

Adds a `gem` entry for the supplied gem to the generated application’s `Gemfile`.

For example, if your application depends on the gems `bj` and `nokogiri`:

```ruby
gem "bj"
gem "nokogiri"
```

Please note that this will NOT install the gems for you and you will have to run `bundle install` to do that.

```bash
bundle install
```

### gem_group(*names, &block)

Wraps gem entries inside a group.

For example, if you want to load `rspec-rails` only in the `development` and `test` groups:

```ruby
gem_group :development, :test do
  gem "rspec-rails"
end
```

### add_source(source, options = {})

Adds the given source to the generated application's `Gemfile`.

For example, if you need to source a gem from "http://code.whytheluckystiff.net":

```ruby
add_source "http://code.whytheluckystiff.net"
```

### environment/application(data=nil, options={}, &block)

Adds a line inside the `Application` class for `config/application.rb`.

If `options[:env]` is specified, the line is appended to the corresponding file in `config/environments`.

```ruby
environment 'config.action_mailer.default_url_options = {host: 'http://yourwebsite.example.com'}, env: 'production'
```

A block can be used in place of the `data` argument.

### vendor/lib/file/initializer(filename, data = nil, &block)

Adds an initializer to the generated application’s `config/initializers` directory.

Let's say you like using `Object#not_nil?` and `Object#not_blank?`:

```ruby
initializer 'bloatlol.rb', <<-CODE
  class Object
    def not_nil?
      !nil?
    end

    def not_blank?
      !blank?
    end
  end
CODE
```

Similarly, `lib()` creates a file in the `lib/` directory and `vendor()` creates a file in the `vendor/` directory.

There is even `file()`, which accepts a relative path from `Rails.root` and creates all the directories/files needed:

```ruby
file 'app/components/foo.rb', <<-CODE
  class Foo
  end
CODE
```

That’ll create the `app/components` directory and put `foo.rb` in there.

### rakefile(filename, data = nil, &block)

Creates a new rake file under `lib/tasks` with the supplied tasks:

```ruby
rakefile("bootstrap.rake") do
  <<-TASK
    namespace :boot do
      task :strap do
        puts "i like boots!"
      end
    end
  TASK
end
```

The above creates `lib/tasks/bootstrap.rake` with a `boot:strap` rake task.

### generate(what, *args)

Runs the supplied rails generator with given arguments.

```ruby
generate(:scaffold, "person", "name:string", "address:text", "age:number")
```

### run(command)

Executes an arbitrary command. Just like the backticks. Let's say you want to remove the `README.rdoc` file:

```ruby
run "rm README.rdoc"
```

### rake(command, options = {})

Runs the supplied rake tasks in the Rails application. Let's say you want to migrate the database:

```ruby
rake "db:migrate"
```

You can also run rake tasks with a different Rails environment:

```ruby
rake "db:migrate", env: 'production'
```

### route(routing_code)

Adds a routing entry to the `config/routes.rb` file. In the steps above, we generated a person scaffold and also removed `README.rdoc`. Now, to make `PeopleController#index` the default page for the application:

```ruby
route "root to: 'person#index'"
```

### inside(dir)

Enables you to run a command from the given directory. For example, if you have a copy of edge rails that you wish to symlink from your new apps, you can do this:

```ruby
inside('vendor') do
  run "ln -s ~/commit-rails/rails rails"
end
```

### ask(question)

`ask()` gives you a chance to get some feedback from the user and use it in your templates. Let's say you want your user to name the new shiny library you’re adding:

```ruby
lib_name = ask("What do you want to call the shiny library ?")
lib_name << ".rb" unless lib_name.index(".rb")

lib lib_name, <<-CODE
  class Shiny
  end
CODE
```

### yes?(question) or no?(question)

These methods let you ask questions from templates and decide the flow based on the user’s answer. Let's say you want to freeze rails only if the user wants to:

```ruby
rake("rails:freeze:gems") if yes?("Freeze rails gems?")
# no?(question) acts just the opposite.
```

### git(:command)

Rails templates let you run any git command:

```ruby
git :init
git add: "."
git commit: "-a -m 'Initial commit'"
```
