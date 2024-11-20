# frozen_string_literal: true

require "active_support/benchmarkable"
require "active_support/dependencies"
require "active_support/descendants_tracker"
require "active_support/time"
require "active_support/core_ext/class/subclasses"
require "active_record/log_subscriber"
require "active_record/explain_subscriber"
require "active_record/relation/delegation"
require "active_record/attributes"
require "active_record/type_caster"
require "active_record/database_configurations"

module ActiveRecord # :nodoc:
  # = Active Record
  #
  # Active Record objects don't specify their attributes directly, but rather infer them from
  # the table definition with which they're linked. Adding, removing, and changing attributes
  # and their type is done directly in the database. Any change is instantly reflected in the
  # Active Record objects. The mapping that binds a given Active Record class to a certain
  # database table will happen automatically in most common cases, but can be overwritten for the uncommon ones.
  #
  # See the mapping rules in table_name and the full example in link:files/activerecord/README_rdoc.html for more insight.
  #
  # == Creation
  #
  # Active Records accept constructor parameters either in a hash or as a block. The hash
  # method is especially useful when you're receiving the data from somewhere else, like an
  # HTTP request. It works like this:
  #
  #   user = User.new(name: "David", occupation: "Code Artist")
  #   user.name # => "David"
  #
  # You can also use block initialization:
  #
  #   user = User.new do |u|
  #     u.name = "David"
  #     u.occupation = "Code Artist"
  #   end
  #
  # And of course you can just create a bare object and specify the attributes after the fact:
  #
  #   user = User.new
  #   user.name = "David"
  #   user.occupation = "Code Artist"
  #
  # == Conditions
  #
  # Conditions can either be specified as a string, array, or hash representing the WHERE-part of an SQL statement.
  # The array form is to be used when the condition input is tainted and requires sanitization. The string form can
  # be used for statements that don't involve tainted data. The hash form works much like the array form, except
  # only equality and range is possible. Examples:
  #
  #   class User < ActiveRecord::Base
  #     def self.authenticate_unsafely(user_name, password)
  #       where("user_name = '#{user_name}' AND password = '#{password}'").first
  #     end
  #
  #     def self.authenticate_safely(user_name, password)
  #       where("user_name = ? AND password = ?", user_name, password).first
  #     end
  #
  #     def self.authenticate_safely_simply(user_name, password)
  #       where(user_name: user_name, password: password).first
  #     end
  #   end
  #
  # The <tt>authenticate_unsafely</tt> method inserts the parameters directly into the query
  # and is thus susceptible to SQL-injection attacks if the <tt>user_name</tt> and +password+
  # parameters come directly from an HTTP request. The <tt>authenticate_safely</tt> and
  # <tt>authenticate_safely_simply</tt> both will sanitize the <tt>user_name</tt> and +password+
  # before inserting them in the query, which will ensure that an attacker can't escape the
  # query and fake the login (or worse).
  #
  # When using multiple parameters in the conditions, it can easily become hard to read exactly
  # what the fourth or fifth question mark is supposed to represent. In those cases, you can
  # resort to named bind variables instead. That's done by replacing the question marks with
  # symbols and supplying a hash with values for the matching symbol keys:
  #
  #   Company.where(
  #     "id = :id AND name = :name AND division = :division AND created_at > :accounting_date",
  #     { id: 3, name: "37signals", division: "First", accounting_date: '2005-01-01' }
  #   ).first
  #
  # Similarly, a simple hash without a statement will generate conditions based on equality with the SQL AND
  # operator. For instance:
  #
  #   Student.where(first_name: "Harvey", status: 1)
  #   Student.where(params[:student])
  #
  # A range may be used in the hash to use the SQL BETWEEN operator:
  #
  #   Student.where(grade: 9..12)
  #
  # An array may be used in the hash to use the SQL IN operator:
  #
  #   Student.where(grade: [9,11,12])
  #
  # When joining tables, nested hashes or keys written in the form 'table_name.column_name'
  # can be used to qualify the table name of a particular condition. For instance:
  #
  #   Student.joins(:schools).where(schools: { category: 'public' })
  #   Student.joins(:schools).where('schools.category' => 'public' )
  #
  # == Overwriting default accessors
  #
  # All column values are automatically available through basic accessors on the Active Record
  # object, but sometimes you want to specialize this behavior. This can be done by overwriting
  # the default accessors (using the same name as the attribute) and calling
  # +super+ to actually change things.
  #
  #   class Song < ActiveRecord::Base
  #     # Uses an integer of seconds to hold the length of the song
  #
  #     def length=(minutes)
  #       super(minutes.to_i * 60)
  #     end
  #
  #     def length
  #       super / 60
  #     end
  #   end
  #
  # == Attribute query methods
  #
  # In addition to the basic accessors, query methods are also automatically available on the Active Record object.
  # Query methods allow you to test whether an attribute value is present.
  # Additionally, when dealing with numeric values, a query method will return false if the value is zero.
  #
  # For example, an Active Record User with the <tt>name</tt> attribute has a <tt>name?</tt> method that you can call
  # to determine whether the user has a name:
  #
  #   user = User.new(name: "David")
  #   user.name? # => true
  #
  #   anonymous = User.new(name: "")
  #   anonymous.name? # => false
  #
  # Query methods will also respect any overrides of default accessors:
  #
  #   class User
  #     # Has admin boolean column
  #     def admin
  #       false
  #     end
  #   end
  #
  #   user.update(admin: true)
  #
  #   user.read_attribute(:admin)  # => true, gets the column value
  #   user[:admin] # => true, also gets the column value
  #
  #   user.admin   # => false, due to the getter override
  #   user.admin?  # => false, due to the getter override
  #
  # == Accessing attributes before they have been typecasted
  #
  # Sometimes you want to be able to read the raw attribute data without having the column-determined
  # typecast run its course first. That can be done by using the <tt><attribute>_before_type_cast</tt>
  # accessors that all attributes have. For example, if your Account model has a <tt>balance</tt> attribute,
  # you can call <tt>account.balance_before_type_cast</tt> or <tt>account.id_before_type_cast</tt>.
  #
  # This is especially useful in validation situations where the user might supply a string for an
  # integer field and you want to display the original string back in an error message. Accessing the
  # attribute normally would typecast the string to 0, which isn't what you want.
  #
  # == Dynamic attribute-based finders
  #
  # Dynamic attribute-based finders are a mildly deprecated way of getting (and/or creating) objects
  # by simple queries without turning to SQL. They work by appending the name of an attribute
  # to <tt>find_by_</tt> like <tt>Person.find_by_user_name</tt>.
  # Instead of writing <tt>Person.find_by(user_name: user_name)</tt>, you can use
  # <tt>Person.find_by_user_name(user_name)</tt>.
  #
  # It's possible to add an exclamation point (!) on the end of the dynamic finders to get them to raise an
  # ActiveRecord::RecordNotFound error if they do not return any records,
  # like <tt>Person.find_by_last_name!</tt>.
  #
  # It's also possible to use multiple attributes in the same <tt>find_by_</tt> by separating them with
  # "_and_".
  #
  #  Person.find_by(user_name: user_name, password: password)
  #  Person.find_by_user_name_and_password(user_name, password) # with dynamic finder
  #
  # It's even possible to call these dynamic finder methods on relations and named scopes.
  #
  #   Payment.order("created_on").find_by_amount(50)
  #
  # == Saving arrays, hashes, and other non-mappable objects in text columns
  #
  # Active Record can serialize any object in text columns using YAML. To do so, you must
  # specify this with a call to the class method
  # {serialize}[rdoc-ref:AttributeMethods::Serialization::ClassMethods#serialize].
  # This makes it possible to store arrays, hashes, and other non-mappable objects without doing
  # any additional work.
  #
  #   class User < ActiveRecord::Base
  #     serialize :preferences
  #   end
  #
  #   user = User.create(preferences: { "background" => "black", "display" => large })
  #   User.find(user.id).preferences # => { "background" => "black", "display" => large }
  #
  # You can also specify a class option as the second parameter that'll raise an exception
  # if a serialized object is retrieved as a descendant of a class not in the hierarchy.
  #
  #   class User < ActiveRecord::Base
  #     serialize :preferences, Hash
  #   end
  #
  #   user = User.create(preferences: %w( one two three ))
  #   User.find(user.id).preferences    # raises SerializationTypeMismatch
  #
  # When you specify a class option, the default value for that attribute will be a new
  # instance of that class.
  #
  #   class User < ActiveRecord::Base
  #     serialize :preferences, OpenStruct
  #   end
  #
  #   user = User.new
  #   user.preferences.theme_color = "red"
  #
  #
  # == Single table inheritance
  #
  # Active Record allows inheritance by storing the name of the class in a
  # column that is named "type" by default. See ActiveRecord::Inheritance for
  # more details.
  #
  # == Connection to multiple databases in different models
  #
  # Connections are usually created through
  # {ActiveRecord::Base.establish_connection}[rdoc-ref:ConnectionHandling#establish_connection] and retrieved
  # by ActiveRecord::Base.lease_connection. All classes inheriting from ActiveRecord::Base will use this
  # connection. But you can also set a class-specific connection. For example, if Course is an
  # ActiveRecord::Base, but resides in a different database, you can just say <tt>Course.establish_connection</tt>
  # and Course and all of its subclasses will use this connection instead.
  #
  # This feature is implemented by keeping a connection pool in ActiveRecord::Base that is
  # a hash indexed by the class. If a connection is requested, the
  # {ActiveRecord::Base.retrieve_connection}[rdoc-ref:ConnectionHandling#retrieve_connection] method
  # will go up the class-hierarchy until a connection is found in the connection pool.
  #
  # == Exceptions
  #
  # * ActiveRecordError - Generic error class and superclass of all other errors raised by Active Record.
  # * AdapterNotSpecified - The configuration hash used in
  #   {ActiveRecord::Base.establish_connection}[rdoc-ref:ConnectionHandling#establish_connection]
  #   didn't include an <tt>:adapter</tt> key.
  # * AdapterNotFound - The <tt>:adapter</tt> key used in
  #   {ActiveRecord::Base.establish_connection}[rdoc-ref:ConnectionHandling#establish_connection]
  #   specified a non-existent adapter
  #   (or a bad spelling of an existing one).
  # * AssociationTypeMismatch - The object assigned to the association wasn't of the type
  #   specified in the association definition.
  # * AttributeAssignmentError - An error occurred while doing a mass assignment through the
  #   {ActiveRecord::Base#attributes=}[rdoc-ref:AttributeAssignment#attributes=] method.
  #   You can inspect the +attribute+ property of the exception object to determine which attribute
  #   triggered the error.
  # * ConnectionNotEstablished - No connection has been established.
  #   Use {ActiveRecord::Base.establish_connection}[rdoc-ref:ConnectionHandling#establish_connection] before querying.
  # * MultiparameterAssignmentErrors - Collection of errors that occurred during a mass assignment using the
  #   {ActiveRecord::Base#attributes=}[rdoc-ref:AttributeAssignment#attributes=] method.
  #   The +errors+ property of this exception contains an array of
  #   AttributeAssignmentError
  #   objects that should be inspected to determine which attributes triggered the errors.
  # * RecordInvalid - raised by {ActiveRecord::Base#save!}[rdoc-ref:Persistence#save!] and
  #   {ActiveRecord::Base.create!}[rdoc-ref:Persistence::ClassMethods#create!]
  #   when the record is invalid.
  # * RecordNotFound - No record responded to the {ActiveRecord::Base.find}[rdoc-ref:FinderMethods#find] method.
  #   Either the row with the given ID doesn't exist or the row didn't meet the additional restrictions.
  #   Some {ActiveRecord::Base.find}[rdoc-ref:FinderMethods#find] calls do not raise this exception to signal
  #   nothing was found, please check its documentation for further details.
  # * SerializationTypeMismatch - The serialized object wasn't of the class specified as the second parameter.
  # * StatementInvalid - The database server rejected the SQL statement. The precise error is added in the message.
  #
  # *Note*: The attributes listed are class-level attributes (accessible from both the class and instance level).
  # So it's possible to assign a logger to the class through <tt>Base.logger=</tt> which will then be used by all
  # instances in the current object space.
  class Base
    include ActiveModel::API

    extend ActiveSupport::Benchmarkable
    extend ActiveSupport::DescendantsTracker

    extend ConnectionHandling
    extend QueryCache::ClassMethods
    extend Querying
    extend Translation
    extend DynamicMatchers
    extend DelegatedType
    extend Explain
    extend Enum
    extend Delegation::DelegateCache
    extend Aggregations::ClassMethods

    include Core
    include Persistence
    include ReadonlyAttributes
    include ModelSchema
    include Inheritance
    include Scoping
    include Sanitization
    include AttributeAssignment
    include Integration
    include Validations
    include CounterCache
    include Attributes
    include Locking::Optimistic
    include Locking::Pessimistic
    include Encryption::EncryptableRecord
    include AttributeMethods
    include Callbacks
    include Timestamp
    include Associations
    include SecurePassword
    include AutosaveAssociation
    include NestedAttributes
    include Transactions
    include TouchLater
    include NoTouching
    include Reflection
    include Serialization
    include Store
    include SecureToken
    include TokenFor
    include SignedId
    include Suppressor
    include Normalization
    include Marshalling::Methods

    self.param_delimiter = "_"
  end

  ActiveSupport.run_load_hooks(:active_record, Base)
end
