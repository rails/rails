h2. Getting Started with Rails

This guide covers getting up and running with Ruby on Rails. After reading it,
you should be familiar with:

* Installing Rails, creating a new Rails application, and connecting your application to a database
* The general layout of a Rails application
* The basic principles of MVC (Model, View Controller) and RESTful design
* How to quickly generate the starting pieces of a Rails application

endprologue.

WARNING. This Guide is based on Rails 3.2. Some of the code shown here will not
work in earlier versions of Rails.

h3. Guide Assumptions

This guide is designed for beginners who want to get started with a Rails
application from scratch. It does not assume that you have any prior experience
with Rails. However, to get the most out of it, you need to have some
prerequisites installed:

* The "Ruby":http://www.ruby-lang.org/en/downloads language version 1.9.3 or higher

* The "RubyGems":http://rubyforge.org/frs/?group_id=126 packaging system
  ** If you want to learn more about RubyGems, please read the "RubyGems User Guide":http://docs.rubygems.org/read/book/1
* A working installation of the "SQLite3 Database":http://www.sqlite.org

Rails is a web application framework running on the Ruby programming language.
If you have no prior experience with Ruby, you will find a very steep learning
curve diving straight into Rails. There are some good free resources on the
internet for learning Ruby, including:

* "Mr. Neighborly's Humble Little Ruby Book":http://www.humblelittlerubybook.com
* "Programming Ruby":http://www.ruby-doc.org/docs/ProgrammingRuby/
* "Why's (Poignant) Guide to Ruby":http://mislav.uniqpath.com/poignant-guide/

h3. What is Rails?

Rails is a web application development framework written in the Ruby language.
It is designed to make programming web applications easier by making assumptions
about what every developer needs to get started. It allows you to write less
code while accomplishing more than many other languages and frameworks.
Experienced Rails developers also report that it makes web application
development more fun.

Rails is opinionated software. It makes the assumption that there is a "best"
way to do things, and it's designed to encourage that way - and in some cases to
discourage alternatives. If you learn "The Rails Way" you'll probably discover a
tremendous increase in productivity. If you persist in bringing old habits from
other languages to your Rails development, and trying to use patterns you
learned elsewhere, you may have a less happy experience.

The Rails philosophy includes two major guiding principles:

* DRY - "Don't Repeat Yourself" - suggests that writing the same code over and over again is a bad thing.
* Convention Over Configuration - means that Rails makes assumptions about what you want to do and how you're going to
do it, rather than requiring you to specify every little thing through endless configuration files.

h3. Creating a New Rails Project

The best way to use this guide is to follow each step as it happens, no code or
step needed to make this example application has been left out, so you can
literally follow along step by step. You can get the complete code
"here":https://github.com/lifo/docrails/tree/master/guides/code/getting_started.

By following along with this guide, you'll create a Rails project called
+blog+, a
(very) simple weblog. Before you can start building the application, you need to
make sure that you have Rails itself installed.

TIP: The examples below use # and $ to denote superuser and regular user terminal prompts respectively in a UNIX-like OS. If you are using Windows, your prompt will look something like c:\source_code>

h4. Installing Rails

To install Rails, use the +gem install+ command provided by RubyGems:

<shell>
# gem install rails
</shell>

TIP. A number of tools exist to help you quickly install Ruby and Ruby
on Rails on your system. Windows users can use "Rails
Installer":http://railsinstaller.org, while Mac OS X users can use
"Rails One Click":http://railsoneclick.com.

To verify that you have everything installed correctly, you should be able to run the following:

<shell>
$ rails --version
</shell>

If it says something like "Rails 3.2.3" you are ready to continue.

h4. Creating the Blog Application

Rails comes with a number of generators that are designed to make your development life easier. One of these is the new application generator, which will provide you with the foundation of a Rails application so that you don't have to write it yourself.

To use this generator, open a terminal, navigate to a directory where you have rights to create files, and type:

<shell>
$ rails new blog
</shell>

This will create a Rails application called Blog in a directory called blog and install the gem dependencies that are already mentioned in +Gemfile+ using +bundle install+.

TIP: You can see all of the command line options that the Rails
application builder accepts by running +rails new -h+.

After you create the blog application, switch to its folder to continue work directly in that application:

<shell>
$ cd blog
</shell>

The +rails new blog+ command we ran above created a folder in your
working directory called +blog+. The +blog+ directory has a number of
auto-generated files and folders that make up the structure of a Rails
application. Most of the work in this tutorial will happen in the +app/+ folder, but here's a basic rundown on the function of each of the files and folders that Rails created by default:

|_.File/Folder|_.Purpose|
|app/|Contains the controllers, models, views, helpers, mailers and assets for your application. You'll focus on this folder for the remainder of this guide.|
|config/|Configure your application's runtime rules, routes, database, and more.  This is covered in more detail in "Configuring Rails Applications":configuring.html|
|config.ru|Rack configuration for Rack based servers used to start the application.|
|db/|Contains your current database schema, as well as the database migrations.|
|doc/|In-depth documentation for your application.|
|Gemfile<br />Gemfile.lock|These files allow you to specify what gem dependencies are needed for your Rails application. These files are used by the Bundler gem. For more information about Bundler, see "the Bundler website":http://gembundler.com |
|lib/|Extended modules for your application.|
|log/|Application log files.|
|public/|The only folder seen to the world as-is. Contains the static files and compiled assets.|
|Rakefile|This file locates and loads tasks that can be run from the command line. The task definitions are defined throughout the components of Rails. Rather than changing Rakefile, you should add your own tasks by adding files to the lib/tasks directory of your application.|
|README.rdoc|This is a brief instruction manual for your application. You should edit this file to tell others what your application does, how to set it up, and so on.|
|script/|Contains the rails script that starts your app and can contain other scripts you use to deploy or run your application.|
|test/|Unit tests, fixtures, and other test apparatus. These are covered in "Testing Rails Applications":testing.html|
|tmp/|Temporary files (like cache, pid and session files)|
|vendor/|A place for all third-party code. In a typical Rails application, this includes Ruby Gems and the Rails source code (if you optionally install it into your project).|

h3. Hello, Rails!

To begin with, let's get some text up on screen quickly. To do this, you need to get your Rails application server running.

h4. Starting up the Web Server

You actually have a functional Rails application already. To see it, you need to start a web server on your development machine. You can do this by running:

<shell>
$ rails server
</shell>

TIP: Compiling CoffeeScript to JavaScript requires a JavaScript runtime and the absence of a runtime will give you an +execjs+ error. Usually Mac OS X and Windows come with a JavaScript runtime installed. Rails adds the +therubyracer+ gem to Gemfile in a commented line for new apps and you can uncomment if you need it. +therubyrhino+ is the recommended runtime for JRuby users and is added by default to Gemfile in apps generated under JRuby. You can investigate about all the supported runtimes at "ExecJS":https://github.com/sstephenson/execjs#readme.

This will fire up WEBrick, a webserver built into Ruby by default. To see your application in action, open a browser window and navigate to "http://localhost:3000":http://localhost:3000. You should see the Rails default information page:

!images/rails_welcome.png(Welcome Aboard screenshot)!

TIP: To stop the web server, hit Ctrl+C in the terminal window where it's running. In development mode, Rails does not generally require you to restart the server; changes you make in files will be automatically picked up by the server.

The "Welcome Aboard" page is the _smoke test_ for a new Rails application: it makes sure that you have your software configured correctly enough to serve a page. You can also click on the _About your application’s environment_ link to see a summary of your application's environment.

