Rails Nested Model Forms
========================

Creating a form for a model _and_ its associations can become quite tedious. Therefore Rails provides helpers to assist in dealing with the complexities of generating these forms _and_ the required CRUD operations to create, update, and destroy associations.

After reading this guide, you will know:

* do stuff.

--------------------------------------------------------------------------------

NOTE: This guide assumes the user knows how to use the [Rails form helpers](form_helpers.html) in general. Also, it's **not** an API reference. For a complete reference please visit [the Rails API documentation](http://api.rubyonrails.org/).


Model setup
-----------

To be able to use the nested model functionality in your forms, the model will need to support some basic operations.

First of all, it needs to define a writer method for the attribute that corresponds to the association you are building a nested model form for. The `fields_for` form helper will look for this method to decide whether or not a nested model form should be built.

If the associated object is an array, a form builder will be yielded for each object, else only a single form builder will be yielded.

Consider a Person model with an associated Address. When asked to yield a nested FormBuilder for the `:address` attribute, the `fields_for` form helper will look for a method on the Person instance named `address_attributes=`.

### ActiveRecord::Base model

For an ActiveRecord::Base model and association this writer method is commonly defined with the `accepts_nested_attributes_for` class method:

#### has_one

```ruby
class Person < ActiveRecord::Base
  has_one :address
  accepts_nested_attributes_for :address
end
```

#### belongs_to

```ruby
class Person < ActiveRecord::Base
  belongs_to :firm
  accepts_nested_attributes_for :firm
end
```

#### has_many / has_and_belongs_to_many

```ruby
class Person < ActiveRecord::Base
  has_many :projects
  accepts_nested_attributes_for :projects
end
```

NOTE: For greater detail on associations see [Active Record Associations](association_basics.html).
For a complete reference on associations please visit the API documentation for [ActiveRecord::Associations::ClassMethods](http://api.rubyonrails.org/classes/ActiveRecord/Associations/ClassMethods.html).

### Custom model

As you might have inflected from this explanation, you _don't_ necessarily need an ActiveRecord::Base model to use this functionality. The following examples are sufficient to enable the nested model form behavior:

#### Single associated object

```ruby
class Person
  def address
    Address.new
  end

  def address_attributes=(attributes)
    # ...
  end
end
```

#### Association collection

```ruby
class Person
  def projects
    [Project.new, Project.new]
  end

  def projects_attributes=(attributes)
    # ...
  end
end
```

NOTE: See (TODO) in the advanced section for more information on how to deal with the CRUD operations in your custom model.

Views
-----

### Controller code

A nested model form will _only_ be built if the associated object(s) exist. This means that for a new model instance you would probably want to build the associated object(s) first.

Consider the following typical RESTful controller which will prepare a new Person instance and its `address` and `projects` associations before rendering the `new` template:

```ruby
class PeopleController < ApplicationController
  def new
    @person = Person.new
    @person.built_address
    2.times { @person.projects.build }
  end

  def create
    @person = Person.new(params[:person])
    if @person.save
      # ...
    end
  end
end
```

NOTE: Obviously the instantiation of the associated object(s) can become tedious and not DRY, so you might want to move that into the model itself. ActiveRecord::Base provides an `after_initialize` callback which is a good way to refactor this.

### Form code

Now that you have a model instance, with the appropriate methods and associated object(s), you can start building the nested model form.

#### Standard form

Start out with a regular RESTful form:

```erb
<%= form_for @person do |f| %>
  <%= f.text_field :name %>
<% end %>
```

This will generate the following html:

```html
<form action="/people" class="new_person" id="new_person" method="post">
  <input id="person_name" name="person[name]" type="text" />
</form>
```

#### Nested form for a single associated object

Now add a nested form for the `address` association:

```erb
<%= form_for @person do |f| %>
  <%= f.text_field :name %>

  <%= f.fields_for :address do |af| %>
    <%= af.text_field :street %>
  <% end %>
<% end %>
```

This generates:

```html
<form action="/people" class="new_person" id="new_person" method="post">
  <input id="person_name" name="person[name]" type="text" />

  <input id="person_address_attributes_street" name="person[address_attributes][street]" type="text" />
</form>
```

Notice that `fields_for` recognized the `address` as an association for which a nested model form should be built by the way it has namespaced the `name` attribute.

When this form is posted the Rails parameter parser will construct a hash like the following:

```ruby
{
  "person" => {
    "name" => "Eloy Duran",
    "address_attributes" => {
      "street" => "Nieuwe Prinsengracht"
    }
  }
}
```

That's it. The controller will simply pass this hash on to the model from the `create` action. The model will then handle building the `address` association for you and automatically save it when the parent (`person`) is saved.

#### Nested form for a collection of associated objects

The form code for an association collection is pretty similar to that of a single associated object:

```erb
<%= form_for @person do |f| %>
  <%= f.text_field :name %>

  <%= f.fields_for :projects do |pf| %>
    <%= pf.text_field :name %>
  <% end %>
<% end %>
```

Which generates:

```html
<form action="/people" class="new_person" id="new_person" method="post">
  <input id="person_name" name="person[name]" type="text" />

  <input id="person_projects_attributes_0_name" name="person[projects_attributes][0][name]" type="text" />
  <input id="person_projects_attributes_1_name" name="person[projects_attributes][1][name]" type="text" />
</form>
```

As you can see it has generated 2 `project name` inputs, one for each new `project` that was built in the controller's `new` action. Only this time the `name` attribute of the input contains a digit as an extra namespace. This will be parsed by the Rails parameter parser as:

```ruby
{
  "person" => {
    "name" => "Eloy Duran",
    "projects_attributes" => {
      "0" => { "name" => "Project 1" },
      "1" => { "name" => "Project 2" }
    }
  }
}
```

You can basically see the `projects_attributes` hash as an array of attribute hashes, one for each model instance.

NOTE: The reason that `fields_for` constructed a hash instead of an array is that it won't work for any form nested deeper than one level deep.

TIP: You _can_ however pass an array to the writer method generated by `accepts_nested_attributes_for` if you're using plain Ruby or some other API access. See (TODO) for more info and example.
