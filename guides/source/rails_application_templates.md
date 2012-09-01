h2. Rails Application Templates

Application templates are simple Ruby files containing DSL for adding gems/initializers etc. to your freshly created Rails project or an existing Rails project.

By referring to this guide, you will be able to:

* Use templates to generate/customize Rails applications
* Write your own reusable application templates using the Rails template API

endprologue.

h3. Usage

To apply a template, you need to provide the Rails generator with the location of the template you wish to apply, using -m option. This can either be path to a file or a URL.

<shell>
$ rails new blog -m ~/template.rb
$ rails new blog -m http://example.com/template.rb
</shell>

You can use the rake task +rails:template+ to apply templates to an existing Rails application. The location of the template needs to be passed in to an environment variable named LOCATION. Again, this can either be path to a file or a URL.

<shell>
$ rake rails:template LOCATION=~/template.rb
$ rake rails:template LOCATION=http://example.com/template.rb
</shell>

h3. Template API

Rails templates API is very self explanatory and easy to understand. Here's an example of a typical Rails template:

<ruby>
# template.rb
run "rm public/index.html"
generate(:scaffold, "person name:string")
route "root :to => 'people#index'"
rake("db:migrate")

git :init
git :add => "."
git :commit => %Q{ -m 'Initial commit' }
</ruby>

The following sections outlines the primary methods provided by the API:

h4. gem(name, options = {})

Adds a +gem+ entry for the supplied gem to the generated application’s +Gemfile+.

For example, if your application depends on the gems +bj+ and +nokogiri+:

<ruby>
gem "bj"
gem "nokogiri"
</ruby>

Please note that this will NOT install the gems for you and you will have to run +bundle install+ to do that.

<ruby>
bundle install
</ruby>

h4. gem_group(*names, &block)

Wraps gem entries inside a group.

For example, if you want to load +rspec-rails+ only in +development+ and +test+ group:

<ruby>
gem_group :development, :test do
  gem "rspec-rails"
end
</ruby>

h4. add_source(source, options = {})

Adds the given source to the generated application's +Gemfile+.

For example, if you need to source a gem from "http://code.whytheluckystiff.net":

<ruby>
add_source "http://code.whytheluckystiff.net"
</ruby>

h4. vendor/lib/file/initializer(filename, data = nil, &block)

Adds an initializer to the generated application’s +config/initializers+ directory.

Lets say you like using +Object#not_nil?+ and +Object#not_blank?+:

<ruby>
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
</ruby>

Similarly +lib()+ creates a file in the +lib/+ directory and +vendor()+ creates a file in the +vendor/+ directory.

There is even +file()+, which accepts a relative path from +Rails.root+ and creates all the directories/file needed:

<ruby>
file 'app/components/foo.rb', <<-CODE
class Foo
end
CODE
</ruby>

That’ll create +app/components+ directory and put +foo.rb+ in there.

h4. rakefile(filename, data = nil, &block)

Creates a new rake file under +lib/tasks+ with the supplied tasks:

<ruby>
rakefile("bootstrap.rake") do
  <<-TASK
    namespace :boot do
      task :strap do
        puts "i like boots!"
      end
    end
  TASK
end
</ruby>

The above creates +lib/tasks/bootstrap.rake+ with a +boot:strap+ rake task.

h4. generate(what, args)

Runs the supplied rails generator with given arguments.

<ruby>
generate(:scaffold, "person", "name:string", "address:text", "age:number")
</ruby>

h4. run(command)

Executes an arbitrary command. Just like the backticks. Let's say you want to remove the +public/index.html+ file:

<ruby>
run "rm public/index.html"
</ruby>

h4. rake(command, options = {})

Runs the supplied rake tasks in the Rails application. Let's say you want to migrate the database:

<ruby>
rake "db:migrate"
</ruby>

You can also run rake tasks with a different Rails environment:

<ruby>
rake "db:migrate", :env => 'production'
</ruby>

h4. route(routing_code)

This adds a routing entry to the +config/routes.rb+ file. In above steps, we generated a person scaffold and also removed +public/index.html+. Now to make +PeopleController#index+ as the default page for the application:

<ruby>
route "root :to => 'person#index'"
</ruby>

h4. inside(dir)

Enables you to run a command from the given directory. For example, if you have a copy of edge rails that you wish to symlink from your new apps, you can do this:

<ruby>
inside('vendor') do
  run "ln -s ~/commit-rails/rails rails"
end
</ruby>

h4. ask(question)

+ask()+ gives you a chance to get some feedback from the user and use it in your templates. Lets say you want your user to name the new shiny library you’re adding:

<ruby>
lib_name = ask("What do you want to call the shiny library ?")
lib_name << ".rb" unless lib_name.index(".rb")

lib lib_name, <<-CODE
class Shiny
end
CODE
</ruby>

h4. yes?(question) or no?(question)

These methods let you ask questions from templates and decide the flow based on the user’s answer. Lets say you want to freeze rails only if the user want to:

<ruby>
rake("rails:freeze:gems") if yes?("Freeze rails gems ?")
no?(question) acts just the opposite.
</ruby>

h4. git(:command)

Rails templates let you run any git command:

<ruby>
git :init
git :add => "."
git :commit => "-a -m 'Initial commit'"
</ruby>
