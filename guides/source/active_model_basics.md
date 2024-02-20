**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON https://guides.rubyonrails.org.**

Active Model Basics
===================

This guide will provide you with what you need to get started using Active
Model. Active Model provides a way for Action Pack and Action View helpers to
interact with plain Ruby objects. It also helps to build custom ORMs for use
outside of the Rails framework.

After reading this guide, you will know:

* What Active Model is, and how it relates to Active Record.
* The different modules that are included in Active Model.
* How to use Active Model in your classes.

--------------------------------------------------------------------------------

What is Active Model?
---------------------

To understand Active Model, you need to know a little about [Active
Record](active_record_basics.html). Active Record is an ORM (Object Relational
Mapper) that connects objects whose data requires persistent storage to a
relational database. However, it has functionality that is useful outside of the
ORM, some of these include validations, callbacks, translations, the ability to
create custom attributes etc.

Some of this functionality was abstracted from Active Record to form Active
Model. Active Model is a library containing various modules that can be used on
plain Ruby objects that require model-like features but are not tied to any
table in a database.

Some of these modules are explained below.

### API

`ActiveModel::API` adds the ability for a class to work with [Action
Pack](https://api.rubyonrails.org/files/actionpack/README_rdoc.html) and [Action
View](action_view_overview.html) right out of the box.

When including `ActiveModel::API`, other modules are included by default which
enables you to get features like:

- [Attribute Assignment](active_model_basics.html#attribute-assignment)
- [Conversion](active_model_basics.html#conversion)
- [Naming](active_model_basics.html#naming)
- [Translation](active_model_basics.html#translation)
- [Validations](active_model_basics.html#validations)

Here is an example of a class that includes `ActiveModel::API` and how it can be
used:

```ruby
class EmailContact
  include ActiveModel::API

  attr_accessor :name, :email, :message
  validates :name, :email, :message, presence: true

  def deliver
    if valid?
      # deliver email
    end
  end
end
```

```irb
irb> email_contact = EmailContact.new(name: "David", email: "david@example.com", message: "Hello World")

irb> email_contact.name # attribute assignment
=> "David"

irb> email_contact.to_model == email_contact # conversion
=> true

irb> email_contact.model_name.name # naming
=> EmailContact

irb> email_contact.human_attribute_name("name") # translation if the locale is set
=> "Name"

irb> email_contact.valid? # validations
=> true
```

Any class that includes `ActiveModel::API` can be used with `form_with`,
`render` and any other [Action View helper
methods](https://api.rubyonrails.org/classes/ActionView/Helpers.html), just like
Active Record objects.

For example, `form_with` can be used to create a form for an `EmailContact`
object as follows:

```erb+html
<%= form_with model: EmailContact.new do |form| %>
  <%= form.text_field :name %>
<% end %>

# =>
<form action="/email_contacts" method="post" data-remote="true">
  <input type="text" name="email_contact[name]">
</form>
```

`render` can be used to render a partial with the object as a local variable:

```erb+html
<%= render partial: "email_contact", email_contact: EmailContact.new(name: "David", email: "david@example.com", message: "Hello World") %>
```

### Attributes

`ActiveModel::Attributes` allows you to define data types, set default values,
and handle casting and serialization on plain Ruby objects. This can be useful
for form data which will produce Active Record-like conversion for things like
dates and booleans on regular objects.

To use Attributes, include the module in your model class and define your
attributes using the `attribute` macro. It accepts a name, a cast type, a
default value, and any other options supported by the attribute type.

```ruby
class Person
  include ActiveModel::Attributes

  attribute :name, :string
  attribute :date_of_birth, :date
  attribute :active, :boolean, default: true
end
```

```irb
irb> person = Person.new

irb> person.name = "Jane"
irb> person.name
=> "Jane"

# casts the string to a date set by the attribute
irb> person.date_of_birth = "2020-01-01"
irb> person.date_of_birth
=> Wed, 01 Jan 2020
irb> person.date_of_birth.class
=> Date

# obtains the default value set by the attribute
irb> person.active
=> true

# casts the string to a boolean set by the attribute
irb> person.active = "0"
irb> person.active
=> false
```

Some additional methods described below are available when using
`ActiveModel::Attributes`.

#### Method: `attribute_names`

The `attribute_names` method returns an array of attribute names.

```irb
irb> Person.attribute_names
=> ["name", "date_of_birth", "active"]
```

#### Method: `attributes`

The `attributes` method returns a hash of all the attributes with their names as
keys and the values of the attributes as values.

```irb
irb> person = Person.new
irb> person.name = "John"
irb> person.date_of_birth = "1998-01-01"
irb> person.active = false

irb> person.attributes
=> {"name"=>"John", "date_of_birth"=>Thu, 01 Jan 1998, "active"=>false}
```

### Attribute Assignment

`ActiveModel::AttributeAssignment` allows you to set an object's attributes by
passing in a hash of attributes with keys matching the attribute names. This is
useful when you want to set multiple attributes at once.

Consider the following class:

```ruby
class Person
  include ActiveModel::AttributeAssignment

  attr_accessor :name, :date_of_birth, :active
end
```

You can set multiple attributes at once using the `assign_attributes` method:

```irb
irb> person = Person.new

# using the `assign_attributes` method to set multiple attributes at once
irb> person.assign_attributes(name: "John", date_of_birth: "1998-01-01", active: false)

# check the values of the attributes that were assigned
irb> person.name
=> "John"
irb> person.date_of_birth
=> Thu, 01 Jan 1998
irb> person.active
=> false
```

If the passed hash responds to the `permitted?` method and the return value of
this method is `false`, an `ActiveModel::ForbiddenAttributesError` exception is
raised.

#### Method alias: `attributes=`

The `assign_attributes` method has an alias `attributes=`.

INFO: A method alias is a method that performs the same action as another
method, but is called something different.

The following example demonstrates the use of the `attributes=` method to set
multiple attributes at once:

```irb
irb> person = Person.new

# using the `attributes= method` to set multiple attributes at once
irb> person.attributes = { name: "John", date_of_birth: "1998-01-01", active: false }

irb> person.name
=> "John"

# using the `assign_attributes` method to set multiple attributes at once
irb> person.assign_attributes(name: "Jane")

irb> person.name
=> "Jane"
irb> person.date_of_birth
=> "1998-01-01"
```

### Attribute Methods

`ActiveModel::AttributeMethods` provides a way to define methods dynamically for
attributes of a model. This module is particularly useful to simplify attribute
access and manipulation, and it can add custom prefixes and suffixes to the
methods of a class. You can define the prefixes and suffixes and which methods
on the object will use them as follows:

1. Include `ActiveModel::AttributeMethods` in your class.
2. Call each of the methods you want to add, such as `attribute_method_suffix`,
   `attribute_method_prefix`, `attribute_method_affix`.
3. Call the `define_attribute_methods` after the other methods to declare the
   attribute that should be prefixed and suffixed.
4.  Define the various generic `_attribute` methods that you have declared. The
    parameter `attribute` in these methods will be replaced by the argument
    passed in `define_attribute_methods`. In our case it is `name`.

NOTE: `attribute_method_prefix` and `attribute_method_suffix` are used to define
the prefixes and suffixes that will be used to create the methods.
`attribute_method_affix` is used to define both the prefix and suffix at the
same time.

```ruby
class Person
  include ActiveModel::AttributeMethods

  attribute_method_affix prefix: "reset_", suffix: "_to_default!"
  attribute_method_prefix "first_"
  attribute_method_prefix "last_"
  attribute_method_suffix "_short?"

  define_attribute_methods "name"

  attr_accessor :name

  private

  # this will create a method 'first_name'
  def first_attribute(attribute)
    public_send(attribute).split.first
  end

  # this will create a method 'last_name'
  def last_attribute(attribute)
    public_send(attribute).split.last
  end

  # this will create a method 'name_short?'
  def attribute_short?(attribute)
    public_send(attribute).length < 5
  end

  # this will create a method 'reset_name_to_default!'
  def reset_attribute_to_default!(attribute)
    public_send("#{attribute}=", "Default Name")
  end
end
```

```irb
irb> person = Person.new

irb> person.name = "Jane Doe"

# utilizing the `first_name` and `last_name` prefix methods
irb> person.first_name
=> "Jane"
irb> person.last_name
=> "Doe"

# utilizing the `name_short?` suffix method
irb> person.name_short?
=> false

# utilizing the `reset_name_to_default!` prefix and suffix methods
irb> person.reset_name_to_default!
=> "Default Name"
```

If you call a method that is not defined, it will raise a `method_missing`
error.

#### Method: `alias_attribute`

`ActiveModel::AttributeMethods` also provides aliasing of attribute methods.
This can be done by using the `alias_attribute` method.

```ruby
class Person
  include ActiveModel::AttributeMethods

  attribute_method_suffix '_short?'
  define_attribute_methods :name

  attr_accessor :name

  alias_attribute :nickname, :name

  private

  def attribute_short?(attribute)
    public_send(attribute).length < 5
  end

end
```

```irb
irb> person = Person.new

irb> person.name = "Joe"

irb> person.name
=> "Joe"

# `nickname` is the alias for `name`, and returns the same value
irb> person.nickname
=> "Joe"
irb> person.name_short?
=> true

# `nickname_short?` is the alias for `name_short?`, and returns the same value
irb> person.nickname_short?
=> true
```

### Callbacks

`ActiveModel::Callbacks` gives plain Ruby objects Active Record style callbacks.
The callbacks allow you to hook into model lifecycle events, such as
`before_update` and `after_create`, as well as to define custom logic to be
executed at specific points in the model's lifecycle.

You can implement `ActiveModel::Callbacks` by following the steps below:

1. Extend `ActiveModel::Callbacks` in your class.
2. Using `define_model_callbacks`, define a list of methods that you want
   callbacks attached to. When you define a method like `:update`, it will
   provide all three standard callbacks (before, around and after) for the
   `:update` method.
3. Wrap the methods you want callbacks on in a block so that the callbacks get a
   chance to fire.
4. Then in your class, you can use the `before_create`, `after_create`, and
   `around_create` methods, just as you would in an Active Record model.

```ruby
class Person
  extend ActiveModel::Callbacks

  define_model_callbacks :update

  before_update :reset_me
  after_update :finalize_me
  around_update :log_me

  def update
    run_callbacks(:update) do
      puts "update method called"
      # This is the callback method executed when `update` is called on an object.
    end
  end

  def reset_me
    puts "reset_me method: called before the update method"
    # When update is called on an object, then this method is called by `before_update` callback
  end

  def finalize_me
    puts "finalize_me method: called after the update method"
    # When update is called on an object, then this method is called by `after_update` callback
  end

  def log_me
    puts "log_me method: called around the update method"
    yield
    puts "log_me method: block successfully called"
    # When update is called on an object, then this method is called by `around_update` callback
  end
end
```

The above class will yield the following which indicates the order in which the
callbacks are being called:

```irb
irb> person = Person.new

irb> person.update
reset_me method: called before the update method
log_me method: called around the update method
update method called
log_me method: block successfully called
finalize_me method: called after the update method
=> nil
```

As per the above example, when defining an 'around' callback remember to `yield`
to the block, otherwise, it won't be executed.

#### Defining Specific Callbacks

You can choose to create specific callbacks by passing a hash to the
`define_model_callbacks` method:

```ruby
define_model_callbacks :update, :create,  only: [:after, :before]
```

The `only: <type>` hash will apply to all callbacks defined on that method call.
To get around this you can call the `define_model_callbacks` method as many
times as you need like below:

```ruby
define_model_callbacks :create,  only: :after
define_model_callbacks :update,  only: :before
define_model_callbacks :destroy, only: :around
```

This will create `after_create`, `before_update`, and `around_destroy` methods
only.

#### Defining Callbacks with a Class

You can pass a class to `before_<type>`, `after_<type>` and `around_<type>`, in
which case the callback will call that class's `<action>_<type>` method thus
passing the object that the callback is being called on.

```ruby
  class MyModel
    extend ActiveModel::Callbacks
    define_model_callbacks :create

    before_create AnotherClass
  end

  class AnotherClass
    def self.before_create(obj)
      # obj is the MyModel instance that the callback is being called on
    end
  end
```

NOTE: `method_name` passed to `define_model_callbacks` must not end with `!`,
`?` or `=`. In addition, defining the same callback multiple times will
overwrite previous callback definitions.

Like the Active Record methods, the callback chain is aborted as soon as one of
the methods throws `:abort`.

### Conversion

`ActiveModel::Conversion` is a collection of methods that allow you to convert
your object to different forms for different purposes. A common use case is to
convert your object to a string or an integer to build URLs, form fields, and
more.

The `ActiveModel::Conversion` module adds the following methods: `to_model`,
`to_key`, `to_param`, and `to_partial_path` to classes.

The return values of the methods depend on whether `persisted?` is defined and
if an `id` is provided. The `persisted?` method should return true if the object
has been saved to the database or store, otherwise, it should return `false`.
The `id` should reference the id of the object or nil if the object is not
saved.

```ruby
class Person
  include ActiveModel::Conversion

  def initialize(id)
    @id = id
  end

  def persisted?
    true
  end
end
```

#### to_model

The `to_model` method returns the object itself.

```irb
irb> person = Person.new(1)
irb> person.to_model == person
=> true
```

If your model does not act like an Active Model object, then you should
define`:to_model` yourself returning a proxy object that wraps your object with
Active Model compliant methods.

```ruby
class Person
  def to_model
    # a proxy object that wraps your object with Active Model compliant methods.
    PersonModel.new(self)
  end
end
```

#### to_key

The `to_key` method returns an array of the object's key attributes if any of
the attributes are set, whether or not the object is persisted. Returns nil if
there are no key attributes.

```irb
irb> person.to_key
=> [1]
```

NOTE: A key attribute is an attribute that is used to identify the object. For
example, in a database-backed model, the key attribute is the primary key.

#### to_param

The `to_param` method returns a `string` representation of the object's key
suitable for use in URLs, or `nil` in the case where `persisted?` is `false`.

```irb
irb> person.to_param
=> "1"
```

#### to_partial_path

The `to_partial_path` method returns a `string` representing the path associated
with the object. ActionPack uses this to find a suitable partial to represent
the object.

```irb
irb> person.to_partial_path
=> "people/person"
```

### Dirty

`ActiveModel::Dirty` is useful for tracking changes made to model attributes
before they are saved. This functionality allows you to determine which
attributes have been modified, what their previous and current values are, and
perform actions based on those changes. It's particularly handy for auditing,
validation, and conditional logic within your application. It provides a way to
track changes in your object in the same way as Active Record.

An object becomes dirty when it has gone through one or more changes to its
attributes and has not been saved. It has attribute-based accessor methods.

To use `ActiveModel::Dirty`, you need to:

1. Include the module in your class.
- Define the attribute methods that you want to track changes for, using
  `define_attribute_methods`.
2. Call `[attr_name]_will_change!` before each change to the tracked attribute.
3. Call `changes_applied` after the changes are persisted.
4. Call `clear_changes_information` when you want to reset the changes
   information.
5. Call `restore_attributes` when you want to restore previous data.

You can then use the methods provided by `ActiveModel::Dirty` to query the
object for its list of all changed attributes, the original values of the
changed attributes, and the changes made to the attributes.

Let's consider a Person class with attributes `first_name` and `last_name`:

```ruby
class Person
  include ActiveModel::Dirty

  define_attribute_methods :first_name, :last_name

  def initialize
    @first_name = nil
    @last_name = nil
  end

  def first_name
    @first_name
  end

  def first_name=(value)
    first_name_will_change! unless value == @first_name
    @first_name = value
  end

  def last_name
    @last_name
  end

  def last_name=(value)
    last_name_will_change! unless value == @last_name
    @last_name = value
  end

  def save
    # Persist data - clears dirty data and moves `changes` to `previously_changed`.
    changes_applied
  end

  def reload!
    # Clears all dirty data: current changes and previous changes.
    clear_changes_information
  end

  def rollback!
   # Restore all previous data of the provided attributes.
    restore_attributes
  end
end
```

#### Querying an Object Directly for its List of All Changed Attributes

```irb
irb> person = Person.new

# A newly instantiated `Person` object is unchanged:
irb> person.changed?
=> false

irb> person.first_name = "Jane Doe"
irb> person.first_name
=> "Jane Doe"
```

**`changed?`** returns true if any of the attributes have unsaved changes,
`false` otherwise.

```irb
irb> person.changed?
=> true
```

**`changed`** returns an array with the name of the attributes containing
unsaved changes.

```irb
irb> person.changed
=> ["first_name"]
```

**`changed_attributes`** returns a hash of the attributes with unsaved changes
indicating their original values like `attr => original value`.

```irb
irb> person.changed_attributes
=> {"first_name"=>nil}
```

**`changes`** returns a Hash of changes, with the attribute names as the keys,
and the values as an array of the original and new values like `attr =>
[original value, new value]`.

```
irb> person.changes
=> {"first_name"=>[nil, "Jane Doe"]}
```

**`previous_changes`** returns a hash of attributes that were changed before the
model was saved.

```irb
irb> person.save
irb> person.previous_changes
=> {"first_name"=>[nil, "Jane Doe"]}
```

#### Attribute-based Accessor Methods

```irb
irb> person = Person.new

irb> person.changed?
=> false

irb> person.first_name = "John Doe"
irb> person.first_name
=> "John Doe"
```

**[attr_name]_changed?** checks whether the particular attribute has been
changed or not.

```
irb> person.first_name_changed?
=> true
```

**[attr_name]_was** tracks the previous value of the attribute.

```irb
irb> person.first_name_was
=> nil
```

**[attr_name]_change** tracks both the previous and current values of the
changed attribute. Returns an array if changed, otherwise returns nil.

```irb
irb> person.first_name_change
=> [nil, "John Doe"]
irb> person.last_name_change
=> nil
```

**[attr_name]_previously_changed?** checks whether the particular attribute has
been changed before the model was saved.

```irb
irb> person.first_name_previously_changed?
=> false
irb> person.save
irb> person.first_name_previously_changed?
=> true
```

**[attr_name]_previous_change** tracks both previous and current values of the
changed attribute before the model was saved. Returns an array if changed,
otherwise returns nil.

```irb
irb> person.first_name_previous_change
=> [nil, "John Doe"]
```

### Validations

The `ActiveModel::Validations` module adds the ability to validate objects and
it is important for ensuring data integrity and consistency within your
application. By incorporating validations into your models, you can define rules
that govern the correctness of attribute values before they are saved to the
database. This helps prevent invalid data from being persisted, maintaining the
integrity of your database records.

```ruby
class Person
  include ActiveModel::Validations

  attr_accessor :name, :email, :token

  validates :name, presence: true
  validates_format_of :email, with: /\A([^\s]+)((?:[-a-z0-9]\.)[a-z]{2,})\z/i
  validates! :token, presence: true
end
```

```irb
irb> person = Person.new
irb> person.token = "2b1f325"
irb> person.valid?
=> false

irb> person.name = "vishnu"
irb> person.email = "me"
irb> person.valid?
=> false

irb> person.email = "me@vishnuatrai.com"
irb> person.valid?
=> true

# token uses validate! and will raise an exception when not set.
irb> person.token = nil
irb> person.valid?
=> "Token can't be blank (ActiveModel::StrictValidationFailed)"
```

#### Validation Methods and Options

You can add validations using some of the following methods:

- `validate`: Adds validation through a method or a block to the class. You can
  read more about how to use `validate`
  [here](https://api.rubyonrails.org/classes/ActiveModel/Validations/ClassMethods.html#method-i-validate).

- `validates`:An attribute can be passed to the `validates` method and it
  provides a shortcut to all default validators. You can read more about how to
  use `validates`
  [here](https://api.rubyonrails.org/classes/ActiveModel/Validations/ClassMethods.html#method-i-validates).

- `validates!` or setting `strict: true`: Used to define validations that cannot
  be corrected by end users and are considered exceptional. Each validator
  defined with a bang or `:strict` option set to true will always raise
  `ActiveModel::StrictValidationFailed` instead of adding to the errors when
  validation fails.

- `validates_with`: Passes the record off to the class or classes specified and
  allows them to add errors based on more complex conditions.

- `validates_each`: Validates each attribute against a block.

Some of the options below can be used with certain validators. To determine if
the option you're using can be used with a specific validator, read through the
documentation
[here](https://api.rubyonrails.org/classes/ActiveModel/Validations/ClassMethods.html).

- `:on`: Specifies the context in which to add the validation. You can pass a
symbol or an array of symbols. (e.g. `on: :create` or `on:
:custom_validation_context` or `on: [:create, :custom_validation_context]`).
Validations without an `:on` option will run no matter the context. Validations
with some `:on` option will only run in the specified context.

- `:if`: Specifies a method, proc or string to call to determine if the
  validation should occur (e.g. `if: :allow_validation`, or `if: Proc.new {
  |user| user.signup_step > 2 }`). The method, proc or string should return or
  evaluate to a `true` or `false` value.

- `:unless`: Specifies a method, proc or string to call to determine if the
  validation should not occur (e.g. `unless: :skip_validation`, or `unless:
  Proc.new { |user| user.signup_step <= 2 }`). The method, proc or string should
  return or evaluate to a `true` or `false` value.

- `:allow_nil`: Skip the validation if the attribute is `nil`.

- `:allow_blank`: Skip the validation if the attribute is blank.

- `:strict`: If the `:strict` option is set to true, it will raise
  ActiveModel::StrictValidationFailed instead of adding the error. `:strict`
  option can also be set to any other exception.

NOTE: Calling `validate` multiple times on the same method will overwrite
previous definitions.

#### Errors

`ActiveModel::Validations` automatically adds an `errors` method to your
instances initialized with a new `ActiveModel::Errors` object, so there is no
need for you to do this manually.

Run `valid?` on the object to check if the object is valid or not. If the object
is not valid, it will return `false` and the errors will be added to the
`errors` object.

```irb
irb> person = Person.new

irb> person.email = "me"
irb> person.valid?
=> Token can't be blank (ActiveModel::StrictValidationFailed)

irb> person.errors
=>  {:name=>["can't be blank"], :email=>["is invalid"]}
```

### Naming

`ActiveModel::Naming` adds several class methods which make naming and routing
easier to manage. The module defines the `model_name` class method which will
define several accessors using some `ActiveSupport::Inflector` methods.

```ruby
class Person
  extend ActiveModel::Naming
end
```

**`name`** returns the name of the model

```irb
irb> Person.model_name.name
=> "Person"
```

**`singular`** returns the singular class name of a record or class.

```irb
irb> Person.model_name.singular
=> "person"
```

**`plural`** returns the plural class name of a record or class.

```irb
irb> Person.model_name.plural
=> "people"
```

**`element`** returns a potentially namespaced class name to snake_case.

```irb
irb> Person.model_name.element
=> "person"
```

**`human`** transforms the model name into a more human format, using I18n. By
default, it will underscore and then humanize the class name.

```irb
irb> Person.model_name.human
=> "Person"
```
**`collection`** returns the name of a table like Rails does for models to table
names. It uses the pluralize method on the last word in the string.

```irb
irb> Person.model_name.collection
=> "people"
```

**`param_key`** returns a string to use for params names. It differs for
namespaced models regarding whether it's inside an isolated engine.

```irb
irb> Person.model_name.param_key
=> "person"
```

**`i18n_key`** returns the name of the i18n key. It underscores the model name
and then returns it as a symbol.

```irb
irb> Person.model_name.i18n_key
=> :person
```

**`route_key`** returns a string to use while generating route names. It differs
for namespaced models regarding whether it's inside isolated engine.

```irb
irb> Person.model_name.route_key
=> "people"
```

**`singular_route_key`** returns a string to use while generating route names.
It differs for namespaced models regarding whether it's inside isolated engine.

```irb
irb> Person.model_name.singular_route_key
=> "person"
```

**`uncountable?`** identifies whether the class name of a record or class is
uncountable.

```irb
irb> Person.model_name.uncountable?
=> false
```

### Model

`ActiveModel::Model` includes ActiveModel::API for the required interface to
allow an object to interact with Action Pack and Action View, but it will be
extended in the future to add more functionality.

Currently, when including `ActiveModel::Model` you get the features from
[ActiveModel::API](active_model_basics.html#api).

### Serialization

`ActiveModel::Serialization` provides basic serialization to a serializable hash
for your objects. You need to declare an attributes Hash which should contain
the attributes you want to serialize. Attributes must be strings, not symbols.

```ruby
class Person
  include ActiveModel::Serialization

  attr_accessor :name, :age

  def attributes
    # compulsory declaration of attributes to serialize
    {"name" => nil, "age" => nil}
  end

  def capitalized_name
  # an example of how we can define a method that will be included a serialized hash
    name.capitalize
  end
end
```

Now you can access a serialized Hash of your object using the
`serializable_hash` method. Valid options for serializable hash include `:only`,
`:except`, `:methods` and `:include`.

```irb
irb> person = Person.new

irb> person.serializable_hash
=> {"name"=>nil, "age"=>nil}

# setting the name and age attributes and then serializing the object
irb> person.name = "bob"
irb> person.age = 22
irb> person.serializable_hash
=> {"name"=>"bob", "age"=>22}

# using the methods option to include the capitalized_name method
irb>  person.serializable_hash(methods: :capitalized_name)
=> {"name"=>"bob", "age"=>22, "capitalized_name"=>"Bob"}

# using the only method to include only the name attribute
irb> person.serializable_hash(only: :name)
=> {"name"=>"bob"}

# using the except method to exclude the name attribute
irb> person.serializable_hash(except: :name)
=> {"age"=>22}
```

The example to utilize the `includes` option requires a slightly more complex
scenario as defined below:

```ruby
  class Person
   include ActiveModel::Serialization
   attr_accessor :name, :notes # Emulate has_many :notes

    def attributes
       {"name" => nil}
    end
  end

  class Note
    include ActiveModel::Serializers::JSON
    attr_accessor :title, :text
    def attributes
      {"title" => nil, "text" => nil}
    end
  end
```


```irb
irb> note = Note.new
irb> note.title = "Weekend Plans"
irb> note.text = "Some text here"

irb> person = Person.new
irb> person.name = "Napoleon"
irb> person.notes = [note]

irb> person.serializable_hash
=> {"name" => "Napoleon"}

irb> person.serializable_hash(include: { notes: { only: "title" }})
=> {"name" => "Napoleon", "notes" => [{"title"=>"Weekend Plans"}]}
```

#### ActiveModel::Serializers

Active Model also provides the `ActiveModel::Serializers::JSON` module for JSON
serializing / deserializing.

##### ActiveModel::Serializers::JSON

To use `ActiveModel::Serializers::JSON` you only need to change the module you
are including from `ActiveModel::Serialization` to
`ActiveModel::Serializers::JSON`. This is because the
`ActiveModel::Serializers::JSON` module automatically includes the
`ActiveModel::Serialization` module, so there is no need to explicitly include
`ActiveModel::Serialization`.

```ruby
class Person
  include ActiveModel::Serializers::JSON

  attr_accessor :name

  def attributes
    { "name" => nil }
  end
end
```

The `as_json` method, similar to `serializable_hash`, provides a Hash
representing the model with its keys as a String. The `to_json` method returns a
JSON string representing the model.

```irb
irb> person = Person.new

# a Hash representing the model with its keys as a String
irb> person.as_json
=> {"name"=>nil}

# a JSON string representing the model
irb> person.to_json
=> "{\"name\":null}"

irb> person.name = "Bob"
irb> person.as_json
=> {"name"=>"Bob"}

irb> person.to_json
=> "{\"name\":\"Bob\"}"
```

You can also define the attributes for a model from a JSON string. However, you
need to define the `attributes=` method in your class:

```ruby
class Person
  include ActiveModel::Serializers::JSON

  attr_accessor :name

  def attributes=(hash)
    hash.each do |key, value|
      public_send("#{key}=", value)
    end
  end

  def attributes
    { "name" => nil }
  end
end
```

Now it is possible to create an instance of `Person` and set attributes using
`from_json`.

```irb
irb> json = { name: "Bob" }.to_json
=> "{\"name\":\"Bob\"}"

irb> person = Person.new

# defining the attributes for a model from a JSON string
irb> person.from_json(json)
=> #<Person:0x00000100c773f0 @name="Bob">

irb> person.name
=> "Bob"
```

### Translation

`ActiveModel::Translation` provides integration between your object and the
Rails internationalization (i18n) framework.

```ruby
class Person
  extend ActiveModel::Translation
end
```

With the `human_attribute_name` method, you can transform attribute names into a
more human-readable format. The human-readable format is defined in your locale
file(s).

  config/locales/app.pt-BR.yml

```yaml
pt-BR:
  activemodel:
    attributes:
      person:
        name: "Nome"
```

```irb
irb> Person.human_attribute_name("name")
=> "Nome"
```

### Lint Tests

`ActiveModel::Lint::Tests` allows you to test whether an object is compliant
with the Active Model API by including `ActiveModel::Lint::Tests` in your
TestCase. It will include tests that tell you whether your object is fully
compliant, or if not, which aspects of the API are not implemented.

These tests do not attempt to determine the semantic correctness of the returned
values. For instance, you could implement `valid?` to always return `true`, and
the tests would pass. It is up to you to ensure that the values are semantically
meaningful.

Objects you pass in are expected to return a compliant object from a call to
`to_model`. It is perfectly fine for `to_model` to return `self`.

* `app/models/person.rb`

    ```ruby
    class Person
      include ActiveModel::API
    end
    ```

* `test/models/person_test.rb`

    ```ruby
    require "test_helper"

    class PersonTest < ActiveSupport::TestCase
      include ActiveModel::Lint::Tests

      setup do
        @model = Person.new
      end
    end
    ```

You can find the test methods
[here](https://api.rubyonrails.org/classes/ActiveModel/Lint/Tests.html).

To run the tests you can use the following command:

```bash
$ bin/rails test

Run options: --seed 14596

# Running:

......

Finished in 0.024899s, 240.9735 runs/s, 1204.8677 assertions/s.

6 runs, 30 assertions, 0 failures, 0 errors, 0 skips
```

### SecurePassword

`ActiveModel::SecurePassword` provides a way to securely store any password in
an encrypted form. When you include this module, a `has_secure_password` class
method is provided which defines a `password` accessor with certain validations
on it by default.

#### Requirements

`ActiveModel::SecurePassword` depends on
[`bcrypt`](https://github.com/codahale/bcrypt-ruby 'BCrypt'), so include this
gem in your `Gemfile` to use `ActiveModel::SecurePassword`.

```ruby
gem "bcrypt"
```

`ActiveModel::SecurePassword` requires you to have a `password_digest`
attribute.

The following validations are added automatically:
1. Password must be present on creation.
2. Confirmation of password (using a `password_confirmation` attribute)
3. The maximum length of a password is 72 bytes (required as `bcrypt`, on which
   ActiveModel::SecurePassword depends, truncates the string to this size before
   encrypting it).

If password confirmation validation is not needed, simply leave out the value
for `password_confirmation` (i.e. don't provide a form field for it). When this
attribute has a `nil` value, the validation will not be triggered.

For further customization, it is possible to suppress the default validations by
passing `validations: false` as an argument.


```ruby
class Person
  include ActiveModel::SecurePassword

  has_secure_password
  has_secure_password :recovery_password, validations: false

  attr_accessor :password_digest, :recovery_password_digest
end
```

```irb
irb> person = Person.new

# When password is blank.
irb> person.valid?
=> false

# When the confirmation doesn't match the password.
irb> person.password = "aditya"
irb> person.password_confirmation = "nomatch"
irb> person.valid?
=> false

# When the length of password exceeds 72.
irb> person.password = person.password_confirmation = "a" * 100
irb> person.valid?
=> false

# When only password is supplied with no password_confirmation.
irb> person.password = "aditya"
irb> person.valid?
=> true

# When all validations are passed.
irb> person.password = person.password_confirmation = "aditya"
irb> person.valid?
=> true

irb> person.recovery_password = "42password"

irb> person.authenticate("aditya")
=> #<Person> # == person
irb> person.authenticate("notright")
=> false
irb> person.authenticate_password("aditya")
=> #<Person> # == person
irb> person.authenticate_password("notright")
=> false

irb> person.authenticate_recovery_password("42password")
=> #<Person> # == person
irb> person.authenticate_recovery_password("notright")
=> false

irb> person.password_digest
=> "$2a$04$gF8RfZdoXHvyTjHhiU4ZsO.kQqV9oonYZu31PRE4hLQn3xM2qkpIy"
irb> person.recovery_password_digest
=> "$2a$04$iOfhwahFymCs5weB3BNH/uXkTG65HR.qpW.bNhEjFP3ftli3o5DQC"
```