h4. Say "Hello", Rails

To get Rails saying "Hello", you need to create at minimum a _controller_ and a _view_.

A controller's purpose is to receive specific requests for the application. _Routing_ decides which controller receives which requests. Often, there is more than one route to each controller, and different routes can be served by different _actions_. Each action's purpose is to collect information to provide it to a view.

A view's purpose is to display this information in a human readable format. An important distinction to make is that it is the _controller_, not the view, where information is collected. The view should just display that information. By default, view templates are written in a language called ERB (Embedded Ruby) which is converted by the request cycle in Rails before being sent to the user.

To create a new controller, you will need to run the "controller" generator and tell it you want a controller called "welcome" with an action called "index", just like this:

<shell>
$ rails generate controller welcome index
</shell>

Rails will create several files and a route for you.

<shell>
create  app/controllers/welcome_controller.rb
 route  get "welcome/index"
invoke  erb
create    app/views/welcome
create    app/views/welcome/index.html.erb
invoke  test_unit
create    test/functional/welcome_controller_test.rb
invoke  helper
create    app/helpers/welcome_helper.rb
invoke    test_unit
create      test/unit/helpers/welcome_helper_test.rb
invoke  assets
invoke    coffee
create      app/assets/javascripts/welcome.js.coffee
invoke    scss
create      app/assets/stylesheets/welcome.css.scss
</shell>

Most important of these are of course the controller, located at +app/controllers/welcome_controller.rb+ and the view, located at +app/views/welcome/index.html.erb+.

Open the +app/views/welcome/index.html.erb+ file in your text editor and edit it to contain a single line of code:

<html>
<h1>Hello, Rails!</h1>
</html>

h4. Setting the Application Home Page

Now that we have made the controller and view, we need to tell Rails when we want "Hello Rails!" to show up. In our case, we want it to show up when we navigate to the root URL of our site, "http://localhost:3000":http://localhost:3000. At the moment, however, the "Welcome Aboard" smoke test is occupying that spot.

To fix this, delete the +index.html+ file located inside the +public+ directory of the application.

You need to do this because Rails will serve any static file in the +public+ directory that matches a route in preference to any dynamic content you generate from the controllers. The +index.html+ file is special: it will be served if a request comes in at the root route, e.g. http://localhost:3000. If another request such as http://localhost:3000/welcome happened, a static file at <tt>public/welcome.html</tt> would be served first, but only if it existed.

Next, you have to tell Rails where your actual home page is located.

Open the file +config/routes.rb+ in your editor.

<ruby>
Blog::Application.routes.draw do
  get "welcome/index"

  # The priority is based upon order of creation:
  # first created -> highest priority.
  # ...
  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  # root :to => "welcome#index"
</ruby>

This is your application's _routing file_ which holds entries in a special DSL (domain-specific language) that tells Rails how to connect incoming requests to controllers and actions. This file contains many sample routes on commented lines, and one of them actually shows you how to connect the root of your site to a specific controller and action. Find the line beginning with +root :to+ and uncomment it. It should look something like the following:

<ruby>
root :to => "welcome#index"
</ruby>

The +root :to => "welcome#index"+ tells Rails to map requests to the root of the application to the welcome controller's index action and +get "welcome/index"+ tells Rails to map requests to "http://localhost:3000/welcome/index":http://localhost:3000/welcome/index to the welcome controller's index action. This was created earlier when you ran the controller generator (+rails generate controller welcome index+).

If you navigate to "http://localhost:3000":http://localhost:3000 in your browser, you'll see the +Hello, Rails!+ message you put into +app/views/welcome/index.html.erb+, indicating that this new route is indeed going to +WelcomeController+'s +index+ action and is rendering the view correctly.

NOTE. For more information about routing, refer to "Rails Routing from the Outside In":routing.html.

h3. Getting Up and Running

Now that you've seen how to create a controller, an action and a view, let's create something with a bit more substance.

In the Blog application, you will now create a new _resource_. A resource is the term used for a collection of similar objects, such as posts, people or animals. You can create, read, update and destroy items for a resource and these operations are referred to as _CRUD_ operations.

In the next section, you will add the ability to create new posts in your application and be able to view them. This is the "C" and the "R" from CRUD: creation and reading. The form for doing this will look like this:

!images/getting_started/new_post.png(The new post form)!

It will look a little basic for now, but that's ok. We'll look at improving the styling for it afterwards.

h4. Laying down the ground work

The first thing that you are going to need to create a new post within the application is a place to do that. A great place for that would be at +/posts/new+. If you attempt to navigate to that now -- by visiting "http://localhost:3000/posts/new":http://localhost:3000/posts/new -- Rails will give you a routing error:

!images/getting_started/routing_error_no_route_matches.png(A routing error, no route matches /posts/new)!

This is because there is nowhere inside the routes for the application -- defined inside +config/routes.rb+ -- that defines this route. By default, Rails has no routes configured at all, besides the root route you defined earlier, and so you must define your routes as you need them.

 To do this, you're going to need to create a route inside +config/routes.rb+ file, on a new line between the +do+ and the +end+ for the +draw+ method:

<ruby>
get "posts/new"
</ruby>

This route is a super-simple route: it defines a new route that only responds to +GET+ requests, and that the route is at +posts/new+. But how does it know where to go without the use of the +:to+ option? Well, Rails uses a sensible default here: Rails will assume that you want this route to go to the new action inside the posts controller.

With the route defined, requests can now be made to +/posts/new+ in the application. Navigate to "http://localhost:3000/posts/new":http://localhost:3000/posts/new and you'll see another routing error:

!images/getting_started/routing_error_no_controller.png(Another routing error, uninitialized constant PostsController)!

This error is happening because this route need a controller to be defined. The route is attempting to find that controller so it can serve the request, but with the controller undefined, it just can't do that. The solution to this particular problem is simple: you need to create a controller called +PostsController+. You can do this by running this command:

<shell>
$ rails g controller posts
</shell>

If you open up the newly generated +app/controllers/posts_controller.rb+ you'll see a fairly empty controller:

<ruby>
class PostsController < ApplicationController
end
</ruby>

A controller is simply a class that is defined to inherit from +ApplicationController+. It's inside this class that you'll define methods that will become the actions for this controller. These actions will perform CRUD operations on the posts within our system.

If you refresh "http://localhost:3000/posts/new":http://localhost:3000/posts/new now, you'll get a new error:

!images/getting_started/unknown_action_new_for_posts.png(Unknown action new for PostsController!)!

This error indicates that Rails cannot find the +new+ action inside the +PostsController+ that you just generated. This is because when controllers are generated in Rails they are empty by default, unless you tell it you wanted actions during the generation process.

To manually define an action inside a controller, all you need to do is to define a new method inside the controller. Open +app/controllers/posts_controller.rb+ and inside the +PostsController+ class, define a +new+ method like this:

<ruby>
def new
end
</ruby>

With the +new+ method defined in +PostsController+, if you refresh "http://localhost:3000/posts/new":http://localhost:3000/posts/new you'll see another error:

!images/getting_started/template_is_missing_posts_new.png(Template is missing for posts/new)!

You're getting this error now because Rails expects plain actions like this one to have views associated with them to display their information. With no view available, Rails errors out.

In the above image, the bottom line has been truncated. Let's see what the full thing looks like:

