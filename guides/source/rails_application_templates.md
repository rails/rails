**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON https://guides.rubyonrails.org.**

Rails Application Templates
===========================

Application templates are simple Ruby files containing DSL for adding gems/initializers etc. to your freshly created Rails project or an existing Rails project.

After reading this guide, you will know:

* How to use templates to generate/customize Rails applications.
* How to write your own reusable application templates using the Rails template API.

--------------------------------------------------------------------------------

Usage
-----

To apply a template, you need to provide the Rails generator with the location of the template you wish to apply using the `-m` option. This can either be a path to a file or a URL.

```bash
$ rails new blog -m ~/template.rb
$ rails new blog -m http://example.com/template.rb
```

You can use the `app:template` rails command to apply templates to an existing Rails application. The location of the template needs to be passed in via the LOCATION environment variable. Again, this can either be path to a file or a URL.

```bash
$ rails app:template LOCATION=~/template.rb
$ rails app:template LOCATION=http://example.com/template.rb
```

Template API
------------

Here's an example of a Rails template:

```ruby
# template.rb
generate(:scaffold, "person name:string")
route "root 'people#index'"
rails_command("db:create")
rails_command("db:migrate")

after_bundle do
  git add: "."
  git commit: %Q{ -m 'Initial commit' }
end
```

The following sections outline the primary methods provided by the API:

### gem(*args)

Appends a `gem` entry for the supplied gem to the end of the generated application's `Gemfile`.

For example, add the gem `sassc-rails`:

```ruby
gem "sassc-rails"
```

### gem_group(*names, &block)

Wraps gem entries inside a group.

For example, add `rspec-rails` only in the `development` and `test` groups:

```ruby
gem_group :development, :test do
  gem "rspec-rails"
end
```

### add_source(source, options={}, &block)

Adds the given source to the generated application's `Gemfile`.

For example, if you need to source a gem from `"http://code.whytheluckystiff.net"`:

```ruby
add_source "http://code.whytheluckystiff.net"
```

If block is given, gem entries in block are wrapped into the source group.

```ruby
add_source "http://gems.github.com/" do
  gem "rspec-rails"
end
```

### environment/application(data=nil, options={}, &block)

Adds a line inside the `Application` class for `config/application.rb`.

If `options[:env]` is specified, the line is appended to the corresponding file in `config/environments`.

```ruby
environment 'config.action_mailer.default_url_options = {host: "http://yourwebsite.example.com"}', env: 'production'
```

A block can be used in place of the `data` argument.

### vendor/lib/file/initializer(filename, data = nil, &block)

Adds an initializer to the generated application's `config/initializers` directory.

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

There is also `file()`, which accepts a relative path from `Rails.root` and creates all the directories/files needed:

```ruby
file 'app/components/foo.rb', <<-CODE
  class Foo
  end
CODE
```

That creates the `app/components` directory and puts `foo.rb` in there.

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

Executes an arbitrary command. For instance, remove the `README.rdoc` file:

```ruby
run "rm README.rdoc"
```

### rails_command(command, options = {})

To run rails commands.

```ruby
rails_command "db:migrate"
```

Specify the Rails environment:

```ruby
rails_command "db:migrate", env: 'production'
```

Run commands as a super-user:

```ruby
rails_command "log:clear", sudo: true
```

To abort application generation if a command fails:

```ruby
rails_command "db:migrate", abort_on_failure: true
```

### route(routing_code)

Adds a routing entry to the `config/routes.rb` file. To make `PeopleController#index` the root page:

```ruby
route "root 'people#index'"
```

### inside(dir)

Runs a command from the given directory. For example, to symlink a copy of edge rails:

```ruby
inside('vendor') do
  run "ln -s ~/commit-rails/rails rails"
end
```

### ask(question)

`ask()` asks for user input, for instance to set a name:

```ruby
lib_name = ask("What do you want to call the shiny library ?")
lib_name << ".rb" unless lib_name.index(".rb")

lib lib_name, <<-CODE
  class Shiny
  end
CODE
```

### yes?(question) or no?(question)

These methods let you ask questions from templates and decide the flow based on the user's answer. Let's say you want to Freeze Rails only if the user wants to:

```ruby
rails_command("rails:freeze:gems") if yes?("Freeze rails gems?")
# no?(question) acts just the opposite.
```

### git(:command)

Run any git command:

```ruby
git :init
git add: "."
git commit: "-am 'Initial commit'"
```

### after_bundle(&block)

Registers a callback to be executed after the gems are bundled and binstubs
are generated. Useful for all generated files to version control:

```ruby
after_bundle do
  rails_command "webpacker:install"
end
```

The callbacks gets executed even if `--skip-bundle` and/or `--skip-spring` has
been passed.

Advanced Usage
--------------

The application template is evaluated in the context of a
`Rails::Generators::AppGenerator` instance. It uses the `apply` action
provided by
[Thor](https://github.com/erikhuda/thor/blob/master/lib/thor/actions.rb#L207).
This means you can extend and change the instance to match your needs.

For example by overwriting the `source_paths` method to contain the
location of your template. Now methods like `copy_file` will accept
relative paths to your template's location.

```ruby
def source_paths
  [__dir__]
end
```
