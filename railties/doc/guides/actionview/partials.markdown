A Guide to Using Partials
===============================

This guide elaborates on the use and function of partials in Ruby on Rails. As your Rails application grows, your view templates can start to contain a lot of duplicate view code. To manage and reduce this complexity, you can by abstract view template code into partials. Partials are reusable snippets of eRB template code stored in separate files with an underscore ('_') prefix.

Partials can be located anywhere in the `app/views` directory. File extensions for partials work just like other template files, they bear an extension that denotes what kind of code they generate. For example, `_animal.html.erb` and `_animal.xml.erb` are valid filenames for partials.

Partials can be inserted in eRB template code by calling the `render` method with the `:partial` option. For example:

	<%= render :partial => 'foo' %>

This inserts the result of evaluating the template `_foo.html.erb` into the parent template file at this location. Note that `render` assumes that the partial will be in the same directory as the calling parent template and have the same file extension. Partials can be located anywhere within the `app/views` directory. To use a partial located in a different directory then it the parent, add a '/' before it:

	<%= render :partial => '/common/foo' %>

Loads the partial file from the `app/views/common/_foo.html.erb` directory.

Abstracting views into partials can be approached in a number of different ways, depending on the situation. Sometimes, the code that you are abstracting is a specialized view of an object or a collection of objects. Other times, you can look at partials as a reusable subroutine. We'll explore each of these approaches and when to use them as well as the syntax for calling them.

Partials as a View Subroutine
-----------------------------

Using the `:locals` option, you can pass a hash of values which will be treated as local variables within the partial template.

	<%= render :partial => "person", :locals => { :name => "david" } %>

The variable `name` contains the value `"david"` within the `_person.html.erb` template. Passing variables in this way allows you to create modular, reusable template files. Note that if you want to make local variables that are optional in some use cases, you will have to set them to a sentinel value such as `nil` when they have not been passed. So, in the example above, if the `name` variable is optional in some use cases, you must set:

	<% name ||= nil -%>

So that you can later check:

	<% if name -%>
		<p>Hello, <%= name %>!</p>
	<% end -%>

Otherwise, the if statement will throw an error at runtime.

Another thing to be aware of is that instance variables that are visible to the parent view template are visible to the partial. So you might be tempted to do this:

	<%= render :partial => "person" %>

And then within the partial:

	<% if @name -%>
		<p>Hello, <%= @name %>!</p>
	<% end -%>

The potential snag here is that if multiple templates start to rely on this partial, you will need to maintain an instance variable with the same name across all of these templates and controllers. This approach can quickly become brittle if overused.

Partials as a View of an Object
--------------------------------

Another way to look at partials is to view them as mini-views of a particular object or instance variable. Use the `:object` option to pass an object assigns that object to an instance variable named after the partial itself. For example:

	# Renders the partial, making @new_person available through
	# the local variable 'person'
	render :partial => "person", :object => @new_person

If the instance variable `name` in the parent template matches the name of the partial, you can use a shortcut:

	render :partial => "person"

Now the value that was in `@person` in the parent template is accessible as `person` in the partial.

Partials as a View of a Collection
-----------------------------------

Often it is the case that you need to display not just a single object, but a collection of objects. Rather than having to constantly nest the same partial within the same iterator code, Rails provides a syntactical shortcut using the `:collection` option:

	# Renders a collection of the same partial by making each element
	# of @winners available through the local variable "person" as it
	# builds the complete response.
	render :partial => "person", :collection => @winners

This calls the `_person.html.erb` partial for each person in the `@winners` collection. This also creates a local variable within the partial called `partial_counter` which contains the index of the current value. So for example:

	<%= partial_counter %>) <%= person -%>

Where `@winners` contains three people, produces the following output:

	1) Bill
	2) Jeff
	3) Nick

One last detail, you can place an arbitrary snippet of code in between the objects using the `:spacer_template` option.

	# Renders the same collection of partials, but also renders the
	# person_divider partial between each person partial.
	render :partial => "person", :collection => @winners, :spacer_template => "person_divider"