<blockquote>
Missing template posts/new, application/new with {:locale=>[:en], :formats=>[:html], :handlers=>[:erb, :builder, :coffee]}. Searched in: * "/path/to/blog/app/views"
</blockquote>

That's quite a lot of text! Let's quickly go through and understand what each part of it does.

The first part identifies what template is missing. In this case, it's the +posts/new+ template. Rails will first look for this template. If not found, then it will attempt to load a template called +application/new+. It looks for one here because the +PostsController+ inherits from +ApplicationController+.

The next part of the message contains a hash. The +:locale+ key in this hash simply indicates what spoken language template should be retrieved. By default, this is the English -- or "en" -- template. The next key, +:formats+ specifies the format of template to be served in response . The default format is +:html+, and so Rails is looking for an HTML template. The final key, +:handlers+, is telling us what _template handlers_ could be used to render our template. +:erb+ is most commonly used for HTML templates, +:builder+ is used for XML templates, and +:coffee+ uses CoffeeScript to build JavaScript templates.

The final part of this message tells us where Rails has looked for the templates. Templates within a basic Rails application like this are kept in a single location, but in more complex applications it could be many different paths.

The simplest template that would work in this case would be one located at +app/views/posts/new.html.erb+. The extension of this file name is key: the first extension is the _format_ of the template, and the second extension is the _handler_ that will be used. Rails is attempting to find a template called +posts/new+ within +app/views+ for the application. The format for this template can only be +html+ and the handler must be one of +erb+, +builder+ or +coffee+. Because you want to create a new HTML form, you will be using the +ERB+ language. Therefore the file should be called +posts/new.html.erb+ and needs to be located inside the +app/views+ directory of the application.

Go ahead now and create a new file at +app/views/posts/new.html.erb+ and write this content in it:

<erb>
<h1>New Post</h1>
</erb>

When you refresh "http://localhost:3000/posts/new":http://localhost:3000/posts/new you'll now see that the page has a title. The route, controller, action and view are now working harmoniously! It's time to create the form for a new post.

h4. The first form

To create a form within this template, you will use a <em>form
builder</em>. The primary form builder for Rails is provided by a helper
method called +form_for+. To use this method, add this code into +app/views/posts/new.html.erb+:

<erb>
<%= form_for :post do |f| %>
  <p>
    <%= f.label :title %><br>
    <%= f.text_field :title %>
  </p>

  <p>
    <%= f.label :text %><br>
    <%= f.text_area :text %>
  </p>

  <p>
    <%= f.submit %>
  </p>
<% end %>
</erb>

If you refresh the page now, you'll see the exact same form as in the example. Building forms in Rails is really just that easy!

When you call +form_for+, you pass it an identifying object for this
form. In this case, it's the symbol +:post+. This tells the +form_for+
helper what this form is for. Inside the block for this method, the
+FormBuilder+ object -- represented by +f+ -- is used to build two labels and two text fields, one each for the title and text of a post. Finally, a call to +submit+ on the +f+ object will create a submit button for the form.

There's one problem with this form though. If you inspect the HTML that is generated, by viewing the source of the page, you will see that the +action+ attribute for the form is pointing at +/posts/new+. This is a problem because this route goes to the very page that you're on right at the moment, and that route should only be used to display the form for a new post.

The form needs to use a different URL in order to go somewhere else.
This can be done quite simply with the +:url+ option of +form_for+.
Typically in Rails, the action that is used for new form submissions
like this is called "create", and so the form should be pointed to that action.

Edit the +form_for+ line inside +app/views/posts/new.html.erb+ to look like this:

<erb>
<%= form_for :post, :url => { :action => :create } do |f| %>
</erb>

In this example, a +Hash+ object is passed to the +:url+ option. What Rails will do with this is that it will point the form to the +create+ action of the current controller, the +PostsController+, and will send a +POST+ request to that route. For this to work, you will need to add a route to +config/routes.rb+, right underneath the one for "posts/new":

<ruby>
post "posts" => "posts#create"
</ruby>

By using the +post+ method rather than the +get+ method, Rails will define a route that will only respond to POST methods. The POST method is the typical method used by forms all over the web.

With the form and its associated route defined, you will be able to fill in the form and then click the submit button to begin the process of creating a new post, so go ahead and do that. When you submit the form, you should see a familiar error:

!images/getting_started/unknown_action_create_for_posts.png(Unknown action create for PostsController)!

You now need to create the +create+ action within the +PostsController+ for this to work.

h4. Creating posts

To make the "Unknown action" go away, you can define a +create+ action within the +PostsController+ class in +app/controllers/posts_controller.rb+, underneath the +new+ action:

<ruby>
class PostsController < ApplicationController
  def new
  end

  def create
  end

end
</ruby>

If you re-submit the form now, you'll see another familiar error: a template is missing. That's ok, we can ignore that for now. What the +create+ action should be doing is saving our new post to a database.

When a form is submitted, the fields of the form are sent to Rails as _parameters_. These parameters can then be referenced inside the controller actions, typically to perform a particular task. To see what these parameters look like, change the +create+ action to this:

<ruby>
def create
  render :text => params[:post].inspect
end
</ruby>

The +render+ method here is taking a very simple hash with a key of +text+ and value of +params[:post].inspect+. The +params+ method is the object which represents the parameters (or fields) coming in from the form. The +params+ method returns a +HashWithIndifferentAccess+ object, which allows you to access the keys of the hash using either strings or symbols. In this situation, the only parameters that matter are the ones from the form.

If you re-submit the form one more time you'll now no longer get the missing template error. Instead, you'll see something that looks like the following:

<ruby>
{"title"=>"First post!", "text"=>"This is my first post."}
</ruby>

This action is now displaying the parameters for the post that are coming in from the form. However, this isn't really all that helpful. Yes, you can see the parameters but nothing in particular is being done with them.

h4. Creating the Post model

Models in Rails use a singular name, and their corresponding database tables use
a plural name. Rails provides a generator for creating models, which
most Rails developers tend to use when creating new models.
To create the new model, run this command in your terminal:

<shell>
$ rails generate model Post title:string text:text
</shell>

With that command we told Rails that we want a +Post+ model, together
with a _title_ attribute of type string, and a _text_ attribute
of type text. Those attributes are automatically added to the +posts+
table in the database and mapped to the +Post+ model.

Rails responded by creating a bunch of files. For
now, we're only interested in +app/models/post.rb+ and
+db/migrate/20120419084633_create_posts.rb+ (your name could be a bit
different). The latter is responsible
for creating the database structure, which is what we'll look at next.

TIP: Active Record is smart enough to automatically map column names to
model attributes, which means you don't have to declare attributes
inside Rails models, as that will be done automatically by Active
Record.

h4. Running a Migration

As we've just seen, +rails generate model+ created a _database
migration_ file inside the +db/migrate+ directory.
Migrations are Ruby classes that are designed to make it simple to
create and modify database tables. Rails uses rake commands to run migrations,
and it's possible to undo a migration after it's been applied to your database.
Migration filenames include a timestamp to ensure that they're processed in the
order that they were created.

If you look in the +db/migrate/20120419084633_create_posts.rb+ file (remember,
yours will have a slightly different name), here's what you'll find:

<ruby>
class CreatePosts < ActiveRecord::Migration
  def change
    create_table :posts do |t|
      t.string :title
      t.text :text

      t.timestamps
    end
  end
end
</ruby>

