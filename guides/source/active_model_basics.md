**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON https://guides.rubyonrails.org.**


Active Model Basics
===================

This guide should provide you with all you need to get started using model
classes. Active Model allows for Action Pack helpers to interact with
plain Ruby objects. Active Model also helps build custom ORMs for use
outside of the Rails framework.

After reading this guide, you will know:

* How an Active Record model behaves.
* How Callbacks and validations work.
* How serializers work.
* How Active Model integrates with the Rails internationalization (i18n) framework.

--------------------------------------------------------------------------------

What is Active Model?
---------------------

To understand Active Model, you need to know a little about [Active Record](active_record_basics.html). Active Record is an ORM (Object Relational Mapper) that connects objects whose data requires persistent storage to a relational database. However, it has functionality that is useful outside of the ORM, some of these include validations, callbacks, translations, the ability to create custom attributes etc.

Some of this functionality was abstracted from Active Record to form Active Model. Active Model is a library containing various modules that can be used on plain ruby objects that require model-like features but are not tied to any table in a database.

Some of these modules are explained below.

### API

`ActiveModel::API` adds the ability for a class to work with [Action Pack](https://api.rubyonrails.org/files/actionpack/README_rdoc.html) and [Action View](action_view_overview.html) right out of the box.

When including `ActiveModel::API`, other modules are included by default which enables you to get features like:

- [Attribute Assignments]()
- [Conversions](active_model_basics.html#conversion)
- [Name Introspections](active_model_basics.html#naming)
- [Translations](active_model_basics.html#translation)
- [Validations](active_model_basics.html#validations)

Here is an example of a class that includes `ActiveModel::API` and how it can be used:

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
irb> email_contact = EmailContact.new(name: 'David', email: 'david@example.com', message: 'Hello World')

irb> email_contact.name #attribute assignments
=> "David"

irb> email_contact.to_model == email_contact #conversions
=> true

irb> email_contact.model_name.name #naming
=> EmailContact

irb> email_contact.human_attribute_name('name') #translations if locale is set
=> "Name"

irb> email_contact.valid? #validations
=> true
```

Any class that includes `ActiveModel::API` can be used with `form_with`,
`render` and any other [Action View helper methods](https://api.rubyonrails.org/classes/ActionView/Helpers.html), just like Active Record objects.

For example, `form_with` can be used with the above class as follows

```erb+html
<%= form_with model: EmailContact.new do |form| %>
  <%= form.text_field :name %>
<% end %>
# =>
<form action="/email_contacts" method="post" data-remote="true">
  <input type="text" name="email_contact[title]">
</form>
```

`render` can be used to render a partial with the class object as a local variable as follows:

```erb+html
<%= render partial: "email_contact", email_contact: EmailContact.new(name: 'David', email: 'david@example.com', message: 'Hello World') %>
```

### Attributes

Similar to Active Record attributes, which are typically inferred from the database schema, Active Model Attributes allow you to define data types, set default values, and handle casting and serialization on plain ruby objects. This can be useful for form data which will give produce the Active Record-like conversion for things like dates and booleans on regular objects.

To use Attributes, include the module in your model class and define your attributes using the `attribute` macro. It accepts a name, a cast type, a default value, and any other options supported by the attribute type.

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

#casts the string to a date
irb> person.date_of_birth = "2020-01-01"
irb> person.date_of_birth
=> Wed, 01 Jan 2020
irb> person.date_of_birth.class
=> Date

#obtains a default value of true
irb> person.active
=> true

#casts the string to a boolean
irb> person.active = "0"
irb> person.active
=> false
```

There are some additional methods described below that are available when using `ActiveModel::Attributes`.

#### Method: Attribute Names

The `attribute_names` method which returns an array of the attribute names.

```ruby
  Person.attribute_names # => ["name", "date_of_birth", "active"]
```

#### Method: Attributes

The `attributes` method which returns a hash of all the attributes with their names as keys and the values of the attributes as values.

```ruby
    person = Person.new
    person.name = "John"
    person.date_of_birth = "1998-01-01"
    person.active = false

    person.attributes # => {"name"=>"John", "date_of_birth"=>Thu, 01 Jan 1998, "active"=>false}
```

### Attribute Assignment

Attribute Assignment allows you to set an object's attributes by passing in a hash of attributes with keys matching the attribute names. This is useful when you want to set multiple attributes at once.

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
irb> person.assign_attributes(name: "John", date_of_birth: "1998-01-01", active: false)
irb> person.name
=> "John"
irb> person.date_of_birth
=> Thu, 01 Jan 1998
irb> person.active
=> false
```

If the passed hash the `permitted?` method and the return value of this method is `false`, an `ActiveModel::ForbiddenAttributesError` exception is raised.

The `assign_attributes` method has an alias `attributes=`.

INFO: A method alias is a method that performs the same action as another method, but is called something different.

The following example demonstrates the use of the `attributes=` method to set multiple attributes at once:

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

The `ActiveModel::AttributeMethods` module can add custom prefixes and suffixes
on methods of a class. It is used by defining the prefixes and suffixes and
which methods on the object will use them.

The requirements to implement `ActiveModel::AttributeMethods` are to:
- Include `ActiveModel::AttributeMethods` in your class.
- Call each of its methods you want to add, such as `attribute_method_suffix` or `attribute_method_prefix`.
- Call the `define_attribute_methods` after the other methods are called to declare the attribute that should be prefixed and suffixed.
-  Define the various generic `_attribute` methods that you have declared.

And attribute will be replaced by the argument passed in define_attribute_methods. In our case it is name.

```ruby
class Person
  include ActiveModel::AttributeMethods
  attribute_method_affix prefix: 'reset_', suffix: '_to_default!'
  attribute_method_prefix 'first_'
  attribute_method_prefix 'last_'
  attribute_method_suffix '_short?'
  define_attribute_methods 'name'


  attr_accessor :name

  private

  # this will create a method 'first_name'
  def first_attribute(attribute)
    send(attribute).split.first
  end

  # this will create a method 'last_name'
  def last_attribute(attribute)
    send(attribute).split.last
  end

  # this will create a method 'name_short?'
  def attribute_short?(attribute)
    send(attribute) < 5
  end

  # this will create a method 'reset_name_to_default!'
  def reset_attribute_to_default!(attribute)
    send("#{attribute}=", "Default Name")
  end

end
```

```irb
irb> person.name = "Jane Doe"
irb> person.first_name
=> "Jane"
irb> person.last_name
=> "Doe"

irb> person.name_short?
=> false

irb> person.reset_name_to_default!
=> "Default Name"
```

If the method is not defined, it will raise a `method_missing` error.

`ActiveModel::AttributeMethods` also provides aliasing of attribute methods. This can be done by using the `alias_attribute` method.

```ruby
class Person
  include ActiveModel::AttributeMethods

  attribute_method_suffix '_short?'
  define_attribute_methods :name

  attr_accessor :name

  alias_attribute :nickname, :name

  private

  def attribute_short?(attribute)
    send(attribute).length < 5
  end

end
```

```irb
irb> person = Person.new
irb> person.name = "Joe"
irb> person.name
=> "Joe"
irb> person.nickname
=> "Joe"
irb> person.name_short?
=> true
irb> person.nickname_short?
=> true
```

### Callbacks

`ActiveModel::Callbacks` gives plain ruby objects Active Record style callbacks. This provides an
ability to define callbacks that run at appropriate times.
After defining callbacks, you can wrap them with before, after, and around
custom methods.

You can implement `ActiveModel::Callbacks` by following the steps below:

- Extend `ActiveModel::Callbacks` in your class.
- Using `define_model_callbacks`, define a list of methods that you want callbacks attached to. When you define a method like `:update`, it will provide all three standard callbacks (before, around and after) for the `:update` method.
- Wrap the methods you want callbacks on in a block so that the callbacks get a chance to fire.
- Then in your class, you can use the `before_create`, `after_create`, and `around_create` methods, just as you would in an Active Record model.

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
      # This is the callback method when update is called on an object.
    end
  end

  def reset_me
    puts "reset_me method: called before the update method"
    # This method is called as a before_update callback when update is called on an object.
  end

  def finalize_me
    puts "finalize_me method: called after the update method"
    # This method is called as an after_update callback when update is called on an object .
  end

  def log_me
    puts "log_me method: called around the update method"
    yield
    puts "log_me method: block successfully called"
    # This method is called as a around_update callback when update is called on an object.
  end
end
```

This will yield the following which indicates the order in which the callbacks are being called:

```irb
irb> person = Person.new
irb> person.update
=> reset_me method: called before the update method
=> log_me method: called around the update method
=> update method called
=> block successfully called
=> finalize_me method: called after the update method
```

As per the above example, when defining an 'around' callback remember to yield to the block, otherwise, it won't be executed.


#### Defining Specific Callbacks

You can choose to have only specific callbacks by passing a hash to the `define_model_callbacks` method:

```ruby
define_model_callbacks :update, :create,  only: [:after, :before]
```
The `only: <type>` hash will apply to all callbacks defined on that method call. To get around this you can call the `define_model_callbacks` method as many times as you need like below:

```ruby
define_model_callbacks :create,  only: :after
define_model_callbacks :update,  only: :before
define_model_callbacks :destroy, only: :around
```

This will create `after_create`, `before_update`, and `around_destroy` methods only.

#### Defining Callbacks with a Class

You can pass in a class to `before_<type>`, `after_<type>` and `around_<type>`, in which case the callback will call that class's `<action>_<type>` method
passing the object that the callback is being called on.

```ruby
  class MyModel
    extend ActiveModel::Callbacks
    define_model_callbacks :create

    before_create AnotherClass
  end

  class AnotherClass
    def self.before_create( obj )
      <!-- obj is the MyModel instance that the callback is being called on -->
    end
  end
```

NOTE: `method_name` passed to `define_model_callbacks` must not end with `!`, `?` or `=`. In addition, defining the same callback multiple times will overwrite previous callback definitions.

Like the Active Record methods, the callback chain is aborted as soon as one of the methods throws `:abort`.

### Conversion

`ActiveModel::Conversion` is a collection of methods that allow you to convert your object to different forms for different purposes. A common use case is to convert your object to a string or an integer to build URLs, form fields, and more.

The `ActiveModel::Conversion` module adds the following methods: `to_model`, `to_key`, `to_param`, and `to_partial_path` to our classes.

It is most useful when the class defines `persisted?` and `id` methods. The `persisted?` method should return true if the object has been saved to the database or store, otherwise, it should return `false`. The `id` method should return the id of the object or nil if it is not saved.

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

If your model does not act like an Active Model object, then you should define`:to_model` yourself returning a proxy object
that wraps your object with Active Model compliant methods.

```ruby
class Person
  def to_model
    # a proxy object that wraps your object with Active Model compliant methods.
    PersonModel.new(self)
  end
end
```

#### to_key

The `to_key` method returns an array of the object's key attributes if any of the attributes are set, whether or not
the object is persisted. Returns nil if there are no key attributes.

```irb
irb> person.to_key
=> [1]
```

NOTE: A key attribute is an attribute that is used to identify the object. For example, in a database-backed model, the key attribute is the primary key.

#### to_param

The `to_param` method returns a `string` representation of the object's key suitable for use in URLs, or `nil` if `persisted?` is `false`.

```irb
irb> person.to_param
=> "1"
```

#### to_partial_path

The `to_partial_path` method returns a `string` representing the path associated with the object. ActionPack uses this to find a suitable partial to represent the object.


```irb
irb> person.to_partial_path
=> "people/person"
```

### Dirty

An object becomes dirty when it has gone through one or more changes to its
attributes and has not been saved. `ActiveModel::Dirty` gives the ability to
check whether an object has been changed or not. It also has attribute-based
accessor methods. Let's consider a Person class with attributes `first_name`
and `last_name`:

```ruby
class Person
  include ActiveModel::Dirty
  define_attribute_methods :first_name, :last_name

  def first_name
    @first_name
  end

  def first_name=(value)
    first_name_will_change!
    @first_name = value
  end

  def last_name
    @last_name
  end

  def last_name=(value)
    last_name_will_change!
    @last_name = value
  end

  def save
    # do save work...
    changes_applied
  end
end
```

#### Querying an Object Directly for its List of All Changed Attributes

```irb
irb> person = Person.new
irb> person.changed?
=> false

irb> person.first_name = "First Name"
irb> person.first_name
=> "First Name"

# Returns true if any of the attributes have unsaved changes.
irb> person.changed?
=> true

# Returns a list of attributes that have changed before saving.
irb> person.changed
=> ["first_name"]

# Returns a Hash of the attributes that have changed with their original values.
irb> person.changed_attributes
=> {"first_name"=>nil}

# Returns a Hash of changes, with the attribute names as the keys, and the values as an array of the old and new values for that field.
irb> person.changes
=> {"first_name"=>[nil, "First Name"]}
```

#### Attribute-based Accessor Methods

Track whether the particular attribute has been changed or not.

```irb
irb> person.first_name
=> "First Name"

# attr_name_changed?
irb> person.first_name_changed?
=> true
```

Track the previous value of the attribute.

```irb
# attr_name_was accessor
irb> person.first_name_was
=> nil
```

Track both previous and current values of the changed attribute. Returns an array
if changed, otherwise returns nil.

```irb
# attr_name_change
irb> person.first_name_change
=> [nil, "First Name"]
irb> person.last_name_change
=> nil
```

### Validations

The `ActiveModel::Validations` module adds the ability to validate objects
like in Active Record.

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
irb> person.name = 'vishnu'
irb> person.email = 'me'
irb> person.valid?
=> false
irb> person.email = 'me@vishnuatrai.com'
irb> person.valid?
=> true
irb> person.token = nil
irb> person.valid?
ActiveModel::StrictValidationFailed
```

### Naming

`ActiveModel::Naming` adds several class methods which make naming and routing
easier to manage. The module defines the `model_name` class method which
will define several accessors using some `ActiveSupport::Inflector` methods.

```ruby
class Person
  extend ActiveModel::Naming
end

Person.model_name.name                # => "Person"
Person.model_name.singular            # => "person"
Person.model_name.plural              # => "people"
Person.model_name.element             # => "person"
Person.model_name.human               # => "Person"
Person.model_name.collection          # => "people"
Person.model_name.param_key           # => "person"
Person.model_name.i18n_key            # => :person
Person.model_name.route_key           # => "people"
Person.model_name.singular_route_key  # => "person"
```

### Model

`ActiveModel::Model` includes [ActiveModel::API](active_model_basics.html#api) for the required interface to allow an
object to interact with Action Pack and Action View, but it will be extended in the future to add more functionality.

Currently, when including `ActiveModel::Model` you get all the features from `ActiveModel::API`.

### Serialization

`ActiveModel::Serialization` provides basic serialization for your object.
You need to declare an attributes Hash which contains the attributes you want to
serialize. Attributes must be strings, not symbols.

```ruby
class Person
  include ActiveModel::Serialization

  attr_accessor :name

  def attributes
    { 'name' => nil }
  end
end
```

Now you can access a serialized Hash of your object using the `serializable_hash` method.

```irb
irb> person = Person.new
irb> person.serializable_hash
=> {"name"=>nil}
irb> person.name = "Bob"
irb> person.serializable_hash
=> {"name"=>"Bob"}
```

#### ActiveModel::Serializers

Active Model also provides the `ActiveModel::Serializers::JSON` module
for JSON serializing / deserializing. This module automatically includes the
previously discussed `ActiveModel::Serialization` module.

##### ActiveModel::Serializers::JSON

To use `ActiveModel::Serializers::JSON` you only need to change the
module you are including from `ActiveModel::Serialization` to `ActiveModel::Serializers::JSON`.

```ruby
class Person
  include ActiveModel::Serializers::JSON

  attr_accessor :name

  def attributes
    { 'name' => nil }
  end
end
```

The `as_json` method, similar to `serializable_hash`, provides a Hash representing
the model.

```irb
irb> person = Person.new
irb> person.as_json
=> {"name"=>nil}
irb> person.name = "Bob"
irb> person.as_json
=> {"name"=>"Bob"}
```

You can also define the attributes for a model from a JSON string.
However, you need to define the `attributes=` method on your class:

```ruby
class Person
  include ActiveModel::Serializers::JSON

  attr_accessor :name

  def attributes=(hash)
    hash.each do |key, value|
      send("#{key}=", value)
    end
  end

  def attributes
    { 'name' => nil }
  end
end
```

Now it is possible to create an instance of `Person` and set attributes using `from_json`.

```irb
irb> json = { name: 'Bob' }.to_json
irb> person = Person.new
irb> person.from_json(json)
=> #<Person:0x00000100c773f0 @name="Bob">
irb> person.name
=> "Bob"
```

### Translation

`ActiveModel::Translation` provides integration between your object and the Rails
internationalization (i18n) framework.

```ruby
class Person
  extend ActiveModel::Translation
end
```

With the `human_attribute_name` method, you can transform attribute names into a
more human-readable format. The human-readable format is defined in your locale file(s).

* config/locales/app.pt-BR.yml

```yaml
pt-BR:
  activemodel:
    attributes:
      person:
        name: 'Nome'
```

```ruby
Person.human_attribute_name('name') # => "Nome"
```

### Lint Tests

`ActiveModel::Lint::Tests` allows you to test whether an object is compliant with
the Active Model API.

* `app/models/person.rb`

    ```ruby
    class Person
      include ActiveModel::Model
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

```bash
$ bin/rails test

Run options: --seed 14596

# Running:

......

Finished in 0.024899s, 240.9735 runs/s, 1204.8677 assertions/s.

6 runs, 30 assertions, 0 failures, 0 errors, 0 skips
```

An object is not required to implement all APIs in order to work with
Action Pack. This module only intends to guide in case you want all
features out of the box.

### SecurePassword

`ActiveModel::SecurePassword` provides a way to securely store any
password in an encrypted form. When you include this module, a
`has_secure_password` class method is provided which defines
a `password` accessor with certain validations on it by default.

#### Requirements

`ActiveModel::SecurePassword` depends on [`bcrypt`](https://github.com/codahale/bcrypt-ruby 'BCrypt'),
so include this gem in your `Gemfile` to use `ActiveModel::SecurePassword` correctly.
In order to make this work, the model must have an accessor named `XXX_digest`.
Where `XXX` is the attribute name of your desired password.
The following validations are added automatically:

1. Password should be present.
2. Password should be equal to its confirmation (provided `XXX_confirmation` is passed along).
3. The maximum length of a password is 72 bytes (required as `bcrypt`, on which
   ActiveModel::SecurePassword depends, truncates the string to this size before encrypting it).

#### Examples

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
irb> person.password = 'aditya'
irb> person.password_confirmation = 'nomatch'
irb> person.valid?
=> false

# When the length of password exceeds 72.
irb> person.password = person.password_confirmation = 'a' * 100
irb> person.valid?
=> false

# When only password is supplied with no password_confirmation.
irb> person.password = 'aditya'
irb> person.valid?
=> true

# When all validations are passed.
irb> person.password = person.password_confirmation = 'aditya'
irb> person.valid?
=> true

irb> person.recovery_password = "42password"

irb> person.authenticate('aditya')
=> #<Person> # == person
irb> person.authenticate('notright')
=> false
irb> person.authenticate_password('aditya')
=> #<Person> # == person
irb> person.authenticate_password('notright')
=> false

irb> person.authenticate_recovery_password('42password')
=> #<Person> # == person
irb> person.authenticate_recovery_password('notright')
=> false

irb> person.password_digest
=> "$2a$04$gF8RfZdoXHvyTjHhiU4ZsO.kQqV9oonYZu31PRE4hLQn3xM2qkpIy"
irb> person.recovery_password_digest
=> "$2a$04$iOfhwahFymCs5weB3BNH/uXkTG65HR.qpW.bNhEjFP3ftli3o5DQC"
```
