Active Model Basics
===================

This guide should provide you with all you need to get started using model classes. Active Model allows for Action Pack helpers to interact with non-ActiveRecord models. Active Model also helps building custom ORMs for use outside of the Rails framework.

--------------------------------------------------------------------------------

WARNING. This guide is based on Rails 3.0. Some of the code shown here will not work in earlier versions of Rails.

Introduction
------------

Active Model is a library containing various modules used in developing frameworks that need to interact with the Rails Action Pack library. Active Model provides a known set of interfaces for usage in classes. Some of modules are explained below.  

### AttributeMethods

The AttributeMethods module can add custom prefixes and suffixes on methods of a class. It is used by defining the prefixes and suffixes, which methods on the object will use them.

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
    send(attribute) > 100 ? true : false
  end
  
end

person = Person.new
person.age = 110
person.age_highest?  # true
person.reset_age     # 0
person.age_highest?  # false 

```

### Callbacks

Callbacks gives Active Record style callbacks. This provides the ability to define the callbacks and those will run at appropriate time. After defining a callbacks you can wrap with before, after and around custom methods.

```ruby
class Person
  extend ActiveModel::Callbacks

  define_model_callbacks :update

  before_update :reset_me

  def update
    run_callbacks(:update) do
      # This will call when we are trying to call update on object.
    end
  end

  def reset_me
    # This method will call when you are calling update on object as a before_update callback as defined.
  end
end
```

### Conversion

If a class defines `persisted?` and `id` methods then you can include `Conversion` module in that class and you can able to call Rails conversion methods to objects of that class.

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
person.to_model == person  #=> true
person.to_key              #=> nil
person.to_param            #=> nil
```

### Dirty

An object becomes dirty when it has gone through one or more changes to its attributes and has not been saved. This gives the ability to check whether an object has been changed or not. It also has attribute based accessor methods. Let's consider a Person class with attributes first_name and last_name

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
    @previously_changed = changes
  end

end
```

#### Querying object directly for its list of all changed attributes.

```ruby
person = Person.new
person.first_name = "First Name"

person.first_name #=> "First Name"
person.first_name = "First Name Changed"

person.changed? #=> true

#returns an list of fields arry which all has been changed before saved.
person.changed #=> ["first_name"]

#returns a hash of the fields that have changed with their original values.
person.changed_attributes #=> {"first_name" => "First Name Changed"}

#returns a hash of changes, with the attribute names as the keys, and the values will be an array of the old and new value for that field.
person.changes #=> {"first_name" => ["First Name","First Name Changed"]}
```

#### Attribute based accessor methods

Track whether the particular attribute has been changed or not.

```ruby
#attr_name_changed?
person.first_name #=> "First Name"

#assign some other value to first_name attribute
person.first_name = "First Name 1"

person.first_name_changed? #=> true
```

Track what was the previous value of the attribute.

```ruby
#attr_name_was accessor
person.first_name_was  #=> "First Name"
```

Track both previous and current value of the changed attribute. Returns an array if changed, else returns nil.

```ruby
#attr_name_change
person.first_name_change #=> ["First Name", "First Name 1"]
person.last_name_change #=> nil
```

### Validations

Validations module adds the ability to class objects to validate them in Active Record style.

```ruby
class Person
  include ActiveModel::Validations

  attr_accessor :name, :email, :token
  
  validates :name, :presence => true
  validates_format_of :email, :with => /\A([^\s]+)((?:[-a-z0-9]\.)[a-z]{2,})\z/i  
  validates! :token, :presence => true
  
end

person = Person.new(:token => "2b1f325")
person.valid?                        #=> false
person.name  = 'vishnu'
person.email  = 'me'
person.valid?                        #=> false
person.email = 'me@vishnuatrai.com'
person.valid?                        #=> true
person.token = nil
person.valid?                        #=> raises ActiveModel::StrictValidationFailed
```