The above migration creates a method named +change+ which will be called when you
run this migration. The action defined in this method is also reversible, which
means Rails knows how to reverse the change made by this migration, in case you
want to reverse it later. When you run this migration it will create a
+posts+ table with one string column and a text column. It also creates two
timestamp fields to allow Rails to track post creation and update times. More
information about Rails migrations can be found in the "Rails Database
Migrations":migrations.html guide.

At this point, you can use a rake command to run the migration:

<shell>
$ rake db:migrate
</shell>

Rails will execute this migration command and tell you it created the Posts
table.

<shell>
==  CreatePosts: migrating ====================================================
-- create_table(:posts)
   -> 0.0019s
==  CreatePosts: migrated (0.0020s) ===========================================
</shell>

NOTE. Because you're working in the development environment by default, this
command will apply to the database defined in the +development+ section of your
+config/database.yml+ file. If you would like to execute migrations in another
environment, for instance in production, you must explicitly pass it when
invoking the command: +rake db:migrate RAILS_ENV=production+.

h4. Saving data in the controller

Back in +posts_controller+, we need to change the +create+ action
to use the new +Post+ model to save the data in the database. Open that file
and change the +create+ action to look like this:

<ruby>
def create
  @post = Post.new(params[:post])

  @post.save
  redirect_to :action => :show, :id => @post.id
end
</ruby>

