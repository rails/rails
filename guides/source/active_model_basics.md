Active Model Basics
===================

This guide should provide you with all you need to get started using model classes. Active Model allows for Action Pack helpers to interact with non-Active Record models. Active Model also helps building custom ORMs for use outside of the Rails framework.

After reading this guide, you will know:

--------------------------------------------------------------------------------

Introduction
------------

Active Model is a library containing various modules used in developing frameworks that need to interact with the Rails Action Pack library. Active Model provides a known set of interfaces for usage in classes. Some of modules are explained below.

### AttributeMethods

The AttributeMethods module can add custom prefixes and suffixes on methods of a class. It is used by defining the prefixes and suffixes and which methods on the object will use them.

```ruby
class Person
  include ActiveModel::AttributeMethods

  attribute_method_prefix 'reset_'
  attribute_method_suffix '_highest?'
  define_attribute_methods 'age'

  attr_accessor :age

  private
    def reset_attribute(attribute)
      send("#{attribute}=", 0)
    end

    def attribute_highest?(attribute)
      send(attribute) > 100
    end
end

person = Person.new
person.age = 110
person.age_highest?  # true
person.reset_age     # 0
person.age_highest?  # false
```

### Callbacks

Callbacks gives Active Record style callbacks. This provides an ability to define callbacks which run at appropriate times. After defining callbacks, you can wrap them with before, after and around custom methods.

```ruby
class Person
  extend ActiveModel::Callbacks

  define_model_callbacks :update

  before_update :reset_me

  def update
    run_callbacks(:update) do
      # This method is called when update is called on an object.
    end
  end

  def reset_me
    # This method is called when update is called on an object as a before_update callback is defined.
  end
end
```

### Conversion

If a class defines `persisted?` and `id` methods, then you can include the `Conversion` module in that class and call the Rails conversion methods on objects of that class.

```ruby
class Person
  include ActiveModel::Conversion

  def persisted?
    false
  end

  def id
    nil
  end
end

person = Person.new
person.to_model == person  # => true
person.to_key              # => nil
person.to_param            # => nil
```

### Dirty

An object becomes dirty when it has gone through one or more changes to its attributes and has not been saved. This gives the ability to check whether an object has been changed or not. It also has attribute based accessor methods. Let's consider a Person class with attributes `first_name` and `last_name`:

```ruby
require 'active_model'

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

#### Querying object directly for its list of all changed attributes.

```ruby
person = Person.new
person.changed? # => false

person.first_name = "First Name"
person.first_name # => "First Name"

# returns if any attribute has changed.
person.changed? # => true

# returns a list of attributes that have changed before saving.
person.changed # => ["first_name"]

# returns a hash of the attributes that have changed with their original values.
person.changed_attributes # => {"first_name"=>nil}

# returns a hash of changes, with the attribute names as the keys, and the values will be an array of the old and new value for that field.
person.changes # => {"first_name"=>[nil, "First Name"]}
```

#### Attribute based accessor methods

Track whether the particular attribute has been changed or not.

```ruby
# attr_name_changed?
person.first_name # => "First Name"
person.first_name_changed? # => true
```

Track what was the previous value of the attribute.

```ruby
# attr_name_was accessor
person.first_name_was # => "First Name"
```

Track both previous and current value of the changed attribute. Returns an array if changed, else returns nil.

```ruby
# attr_name_change
person.first_name_change # => [nil, "First Name"]
person.last_name_change # => nil
```

### Validations

Validations module adds the ability to class objects to validate them in Active Record style.

```ruby
class Person
  include ActiveModel::Validations

  attr_accessor :name, :email, :token

  validates :name, presence: true
  validates_format_of :email, with: /\A([^\s]+)((?:[-a-z0-9]\.)[a-z]{2,})\z/i
  validates! :token, presence: true
end

person = Person.new(token: "2b1f325")
person.valid?                        # => false
person.name = 'vishnu'
person.email = 'me'
person.valid?                        # => false
person.email = 'me@vishnuatrai.com'
person.valid?                        # => true
person.token = nil
person.valid?                        # => raises ActiveModel::StrictValidationFailed
```

### ActiveModel::SecurePassword

`ActiveModel::SecurePassword` provides a way to securely store any
password in an encrypted form. On including this module, a
`has_secure_password` class method is provided which defines 
an accessor named `password` with certain validations on it. The 
`ActiveModel::SecurePassword` depends on the 
[`bcrypt`](https://github.com/codahale/bcrypt-ruby 'BCrypt'), so include 
this gem in your Gemfile to use `ActiveModel::SecurePassword` correctly.

In order to make this work, the model must have an accessor named 
`password_digest`. The `has_secure_password` will add the following 
validations on the `password` accessor:

1. Password should be present.
2. Password should be equal to its confirmation.
3. This maximum length of a password is 72 (required by `bcrypt` on which ActiveModel::SecurePassword depends)

```ruby
class Person
  include ActiveModel::SecurePassword
  has_secure_password
  attr_accessor :password_digest
end

person = Person.new

# When password is blank.
person.valid? # => false

# When the confirmation doesn't match the password.
person.password = 'aditya'
person.password_confirmation = 'nomatch'
person.valid? # => false

# When the length of password, exceeds 72.
person.password = person.password_confirmation = 'a' * 100
person.valid? # => false

# When all validations are passed.
person.password = person.password_confirmation = 'aditya'
person.valid? # => true
```