Here's what's going on: every Rails model can be initialized with its
respective attributes, which are automatically mapped to the respective
database columns. In the first line we do just that (remember that
+params[:post]+ contains the attributes we're interested in). Then,
+@post.save+ is responsible for saving the model in the database.
Finally, we redirect the user to the +show+ action,
which we'll define later.

TIP: As we'll see later, +@post.save+ returns a boolean indicating
wherever the model was saved or not.

h4. Showing Posts

If you submit the form again now, Rails will complain about not finding
the +show+ action. That's not very useful though, so let's add the
+show+ action before proceeding. Open +config/routes.rb+ and add the following route:

<ruby>
get "posts/:id" => "posts#show"
</ruby>

The special syntax +:id+ tells rails that this route expects an +:id+
parameter, which in our case will be the id of the post. Note that this
time we had to specify the actual mapping, +posts#show+ because
otherwise Rails would not know which action to render.

As we did before, we need to add the +show+ action in the
+posts_controller+ and its respective view.

<ruby>
def show
  @post = Post.find(params[:id])
end
</ruby>

A couple of things to note. We use +Post.find+ to find the post we're
interested in. We also use an instance variable (prefixed by +@+) to
hold a reference to the post object. We do this because Rails will pass all instance
variables to the view.

Now, create a new file +app/view/posts/show.html.erb+ with the following
content:

<erb>
<p>
  <strong>Title:</strong>
  <%= @post.title %>
</p>

<p>
  <strong>Text:</strong>
  <%= @post.text %>
</p>
</erb>

Finally, if you now go to
"http://localhost:3000/posts/new":http://localhost:3000/posts/new you'll
be able to create a post. Try it!

!images/getting_started/show_action_for_posts.png(Show action for posts)!

h4. Listing all posts

We still need a way to list all our posts, so let's do that. As usual,
we'll need a route placed into +config/routes.rb+:

<ruby>
get "posts" => "posts#index"
</ruby>

And an action for that route inside the +PostsController+ in the +app/controllers/posts_controller.rb+ file:

<ruby>
def index
  @posts = Post.all
end
</ruby>

And then finally a view for this action, located at +app/views/posts/index.html.erb+:

<erb>
<h1>Listing posts</h1>

<table>
  <tr>
    <th>Title</th>
    <th>Text</th>
  </tr>

  <% @posts.each do |post| %>
    <tr>
      <td><%= post.title %></td>
      <td><%= post.text %></td>
    </tr>
  <% end %>
</table>
</erb>

Now if you go to +http://localhost:3000/posts+ you will see a list of all the posts that you have created.

h4. Adding links

You can now create, show, and list posts. Now let's add some links to
navigate through pages.

Open +app/views/welcome/index.html.erb+ and modify it as follows:

<ruby>
<h1>Hello, Rails!</h1>
<%= link_to "My Blog", :controller => "posts" %>
</ruby>

The +link_to+ method is one of Rails' built-in view helpers. It creates a
hyperlink based on text to display and where to go - in this case, to the path
for posts.

Let's add links to the other views as well, starting with adding this "New Post" link to +app/views/posts/index.html.erb+, placing it above the +&lt;table&gt;+ tag:

<erb>
<%= link_to 'New post', :action => :new %>
</erb>

This link will allow you to bring up the form that lets you create a new post. You should also add a link to this template -- +app/views/posts/new.html.erb+ -- to go back to the +index+ action. Do this by adding this underneath the form in this template:

<erb>
<%= form_for :post do |f| %>
  ...
<% end %>

<%= link_to 'Back', :action => :index %>
</erb>

Finally, add another link to the +app/views/posts/show.html.erb+ template to go back to the +index+ action as well, so that people who are viewing a single post can go back and view the whole list again:

<erb>
<p>
  <strong>Title:</strong>
  <%= @post.title %>
</p>

<p>
  <strong>Text:</strong>
  <%= @post.text %>
</p>

<%= link_to 'Back', :action => :index %>
</erb>

TIP: If you want to link to an action in the same controller, you don't
need to specify the +:controller+ option, as Rails will use the current
controller by default.

TIP: In development mode (which is what you're working in by default), Rails
reloads your application with every browser request, so there's no need to stop
and restart the web server when a change is made.

h4. Allowing the update of fields

The model file, +app/models/post.rb+ is about as simple as it can get:

<ruby>
class Post < ActiveRecord::Base
end
</ruby>

There isn't much to this file - but note that the +Post+ class inherits from
+ActiveRecord::Base+. Active Record supplies a great deal of functionality to
your Rails models for free, including basic database CRUD (Create, Read, Update,
Destroy) operations, data validation, as well as sophisticated search support
and the ability to relate multiple models to one another.

Rails includes methods to help you secure some of your model fields.
Open the +app/models/post.rb+ file and edit it:

<ruby>
class Post < ActiveRecord::Base
  attr_accessible :text, :title
end
</ruby>

This change will ensure that all changes made through HTML forms can edit the content of the text and title fields.
It will not be possible to define any other field value through forms. You can still define them by calling the `field=` method of course.
Accessible attributes and the mass assignment problem is covered in details in the "Security guide":security.html#mass-assignment

h4. Adding Some Validation

Rails includes methods to help you validate the data that you send to models.
Open the +app/models/post.rb+ file and edit it:

<ruby>
class Post < ActiveRecord::Base
  attr_accessible :text, :title

  validates :title, :presence => true,
                    :length => { :minimum => 5 }
end
</ruby>

These changes will ensure that all posts have a title that is at least five characters long.
Rails can validate a variety of conditions in a model, including the presence or uniqueness of columns, their
format, and the existence of associated objects. Validations are covered in detail
in "Active Record Validations and
Callbacks":active_record_validations_callbacks.html#validations-overview

With the validation now in place, when you call +@post.save+ on an invalid
post, it will return +false+. If you open +app/controllers/posts_controller.rb+
again, you'll notice that we don't check the result of calling +@post.save+
inside the +create+ action. If +@post.save+ fails in this situation, we need to
show the form back to the user. To do this, change the +new+ and +create+
actions inside +app/controllers/posts_controller.rb+ to these:

<ruby>
def new
  @post = Post.new
end

def create
  @post = Post.new(params[:post])

  if @post.save
    redirect_to :action => :show, :id => @post.id
  else
    render 'new'
  end
end
</ruby>

The +new+ action is now creating a new instance variable called +@post+, and
you'll see why that is in just a few moments.

Notice that inside the +create+ action we use +render+ instead of +redirect_to+ when +save+
returns +false+. The +render+ method is used so that the +@post+ object is passed back to the +new+ template when it is rendered. This rendering is done within the same request as the form submission, whereas the +redirect_to+ will tell the browser to issue another request.

If you reload
"http://localhost:3000/posts/new":http://localhost:3000/posts/new and
try to save a post without a title, Rails will send you back to the
form, but that's not very useful. You need to tell the user that
something went wrong. To do that, you'll modify
+app/views/posts/new.html.erb+ to check for error messages:

<erb>
<%= form_for :post, :url => { :action => :create } do |f| %>
  <% if @post.errors.any? %>
  <div id="errorExplanation">
    <h2><%= pluralize(@post.errors.count, "error") %> prohibited
	    this post from being saved:</h2>
    <ul>
    <% @post.errors.full_messages.each do |msg| %>
      <li><%= msg %></li>
    <% end %>
    </ul>
  </div>
  <% end %>
  <p>
    <%= f.label :title %><br>
    <%= f.text_field :title %>
  </p>

  <p>
    <%= f.label :text %><br>
    <%= f.text_area :text %>
  </p>

  <p>
    <%= f.submit %>
  </p>
<% end %>

<%= link_to 'Back', :action => :index %>
</erb>

A few things are going on. We check if there are any errors with
+@post.errors.any?+, and in that case we show a list of all
errors with +@post.errors.full_messages+.

+pluralize+ is a rails helper that takes a number and a string as its
arguments. If the number is greater than one, the string will be automatically pluralized.

The reason why we added +@post = Post.new+ in +posts_controller+ is that
otherwise +@post+ would be +nil+ in our view, and calling
+@post.errors.any?+ would throw an error.

TIP: Rails automatically wraps fields that contain an error with a div
with class +field_with_errors+. You can define a css rule to make them
standout.

Now you'll get a nice error message when saving a post without title when you
attempt to do just that on the "new post form(http://localhost:3000/posts/new)":http://localhost:3000/posts/new.

!images/getting_started/form_with_errors.png(Form With Errors)!

h4. Updating Posts

We've covered the "CR" part of CRUD. Now let's focus on the "U" part,
updating posts.

The first step we'll take is adding a +edit+ action to
+posts_controller+.

Start by adding a route to +config/routes.rb+:

<ruby>
get "posts/:id/edit" => "posts#edit"
</ruby>

And then add the controller action:

<ruby>
def edit
  @post = Post.find(params[:id])
end
</ruby>

The view will contain a form similar to the one we used when creating
new posts. Create a file called +app/views/posts/edit.html.erb+ and make
it look as follows:

<erb>
<h1>Editing post</h1>

<%= form_for :post, :url => { :action => :update, :id => @post.id },
:method => :put do |f| %>
  <% if @post.errors.any? %>
  <div id="errorExplanation">
    <h2><%= pluralize(@post.errors.count, "error") %> prohibited
	    this post from being saved:</h2>
    <ul>
    <% @post.errors.full_messages.each do |msg| %>
      <li><%= msg %></li>
    <% end %>
    </ul>
  </div>
  <% end %>
  <p>
    <%= f.label :title %><br>
    <%= f.text_field :title %>
  </p>

  <p>
    <%= f.label :text %><br>
    <%= f.text_area :text %>
  </p>

  <p>
    <%= f.submit %>
  </p>
<% end %>

<%= link_to 'Back', :action => :index %>
</erb>

This time we point the form to the +update+ action, which is not defined yet
but will be very soon.

The +:method => :put+ option tells Rails that we want this form to be
submitted via the +PUT+, HTTP method which is the HTTP method you're expected to use to
*update* resources according to the REST protocol.

TIP: By default forms built with the +form_for_ helper are sent via +POST+.

Next, we need to add the +update+ action. The file
+config/routes.rb+ will need just one more line:

<ruby>
put "posts/:id" => "posts#update"
</ruby>

And then create the +update+ action in +app/controllers/posts_controller.rb+:

<ruby>
def update
  @post = Post.find(params[:id])

  if @post.update_attributes(params[:post])
    redirect_to :action => :show, :id => @post.id
  else
    render 'edit'
  end
end
</ruby>

The new method, +update_attributes+, is used when you want to update a record
that already exists, and it accepts a hash containing the attributes
that you want to update. As before, if there was an error updating the
post we want to show the form back to the user.

TIP: you don't need to pass all attributes to +update_attributes+. For
example, if you'd call +@post.update_attributes(:title => 'A new title')+
Rails would only update the +title+ attribute, leaving all other
attributes untouched.

Finally, we want to show a link to the +edit+ action in the list of all the
posts, so let's add that now to +app/views/posts/index.html.erb+ to make it
appear next to the "Show" link:

<erb>

<table>
  <tr>
    <th>Title</th>
    <th>Text</th>
    <th></th>
    <th></th>
  </tr>

<% @posts.each do |post| %>
  <tr>
    <td><%= post.title %></td>
    <td><%= post.text %></td>
    <td><%= link_to 'Show', :action => :show, :id => post.id %></td>
    <td><%= link_to 'Edit', :action => :edit, :id => post.id %></td>
  </tr>
<% end %>
</table>
</erb>

And we'll also add one to the +app/views/posts/show.html.erb+ template as well,
so that there's also an "Edit" link on a post's page. Add this at the bottom of
the template:

<erb>
...


<%= link_to 'Back', :action => :index %>
| <%= link_to 'Edit', :action => :edit, :id => @post.id %>
</erb>

And here's how our app looks so far:

!images/getting_started/index_action_with_edit_link.png(Index action
with edit link)!

h4. Using partials to clean up duplication in views

+partials+ are what Rails uses to remove duplication in views. Here's a
simple example:

<erb>
# app/views/user/show.html.erb

<h1><%= @user.name %></h1>

<%= render 'user_details' %>

# app/views/user/_user_details.html.erb

<%= @user.location %>

<%= @user.about_me %>
</erb>

The +users/show+ template will automatically include the content of the
+users/_user_details+ template. Note that partials are prefixed by an underscore,
as to not be confused with regular views. However, you don't include the
underscore when including them with the +helper+ method.

TIP: You can read more about partials in the "Layouts and Rendering in
Rails":layouts_and_rendering.html guide.

Our +edit+ action looks very similar to the +new+ action, in fact they
both share the same code for displaying the form. Lets clean them up by
using a partial.

Create a new file +app/views/posts/_form.html.erb+ with the following
content:

<erb>
<%= form_for @post do |f| %>
  <% if @post.errors.any? %>
  <div id="errorExplanation">
    <h2><%= pluralize(@post.errors.count, "error") %> prohibited
      this post from being saved:</h2>
    <ul>
    <% @post.errors.full_messages.each do |msg| %>
      <li><%= msg %></li>
    <% end %>
    </ul>
  </div>
  <% end %>
  <p>
    <%= f.label :title %><br>
    <%= f.text_field :title %>
  </p>

  <p>
    <%= f.label :text %><br>
    <%= f.text_area :text %>
  </p>

  <p>
    <%= f.submit %>
  </p>
<% end %>
</erb>

Everything except for the +form_for+ declaration remained the same.
How +form_for+ can figure out the right +action+ and +method+ attributes
when building the form will be explained in just a moment. For now, let's update the
+app/views/posts/new.html.erb+ view to use this new partial, rewriting it
completely:

<erb>
<h1>New post</h1>

<%= render 'form' %>

<%= link_to 'Back', :action => :index %>
</erb>

Then do the same for the +app/views/posts/edit.html.erb+ view:

<erb>
<h1>Edit post</h1>

<%= render 'form' %>

<%= link_to 'Back', :action => :index %>
</erb>

Point your browser to "http://localhost:3000/posts/new":http://localhost:3000/posts/new and
try creating a new post. Everything still works. Now try editing the
post and you'll receive the following error:

!images/getting_started/undefined_method_post_path.png(Undefined method
post_path)!

To understand this error, you need to understand how +form_for+ works.
When you pass an object to +form_for+ and you don't specify a +:url+
option, Rails will try to guess the +action+ and +method+ options by
checking if the passed object is a new record or not. Rails follows the
REST convention, so to create a new +Post+ object it will look for a
route named +posts_path+, and to update a +Post+ object it will look for
a route named +post_path+ and pass the current object. Similarly, rails
knows that it should create new objects via POST and update them via
PUT.

If you run +rake routes+ from the console you'll see that we already
have a +posts_path+ route, which was created automatically by Rails when we
defined the route for the index action.
However, we don't have a +post_path+ yet, which is the reason why we
received an error before.

<shell>
# rake routes

    posts GET  /posts(.:format)            posts#index
posts_new GET  /posts/new(.:format)        posts#new
          POST /posts(.:format)            posts#create
          GET  /posts/:id(.:format)        posts#show
          GET  /posts/:id/edit(.:format)   posts#edit
          PUT  /posts/:id(.:format)        posts#update
     root      /                           welcome#index
</shell>

To fix this, open +config/routes.rb+ and modify the +get "posts/:id"+
line like this:

<ruby>
get "posts/:id" => "posts#show", :as => :post
</ruby>

The +:as+ option tells the +get+ method that we want to make routing helpers
called +post_url+ and +post_path+ available to our application. These are
precisely the methods that the +form_for+ needs when editing a post, and so now
you'll be able to update posts again.

NOTE: The +:as+ option is available on the +post+, +put+, +delete+ and +match+
routing methods also.

h4. Deleting Posts

We're now ready to cover the "D" part of CRUD, deleting posts from the
database. Following the REST convention, we're going to add a route for
deleting posts to +config/routes.rb+:

<ruby>
delete "posts/:id" => "posts#destroy"
</ruby>

The +delete+ routing method should be used for routes that destroy
resources. If this was left as a typical +get+ route, it could be possible for
people to craft malicious URLs like this:

<html>
<a href='http://yoursite.com/posts/1/destroy'>look at this cat!</a>
</html>

We use the +delete+ method for destroying resources, and this route is mapped to
the +destroy+ action inside +app/controllers/posts_controller.rb+, which doesn't exist yet, but is
provided below:

<ruby>
def destroy
  @post = Post.find(params[:id])
  @post.destroy

  redirect_to :action => :index
end
</ruby>

You can call +destroy+ on Active Record objects when you want to delete
them from the database. Note that we don't need to add a view for this
action since we're redirecting to the +index+ action.

Finally, add a 'destroy' link to your +index+ action template
(+app/views/posts/index.html.erb) to wrap everything
together.

<erb>
<h1>Listing Posts</h1>
<table>
  <tr>
    <th>Title</th>
    <th>Text</th>
    <th></th>
    <th></th>
    <th></th>
  </tr>

<% @posts.each do |post| %>
  <tr>
    <td><%= post.title %></td>
    <td><%= post.text %></td>
    <td><%= link_to 'Show', :action => :show, :id => post.id %></td>
    <td><%= link_to 'Edit', :action => :edit, :id => post.id %></td>
    <td><%= link_to 'Destroy', { :action => :destroy, :id => post.id }, :method => :delete, :data => { :confirm => 'Are you sure?' } %></td>
  </tr>
<% end %>
</table>
</erb>

Here we're using +link_to+ in a different way. We wrap the
+:action+ and +:id+ attributes in a hash so that we can pass those two keys in
first as one argument, and then the final two keys as another argument. The +:method+ and +:'data-confirm'+
options are used as HTML5 attributes so that when the link is clicked,
Rails will first show a confirm dialog to the user, and then submit the link with method +delete+.
This is done via the JavaScript file +jquery_ujs+ which is automatically included
into your application's layout (+app/views/layouts/application.html.erb+) when you
generated the application. Without this file, the confirmation dialog box wouldn't appear.

!images/getting_started/confirm_dialog.png(Confirm Dialog)!

Congratulations, you can now create, show, list, update and destroy
posts. In the next section will see how Rails can aid us when creating
REST applications, and how we can refactor our Blog app to take
advantage of it.

h4. Going Deeper into REST

We've now covered all the CRUD actions of a REST app. We did so by
declaring separate routes with the appropriate verbs into
+config/routes.rb+. Here's how that file looks so far:

<ruby>
get "posts" => "posts#index"
get "posts/new"
post "posts" => "posts#create"
get "posts/:id" => "posts#show", :as => :post
get "posts/:id/edit" => "posts#edit"
put "posts/:id" => "posts#update"
delete "posts/:id" => "posts#destroy"
</ruby>

That's a lot to type for covering a single *resource*. Fortunately,
Rails provides a +resources+ method which can be used to declare a
standard REST resource. Here's how +config/routes.rb+ looks after the
cleanup:

<ruby>
Blog::Application.routes.draw do

  resources :posts

  root :to => "welcome#index"
end
</ruby>

If you run +rake routes+, you'll see that all the routes that we
declared before are still available:

<shell>
# rake routes
    posts GET    /posts(.:format)          posts#index
          POST   /posts(.:format)          posts#create
 new_post GET    /posts/new(.:format)      posts#new
edit_post GET    /posts/:id/edit(.:format) posts#edit
     post GET    /posts/:id(.:format)      posts#show
          PUT    /posts/:id(.:format)      posts#update
          DELETE /posts/:id(.:format)      posts#destroy
     root        /                         welcome#index
</shell>

Also, if you go through the motions of creating, updating and deleting
posts the app still works as before.

TIP: In general, Rails encourages the use of resources objects in place
of declaring routes manually. It was only done in this guide as a learning
exercise. For more information about routing, see
"Rails Routing from the Outside In":routing.html.

h3. Adding a Second Model

It's time to add a second model to the application. The second model will handle comments on
posts.

h4. Generating a Model

We're going to see the same generator that we used before when creating
the +Post+ model. This time we'll create a +Comment+ model to hold
reference of post comments. Run this command in your terminal:

<shell>
$ rails generate model Comment commenter:string body:text post:references
</shell>

This command will generate four files:

|_.File                                       |_.Purpose|
|db/migrate/20100207235629_create_comments.rb | Migration to create the comments table in your database (your name will include a different timestamp) |
| app/models/comment.rb                       | The Comment model |
| test/unit/comment_test.rb                   | Unit testing harness for the comments model |
| test/fixtures/comments.yml                  | Sample comments for use in testing |

First, take a look at +comment.rb+:

<ruby>
class Comment < ActiveRecord::Base
  belongs_to :post
  attr_accessible :body, :commenter
end
</ruby>

This is very similar to the +post.rb+ model that you saw earlier. The difference
is the line +belongs_to :post+, which sets up an Active Record _association_.
You'll learn a little about associations in the next section of this guide.

In addition to the model, Rails has also made a migration to create the
corresponding database table:

<ruby>
class CreateComments < ActiveRecord::Migration
  def change
    create_table :comments do |t|
      t.string :commenter
      t.text :body
      t.references :post

      t.timestamps
    end

    add_index :comments, :post_id
  end
end
</ruby>

The +t.references+ line sets up a foreign key column for the association between
the two models. And the +add_index+ line sets up an index for this association
column. Go ahead and run the migration:

<shell>
$ rake db:migrate
</shell>

Rails is smart enough to only execute the migrations that have not already been
run against the current database, so in this case you will just see:

<shell>
==  CreateComments: migrating =================================================
-- create_table(:comments)
   -> 0.0008s
-- add_index(:comments, :post_id)
   -> 0.0003s
==  CreateComments: migrated (0.0012s) ========================================
</shell>

h4. Associating Models

Active Record associations let you easily declare the relationship between two
models. In the case of comments and posts, you could write out the relationships
this way:

* Each comment belongs to one post.
* One post can have many comments.

In fact, this is very close to the syntax that Rails uses to declare this
association. You've already seen the line of code inside the Comment model that
makes each comment belong to a Post:

<ruby>
class Comment < ActiveRecord::Base
  belongs_to :post
end
</ruby>

You'll need to edit the +post.rb+ file to add the other side of the association:

<ruby>
class Post < ActiveRecord::Base
  validates :title, :presence => true,
                    :length => { :minimum => 5 }

  has_many :comments
end
</ruby>

These two declarations enable a good bit of automatic behavior. For example, if
you have an instance variable +@post+ containing a post, you can retrieve all
the comments belonging to that post as an array using +@post.comments+.

TIP: For more information on Active Record associations, see the "Active Record
Associations":association_basics.html guide.

h4. Adding a Route for Comments

As with the +welcome+ controller, we will need to add a route so that Rails knows
where we would like to navigate to see +comments+. Open up the
+config/routes.rb+ file again, and edit it as follows:

<ruby>
resources :posts do
  resources :comments
end
</ruby>

This creates +comments+ as a _nested resource_ within +posts+. This is another
part of capturing the hierarchical relationship that exists between posts and
comments.

TIP: For more information on routing, see the "Rails Routing from the Outside
In":routing.html guide.

h4. Generating a Controller

With the model in hand, you can turn your attention to creating a matching
controller. Again, we'll use the same generator we used before:

<shell>
$ rails generate controller Comments
</shell>

This creates six files and one empty directory:

|_.File/Directory                             |_.Purpose                                 |
| app/controllers/comments_controller.rb      | The Comments controller                  |
| app/views/comments/                         | Views of the controller are stored here  |
| test/functional/comments_controller_test.rb | The functional tests for the controller  |
| app/helpers/comments_helper.rb              | A view helper file                       |
| test/unit/helpers/comments_helper_test.rb   | The unit tests for the helper            |
| app/assets/javascripts/comment.js.coffee    | CoffeeScript for the controller          |
| app/assets/stylesheets/comment.css.scss     | Cascading style sheet for the controller |

Like with any blog, our readers will create their comments directly after
reading the post, and once they have added their comment, will be sent back to
the post show page to see their comment now listed. Due to this, our
+CommentsController+ is there to provide a method to create comments and delete
spam comments when they arrive.

So first, we'll wire up the Post show template
(+/app/views/posts/show.html.erb+) to let us make a new comment:

<erb>
<p>
  <strong>Title:</strong>
  <%= @post.title %>
</p>

<p>
  <strong>Text:</strong>
  <%= @post.text %>
</p>

<h2>Add a comment:</h2>
<%= form_for([@post, @post.comments.build]) do |f| %>
  <p>
    <%= f.label :commenter %><br />
    <%= f.text_field :commenter %>
  </p>
  <p>
    <%= f.label :body %><br />
    <%= f.text_area :body %>
  </p>
  <p>
    <%= f.submit %>
  </p>
<% end %>

<%= link_to 'Edit Post', edit_post_path(@post) %> |
<%= link_to 'Back to Posts', posts_path %>
</erb>

This adds a form on the +Post+ show page that creates a new comment by
calling the +CommentsController+ +create+ action. The +form_for+ call here uses
an array, which will build a nested route, such as +/posts/1/comments+.

Let's wire up the +create+:

<ruby>
class CommentsController < ApplicationController
  def create
    @post = Post.find(params[:post_id])
    @comment = @post.comments.create(params[:comment])
    redirect_to post_path(@post)
  end
end
</ruby>

You'll see a bit more complexity here than you did in the controller for posts.
That's a side-effect of the nesting that you've set up. Each request for a
comment has to keep track of the post to which the comment is attached, thus the
initial call to the +find+ method of the +Post+ model to get the post in question.

In addition, the code takes advantage of some of the methods available for an
association. We use the +create+ method on +@post.comments+ to create and save
the comment. This will automatically link the comment so that it belongs to that
particular post.

Once we have made the new comment, we send the user back to the original post
using the +post_path(@post)+ helper. As we have already seen, this calls the
+show+ action of the +PostsController+ which in turn renders the +show.html.erb+
template. This is where we want the comment to show, so let's add that to the
+app/views/posts/show.html.erb+.

<erb>
<p>
  <strong>Title:</strong>
  <%= @post.title %>
</p>

<p>
  <strong>Text:</strong>
  <%= @post.text %>
</p>

<h2>Comments</h2>
<% @post.comments.each do |comment| %>
  <p>
    <strong>Commenter:</strong>
    <%= comment.commenter %>
  </p>

  <p>
    <strong>Comment:</strong>
    <%= comment.body %>
  </p>
<% end %>

<h2>Add a comment:</h2>
<%= form_for([@post, @post.comments.build]) do |f| %>
  <p>
    <%= f.label :commenter %><br />
    <%= f.text_field :commenter %>
  </p>
  <p>
    <%= f.label :body %><br />
    <%= f.text_area :body %>
  </p>
  <p>
    <%= f.submit %>
  </p>
<% end %>

<%= link_to 'Edit Post', edit_post_path(@post) %> |
<%= link_to 'Back to Posts', posts_path %>
</erb>

Now you can add posts and comments to your blog and have them show up in the
right places.

!images/getting_started/post_with_comments.png(Post with Comments)!

h3. Refactoring

Now that we have posts and comments working, take a look at the
+app/views/posts/show.html.erb+ template. It is getting long and awkward. We can
use partials to clean it up.

h4. Rendering Partial Collections

First, we will make a comment partial to extract showing all the comments for the
post. Create the file +app/views/comments/_comment.html.erb+ and put the
following into it:

<erb>
<p>
  <strong>Commenter:</strong>
  <%= comment.commenter %>
</p>

<p>
  <strong>Comment:</strong>
  <%= comment.body %>
</p>
</erb>

Then you can change +app/views/posts/show.html.erb+ to look like the
following:

<erb>
<p>
  <strong>Title:</strong>
  <%= @post.title %>
</p>

<p>
  <strong>Text:</strong>
  <%= @post.text %>
</p>

<h2>Comments</h2>
<%= render @post.comments %>

<h2>Add a comment:</h2>
<%= form_for([@post, @post.comments.build]) do |f| %>
  <p>
    <%= f.label :commenter %><br />
    <%= f.text_field :commenter %>
  </p>
  <p>
    <%= f.label :body %><br />
    <%= f.text_area :body %>
  </p>
  <p>
    <%= f.submit %>
  </p>
<% end %>

<%= link_to 'Edit Post', edit_post_path(@post) %> |
<%= link_to 'Back to Posts', posts_path %>
</erb>

This will now render the partial in +app/views/comments/_comment.html.erb+ once
for each comment that is in the +@post.comments+ collection. As the +render+
method iterates over the <tt>@post.comments</tt> collection, it assigns each
comment to a local variable named the same as the partial, in this case
+comment+ which is then available in the partial for us to show.

h4. Rendering a Partial Form

Let us also move that new comment section out to its own partial. Again, you
create a file +app/views/comments/_form.html.erb+ containing:

<erb>
<%= form_for([@post, @post.comments.build]) do |f| %>
  <p>
    <%= f.label :commenter %><br />
    <%= f.text_field :commenter %>
  </p>
  <p>
    <%= f.label :body %><br />
    <%= f.text_area :body %>
  </p>
  <p>
    <%= f.submit %>
  </p>
<% end %>
</erb>

Then you make the +app/views/posts/show.html.erb+ look like the following:

<erb>
<p>
  <strong>Title:</strong>
  <%= @post.title %>
</p>

<p>
  <strong>Text:</strong>
  <%= @post.text %>
</p>

<h2>Add a comment:</h2>
<%= render "comments/form" %>

<%= link_to 'Edit Post', edit_post_path(@post) %> |
<%= link_to 'Back to Posts', posts_path %>
</erb>

The second render just defines the partial template we want to render,
<tt>comments/form</tt>. Rails is smart enough to spot the forward slash in that
string and realize that you want to render the <tt>_form.html.erb</tt> file in
the <tt>app/views/comments</tt> directory.

The +@post+ object is available to any partials rendered in the view because we
defined it as an instance variable.

h3. Deleting Comments

Another important feature of a blog is being able to delete spam comments. To do
this, we need to implement a link of some sort in the view and a +DELETE+ action
in the +CommentsController+.

So first, let's add the delete link in the
+app/views/comments/_comment.html.erb+ partial:

<erb>
<p>
  <strong>Commenter:</strong>
  <%= comment.commenter %>
</p>

<p>
  <strong>Comment:</strong>
  <%= comment.body %>
</p>

<p>
  <%= link_to 'Destroy Comment', [comment.post, comment],
               :method => :delete,
               :data => { :confirm => 'Are you sure?' } %>
</p>
</erb>

Clicking this new "Destroy Comment" link will fire off a <tt>DELETE
/posts/:id/comments/:id</tt> to our +CommentsController+, which can then use
this to find the comment we want to delete, so let's add a destroy action to our
controller:

<ruby>
class CommentsController < ApplicationController

  def create
    @post = Post.find(params[:post_id])
    @comment = @post.comments.create(params[:comment])
    redirect_to post_path(@post)
  end

  def destroy
    @post = Post.find(params[:post_id])
    @comment = @post.comments.find(params[:id])
    @comment.destroy
    redirect_to post_path(@post)
  end

end
</ruby>

The +destroy+ action will find the post we are looking at, locate the comment
within the <tt>@post.comments</tt> collection, and then remove it from the
database and send us back to the show action for the post.


h4. Deleting Associated Objects

If you delete a post then its associated comments will also need to be deleted.
Otherwise they would simply occupy space in the database. Rails allows you to
use the +dependent+ option of an association to achieve this. Modify the Post
model, +app/models/post.rb+, as follows:

<ruby>
class Post < ActiveRecord::Base
  validates :title, :presence => true,
                    :length => { :minimum => 5 }
  has_many :comments, :dependent => :destroy
end
</ruby>

h3. Security

If you were to publish your blog online, anybody would be able to add, edit and
delete posts or delete comments.

Rails provides a very simple HTTP authentication system that will work nicely in
this situation.

In the +PostsController+ we need to have a way to block access to the various
actions if the person is not authenticated, here we can use the Rails
<tt>http_basic_authenticate_with</tt> method, allowing access to the requested
action if that method allows it.

To use the authentication system, we specify it at the top of our
+PostsController+, in this case, we want the user to be authenticated on every
action, except for +index+ and +show+, so we write that:

<ruby>
class PostsController < ApplicationController

  http_basic_authenticate_with :name => "dhh", :password => "secret", :except => [:index, :show]

  def index
    @posts = Post.all
# snipped for brevity
</ruby>

We also only want to allow authenticated users to delete comments, so in the
+CommentsController+ we write:

<ruby>
class CommentsController < ApplicationController

  http_basic_authenticate_with :name => "dhh", :password => "secret", :only => :destroy

  def create
    @post = Post.find(params[:post_id])
# snipped for brevity
</ruby>

Now if you try to create a new post, you will be greeted with a basic HTTP
Authentication challenge

!images/challenge.png(Basic HTTP Authentication Challenge)!

h3. What's Next?

Now that you've seen your first Rails application, you should feel free to
update it and experiment on your own. But you don't have to do everything
without help. As you need assistance getting up and running with Rails, feel
free to consult these support resources:

* The "Ruby on Rails guides":index.html
* The "Ruby on Rails Tutorial":http://railstutorial.org/book
* The "Ruby on Rails mailing list":http://groups.google.com/group/rubyonrails-talk
* The "#rubyonrails":irc://irc.freenode.net/#rubyonrails channel on irc.freenode.net

Rails also comes with built-in help that you can generate using the rake command-line utility:

* Running +rake doc:guides+ will put a full copy of the Rails Guides in the +doc/guides+ folder of your application. Open +doc/guides/index.html+ in your web browser to explore the Guides.
* Running +rake doc:rails+ will put a full copy of the API documentation for Rails in the +doc/api+ folder of your application. Open +doc/api/index.html+ in your web browser to explore the API documentation.

h3. Configuration Gotchas

The easiest way to work with Rails is to store all external data as UTF-8. If
you don't, Ruby libraries and Rails will often be able to convert your native
data into UTF-8, but this doesn't always work reliably, so you're better off
ensuring that all external data is UTF-8.

If you have made a mistake in this area, the most common symptom is a black
diamond with a question mark inside appearing in the browser. Another common
symptom is characters like "Ã¼" appearing instead of "ü". Rails takes a number
of internal steps to mitigate common causes of these problems that can be
automatically detected and corrected. However, if you have external data that is
not stored as UTF-8, it can occasionally result in these kinds of issues that
cannot be automatically detected by Rails and corrected.

Two very common sources of data that are not UTF-8:
* Your text editor: Most text editors (such as Textmate), default to saving files as
  UTF-8. If your text editor does not, this can result in special characters that you
  enter in your templates (such as é) to appear as a diamond with a question mark inside
  in the browser. This also applies to your I18N translation files.
  Most editors that do not already default to UTF-8 (such as some versions of
  Dreamweaver) offer a way to change the default to UTF-8. Do so.
* Your database. Rails defaults to converting data from your database into UTF-8 at
  the boundary. However, if your database is not using UTF-8 internally, it may not
  be able to store all characters that your users enter. For instance, if your database
  is using Latin-1 internally, and your user enters a Russian, Hebrew, or Japanese
  character, the data will be lost forever once it enters the database. If possible,
  use UTF-8 as the internal storage of your database.
