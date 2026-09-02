**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Active Support Core Extensions
==============================

Active Support is a Rails component that provides Ruby language extensions and
utilities.

It offers a richer bottom-line at the language level, both for Rails
applications and for developing the Ruby on Rails framework itself.

After reading this guide, you will know:

* What Core Extensions are.
* How to load all extensions.
* How to include only the extensions you want.
* What extensions Active Support provides.

--------------------------------------------------------------------------------

NOTE: this document will not list every single core extension. The Rails API docs are a great resource for that. The goal of this doc is to highlight the use cases for the various extensions and show the breath of the methods Rails adds to Ruby.

What are Core Extensions
------------------------

Ruby has a distinct feature, *open classes*, that sets it apart from many other
programming languages. In Ruby, any class, including built-in ones like
`String`, `Integer`, or `Array`, can be reopened and have new methods added to
it.

This is the mechanism Active Support Core Extensions use. They reopen Ruby's
built-in classes and add dozens of utility methods that are useful in the
development of the Rails framework itself as well as everyday Rails applications.

For example,
[`blank?`](https://api.rubyonrails.org/classes/Object.html#method-i-blank-3F) is
one such convenience method. This method is added directly to Ruby's `Object`
class, making it available on any Ruby object:

```ruby
class Object
  def blank?
    respond_to?(:empty?) ? empty? : !self
  end
end

"".blank?      # => true
nil.blank?     # => true
"hello".blank? # => false
```

This method enhances Ruby's built-in `empty` method and works for `nil`.

Rails has shipped these extensions since its earliest versions, and they have
come to define a style of Ruby code that is expressive and reads close
to natural language.

WARNING: Because open classes modify Ruby's built-in types globally, they are a
form of **monkey patching**. A method added to `String` in one part of your
program affects all strings everywhere. This can lead to subtle bugs if
extensions conflict with other gems or future versions of Ruby. Active Support's
extensions are well-tested and widely used, but if you are loading them in a
non-Rails project, prefer [selective
loading](#cherry-picking-a-single-extension) over `require "active_support/all"`
to limit the surface area. Avoid writing your own monkey patches on top of
Active Support's, and never monkey patch classes in a gem you do not own.

How to Load Core Extensions
---------------------------

### Within a Rails Application

Active Support core extensions are loaded by default in any Rails application. They are immediately available across your models, controllers, helpers, and elsewhere in your applications. No additional configuration is required.

```ruby
"hello world".titleize # => "Hello World"
1.week.ago # => 2026-04-13 19:37:46.287277000 UTC +00:00
```

You can opt out of loading all core extensions by setting `config.active_support.bare = true` in your application config. In that case, only the extensions Rails itself needs are loaded, and you can cherry-pick additional ones as needed.

### Using Core Extensions Outside of Rails

Active Support ships as its own gem and can be used in any Ruby project independently of Rails. You have several options for how much to load.

#### Cherry-picking a Single Extension

You can load just the extension you need. For example, to use a [`Hash#with_indifferent_access`](https://api.rubyonrails.org/classes/ActiveSupport/HashWithIndifferentAccess.html) where the keys `:foo` and `"foo"` are considered the same:

```ruby
require "active_support/core_ext/hash/indifferent_access"

{ a: 1 }.with_indifferent_access["a"] # => 1
```

NOTE: Throughout this guide, each extension includes a note indicating where it is defined, which tells you exactly what to require.

#### Loading All Extensions for a Class

To load all extensions for a given class, use `active_support/core_ext/<class>`:

```ruby
require "active_support/core_ext/hash"
```

#### Loading All Core Extensions

To load all core extensions at once:

```ruby
require "active_support/core_ext"
```

The above loads all of the extensions added to Ruby's built-in classes, but not the entire Active Support library.

#### Loading All of Active Support

To load the entire Active Support library:

```ruby
require "active_support/all"
```

This loads things like `ActiveSupport::Cache`, `ActiveSupport::Notifications`, in addition to the core extensions.

NOTE: `require "active_support/all"` does not load everything into memory upfront. Some features are configured via [`autoload`](https://guides.rubyonrails.org/autoloading_and_reloading_constants.html) and are only loaded when used.

Extensions to All Objects
-------------------------

### `blank?`

The [`blank?`][Object#blank?] method returns `true` if the value is `nil`,
`false`, or empty. It enhances Ruby's built-in `empty` method and works across
types. For example, it works for `nil` by returning `true` (on the other hand,
calling `.empty?` on `nil` would raise a `NoMethodError`).

Specifically, the following values are considered to be blank in a Rails
application:

* `nil` and `false`,
* strings composed only of whitespace,
* empty arrays and hashes, and
* any other object that responds `true` to the `empty?` method.

Active Support's `blank?` unifies all of these cases into a single predicate that works across types, so the same check applies whether you're looking at a string, an array, a hash, or nil:

```ruby
nil.blank?              # => true
false.blank?            # => true
"".blank?                # => true
"   ".blank?             # => true
[].blank?                # => true
{}.blank?                # => true
[1, 2].blank?            # => false
"hello".blank?           # => false
```

Here is an example of the `blank?` method being used within Rails source code
for checking whether a token is blank:

```ruby
# From [http_authentication.rb](https://github.com/rails/rails/blob/83423052fc899315fad91c20b5197a186fc8f0fd/actionpack/lib/action_controller/metal/http_authentication.rb#L474)
def authenticate(controller, &login_procedure)
  token, options = token_and_options(controller.request)
  unless token.blank?
    login_procedure.call(token, options)
  end
end
```

NOTE: `blank?` uses a Unicode-aware definition of whitespace when checking strings. This means it recognizes more than just ordinary spaces and tabs as whitespace. It treats Unicode whitespace characters such as U+00A0 (non-breaking space) and U+2029 (paragraph separator) as blank.

WARNING: Numbers such as `0` or `0.0` are **not** considered blank.

```ruby
0.blank?    # => false
0.0.blank?  # => false
```

NOTE: Defined in `active_support/core_ext/object/blank.rb`.

[Object#blank?]: https://api.rubyonrails.org/classes/Object.html#method-i-blank-3F

### `present?`

The method [`present?`][Object#present?] is the inverse of `blank?` and its return value is equivalent to `!blank?`:

```ruby
[1, 2].present?  # => true
"hello".present? # => true
nil.present?     # => false
"   ".present?    # => false
```

NOTE: Defined in `active_support/core_ext/object/blank.rb`.

[Object#present?]: https://api.rubyonrails.org/classes/Object.html#method-i-present-3F

### `presence`

The [`presence`][Object#presence] method returns its receiver (the object it was called on) if `present?` returns `true`, and returns `nil` otherwise. It is useful for idioms like this:

```ruby
config[:host] = ""            # Assuming config[:host] is blank
config[:host].present?        # => false
config[:host].presence        # => nil

# Default to "localhost" if config[:host] is blank
host = config[:host].presence || "localhost"
```

NOTE: Defined in `active_support/core_ext/object/blank.rb`.

[Object#presence]: https://api.rubyonrails.org/classes/Object.html#method-i-presence

### `duplicable?`

In Ruby, most objects can be duplicated via `dup` or `clone` but not all. When an object does not support duplication, a call to `dup` raises an error. Active Support adds a predicate method, [`duplicable?`][Object#duplicable?], as a shorthand to find out if a given object is duplicable. For example:

```ruby
"foo".dup           # => "foo"
"".dup              # => ""
Rational(1).dup     # => (1/1)
Complex(0).dup      # => (0+0i)
1.method(:+).dup    # => TypeError (allocator undefined for Method)
```

Active Support's `duplicable` returns `false` (instead of raising an error) for the method `+`, as methods are not duplicable in Ruby:

```ruby
"foo".duplicable?           # => true
"".duplicable?              # => true
Rational(1).duplicable?     # => true
Complex(1).duplicable?      # => true
1.method(:+).duplicable?    # => false
```

Without `duplicable?`, the caller of `dup` would need to `rescue` from the error raised by `dup` to discover that a given object is not duplicable.

WARNING: `duplicable?` depends on a [hard-coded list of non-duplicable types](https://github.com/rails/rails/blob/main/activesupport/lib/active_support/core_ext/object/duplicable.rb) built into Active Support source code. This list is small and can change as Ruby evolves — for example, `NilClass`, `TrueClass`, `FalseClass`, `Symbol`, and `Numeric` were removed from the list when Ruby 2.4 made them duplicable. Use `duplicable?` only when you know the hard-coded list covers your use case, otherwise use the slower `rescue` approach.

NOTE: Defined in `active_support/core_ext/object/duplicable.rb`.

[Object#duplicable?]: https://api.rubyonrails.org/classes/Object.html#method-i-duplicable-3F

### `deep_dup`

Normally, when you `dup` an object that contains other objects, Ruby does not
`dup` them as well. So, `dup` creates a *shallow copy* of the object. The
[`deep_dup`][Object#deep_dup] method returns a *deep copy* of a given object, by
also duplicating containing objects. For example, if you have an array of
strings, `dup` can lead to some surprising behavior:

```ruby
array     = ["string"]
duplicate = array.dup

duplicate.push "another-string"

# the `array` object was duplicated, so the string was added only to the duplicate
array     # => ["string"]
duplicate # => ["string", "another-string"]

duplicate.first.gsub!("string", "foo")

# the string element was not duplicated, so it will change in both arrays
array     # => ["foo"]
duplicate # => ["foo, "another-string"]
```

As you can see, after duplicating the `Array` instance, we are able to add to
the separate duplicate object without affecting the original array. This is not
true for the array's elements, however. Since `dup` does not make a deep copy,
the string inside the array is still the same object. And modifying the original
string results in a change to both the new array *and* the original array.

Having the string in the original array change can be a surprising side effect.
The `deep_dup` method addresses this issue by also copying the `String` objects
contained within the `Array` object:

```ruby
array     = ["string"]
duplicate = array.deep_dup

duplicate.first.gsub!("string", "foo")

array     # => ["string"]
duplicate # => ["foo"]
```

If the object is not duplicable, `deep_dup` will just return it:

```ruby
number = 1
duplicate = number.deep_dup
number.object_id == duplicate.object_id   # => true
```

NOTE: Defined in `active_support/core_ext/object/deep_dup.rb`.

[Object#deep_dup]: https://api.rubyonrails.org/classes/Object.html#method-i-deep_dup

### `try` and `try!`

When you call a method on an object and if the object could be `nil`, typically you would need to add a conditional check for `nil` first to avoid errors. The [`try`][Object#try] method provides a way to do this without an explicit `nil` check. It returns `nil` if sent to `nil`. For example:

```ruby
# without try
unless @number.nil?
  @number.next
end

# with try
@number.try(:next)
```

The `try` method can also be called with a block, which will be executed only if the object is not `nil`:

```ruby
@person.try { |p| "#{p.first_name} #{p.last_name}" }
```

Note that `try` will hide no-method errors, returning `nil` instead. You can use [`try!`][Object#try!] if you want to surface errors, made by typos in the method name, for example.

```ruby
@number.try(:nexte)  # => nil
@number.try!(:nexte) # NoMethodError: undefined method `nexte' for 1:Integer
```

NOTE: Ruby has a safe navigation operator `&.` that solves the same nil checking problem. Like `try` and `try!`, `&.` returns `nil` without calling the method if the receiver is `nil`. But if the receiver is not `nil` and the method actually doesn't exist, `&.` raises `NoMethodError` just like a normal method call, it behaves like `try!` in that case. The other difference is that `try`/`try!` also accept a block and method name can be passed as a symbol.

```ruby
@number = nil
@number&.next     # => nil
@number.try(:next)  # => nil
@number.try!(:next) # => nil

@number = 1
@number&.nexte     # => NoMethodError (method doesn't exist)
@number.try(:nexte)  # => nil
@number.try!(:nexte) # => NoMethodError (try! surfaces the error)
```

NOTE: Defined in `active_support/core_ext/object/try.rb`.

[Object#try]: https://api.rubyonrails.org/classes/Object.html#method-i-try
[Object#try!]: https://api.rubyonrails.org/classes/Object.html#method-i-try-21

### `class_eval`

The [`class_eval`][Kernel#class_eval] method evaluates a block in the context of an existing class or module, allowing you to define methods on it dynamically at runtime.

A good example of this is how Rails itself generates the `development?`, `test?`, and `production?` methods on [`ActiveSupport::EnvironmentInquirer`](https://github.com/rails/rails/blob/0e53474dd25bb06cc87c07a75ffec49d3490152c/activesupport/lib/active_support/environment_inquirer.rb#L28):

```ruby
# activesupport/lib/active_support/environment_inquirer.rb
module ActiveSupport
  class EnvironmentInquirer < StringInquirer
    DEFAULT_ENVIRONMENTS = %w[ development test production ]

    DEFAULT_ENVIRONMENTS.each do |env|
      class_eval <<~RUBY, __FILE__, __LINE__ + 1
        def #{env}?
          @#{env}
        end
      RUBY
    end
  end
end
```

Rather than manually writing each predicate method, Rails iterates over the list of environments and uses `class_eval` to define them dynamically. This results in you being able to query for environments:

```ruby
Rails.env.development? # => true
Rails.env.production?  # => false
```

NOTE: Defined in `active_support/core_ext/kernel/singleton_class.rb`.

[Kernel#class_eval]: https://api.rubyonrails.org/classes/Kernel.html#method-i-class_eval

### `acts_like?`

The [`acts_like`][Object#acts_like?] method provides a way to check if an object is designed to behave like another class, without requiring it to inherit from that class.

Any class that wants to declare it behaves like another can define a marker method. For example, a class that behaves like `Time` can define:

```ruby
def acts_like_time?
end
```

The method body and return value are irrelevant. By convention, its presence alone is the signal. Client code can then check:

```ruby
obj.acts_like?(:time)
```

A real example in Rails is `ActiveSupport::TimeWithZone`. It is not a subclass of `Time`, but it is designed to behave exactly like one, so it declares `acts_like_time?`:

```ruby
Time.now.acts_like?(:time)                    # => true
ActiveSupport::TimeWithZone.now.acts_like?(:time) # => true
```

This is preferable to `is_a?(Time)`, which would return `false` for `TimeWithZone`. Rails uses this pattern for classes that act like `Date` or `Time`.

NOTE: Defined in `active_support/core_ext/object/acts_like.rb`.

[Object#acts_like?]: https://api.rubyonrails.org/classes/Object.html#method-i-acts_like-3F

### `to_param`

All objects in Rails respond to the method [`to_param`][Object#to_param], which returns a string representation of the object suitable for use in a URL or query string. By default `to_param` just calls `to_s`:

```ruby
7.to_param # => "7"
```

The return value of `to_param` is **not** escaped. Rails handles URL escaping separately when building URLs:

```ruby
"Tom & Jerry".to_param # => "Tom & Jerry"
```

Several classes in Rails override this method. `nil`, `true`, and `false` return themselves:

```ruby
nil.to_param   # => nil
true.to_param  # => true
false.to_param # => false
```

[`Array#to_param`][Array#to_param] calls `to_param` on each element and joins the results with `"/"`:

```ruby
[1, 2, 3].to_param # => "1/2/3"
```

Notably, the Rails routing system calls `to_param` on models to get a value for the `:id` placeholder. `ActiveRecord::Base#to_param` returns the `id` of a model by default, but you can override it. For example:

```ruby
class User
  def to_param
    "#{id}-#{name.parameterize}"
  end
end
```

```ruby
@user.to_param # => "67-john-smith"
user_path(@user) # => "/users/67-john-smith"
```

WARNING: Controllers need to be aware of any redefinition of `to_param`. When a request comes in for `/users/67-john-smith`, `params[:id]` will be `"67-john-smith"`, so your controller or model lookup must handle that format.

NOTE: Defined in `active_support/core_ext/object/to_param.rb`.

[Array#to_param]: https://api.rubyonrails.org/classes/Array.html#method-i-to_param
[Object#to_param]: https://api.rubyonrails.org/classes/Object.html#method-i-to_param

### `to_query`

The [`to_query`][Object#to_query] method constructs a query string that associates a given `key` with the return value of `to_param`. Unlike `to_param`, which returns an unescaped URL segment, `to_query` fully escapes its output so it is ready to be used in a query string. For example:

```ruby
"Tom & Jerry".to_param          # => "Tom & Jerry"   (unescaped)
"Tom & Jerry".to_query("name")  # => "name=Tom+%26+Jerry" (escaped)
```

This method escapes whatever is needed, both for the key and the value:

```ruby
account.to_query("company[name]")
# => "company%5Bname%5D=Johnson+%26+Johnson"
```

You can also use it with a custom `to_param` definition on a model. For example, given:

```ruby
class User
  def to_param
    "#{id}-#{name.parameterize}"
  end
end
```

```ruby
current_user.to_query("user") # => "user=67-john-smith"
```

Arrays return the result of applying `to_query` to each element with `key[]` as the key, joined with `"&"`:

```ruby
[3.4, -45.6].to_query("sample")
# => "sample%5B%5D=3.4&sample%5B%5D=-45.6"
# which is sample[]=3.4&sample[]=-45.6
```

Hashes also respond to `to_query`. With no argument, it generates a sorted series of key/value assignments and joins them with `"&"`:

```ruby
{ c: 3, b: 2, a: 1 }.to_query # => "a=1&b=2&c=3"
```

[`Hash#to_query`][Hash#to_query] also accepts an optional namespace for the keys:

```ruby
{ id: 89, name: "John Smith" }.to_query("user")
# => "user%5Bid%5D=89&user%5Bname%5D=John+Smith"
# which is user[id]=89&user[name]=John+Smith
```

NOTE: Defined in `active_support/core_ext/object/to_query.rb`.

[Hash#to_query]: https://api.rubyonrails.org/classes/Hash.html#method-i-to_query
[Object#to_query]: https://api.rubyonrails.org/classes/Object.html#method-i-to_query

### `with_options`

The [`with_options`][Object#with_options] method provides a way to avoid repeating the same options across multiple method calls. It takes a hash of default options and yields a proxy object to a block. Any method called on that proxy object is forwarded to the receiver with the common options automatically merged in.

For example, instead of repeating `dependent: :destroy` on every association:

```ruby
class Account < ApplicationRecord
  has_many :customers, dependent: :destroy
  has_many :products,  dependent: :destroy
  has_many :invoices,  dependent: :destroy
  has_many :expenses,  dependent: :destroy
end
```

You can use `with_options` like this:

```ruby
class Account < ApplicationRecord
  with_options dependent: :destroy do |assoc|
    assoc.has_many :customers
    assoc.has_many :products
    assoc.has_many :invoices
    assoc.has_many :expenses
  end
end
```

This can convey _grouping_ to the reader as well. For example, say you want to send a newsletter whose language depends on the user. You could group locale-dependent bit in the mailer like this:

```ruby
I18n.with_options locale: user.locale, scope: "newsletter" do |i18n|
  subject i18n.t :subject
  body    i18n.t :body, user_name: user.name
end
```

TIP: The `with_options` blocks can be nested. Each inner block inherits the options from its outer block and merges in its own, so the deeper the nesting, the more options are accumulated and shared across the calls within that block.

NOTE: Defined in `active_support/core_ext/object/with_options.rb`.

[Object#with_options]: https://api.rubyonrails.org/classes/Object.html#method-i-with_options

### `to_json`

The `to_json` method is a Ruby method that comes from the `json` gem in Ruby's standard library. Active Support overrides the implementation for certain classes where Ruby's default output is insufficient.

The most notable example is `Time` and `Date` — Active Support ensures they serialize to ISO 8601 format, which plain Ruby does not guarantee:

```ruby
Time.now.to_json       # => "\"2026-04-30T12:00:00.000Z\""
Date.today.to_json     # => "\"2026-04-30\""
```

Other common types serialize as you would expect:

```ruby
1.to_json                           # => "1"
true.to_json                        # => "true"
nil.to_json                         # => "null"
{ a: 1, b: [2, 3] }.to_json        # => "{\"a\":1,\"b\":[2,3]}"
```

Classes like `Hash` and `Process::Status` also receive special handling to ensure their JSON output is accurate and meaningful.

NOTE: Defined in `active_support/core_ext/object/json.rb`.

### `instance_values`

The [`instance_values`][Object#instance_values] method returns a hash that maps
instance variable names (without "@") to their corresponding values. Keys are
strings:

```ruby
class C
  def initialize(x, y)
    @x, @y = x, y
  end
end

C.new(0, 1).instance_values # => {"x" => 0, "y" => 1}
```

NOTE: Defined in `active_support/core_ext/object/instance_variables.rb`.

[Object#instance_values]: https://api.rubyonrails.org/classes/Object.html#method-i-instance_values

### `instance_variable_names`

The [`instance_variable_names`][Object#instance_variable_names] method returns an array. Each name includes the "@" sign.

```ruby
class C
  def initialize(x, y)
    @x, @y = x, y
  end
end

C.new(0, 1).instance_variable_names # => ["@x", "@y"]
```

NOTE: Defined in `active_support/core_ext/object/instance_variables.rb`.

[Object#instance_variable_names]: https://api.rubyonrails.org/classes/Object.html#method-i-instance_variable_names

### Silencing Warnings and Exceptions

The methods [`silence_warnings`][Kernel#silence_warnings] and [`enable_warnings`][Kernel#enable_warnings] change the value of `$VERBOSE` accordingly for the duration of their block, and reset it afterwards:

```ruby
silence_warnings { Object.const_set "RAILS_DEFAULT_LOGGER", logger }
```

Silencing exceptions is also possible with the [`suppress`][Kernel#suppress] method. This method receives an arbitrary number of exception classes. If an exception is raised during the execution of the block and is `kind_of?` any of the arguments, `suppress` captures it and returns silently. Otherwise the exception is not captured:

```ruby
suppress(ActiveRecord::StaleObjectError) do
  current_user.increment! :visits
end

# `suppress` is a more explicit and readable alternative to this:
begin
  current_user.increment! :visits
rescue ActiveRecord::StaleObjectError
  # do nothing
end
```

NOTE: Defined in `active_support/core_ext/kernel/reporting.rb`.

[Kernel#enable_warnings]: https://api.rubyonrails.org/classes/Kernel.html#method-i-enable_warnings
[Kernel#silence_warnings]: https://api.rubyonrails.org/classes/Kernel.html#method-i-silence_warnings
[Kernel#suppress]: https://api.rubyonrails.org/classes/Kernel.html#method-i-suppress

### `in?`

The predicate [`in?`][Object#in?] tests if an object is included in another object. An `ArgumentError` will be raised if the argument passed does not respond to `include?`.

Examples of `in?`:

```ruby
1.in?([1, 2])        # => true
"lo".in?("hello")   # => true
25.in?(30..50)      # => false
1.in?(1)            # => ArgumentError
```

NOTE: Defined in `active_support/core_ext/object/inclusion.rb`.

[Object#in?]: https://api.rubyonrails.org/classes/Object.html#method-i-in-3F

Extensions to `Module`
----------------------

### `alias_attribute`

The [`alias_attribute`][Module#alias_attribute] method creates an alias for a model attribute, defining all three of its methods — reader, writer, and predicate — under the new name at once.

The new name is the first argument, the existing name is the second:

```ruby
class User < ApplicationRecord
  alias_attribute :login, :email
end
```

Now `email` is also accessible as `login`:

```ruby
user.login                      # same as user.email
user.login = "jane@example.com" # same as user.email=
user.login?                     # same as user.email?
```

This is useful when you want to use domain-specific language with an existing attribute. In this case, referring to `email` as `login` in authentication related code, for example.

NOTE: Defined in `active_support/core_ext/module/aliasing.rb`.

[Module#alias_attribute]: https://api.rubyonrails.org/classes/Module.html#method-i-alias_attribute

### `attr_internal_reader`, `attr_internal_writer`, and `attr_internal_accessor`

When defining attributes in a class meant to be subclassed, name collisions can be a real risk. Especially in libraries where subclasses written by others may unknowingly define attributes with the same name.

Active Support provides [`attr_internal_reader`][], [`attr_internal_writer`][], and [`attr_internal_accessor`][] to address this. They behave like Ruby's built-in `attr_*` methods, except the underlying instance variable is named in a special way that makes collisions far less likely. [`attr_internal`][] is a shorthand alias for `attr_internal_accessor`.

```ruby
# library code
class ThirdPartyLibrary::Crawler
  attr_internal :log_level
end

# client code
class MyCrawler < ThirdPartyLibrary::Crawler
  attr_accessor :log_level
end
```

Here `MyCrawler` defines its own `log_level` attribute without knowing the library uses one too. Because the library used `attr_internal`, its underlying instance variable is stored as `@_log_level` rather than `@log_level`, so the two do not conflict.

By default, the internal instance variable is prefixed with an underscore. This is configurable via `Module.attr_internal_naming_format`, which accepts any `sprintf`-like format string beginning with `@` and containing `%s` as a placeholder for the name. The default is `"@_%s"`.

Rails itself uses `attr_internal` in several places, for example in `ActionView::Base`:

```ruby
module ActionView
  class Base
    attr_internal :captures
    attr_internal :request, :layout
    attr_internal :controller, :template
  end
end
```

NOTE: Defined in `active_support/core_ext/module/attr_internal.rb`.

[attr_internal]: https://api.rubyonrails.org/classes/Module.html#method-i-attr_internal
[attr_internal_accessor]: https://api.rubyonrails.org/classes/Module.html#method-i-attr_internal_accessor
[attr_internal_reader]: https://api.rubyonrails.org/classes/Module.html#method-i-attr_internal_reader
[attr_internal_writer]: https://api.rubyonrails.org/classes/Module.html#method-i-attr_internal_writer

### `mattr_*`

The methods [`mattr_reader`][Module#mattr_reader], [`mattr_writer`][Module#mattr_writer], and [`mattr_accessor`][Module#mattr_accessor] are the same as their `cattr_*` equivalents [defined for class](#cattr-reader-cattr-writer-and-cattr-accessor). In fact, the `cattr_*` method are an aliases for the `mattr_*` ones.

For example, the API for the logger of Active Storage is generated with `mattr_accessor`:

```ruby
module ActiveStorage
  mattr_accessor :logger
end
```

NOTE: Defined in `active_support/core_ext/module/attribute_accessors.rb`.

[Module#mattr_accessor]: https://api.rubyonrails.org/classes/Module.html#method-i-mattr_accessor
[Module#mattr_reader]: https://api.rubyonrails.org/classes/Module.html#method-i-mattr_reader
[Module#mattr_writer]: https://api.rubyonrails.org/classes/Module.html#method-i-mattr_writer

### `module_parent`

The [`module_parent`][Module#module_parent] method returns the module that directly contains the receiver. It is useful for navigating the namespace hierarchy of nested modules. For example:

```ruby
module Blog
  module Admin
    module Settings
    end
  end
end

Blog::Admin::Settings.module_parent # => Blog::Admin
Blog::Admin.module_parent           # => Blog
```

If the module is anonymous or belongs to the top level, `module_parent` returns `Object`, and calling `module_parent_name` on it will return `nil` rather than a string.

```ruby
Blog.module_parent # => Object
Blog.module_parent_name # => nil
```

NOTE: Defined in `active_support/core_ext/module/introspection.rb`.

[Module#module_parent]: https://api.rubyonrails.org/classes/Module.html#method-i-module_parent

### `module_parent_name`

The [`module_parent_name`][Module#module_parent_name] method works like `module_parent` but returns the fully qualified name of the containing module as a string rather than the module itself:

```ruby
module Blog
  module Admin
    module Settings
    end
  end
end

Blog::Admin::Settings.module_parent_name # => "Blog::Admin"
Blog::Admin.module_parent_name           # => "Blog"
```

For top-level or anonymous modules, `module_parent_name` returns `nil`, whereas `module_parent` would return `Object`.

NOTE: Defined in `active_support/core_ext/module/introspection.rb`.

[Module#module_parent_name]: https://api.rubyonrails.org/classes/Module.html#method-i-module_parent_name


### `module_parents`

The [`module_parents`][Module#module_parents] method calls `module_parent` on the receiver and continues upwards until `Object` is reached, returning the entire chain as an array from bottom to top:

```ruby
module Blog
  module Admin
    module Settings
    end
  end
end

Blog::Admin::Settings.module_parents # => [Blog::Admin, Blog, Object]
Blog::Admin.module_parents           # => [Blog, Object]
```

NOTE: Defined in `active_support/core_ext/module/introspection.rb`.

[Module#module_parents]: https://api.rubyonrails.org/classes/Module.html#method-i-module_parents

### `anonymous?`

In Ruby, modules and classes can be created dynamically at runtime with
`Module.new` or `Class.new`. These have no name until assigned to a constant.
The [`Module#anonymous?`][] method lets you check for this explicitly. This is
useful when you need to handle named and unnamed modules differently, for
example, when serializing a class, referencing it by name, or displaying it in
error messages and logs.

A module gets a name when it is assigned to a constant, until then it is anonymous:

```ruby
module Blog
end
Blog.name    # => "Blog"

Blog.anonymous?          # => false
Module.new.anonymous?    # => true
```

Note that being unreachable is not the same as being anonymous. A module can lose its constant reference and become unreachable, but it still retains the name it was given:

```ruby
module Blog
end
detached = Object.send(:remove_const, :Blog)
detached.anonymous? # => false  — still has the name "Blog"
```

An anonymous module, by definition, is always unreachable, but a module can be unreachable without being anonymous.

NOTE: Defined in `active_support/core_ext/module/anonymous.rb`.

[Module#anonymous?]: https://api.rubyonrails.org/classes/Module.html#method-i-anonymous-3F

### `delegate`

The [`delegate`][Module#delegate] method offers an easy way to forward methods to another class.

For example, users in the application below have login information in the `User` model but name and other data in a separate `Profile` model:

```ruby
class User < ApplicationRecord
  has_one :profile
end
```

You can get a user's name via their profile, `user.profile.name`. But it could be handy to access `name` attribute more directly with `user.name` like this:

```ruby
class User < ApplicationRecord
  has_one :profile

  def name
    profile.name
  end
end
```

This is what `delegate` is for:

```ruby
class User < ApplicationRecord
  has_one :profile

  delegate :name, to: :profile
end
```

The method must be public in the target. Using `delegate` makes the intention more obvious.

Multiple methods can be delegated in one call:

```ruby
delegate :name, :age, :address, to: :profile
```

The `:to` option accepts any expression that evaluates to the target object in the context of the receiver, typically a symbol referencing a method, association, or constant:

```ruby
delegate :logger, to: :Rails      # delegates to the Rails constant
delegate :table_name, to: :class  # delegates to the receiver's class
```

By default, if the target is `nil` and the delegation raises `NoMethodError`, the exception propagates. Use `:allow_nil` to return `nil` instead:

```ruby
delegate :name, to: :profile, allow_nil: true
```

With this option, `user.name` returns `nil` if the user has no profile rather than raising an error.

The `:prefix` option prepends the target name to the generated method name:

```ruby
delegate :street, to: :address, prefix: true
# generates address_street rather than street
```

A custom prefix can also be specified:

```ruby
delegate :size, to: :attachment, prefix: :avatar
# generates avatar_size rather than attachment_size
```

WARNING: When using `:prefix`, the `:to` option must be a method name, since it is used to compose the name of the generated method.

By default, delegated methods are public. Use `:private` to change that:

```ruby
delegate :date_of_birth, to: :profile, private: true
```

NOTE: Defined in `active_support/core_ext/module/delegation.rb`

[Module#delegate]: https://api.rubyonrails.org/classes/Module.html#method-i-delegate

### `delegate_missing_to`

Imagine you would like to delegate everything missing from the `User` object,
to the `Profile` one. The [`delegate_missing_to`][Module#delegate_missing_to] macro lets you implement exactly that:

```ruby
class User < ApplicationRecord
  has_one :profile

  delegate_missing_to :profile
end
```

The target can be anything callable within the object, e.g. instance variables,
methods, constants, etc. Only the public methods of the target are delegated.

NOTE: Defined in `active_support/core_ext/module/delegation.rb`.

[Module#delegate_missing_to]: https://api.rubyonrails.org/classes/Module.html#method-i-delegate_missing_to

### `redefine_method`

When using `define_method`, Ruby will issue a warning if a method with that name already exists. The [`redefine_method`][Module#redefine_method] avoids this by removing the existing method first before defining the new one:

```ruby
class User
  redefine_method(:full_name) do
    "#{first_name} #{last_name}"
  end
end
```

This is particularly useful in metaprogramming where methods are generated dynamically and may be defined more than once.

If you need to define the replacement method yourself — for example when using `delegate` — use [`silence_redefinition_of_method`][Module#silence_redefinition_of_method] instead. It suppresses the warning without removing the existing method upfront:

```ruby
silence_redefinition_of_method :full_name
delegate :full_name, to: :profile
```

NOTE: Defined in `active_support/core_ext/module/redefine_method.rb`.

[Module#redefine_method]: https://api.rubyonrails.org/classes/Module.html#method-i-redefine_method
[Module#silence_redefinition_of_method]: https://api.rubyonrails.org/classes/Module.html#method-i-silence_redefinition_of_method

Extensions to `Class`
---------------------

### `class_attribute`

Ruby itself provides two options for class-level data, *class variables* and *class instance variables*, but both have limitations when it comes to inheritance and sharing values.

The [`class_attribute`](https://api.rubyonrails.org/classes/Class.html#method-i-class_attribute) method solves this by declaring an inheritable class level attribute where subclasses inherit the value from their parent but can override it without affecting the parent or any other subclass. For example:

```ruby
class Base
  class_attribute :pagination_limit
  self.pagination_limit = 25
end

class AdminController < Base
  self.pagination_limit = 100
end

Base.pagination_limit            # => 25
AdminController.pagination_limit # => 100
```

The value is also readable at the instance level:

```ruby
Base.new.pagination_limit            # => 25
AdminController.new.pagination_limit # => 100
```

Rails uses `class_attribute` extensively internally, for example,
`ActionMailer::Base` uses it to define default options that each mailer can override independently:

```ruby
class_attribute :default_params
self.default_params = {
  mime_version: "1.0",
  charset: "UTF-8",
  content_type: "text/plain",
  parts_order: [ "text/plain", "text/enriched", "text/html" ]
}.freeze
```

The generation of the writer instance method can be prevented by setting the option `:instance_writer` to `false`. This can be useful as a way to prevent mass-assignment from setting the attribute:

```ruby
class Base
  class_attribute :pagination_limit, instance_writer: false, default: 25
end

Base.new.pagination_limit = 100 # NoMethodError
```

The generation of the reader instance method can also be prevented by setting the option `:instance_reader` to `false`:

The `class_attribute` method also defines an instance predicate method — the double negation of what the instance reader returns. In the examples above it would be called `pagination_limit?`. When `:instance_reader` is `false`, the instance predicate returns a `NoMethodError` just like the reader method.

If you do not want the instance predicate, pass `instance_predicate: false` and it will not be defined.

NOTE: Defined in `active_support/core_ext/class/attribute.rb`.

[Class#class_attribute]: https://api.rubyonrails.org/classes/Class.html#method-i-class_attribute

### `cattr_reader`, `cattr_writer`, and `cattr_accessor`

These `cattr_*` methods ([cattr_accessor][], [cattr_reader][], and [cattr_writer][]) work like Ruby's `attr_*` methods but for classes. They declare a class level variable and generate class methods to read and write it.

The key difference from `class_attribute` is that `cattr_*` uses a **shared class variable** (`@@foo`) across the entire class hierarchy. When any instance or subclass changes the value, it changes everywhere, for the class, all subclasses, and all instances. For example:

```ruby
class Base
  cattr_accessor :pagination_limit, default: 25
end

class AdminController < Base
end

Base.pagination_limit            # => 25
AdminController.pagination_limit # => 25

AdminController.pagination_limit = 100

Base.pagination_limit            # => 100  (changed for everyone!)
AdminController.pagination_limit # => 100
```

This is different from `class_attribute`, where a subclass can override a value without affecting the parent. Use `cattr_accessor` when you want a single shared value across the whole hierarchy, and `class_attribute` when you want subclasses to be able to override independently.

Instance methods are also generated as a convenience, but they read and write the same shared class variable:

```ruby
instance = Base.new
instance.pagination_limit        # => 25
instance.pagination_limit = 100
Base.pagination_limit            # => 100  (instance write affects the class)
```

You can restrict which methods are generated using `:instance_reader`, `:instance_writer`, or `:instance_accessor`:

```ruby
class Base
  cattr_accessor :pagination_limit, instance_reader: false
  cattr_accessor :per_page_limit, instance_writer: false
  cattr_accessor :timeout, instance_accessor: false
end
```

Setting `:instance_accessor` to `false` is useful for preventing mass-assignment from modifying the attribute at the instance level.

NOTE: Defined in `active_support/core_ext/module/attribute_accessors.rb`.

[cattr_accessor]: https://api.rubyonrails.org/classes/Module.html#method-i-cattr_accessor
[cattr_reader]: https://api.rubyonrails.org/classes/Module.html#method-i-cattr_reader
[cattr_writer]: https://api.rubyonrails.org/classes/Module.html#method-i-cattr_writer

### `descendants`

The [`descendants`][Class#descendants] method returns all classes that inherit from the receiver, at any level of the hierarchy, not just direct subclasses. For example:

```ruby
class Vehicle; end
Vehicle.descendants # => []

class Car < Vehicle; end
Vehicle.descendants # => [Car]

class Truck < Vehicle; end
Vehicle.descendants # => [Car, Truck]

class ElectricCar < Car; end
Vehicle.descendants # => [Car, Truck, ElectricCar]

class DriverlessCar < ElectricCar; end
Vehicle.descendants # => [Truck, Car, ElectricCar, DriverlessCar]
```

Notice that `ElectricCar` appears in `Vehicle.descendants` even though it inherits from `Car`, not directly from `Vehicle`. The method walks the entire inheritance tree downward. The order in which classes are returned is unspecified.

NOTE: Defined in `active_support/core_ext/class/subclasses.rb`.

[Class#descendants]: https://api.rubyonrails.org/classes/Class.html#method-i-descendants

Extensions to `String`
----------------------

### `html_safe`

Extra care is needed when inserting user provided strings into HTML. A string like `"Ben & Jerry's is yummy!"` needs to have the ampersand escaped as `&amp;` in order to produce valid HTML. More critically, unescaped user input can be a vector for cross-site scripting (XSS) attacks (See the [Security guide](security.html#cross-site-scripting-xss) for more detail).

Active Support addresses this with the concept of HTML-safe strings. By default, all strings are considered unsafe:

```ruby
"hello".html_safe? # => false
```

The `html_safe` method marks a string as safe for insertion into HTML without escaping:

```ruby
s = "hello".html_safe
s.html_safe? # => true
```

It's important to note that the `html_safe` method performs no escaping. It's purely a declaration that you consider the string safe. Use it only when you are certain the content is trusted:

```ruby
s = "<script>alert('xss')</script>".html_safe
s.html_safe? # => true  — but this would execute JavaScript in the browser!
```

When concatenating strings, safe strings escape any unsafe content appended to them:

```ruby
"".html_safe + "<"          # => "&lt;"         (unsafe input is escaped)
"".html_safe + "<".html_safe # => "<"           (safe input is appended as-is)
```

In views, you rarely need `html_safe` directly, ERB escapes values automatically:

```erb
<%= @review.title %> <%# automatically escaped if needed %>
```

To insert a string without any escaping (for example to rendering HTML tags as
actual HTML rather than as visible text), use the [`raw`][] helper or `<%==`
rather than calling `html_safe` yourself. This makes the intent clearer to
anyone reading the template:

```erb
<%= raw @cms.current_template %>
<%== @cms.current_template %>
```

Any transformation on a safe string, such as `downcase`, `gsub`, `strip`, or `underscore`, produces an unsafe string. The safety flag is always lost after a transformation, regardless of whether the content actually changed. On the other hand, calling `dup` or `clone` on a safe string preserves the safety flag.

NOTE: Defined in `active_support/core_ext/string/output_safety.rb`.

### `remove`

The method [`remove`][String#remove] will remove all occurrences of the pattern. There is a destructive version as well `remove!` which modifies the string in place.

```ruby
str = "Hello, World"
str.remove("Hello, ")   # => "World"
str                     # => "Hello, World"  (unchanged)

str.remove!("Hello, ")  # => "World"
str                     # => "World"  (modified in place)
```

In plain Ruby you would use `gsub` with an empty string to achieve the same result, Active Support's `remove` is the more readable addition.

NOTE: Defined in `active_support/core_ext/string/filters.rb`.

[String#remove]: https://api.rubyonrails.org/classes/String.html#method-i-remove

### `squish`

The method [`squish`][String#squish] strips leading and trailing whitespace, and substitutes runs of whitespace with a single space each (it handles both ASCII and Unicode whitespace):

```ruby
" \n  foo\n\r \t bar \n".squish # => "foo bar"
```

There's also the version `String#squish!` which modifies the string in place.

NOTE: Defined in `active_support/core_ext/string/filters.rb`.

[String#squish]: https://api.rubyonrails.org/classes/String.html#method-i-squish

### `truncate`

[`truncate`][String#truncate] returns a copy of the receiver cut to a given length, with an ellipsis appended to indicate the string was shortened:

```ruby
"Oh dear! Oh dear! I shall be late!".truncate(20)
# => "Oh dear! Oh dear!..."
```

The ellipsis can be customized with the `:omission` option. Note that the omission string counts toward the total length:

```ruby
"Oh dear! Oh dear! I shall be late!".truncate(20, omission: "&hellip;")
# => "Oh dear! Oh &hellip;"
```

NOTE: `&hellip;` is the HTML entity for the ellipsis character `...`.

By default, truncation can cut in the middle of a word. Pass `:separator` to truncate only at a natural break such as a space or word boundary:

```ruby
"Oh dear! Oh dear! I shall be late!".truncate(18)
# => "Oh dear! Oh dea..."

"Oh dear! Oh dear! I shall be late!".truncate(18, separator: " ")
# => "Oh dear! Oh..."
```

`:separator` can also be a regexp:

```ruby
"Oh dear! Oh dear! I shall be late!".truncate(18, separator: /\s/)
# => "Oh dear! Oh..."
```

NOTE: Defined in `active_support/core_ext/string/filters.rb`.

[String#truncate]: https://api.rubyonrails.org/classes/String.html#method-i-truncate

### `truncate_bytes`

The method [`truncate_bytes`][String#truncate_bytes] returns a copy of its receiver truncated to at most `bytesize` bytes:

```ruby
"👍👍👍👍".truncate_bytes(15)
# => "👍👍👍…"
```

Ellipsis can be customized with the `:omission` option:

```ruby
"👍👍👍👍".truncate_bytes(15, omission: "🖖")
# => "👍👍🖖"
```

NOTE: Defined in `active_support/core_ext/string/filters.rb`.

[String#truncate_bytes]: https://api.rubyonrails.org/classes/String.html#method-i-truncate_bytes

### `truncate_words`

[`truncate_words`][String#truncate_words] returns a copy of the receiver truncated after a given number of words:

```ruby
"Oh dear! Oh dear! I shall be late!".truncate_words(4)
# => "Oh dear! Oh dear!..."
```

The ellipsis can be customized with the `:omission` option:

```ruby
"Oh dear! Oh dear! I shall be late!".truncate_words(4, omission: "&hellip;")
# => "Oh dear! Oh dear!&hellip;"
```

By default words are split on whitespace. Pass `:separator` to change what counts as a word boundary:

```ruby
"Oh dear! Oh dear! I shall be late!".truncate_words(3, separator: "!")
# => "Oh dear! Oh dear! I shall be late..."
```

Here `"!"` is the separator, so each `!`-delimited segment is treated as a "word" — the string is truncated after the third one.

`:separator` can also be a regexp:

```ruby
"Oh dear! Oh dear! I shall be late!".truncate_words(4, separator: /\s/)
# => "Oh dear! Oh dear!..."
```

NOTE: Defined in `active_support/core_ext/string/filters.rb`.

[String#truncate_words]: https://api.rubyonrails.org/classes/String.html#method-i-truncate_words

### `inquiry`

The [`inquiry`][String#inquiry] method converts a string into a `StringInquirer`
object making equality checks prettier.

```ruby
"production".inquiry.production? # => true
"active".inquiry.inactive?       # => false, for anything other than ".active?"
```

NOTE: Defined in `active_support/core_ext/string/inquiry.rb`.

[String#inquiry]: https://api.rubyonrails.org/classes/String.html#method-i-inquiry

### `strip_heredoc`

A heredoc is Ruby's syntax for defining a multiline string in code. The string content is written inline, indented to match the surrounding code:

```ruby
if options[:usage]
  puts <<-USAGE
    This command does such and such.
    Supported options are:
      -h         This message
  USAGE
end
```

The problem is that the resulting string preserves all the leading whitespace used for indentation, which means the output will be indented too.

The [`strip_heredoc`][String#strip_heredoc] method solves this by finding the least indented line in the string and removing that amount of leading whitespace from every line, so the output appears flush against the left margin:

```ruby
if options[:usage]
  puts <<-USAGE.strip_heredoc
    This command does such and such.
    Supported options are:
      -h         This message
  USAGE
end
```

The user would see:

```
This command does such and such.
Supported options are:
  -h         This message
```

NOTE: Ruby 2.3+ introduced the squiggly heredoc (`<<~`) which does the same thing natively. The `strip_heredoc` core extension predates this and remains available for compatibility, but in modern Ruby `<<~` is the preferred approach.

NOTE: Defined in `active_support/core_ext/string/strip.rb`.

[String#strip_heredoc]: https://api.rubyonrails.org/classes/String.html#method-i-strip_heredoc

### `indent`

The `indent` method indents the lines in the receiver by a given number of characters:

```ruby
<<~EOS.indent(2)
  def some_method
    some_code
  end
EOS
# =>
  def some_method
    some_code
  end
```

The second argument specifies the indent string to use. The default is `nil`, which causes the `indent` method to guess based on the first indented line, defaulting to a space:

```ruby
"  foo".indent(2)        # => "    foo"
"foo\n\t\tbar".indent(2) # => "\t\tfoo\n\t\t\t\tbar"
"foo".indent(2, "\t")    # => "\t\tfoo"
```

The third argument is a flag for whether empty lines should be indented. It defaults to `false`:

```ruby
"foo\n\nbar".indent(2)            # => "  foo\n\n  bar"
"foo\n\nbar".indent(2, nil, true) # => "  foo\n  \n  bar"
```

The `indent!` method performs the same operation in place.

NOTE: Defined in `active_support/core_ext/string/indent.rb`.

[String#indent!]: https://api.rubyonrails.org/classes/String.html#method-i-indent-21
[String#indent]: https://api.rubyonrails.org/classes/String.html#method-i-indent

### Accessing

#### `at(position)`

The [`at`][String#at] method returns the character of the string at a given position:

```ruby
"hello".at(0)  # => "h"
"hello".at(4)  # => "o"
"hello".at(-1) # => "o"
"hello".at(10) # => nil
```

NOTE: Defined in `active_support/core_ext/string/access.rb`.

[String#at]: https://api.rubyonrails.org/classes/String.html#method-i-at

#### `from(position)`

The [`from`][String#from] method returns a substring of the string starting at a given position:

```ruby
"hello".from(0)  # => "hello"
"hello".from(2)  # => "llo"
"hello".from(-2) # => "lo"
"hello".from(10) # => nil
```

NOTE: Defined in `active_support/core_ext/string/access.rb`.

[String#from]: https://api.rubyonrails.org/classes/String.html#method-i-from

#### `to(position)`

The [`to`][String#to] method returns a substring of the string up to a given position:

```ruby
"hello".to(0)  # => "h"
"hello".to(2)  # => "hel"
"hello".to(-2) # => "hell"
"hello".to(10) # => "hello"
```

NOTE: Defined in `active_support/core_ext/string/access.rb`.

[String#to]: https://api.rubyonrails.org/classes/String.html#method-i-to

#### `first(limit = 1)`

The `first` method returns a substring containing the first `limit` characters of the string. The default value of `limit` is `1`, so calling `first` without an argument returns 1 character:

```ruby
"Hello, World".first     # => "H"
"Hello, World".first(5)  # => "Hello"
"Hello, World".first(0)  # => ""
```

NOTE: Defined in `active_support/core_ext/string/access.rb`.

[String#first]: https://api.rubyonrails.org/classes/String.html#method-i-first

#### `last(limit = 1)`

The `last` method returns a substring containing the last `limit` characters of the string:

```ruby
"Hello, World".last     # => "d"
"Hello, World".last(5)  # => "World"
"Hello, World".last(0)  # => ""
```

NOTE: Defined in `active_support/core_ext/string/access.rb`.

[String#last]: https://api.rubyonrails.org/classes/String.html#method-i-last

### Inflections

#### `pluralize`

The method [`pluralize`][String#pluralize] returns the plural of its receiver:

```ruby
"table".pluralize     # => "tables"
"ruby".pluralize      # => "rubies"
"equipment".pluralize # => "equipment"
```

As the previous example shows, Active Support knows about irregular plurals and uncountable nouns. Built-in rules can be extended in `config/initializers/inflections.rb`. This file is generated by default,  with the `rails new` command and has instructions in comments.

This method can also take an optional `count` parameter. If `count == 1` the singular form will be returned. For any other value of `count` the plural form is returned:

```ruby
"dude".pluralize(0) # => "dudes"
"dude".pluralize(1) # => "dude"
"dude".pluralize(2) # => "dudes"
```

Active Record uses `pluralize` to compute the default table name that corresponds to a model:

```ruby#4
# active_record/model_schema.rb
def undecorated_table_name(model_name)
  table_name = model_name.to_s.demodulize.underscore
  pluralize_table_names ? table_name.pluralize : table_name
end
```

NOTE: Defined in `active_support/core_ext/string/inflections.rb`.

[String#pluralize]: https://api.rubyonrails.org/classes/String.html#method-i-pluralize

#### `singularize`

The [`singularize`][String#singularize] method is the inverse of `pluralize`:

```ruby
"tables".singularize    # => "table"
"rubies".singularize    # => "ruby"
"equipment".singularize # => "equipment"
```

Active Record associations compute the name of the corresponding default associated class using this method:

```ruby#4
# active_record/reflection.rb
def derive_class_name
  class_name = name.to_s.camelize
  class_name = class_name.singularize if collection?
  class_name
end
```

NOTE: Defined in `active_support/core_ext/string/inflections.rb`.

[String#singularize]: https://api.rubyonrails.org/classes/String.html#method-i-singularize

#### `camelize`

The method [`camelize`][String#camelize] returns its receiver in camel case:

```ruby
"product".camelize    # => "Product"
"admin_user".camelize # => "AdminUser"
```

This method is also used to transform paths into Ruby class or module names, where slashes separate namespaces:

```ruby
"backoffice/session".camelize # => "Backoffice::Session"
```

The `/` becomes a `::` above. For example, Action Pack uses this method to load the class that provides a certain session store:

```ruby#4
# action_controller/metal/session_management.rb
def session_store=(store)
  @@session_store = store.is_a?(Symbol) ?
    ActionDispatch::Session.const_get(store.to_s.camelize) :
    store
end
```

The `camelize` method accepts an optional argument, with the values of either `:upper` (default) or `:lower`. Use `:lower` to make the first letter lowercase:

```ruby
"visual_effect".camelize(:lower) # => "visualEffect"
```

That may be handy to compute method names in a language that follows that convention (such as JavaScript).

INFO: You can think of `camelize` as the inverse of [`underscore`](#underscore), though there are cases where that does not hold: `"SSLError".underscore.camelize` gives back `"SslError"`. To support cases such as this, Active Support allows you to specify acronyms in `config/initializers/inflections.rb`:

```ruby
ActiveSupport::Inflector.inflections do |inflect|
  inflect.acronym "SSL"
end

"SSLError".underscore.camelize # => "SSLError"
```

This method is aliased to [`camelcase`][String#camelcase].

NOTE: Defined in `active_support/core_ext/string/inflections.rb`.

[String#camelcase]: https://api.rubyonrails.org/classes/String.html#method-i-camelcase
[String#camelize]: https://api.rubyonrails.org/classes/String.html#method-i-camelize

#### `underscore`

The [`underscore`][String#underscore] method takes a string from camel case to words separated by underscores or paths. It works with string that start with a lowercase too. This method does not accept any argument.

```ruby
"Product".underscore   # => "product"
"AdminUser".underscore # => "admin_user"
"visualEffect".underscore # => "visual_effect"
```

Also converts `::` back to `/`:

```ruby
"Backoffice::Session".underscore # => "backoffice/session"
```

Rails uses `underscore` to get a lowercased name for controller classes:

```ruby
# actionpack/lib/abstract_controller/base.rb
def controller_path
  @controller_path ||= name.delete_suffix("Controller").underscore
end
```

For example, that value is the one you get in `params[:controller]`.

INFO: You can think of `underscore` as the inverse of `camelize`, though there are cases where that does not hold. For example, `"SSLError".underscore.camelize` gives back `"SslError"`.

NOTE: Defined in `active_support/core_ext/string/inflections.rb`.

[String#underscore]: https://api.rubyonrails.org/classes/String.html#method-i-underscore

#### `titleize`

The [`titleize`][String#titleize] method capitalizes the words in the receiver:

```ruby
"alice in wonderland".titleize # => "Alice In Wonderland"
"fermat's enigma".titleize     # => "Fermat's Enigma"
```

This method is aliased to [`titlecase`][String#titlecase].

NOTE: Defined in `active_support/core_ext/string/inflections.rb`.

[String#titlecase]: https://api.rubyonrails.org/classes/String.html#method-i-titlecase
[String#titleize]: https://api.rubyonrails.org/classes/String.html#method-i-titleize

#### `dasherize`

The [`dasherize`][String#dasherize] method replaces the underscores in the receiver with dashes:

```ruby
"name".dasherize         # => "name"
"contact_data".dasherize # => "contact-data"
```

The XML serializer of models uses this method to dasherize node names:

```ruby#4
# active_model/serializers/xml.rb
def reformat_name(name)
  name = name.camelize if camelize?
  dasherize? ? name.dasherize : name
end
```

NOTE: Defined in `active_support/core_ext/string/inflections.rb`.

[String#dasherize]: https://api.rubyonrails.org/classes/String.html#method-i-dasherize

#### `demodulize`

When working with namespaced constants, the [`demodulize`][String#demodulize] method strips the module path and returns just the constant name at the end:

```ruby
"Product".demodulize                        # => "Product"
"Backoffice::UsersController".demodulize    # => "UsersController"
"Admin::Hotel::ReservationUtils".demodulize # => "ReservationUtils"
"::Inflections".demodulize                  # => "Inflections"
"".demodulize                               # => ""
```

Active Record uses this method to compute the name of a counter cache column:

```ruby#4
# active_record/reflection.rb
def counter_cache_column
  if options[:counter_cache] == true
    "#{active_record.name.demodulize.underscore.pluralize}_count"
  elsif options[:counter_cache]
    options[:counter_cache]
  end
end
```

NOTE: Defined in `active_support/core_ext/string/inflections.rb`.

[String#demodulize]: https://api.rubyonrails.org/classes/String.html#method-i-demodulize

#### `deconstantize`

The [`deconstantize`][String#deconstantize]  method is the complement of demodulize, it removes the rightmost segment in a qualified string, returning the containing namespace instead:

```ruby
"Product".deconstantize                        # => ""
"Backoffice::UsersController".deconstantize    # => "Backoffice"
"Admin::Hotel::ReservationUtils".deconstantize # => "Admin::Hotel"
```

NOTE: Defined in `active_support/core_ext/string/inflections.rb`.

[String#deconstantize]: https://api.rubyonrails.org/classes/String.html#method-i-deconstantize

#### `parameterize`

The [`parameterize`][String#parameterize] method normalizes its receiver in a way that can be used in URLs.

```ruby
"John Smith".parameterize # => "john-smith"
"Kurt Gödel".parameterize # => "kurt-godel"
```

To preserve the case of the string, set the `preserve_case` argument to `true`. By default, `preserve_case` is set to `false`.

```ruby
"John Smith".parameterize(preserve_case: true) # => "John-Smith"
"Kurt Gödel".parameterize(preserve_case: true) # => "Kurt-Godel"
```

To use a custom separator, override the `separator` argument.

```ruby
"John Smith".parameterize(separator: "_") # => "john_smith"
"Kurt Gödel".parameterize(separator: "_") # => "kurt_godel"
```

NOTE: Defined in `active_support/core_ext/string/inflections.rb`.

[String#parameterize]: https://api.rubyonrails.org/classes/String.html#method-i-parameterize

#### `tableize`

The `tableize` method converts a class name into the snake_case plural form. It is generally equivalent to calling `underscore` followed by `pluralize`:

```ruby
"Person".tableize      # => "people"
"Invoice".tableize     # => "invoices"
"InvoiceLine".tableize # => "invoice_lines"
```

One use case for `tableize` is deriving database table names that correspond to Active Record model class name. Active Record's actual table name resolution is more involved, it also handles namespacing and respects configuration options like `table_name_prefix`. So the `tableize` method can be thought of as a close approximation but not the exact implementation.

NOTE: Defined in `active_support/core_ext/string/inflections.rb`.

[String#tableize]: https://api.rubyonrails.org/classes/String.html#method-i-tableize

#### `classify`

The [`classify`][String#classify] method is the inverse of `tableize`. It gives you the class name corresponding to a table name:

```ruby
"people".classify        # => "Person"
"invoices".classify      # => "Invoice"
"invoice_lines".classify # => "InvoiceLine"
```

The method understands qualified table names:

```ruby
"highrise_production.companies".classify # => "Company"
```

Note that `classify` returns a class name as a string. You can get the actual class object by invoking `constantize` on it, explained next.

NOTE: Defined in `active_support/core_ext/string/inflections.rb`.

[String#classify]: https://api.rubyonrails.org/classes/String.html#method-i-classify

#### `constantize`

The `constantize` method resolves a string to the constant it references:

```ruby
"Integer".constantize # => Integer

module M
  X = 1
end
"M::X".constantize # => 1
```

If the string does not correspond to a known constant or is not a valid constant name, `constantize` raises `NameError`.

Constant resolution always starts from the top-level `Object`, regardless of the current scope and even without a leading `::`. This means it can behave differently from how Ruby resolves constants in the same context:

```ruby
X = :in_Object

module M
  X = :in_M
  X                  # => :in_M        (Ruby resolves from current scope)
  "X".constantize    # => :in_Object   (constantize always starts from Object)
  "::X".constantize  # => :in_Object
end
```

A practical example of `constantize` in Rails is in Action Mailer's test helper, which infers the mailer class from the test class name:

```ruby
# action_mailer/test_case.rb
def determine_default_mailer(name)
  name.delete_suffix("Test").constantize
rescue NameError => e
  raise NonInferrableMailerError.new(name)
end
```

NOTE: Defined in `active_support/core_ext/string/inflections.rb`.

[String#constantize]: https://api.rubyonrails.org/classes/String.html#method-i-constantize

#### `humanize`

The `humanize` method converts an attribute name into a more readable form suitable for display to end users. It applies the following transformations in order:

- Applies human inflection rules
- Removes leading underscores
- Removes a `_id` suffix if present
- Replaces underscores with spaces
- Downcases all words except acronyms
- Capitalizes the first word

```ruby
"name".humanize           # => "Name"
"author_id".humanize      # => "Author"
"comments_count".humanize # => "Comments count"
"_id".humanize            # => "Id"
"ssl_error".humanize      # => "SSL error"  (if "SSL" is defined as an acronym)
```

The capitalization of the first word can be disabled with `:capitalize`:

```ruby
"author_id".humanize(capitalize: false) # => "author"
```

Rails uses `humanize` internally in `full_messages` to build human readable validation error messages from attribute names:

```ruby
# activemodel/lib/active_model/errors.rb
def full_message
  attr_name = attribute.to_s.tr(".", "_").humanize
  attr_name = @base.class.human_attribute_name(attribute, default: attr_name)
  # ...
end
```

So an attribute like `email_address` would appear as `"Email address"` in a validation error message.

NOTE: Defined in `active_support/core_ext/string/inflections.rb`.

[String#humanize]: https://api.rubyonrails.org/classes/String.html#method-i-humanize

#### `foreign_key`

The method [`foreign_key`][String#foreign_key] derives a foreign key column name from a class name. To do so it demodulizes, underscores, and adds `_id`:

```ruby
"User".foreign_key           # => "user_id"
"InvoiceLine".foreign_key    # => "invoice_line_id"
"Admin::Session".foreign_key # => "session_id"
```

Pass a `false` argument if you do not want the underscore in front of `id`:

```ruby
"User".foreign_key(false) # => "userid"
```

Associations use this method to infer foreign keys, for example `has_one` and `has_many` do this:

```ruby
# active_record/associations.rb
foreign_key = options[:foreign_key] || reflection.active_record.name.foreign_key
```

NOTE: Defined in `active_support/core_ext/string/inflections.rb`.

[String#foreign_key]: https://api.rubyonrails.org/classes/String.html#method-i-foreign_key

#### `upcase_first`

The method [`upcase_first`][String#upcase_first] capitalizes the first letter of the receiver:

```ruby
"employee salary".upcase_first # => "Employee salary"
"".upcase_first                # => ""
```

NOTE: Defined in `active_support/core_ext/string/inflections.rb`.

[String#upcase_first]: https://api.rubyonrails.org/classes/String.html#method-i-upcase_first

#### `downcase_first`

The method [`downcase_first`][String#downcase_first] converts the first letter of the receiver to lowercase:

```ruby
"If I had read Alice in Wonderland".downcase_first # => "if I had read Alice in Wonderland"
"".downcase_first                                  # => ""
```

NOTE: Defined in `active_support/core_ext/string/inflections.rb`.

[String#downcase_first]: https://api.rubyonrails.org/classes/String.html#method-i-downcase_first

### Date and Time Conversions For Strings

The `to_date`, `to_time`, and `to_datetime` methods are convenience wrappers around [`Date._parse`][] from Ruby that convert a string into the corresponding date or time object:

```ruby
"2026-05-05".to_date              # => Tue, 05 May 2026
"2026-05-05 23:37:00".to_time     # => 2026-05-05 23:37:00 +0000
"2026-05-05 23:37:00".to_datetime # => Tue, 05 May 2026 23:37:00 +0000
```

The `to_time` method accepts an optional `:utc` or `:local` argument to specify the time zone. The default is `:local`:

```ruby
"2026-05-05 23:42:00".to_time(:utc)   # => 2026-05-05 23:42:00 UTC
"2026-05-05 23:42:00".to_time(:local) # => 2026-05-05 23:42:00 +0200
```

INFO: All three methods return `nil` for blank strings. Refer to the documentation of `Date._parse` for further details on supported string formats.

NOTE: Defined in `active_support/core_ext/string/conversions.rb`.

[String#to_date]: https://api.rubyonrails.org/classes/String.html#method-i-to_date
[String#to_datetime]: https://api.rubyonrails.org/classes/String.html#method-i-to_datetime
[String#to_time]: https://api.rubyonrails.org/classes/String.html#method-i-to_time
[`Date._parse`]: https://docs.ruby-lang.org/en/3.4/Date.html#method-c-parse

Extensions to `Numeric`
-----------------------

### `bytes`, `kilobytes`, etc.

All numbers respond the below methods for converting to bytes:

* [`bytes`][Numeric#bytes]
* [`kilobytes`][Numeric#kilobytes]
* [`megabytes`][Numeric#megabytes]
* [`gigabytes`][Numeric#gigabytes]
* [`terabytes`][Numeric#terabytes]
* [`petabytes`][Numeric#petabytes]
* [`exabytes`][Numeric#exabytes]
* [`zettabytes`][Numeric#zettabytes]

They return the corresponding number of bytes, using a conversion factor of 1 kilobyte = 1024 bytes:

```ruby
2.kilobytes   # => 2048
3.megabytes   # => 3145728
3.5.gigabytes # => 3758096384.0
-4.exabytes   # => -4611686018427387904
```

Singular forms are aliased so you can also do `1.megabyte`.

NOTE: Defined in `active_support/core_ext/numeric/bytes.rb`.

[Numeric#bytes]: https://api.rubyonrails.org/classes/Numeric.html#method-i-bytes
[Numeric#exabytes]: https://api.rubyonrails.org/classes/Numeric.html#method-i-exabytes
[Numeric#gigabytes]: https://api.rubyonrails.org/classes/Numeric.html#method-i-gigabytes
[Numeric#kilobytes]: https://api.rubyonrails.org/classes/Numeric.html#method-i-kilobytes
[Numeric#megabytes]: https://api.rubyonrails.org/classes/Numeric.html#method-i-megabytes
[Numeric#petabytes]: https://api.rubyonrails.org/classes/Numeric.html#method-i-petabytes
[Numeric#terabytes]: https://api.rubyonrails.org/classes/Numeric.html#method-i-terabytes
[Numeric#zettabytes]: https://api.rubyonrails.org/classes/Numeric.html#method-i-zettabytes

### `hours`, `days`, etc.

Active Support adds the following methods to numbers for expressing and calculating durations:

- [`seconds`][Numeric#seconds]
- [`minutes`][Numeric#minutes]
- [`hours`][Numeric#hours]
- [`days`][Numeric#days]
- [`weeks`][Numeric#weeks]
- [`fortnights`][Numeric#fortnights]

These return `ActiveSupport::Duration` objects that can be combined and used in time calculations:

```ruby
45.minutes + 2.hours + 4.weeks    # => 4 weeks, 2 hours, and 45 minutes

1.day.from_now                    # => Time.current.advance(days: 1)
2.weeks.from_now                  # => Time.current.advance(weeks: 2)
(4.days + 5.weeks).from_now       # => Time.current.advance(days: 4, weeks: 5)
```

They can also be used with [`ago`][Duration#ago] to calculate times in the past:

```ruby
2.hours.ago                       # => Time.current.advance(hours: -2)
```

NOTE: Defined in `active_support/core_ext/numeric/time.rb`.

[Duration#ago]: https://api.rubyonrails.org/classes/ActiveSupport/Duration.html#method-i-ago
[Duration#from_now]: https://api.rubyonrails.org/classes/ActiveSupport/Duration.html#method-i-from_now
[Numeric#days]: https://api.rubyonrails.org/classes/Numeric.html#method-i-days
[Numeric#fortnights]: https://api.rubyonrails.org/classes/Numeric.html#method-i-fortnights
[Numeric#hours]: https://api.rubyonrails.org/classes/Numeric.html#method-i-hours
[Numeric#minutes]: https://api.rubyonrails.org/classes/Numeric.html#method-i-minutes
[Numeric#seconds]: https://api.rubyonrails.org/classes/Numeric.html#method-i-seconds
[Numeric#weeks]: https://api.rubyonrails.org/classes/Numeric.html#method-i-weeks

### Formatting with `to_fs`

Active Support adds `to_fs` to numbers with a variety of formatting options.

Phone numbers:

```ruby
1235551234.to_fs(:phone)                            # => "123-555-1234"
1235551234.to_fs(:phone, area_code: true)           # => "(123) 555-1234"
1235551234.to_fs(:phone, country_code: 1)           # => "+1-123-555-1234"
1235551234.to_fs(:phone, area_code: true, extension: 555) # => "(123) 555-1234 x 555"
```

Currency:

```ruby
1234567890.50.to_fs(:currency)                  # => "$1,234,567,890.50"
1234567890.506.to_fs(:currency, precision: 3)   # => "$1,234,567,890.506"
```

Percentages:

```ruby
100.to_fs(:percentage)                          # => "100.000%"
100.to_fs(:percentage, precision: 0)            # => "100%"
302.24398923423.to_fs(:percentage, precision: 5) # => "302.24399%"
```

Delimited numbers:

```ruby
12345678.to_fs(:delimited)                      # => "12,345,678"
12345678.05.to_fs(:delimited)                   # => "12,345,678.05"
12345678.to_fs(:delimited, delimiter: ".")      # => "12.345.678"
```

Rounded numbers:

```ruby
111.2345.to_fs(:rounded)                        # => "111.235"
111.2345.to_fs(:rounded, precision: 2)          # => "111.23"
389.32314.to_fs(:rounded, precision: 0)         # => "389"
```

Human readable byte sizes:

```ruby
1234.to_fs(:human_size)                         # => "1.21 KB"
1234567.to_fs(:human_size)                      # => "1.18 MB"
1234567890.to_fs(:human_size)                   # => "1.15 GB"
1234567890123.to_fs(:human_size)                # => "1.12 TB"
```

Human readable large numbers:

```ruby
1234.to_fs(:human)                              # => "1.23 Thousand"
1234567.to_fs(:human)                           # => "1.23 Million"
1234567890.to_fs(:human)                        # => "1.23 Billion"
1234567890123.to_fs(:human)                     # => "1.23 Trillion"
```

NOTE: Defined in `active_support/core_ext/numeric/conversions.rb`.

Extensions to `Integer`
-----------------------

### `multiple_of?`

The method [`multiple_of?`][Integer#multiple_of?] tests whether an integer is multiple of the argument:

```ruby
42.multiple_of?(7) # => true
42.multiple_of?(8) # => false
```

NOTE: Defined in `active_support/core_ext/integer/multiple.rb`.

[Integer#multiple_of?]: https://api.rubyonrails.org/classes/Integer.html#method-i-multiple_of-3F

### `ordinal`

The [`ordinal`][Integer#ordinal] method returns the suffix string that corresponds to an integer's position in an ordered sequence — "st", "nd", "rd", or "th":

```ruby
1.ordinal    # => "st"
2.ordinal    # => "nd"
53.ordinal   # => "rd"
2009.ordinal # => "th"
-21.ordinal  # => "st"
-134.ordinal # => "th"
```

NOTE: Defined in `active_support/core_ext/integer/inflections.rb`.

[Integer#ordinal]: https://api.rubyonrails.org/classes/Integer.html#method-i-ordinal

### `ordinalize`

While the `ordinal` method  only returns the suffix string, the [`ordinalize`][Integer#ordinalize] method returns the full ordinal string corresponding to the receiver integer.

```ruby
1.ordinalize    # => "1st"
2.ordinalize    # => "2nd"
53.ordinalize   # => "53rd"
2009.ordinalize # => "2009th"
-21.ordinalize  # => "-21st"
-134.ordinalize # => "-134th"
```

NOTE: Defined in `active_support/core_ext/integer/inflections.rb`.

[Integer#ordinalize]: https://api.rubyonrails.org/classes/Integer.html#method-i-ordinalize

### Time Calculations

Active Support adds [`months`][Integer#months] and [`years`][Integer#years] to integers for expressing calendar level durations:

```ruby
1.month.from_now                          # => Time.current.advance(months: 1)
2.years.from_now                          # => Time.current.advance(years: 2)
(4.months + 5.years).from_now            # => Time.current.advance(months: 4, years: 5)
```

For smaller durations less than a month, such as seconds, minutes, hours, days, and weeks, see the time extensions to `Numeric`.

NOTE: Defined in `active_support/core_ext/integer/time.rb`.

[Integer#months]: https://api.rubyonrails.org/classes/Integer.html#method-i-months
[Integer#years]: https://api.rubyonrails.org/classes/Integer.html#method-i-years

Extensions to `Enumerable`
--------------------------

Any class that includes Ruby's `Enumerable` and implements `each` gets a rich set of iteration and collection methods, such as `map`, `select`, `reject`, `find`, `sort`, etc.

In Rails, classes like `Array`, `Hash`, `Range` and Active Record query results all include `Enumerable`, so these methods are available everywhere.

Active Support extends `Enumerable` with higher level convenience methods.

### `index_by`

The [`index_by`][Enumerable#index_by] method transforms an enumerable into a hash, using the block's return value as the key for each element:

```ruby
users = [
  User.new(id: 1, name: "Alice"),
  User.new(id: 2, name: "Bob")
]

users.index_by(&:id)
# => { 1 => #<User name: "Alice">, 2 => #<User name: "Bob"> }
```

WARNING: Keys must be unique. If the block returns the same value for multiple elements, only the last one is kept.

NOTE: Defined in `active_support/core_ext/enumerable.rb`.

[Enumerable#index_by]: https://api.rubyonrails.org/classes/Enumerable.html#method-i-index_by

### `index_with`

The [`index_with`][Enumerable#index_with] method builds a hash using the elements of an enumerable as keys. Values are either set from a block or a single default value passed as an argument:

```ruby
# Value is set to a default
%i[monday tuesday wednesday].index_with("available")
# => { monday: "available", tuesday: "available", wednesday: "available" }

# Values come from a block
post = Post.new(title: "hey there", body: "what's up?")
%i[title body].index_with { |attr| post.public_send(attr) }
# => { title: "hey there", body: "what's up?" }
```

NOTE: Defined in `active_support/core_ext/enumerable.rb`.

[Enumerable#index_with]: https://api.rubyonrails.org/classes/Enumerable.html#method-i-index_with

### `many?`

The [`many?`][Enumerable#many?] method is a readable shorthand for `collection.size > 1`:

```erb
<% if pages.many? %>
  <%= pagination_links %>
<% end %>
```

An optional block narrows the check to elements matching a condition:

```ruby
videos.many? { |video| video.category == params[:category] }
```

NOTE: Defined in `active_support/core_ext/enumerable.rb`.

[Enumerable#many?]: https://api.rubyonrails.org/classes/Enumerable.html#method-i-many-3F

### `exclude?`

The [`exclude?`][Enumerable#exclude?] method returns `true` if a given object is not present in the collection. It is the complement of Ruby's built-in `include?`:

```ruby
visited.include?(node)  # => true
visited.exclude?(node)  # => false

to_visit << node if visited.exclude?(node)
```

NOTE: Defined in `active_support/core_ext/enumerable.rb`.

[Enumerable#exclude?]: https://api.rubyonrails.org/classes/Enumerable.html#method-i-exclude-3F

### `including`

The [`including`][Enumerable#including] method returns a new enumerable with the given elements appended:

```ruby
[1, 2, 3].including(4, 5)                     # => [1, 2, 3, 4, 5]
["Alice", "Bob"].including("Carol", "Dave")    # => ["Alice", "Bob", "Carol", "Dave"]
```

NOTE: Defined in `active_support/core_ext/enumerable.rb`.

[Enumerable#including]: https://api.rubyonrails.org/classes/Enumerable.html#method-i-including

### `excluding`

The [`excluding`][Enumerable#excluding] method returns a copy of an
enumerable with the specified elements removed:

```ruby
["David", "Rafael", "Aaron", "Todd"].excluding("Aaron", "Todd") # => ["David", "Rafael"]
```

This method is aliased to [`without`][Enumerable#without].

NOTE: Defined in `active_support/core_ext/enumerable.rb`.

[Enumerable#excluding]: https://api.rubyonrails.org/classes/Enumerable.html#method-i-excluding
[Enumerable#without]: https://api.rubyonrails.org/classes/Enumerable.html#method-i-without

### `pluck`

The [`pluck`][Enumerable#pluck] method extracts the given key from each element:

```ruby
[{ name: "David" }, { name: "Rafael" }, { name: "Aaron" }].pluck(:name) # => ["David", "Rafael", "Aaron"]
[{ id: 1, name: "David" }, { id: 2, name: "Rafael" }].pluck(:id, :name) # => [[1, "David"], [2, "Rafael"]]
```

NOTE: Defined in `active_support/core_ext/enumerable.rb`.

[Enumerable#pluck]: https://api.rubyonrails.org/classes/Enumerable.html#method-i-pluck

### `pick`

The [`pick`][Enumerable#pick] method extracts the given key from the first element:

```ruby
[{ name: "David" }, { name: "Rafael" }, { name: "Aaron" }].pick(:name) # => "David"
[{ id: 1, name: "David" }, { id: 2, name: "Rafael" }].pick(:id, :name) # => [1, "David"]
```

NOTE: Defined in `active_support/core_ext/enumerable.rb`.

[Enumerable#pick]: https://api.rubyonrails.org/classes/Enumerable.html#method-i-pick

### `in_order_of`

The [`in_order_of`][Enumerable#in_order_of] method returns a new array reordered to match a given series, based on a specific key of the objects in the collection:

```ruby
Person = Struct.new(:id, :name)

people = [
  Person.new(5, "Carol"),
  Person.new(3, "Bob"),
  Person.new(1, "Alice")
]

people.in_order_of(:id, [1, 5, 3])
# => [Person(id: 1, name: "Alice"), Person(id: 5, name: "Carol"), Person(id: 3, name: "Bob")]
```

By default, elements not named in the series are excluded from the result. Pass `filter: false` to include them at the end instead:

```ruby
people.in_order_of(:id, [ 1, 5 ], filter: false)
# => [ Person.find(1), Person.find(5), Person.find(3) ]  — Person.find(3) appended at end
```

Keys in the series that have no matching element in the collection are silently ignored.

NOTE: Defined in `active_support/core_ext/enumerable.rb`.

[Enumerable#in_order_of]: https://api.rubyonrails.org/classes/Enumerable.html#method-i-in_order_of

### `minimum` and `maximum`

The [`minimum`][Enumerable#minimum] and [`maximum`][Enumerable#maximum] methods extract a specific attribute from each element and return the minimum or maximum value. They are a convenient shorthand for `map` + `min`/`max`:

```ruby
Person = Struct.new(:name, :age)

people = [
  Person.new("Alice", 27),
  Person.new("Bob",   35),
  Person.new("Carol", 31)
]

people.minimum(:age) # => 27
people.maximum(:age) # => 35
```

This is particularly useful with Active Record collections when you want to find the min or max of an attribute without loading all records into memory for manual comparison.

NOTE: Defined in `active_support/core_ext/enumerable.rb`.

[Enumerable#minimum]: https://api.rubyonrails.org/classes/Enumerable.html#method-i-minimum
[Enumerable#maximum]: https://api.rubyonrails.org/classes/Enumerable.html#method-i-maximum

### `sole`

The [`sole`][Enumerable#sole] method returns the only element in the collection. If the collection has no items, or more than one item, it raises `Enumerable::SoleItemExpectedError`:

```ruby
["x"].sole               # => "x"
[].sole                  # => Enumerable::SoleItemExpectedError: no item found
["x", "y"].sole          # => Enumerable::SoleItemExpectedError: multiple items found
{ a: 1, b: 2 }.sole      # => Enumerable::SoleItemExpectedError: multiple items found
```

This is useful when you expect a query or collection to return exactly one result and want an explicit error if that assumption is violated, rather than silently getting `nil` or the first of many.

NOTE: Defined in `active_support/core_ext/enumerable.rb`.

[Enumerable#sole]: https://api.rubyonrails.org/classes/Enumerable.html#method-i-sole

### `compact_blank`

The [`compact_blank`][Enumerable#compact_blank] method returns a new collection with all blank items removed. It uses `Object#blank?` to determine what counts as blank. Unlike Ruby's built-in `compact`, which only removes `nil`, `compact_blank` also removes empty strings, whitespace-only strings, empty arrays, empty hashes, and `false`:

```ruby
[1, "", nil, 2, " ", [], {}, false, true].compact_blank
# => [1, 2, true]
```

When called on a `Hash`, it removes entries with blank values:

```ruby
{ a: "", b: 1, c: nil, d: [], e: false, f: true }.compact_blank
# => { b: 1, f: true }
```

NOTE: Defined in `active_support/core_ext/enumerable.rb`.

[Enumerable#compact_blank]: https://api.rubyonrails.org/classes/Enumerable.html#method-i-compact_blank### `in_order_of`

Extensions to `Array`
---------------------

### `extract!`

The [`extract!`][Array#extract!] method removes and returns the elements for which the block returns true, modifying the original array in place:

```ruby
numbers = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
odd_numbers = numbers.extract! { |n| n.odd? } # => [1, 3, 5, 7, 9]
numbers                                        # => [0, 2, 4, 6, 8]
```

NOTE: Defined in `active_support/core_ext/array/extract.rb`.

[Array#extract!]: https://api.rubyonrails.org/classes/Array.html#method-i-extract-21

### `extract_options!`

Ruby allows you to omit the curly braces when passing a hash as the last argument to a method:

```ruby
User.exists?(email: params[:email])
```

Rails uses this convention extensively to simulate named parameters,particularly for passing options to methods that accept a variable number of arguments via `*`. The problem is that when a method uses `*args`, the trailing hash gets absorbed into the args array and loses its identity as an options hash.

The [`extract_options!`][Array#extract_options!] method solves this. It checks whether the last element of an array is a hash. If so, it removes and returns the hash. Otherwise it returns an empty hash.

Here's how Rails uses it in the `caches_action` controller macro:

```ruby
def caches_action(*actions)
  return unless cache_configured?
  options = actions.extract_options!
  # options contains the hash, actions contains only the action names
end
```

This allows callers to pass any number of action names followed by an optional options hash:

```ruby
caches_action :index, :show, expires_in: 1.hour

# Inside the method:
# actions  => [:index, :show]
# options  => { expires_in: 1.hour }
```

NOTE: Defined in `active_support/core_ext/array/extract_options.rb`.

[Array#extract_options!]: https://api.rubyonrails.org/classes/Array.html#method-i-extract_options-21

#### `to_sentence`

The method [`to_sentence`][Array#to_sentence] turns an array into a string containing a sentence that enumerates its items:

```ruby
%w().to_sentence                # => ""
%w(Earth).to_sentence           # => "Earth"
%w(Earth Wind).to_sentence      # => "Earth and Wind"
%w(Earth Wind Fire).to_sentence # => "Earth, Wind, and Fire"
```

This method accepts three options:

* `:two_words_connector`: What is used for arrays of length 2. Default is " and
  ".
* `:words_connector`: What is used to join the elements of arrays with 3 or more
  elements, except for the last two. Default is ", ".
* `:last_word_connector`: What is used to join the last items of an array with 3
  or more elements. Default is ", and ".

The defaults for these options can be localized, their keys are:

| Option                 | I18n key                            |
| ---------------------- | ----------------------------------- |
| `:two_words_connector` | `support.array.two_words_connector` |
| `:words_connector`     | `support.array.words_connector`     |
| `:last_word_connector` | `support.array.last_word_connector` |

NOTE: Defined in `active_support/core_ext/array/conversions.rb`.

[Array#to_sentence]: https://api.rubyonrails.org/classes/Array.html#method-i-to_sentence

#### `to_fs`

The method [`to_fs`][Array#to_fs] acts like `to_s` by default.

If the array contains items that respond to `id`, however, the symbol `:db` may
be passed as argument. That's typically used with collections of Active Record
objects. Returned strings come from the respective calls to `id`:

```ruby
[].to_fs(:db)            # => "null"
[user].to_fs(:db)        # => "8456"
invoice.lines.to_fs(:db) # => "23,567,556,12"
```

NOTE: Defined in `active_support/core_ext/array/conversions.rb`.

[Array#to_fs]: https://api.rubyonrails.org/classes/Array.html#method-i-to_fs

#### `to_xml`

The [`to_xml`][Array#to_xml] method serializes an array into an XML string by calling `to_xml` on each element and wrapping the results in a root node. All elements must respond to `to_xml`.

The root element name is automatically inferred from the class of the first element, pluralized and dasherized:

```ruby
Contributor.limit(2).order(:rank).to_xml
# =>
# <?xml version="1.0" encoding="UTF-8"?>
# <contributors type="array">
#   <contributor>
#     <id type="integer">1</id>
#     <name>Frodo Baggins</name>
#     <rank type="integer">1</rank>
#     <url-id>frodo-baggins</url-id>
#   </contributor>
#   <contributor>
#     <id type="integer">2</id>
#     <name>Gandalf the Grey</name>
#     <rank type="integer">2</rank>
#     <url-id>gandalf-the-grey</url-id>
#   </contributor>
# </contributors>
```

If the collection contains mixed types, the root element falls back to `"objects"`:

```ruby
[Contributor.first, Commit.first].to_xml
# =>
# <?xml version="1.0" encoding="UTF-8"?>
# <objects type="array">
#   <object>
#     <id type="integer">1</id>
#     <name>Frodo Baggins</name>
#     <rank type="integer">1</rank>
#   </object>
#   <object>
#     <author>Samwise Gamgee</author>
#     <authored-timestamp type="datetime">2026-05-05T12:00:00Z</authored-timestamp>
#     <branch>origin/main</branch>
#     <id type="integer">2</id>
#     <message>Fix bug in authentication flow</message>
#     <sha1>723a47bfb3708f968821bc969a9a3fc873a3ed58</sha1>
#   </object>
# </objects>
```

If the receiver is an array of hashes, the root element is also `"objects"` by default:

```ruby
[{ a: 1, b: 2 }, { c: 3 }].to_xml
# =>
# <?xml version="1.0" encoding="UTF-8"?>
# <objects type="array">
#   <object>
#     <a type="integer">1</a>
#     <b type="integer">2</b>
#   </object>
#   <object>
#     <c type="integer">3</c>
#   </object>
# </objects>
```

WARNING: If the collection is empty, the root element defaults to `"nil-classes"` rather than the expected plural class name. Use the `:root` option to ensure a consistent root element when the collection may be empty.

The name of child nodes is the singularized form of the root node by default. Use the `:children` option to override this. The default XML builder is a fresh instance of `Builder::XmlMarkup`, you can provide your own via the `:builder` option. Other options like `:dasherize` and `:skip_types` are forwarded to the builder:

```ruby
Contributor.limit(2).order(:rank).to_xml(skip_types: true)
# =>
# <?xml version="1.0" encoding="UTF-8"?>
# <contributors>
#   <contributor>
#     <id>1</id>
#     <name>Frodo Baggins</name>
#     <rank>1</rank>
#     <url-id>frodo-baggins</url-id>
#   </contributor>
#   <contributor>
#     <id>2</id>
#     <name>Gandalf the Grey</name>
#     <rank>2</rank>
#     <url-id>gandalf-the-grey</url-id>
#   </contributor>
# </contributors>
```

NOTE: Defined in `active_support/core_ext/array/conversions.rb`.

[Array#to_xml]: https://api.rubyonrails.org/classes/Array.html#method-i-to_xml

### `Array.wrap`

The [`Array.wrap`][Array.wrap] method wraps its argument in an array unless it is already an array. This is useful when you want to normalize input that could be either a single value or a collection.

```ruby
Array.wrap(nil)       # => []
Array.wrap([1, 2, 3]) # => [1, 2, 3]
Array.wrap(0)         # => [0]
Array.wrap("hello")   # => ["hello"]
```

The rules are as follows:

- `nil` returns an empty array
- An array is returned as is
- Anything else is wrapped in a single element array

#### `Array.wrap` vs `Kernel#Array`

`Array.wrap` is similar to Ruby's built-in `Kernel#Array`, but behaves more predictably in edge cases. The most notable difference is with hashes:

```ruby
Array.wrap(foo: :bar) # => [{ foo: :bar }]  — hash is wrapped as a single element
Array(foo: :bar)      # => [[:foo, :bar]]   — hash is converted to key/value pairs
```

`Kernel#Array` calls `to_a` on the argument if `to_ary` returns `nil`, which causes hashes to be decomposed into pairs. `Array.wrap` never calls `to_a`, so a hash stays a hash.

The `Array.wrap` method does not raise an exception if `to_ary` returns a non-Array value (other than `nil`), it simply returns that value.

NOTE: `to_ary` and `to_a` are both array conversion methods but signal different intent. `to_ary` declares that an object is array-like and can be used anywhere an array is expected. `to_a` is a general conversion that may transform the object significantly, like a Hash becoming an array of key/value pairs.

There is a related Ruby idiom using the splat operator:

```ruby
[*object]
```

This behaves similarly but has its own edge cases — for example, `[*nil]` returns `[]` in Ruby, which matches `Array.wrap`, but `[*{foo: :bar}]` returns `[[:foo, :bar]]`, decomposing the hash just like `Kernel#Array`.

NOTE: Defined in `active_support/core_ext/array/wrap.rb`.

[Array.wrap]: https://api.rubyonrails.org/classes/Array.html#method-c-wrap

### `deep_dup`

The [`Array#deep_dup`][Array#deep_dup] method duplicates the array and all objects inside it recursively. Unlike Ruby's built-in `dup`, which produces a shallow copy where nested objects are still shared, `deep_dup` ensures that modifying a nested object in the copy does not affect the original:

```ruby
array = [1, [2, 3]]
dup = array.deep_dup

dup[1] << 4
dup[1]   # => [2, 3, 4]
array[1] # => [2, 3]  — original is unchanged
```

NOTE: Defined in `active_support/core_ext/object/deep_dup.rb`.

[Array#deep_dup]: https://api.rubyonrails.org/classes/Array.html#method-i-deep_dup

### Accessing

Active Support augments the Array API with several convenience accessors.

The [`to`][Array#to] method returns a subarray from the beginning up to and including the element at the given index:

```ruby
%w[a b c d].to(2)  # => ["a", "b", "c"]
[].to(7)           # => []
```

The [`from`][Array#from] method returns the tail of the array starting at the given index. Returns an empty array if the index is out of bounds:

```ruby
%w[a b c d].from(2)  # => ["c", "d"]
%w[a b c d].from(10) # => []
```

The [`including`][Array#including] method returns a new array with the given elements appended:

```ruby
[1, 2, 3].including(4, 5)            # => [1, 2, 3, 4, 5]
```

The [`excluding`][Array#excluding] method returns a copy of the array with the specified elements removed:

```ruby
["Alice", "Bob", "Carol"].excluding("Carol") # => ["Alice", "Bob"]
```

Active Support also provides positional accessors [`second`][Array#second], [`third`][Array#third], [`fourth`][Array#fourth], [`fifth`][Array#fifth], [`second_to_last`][Array#second_to_last], and [`third_to_last`][Array#third_to_last] (`first` and `last` are built into Ruby). [`forty_two`][Array#forty_two] is also available:

```ruby
%w[a b c d e].second # => "b"
%w[a b c d e].third  # => "c"
%w[a b c d e].fifth  # => "e"
```

NOTE: Defined in `active_support/core_ext/array/access.rb`.

[Array#to]: https://api.rubyonrails.org/classes/Array.html#method-i-to
[Array#from]: https://api.rubyonrails.org/classes/Array.html#method-i-from
[Array#including]: https://api.rubyonrails.org/classes/Array.html#method-i-including
[Array#excluding]: https://api.rubyonrails.org/classes/Array.html#method-i-excluding
[Array#second]: https://api.rubyonrails.org/classes/Array.html#method-i-second
[Array#third]: https://api.rubyonrails.org/classes/Array.html#method-i-third
[Array#fourth]: https://api.rubyonrails.org/classes/Array.html#method-i-fourth
[Array#fifth]: https://api.rubyonrails.org/classes/Array.html#method-i-fifth
[Array#second_to_last]: https://api.rubyonrails.org/classes/Array.html#method-i-second_to_last
[Array#third_to_last]: https://api.rubyonrails.org/classes/Array.html#method-i-third_to_last
[Array#forty_two]: https://api.rubyonrails.org/classes/Array.html#method-i-forty_two

### Conversions

#### `to_sentence`

The method [`to_sentence`][Array#to_sentence] turns an array into a string containing a sentence that enumerates its items:

```ruby
%w().to_sentence                # => ""
%w(Earth).to_sentence           # => "Earth"
%w(Earth Wind).to_sentence      # => "Earth and Wind"
%w(Earth Wind Fire).to_sentence # => "Earth, Wind, and Fire"
```

This method accepts three options:

* `:two_words_connector`: What is used for arrays of length 2. Default is " and
  ".
* `:words_connector`: What is used to join the elements of arrays with 3 or more
  elements, except for the last two. Default is ", ".
* `:last_word_connector`: What is used to join the last items of an array with 3
  or more elements. Default is ", and ".

The defaults for these options can be localized, their keys are:

| Option                 | I18n key                            |
| ---------------------- | ----------------------------------- |
| `:two_words_connector` | `support.array.two_words_connector` |
| `:words_connector`     | `support.array.words_connector`     |
| `:last_word_connector` | `support.array.last_word_connector` |

NOTE: Defined in `active_support/core_ext/array/conversions.rb`.

[Array#to_sentence]: https://api.rubyonrails.org/classes/Array.html#method-i-to_sentence

#### `to_fs`

The method [`to_fs`][Array#to_fs] acts like `to_s` by default.

If the array contains items that respond to `id`, however, the symbol `:db` may
be passed as argument. That's typically used with collections of Active Record
objects. Returned strings are:

```ruby
[].to_fs(:db)            # => "null"
[user].to_fs(:db)        # => "8456"
invoice.lines.to_fs(:db) # => "23,567,556,12"
```

Integers in the example above come from the respective calls to `id`.

NOTE: Defined in `active_support/core_ext/array/conversions.rb`.

[Array#to_fs]: https://api.rubyonrails.org/classes/Array.html#method-i-to_fs

#### `to_xml`

The [`to_xml`][Array#to_xml] method serializes an array into an XML string by calling `to_xml` on each element and wrapping the results in a root node. All elements must respond to `to_xml`.

The root element name is automatically inferred from the class of the first element, pluralized and dasherized:

```ruby
Contributor.limit(2).order(:rank).to_xml
# =>
# <?xml version="1.0" encoding="UTF-8"?>
# <contributors type="array">
#   <contributor>
#     <id type="integer">1</id>
#     <name>Frodo Baggins</name>
#     <rank type="integer">1</rank>
#     <url-id>frodo-baggins</url-id>
#   </contributor>
#   <contributor>
#     <id type="integer">2</id>
#     <name>Gandalf the Grey</name>
#     <rank type="integer">2</rank>
#     <url-id>gandalf-the-grey</url-id>
#   </contributor>
# </contributors>
```

If the collection contains mixed types, the root element falls back to `"objects"`:

```ruby
[Contributor.first, Commit.first].to_xml
# =>
# <?xml version="1.0" encoding="UTF-8"?>
# <objects type="array">
#   <object>
#     <id type="integer">1</id>
#     <name>Frodo Baggins</name>
#     <rank type="integer">1</rank>
#   </object>
#   <object>
#     <author>Samwise Gamgee</author>
#     <authored-timestamp type="datetime">2026-05-05T12:00:00Z</authored-timestamp>
#     <branch>origin/main</branch>
#     <id type="integer">2</id>
#     <message>Fix bug in authentication flow</message>
#     <sha1>723a47bfb3708f968821bc969a9a3fc873a3ed58</sha1>
#   </object>
# </objects>
```

If the receiver is an array of hashes, the root element is also `"objects"` by default:

```ruby
[{ a: 1, b: 2 }, { c: 3 }].to_xml
# =>
# <?xml version="1.0" encoding="UTF-8"?>
# <objects type="array">
#   <object>
#     <a type="integer">1</a>
#     <b type="integer">2</b>
#   </object>
#   <object>
#     <c type="integer">3</c>
#   </object>
# </objects>
```

WARNING: If the collection is empty, the root element defaults to `"nil-classes"` rather than the expected plural class name. Use the `:root` option to ensure a consistent root element when the collection may be empty.

The name of child nodes is the singularized form of the root node by default. Use the `:children` option to override this. The default XML builder is a fresh instance of `Builder::XmlMarkup`, you can provide your own via the `:builder` option. Other options like `:dasherize` and `:skip_types` are forwarded to the builder:

```ruby
Contributor.limit(2).order(:rank).to_xml(skip_types: true)
# =>
# <?xml version="1.0" encoding="UTF-8"?>
# <contributors>
#   <contributor>
#     <id>1</id>
#     <name>Frodo Baggins</name>
#     <rank>1</rank>
#     <url-id>frodo-baggins</url-id>
#   </contributor>
#   <contributor>
#     <id>2</id>
#     <name>Gandalf the Grey</name>
#     <rank>2</rank>
#     <url-id>gandalf-the-grey</url-id>
#   </contributor>
# </contributors>
```

NOTE: Defined in `active_support/core_ext/array/conversions.rb`.

[Array#to_xml]: https://api.rubyonrails.org/classes/Array.html#method-i-to_xml

### Grouping

#### `in_groups_of(number, fill_with = nil)`

The method [`in_groups_of`][Array#in_groups_of] splits an array into consecutive groups of a given size. It returns an array with the groups (as arrays):

```ruby
[1, 2, 3].in_groups_of(2) # => [[1, 2], [3, nil]]
```

or yields them in turn if a block is passed:

```html+erb
<% sample.in_groups_of(3) do |a, b, c| %>
  <tr>
    <td><%= a %></td>
    <td><%= b %></td>
    <td><%= c %></td>
  </tr>
<% end %>
```

The first example shows how `in_groups_of` fills the last group with as many `nil` elements as needed to have the requested size. You can change this padding value using the second optional argument:

```ruby
[1, 2, 3].in_groups_of(2, 0) # => [[1, 2], [3, 0]]
```

And you can tell the method not to fill the last group by passing `false` (as a consequence `false` can't be used as a padding value):

```ruby
[1, 2, 3].in_groups_of(2, false) # => [[1, 2], [3]]
```

NOTE: Defined in `active_support/core_ext/array/grouping.rb`.

[Array#in_groups_of]: https://api.rubyonrails.org/classes/Array.html#method-i-in_groups_of

#### `in_groups(number, fill_with = nil)`

The method [`in_groups`][Array#in_groups] divides an array into a given number of groups. The method returns an array with the groups or yields them in turn if a block is passed:

```ruby
%w(1 2 3 4 5 6 7).in_groups(3)
# => [["1", "2", "3"], ["4", "5", nil], ["6", "7", nil]]

# with a block
%w(1 2 3 4 5 6 7).in_groups(3) { |group| p group }
["1", "2", "3"]
["4", "5", nil]
["6", "7", nil]
```

The examples above show that `in_groups` fills some groups with a trailing `nil` element as needed. A group can get at most one of these extra elements, the right most one if any. And the groups that have them are always the last ones.

You can change this padding value using the second optional argument:

```ruby
%w(1 2 3 4 5 6 7).in_groups(3, "0")
# => [["1", "2", "3"], ["4", "5", "0"], ["6", "7", "0"]]
```

And you can tell the method not to fill the smaller groups by passing `false`:

```ruby
%w(1 2 3 4 5 6 7).in_groups(3, false)
# => [["1", "2", "3"], ["4", "5"], ["6", "7"]]
```

NOTE: Defined in `active_support/core_ext/array/grouping.rb`.

[Array#in_groups]: https://api.rubyonrails.org/classes/Array.html#method-i-in_groups

#### `split(value = nil)`

The [`Array#split`][Array#split] method divides an array into chunks separated by a given value or condition, similar to how `String#split` works on strings.

When passed a block, elements for which the block returns true act as the separators and are excluded from the result:

```ruby
(1..10).to_a.split { |i| i.multiple_of?(4) }
# => [[1, 2, 3], [5, 6, 7], [9, 10]]
# 4 and 8 are multiples of 4, so they act as separators
```

When passed a value, that value is used as the separator. The default is `nil`:

```ruby
[0, 1, -5, 1, 1, "foo", "bar"].split(1)
# => [[0], [-5], [], ["foo", "bar"]]
```

Consecutive separators produce empty arrays in the result, as shown above where two `1`s appear next to each other.

NOTE: Defined in `active_support/core_ext/array/grouping.rb`.

[Array#split]: https://api.rubyonrails.org/classes/Array.html#method-i-split

Extensions to `Hash`
--------------------

### `extract!`

The [`extract!`][Hash#extract!] method removes and returns the key/value pairs matching the given keys. It's the inverse of `slice!`, where `slice!` keeps the given keys and returns the rest.

```ruby
hash = { a: 1, b: 2 }
rest = hash.extract!(:a) # => { a: 1 }
hash                     # => { b: 2 }
```

The `extract!` method preserves the subclass of the receiver, so calling it on an `ActiveSupport::HashWithIndifferentAccess` returns the same type:

```ruby
hash = { a: 1, b: 2 }.with_indifferent_access
hash.extract!(:a).class
# => ActiveSupport::HashWithIndifferentAccess
```

NOTE: Defined in `active_support/core_ext/hash/slice.rb`.

[Hash#extract!]: https://api.rubyonrails.org/classes/Hash.html#method-i-extract-21

### `slice` and `slice!`

The [`slice`][Hash#slice] method returns a new hash containing only the given keys, leaving the original hash unchanged:

```ruby
hash = { a: 1, b: 2, c: 3 }
hash.slice(:a, :c) # => { a: 1, c: 3 }
hash               # => { a: 1, b: 2, c: 3 }  — unchanged
```

The [`slice!`][Hash#slice!] method does the opposite in terms of mutation. It modifies the caller to keep only the specified keys and returns a hash of the rest of the removed key/value pairs:

```ruby
hash = { a: 1, b: 2, c: 3 }
rest = hash.slice!(:a) # => { b: 2, c: 3 }
hash                   # => { a: 1 }
```

NOTE: Defined in `active_support/core_ext/hash/slice.rb`.

[Hash#slice]: https://api.rubyonrails.org/classes/Hash.html#method-i-slice
[Hash#slice!]: https://api.rubyonrails.org/classes/Hash.html#method-i-slice-21

### `with_indifferent_access`

The [`with_indifferent_access`][Hash#with_indifferent_access] method converts a hash into an [`ActiveSupport::HashWithIndifferentAccess`][ActiveSupport::HashWithIndifferentAccess], which allows keys to be accessed as either strings or symbols interchangeably:

```ruby
{ a: 1 }.with_indifferent_access["a"] # => 1
{ a: 1 }.with_indifferent_access[:a]  # => 1
```

NOTE: Defined in `active_support/core_ext/hash/indifferent_access.rb`.

[ActiveSupport::HashWithIndifferentAccess]: https://api.rubyonrails.org/classes/ActiveSupport/HashWithIndifferentAccess.html
[Hash#with_indifferent_access]: https://api.rubyonrails.org/classes/Hash.html#method-i-with_indifferent_access

### `deep_dup`

The [`Hash#deep_dup`][Hash#deep_dup] method duplicates a hash along with all the keys and values inside it, recursively. Unlike Ruby's built-in `dup`, which produces a shallow copy where nested objects are still shared, `deep_dup` ensures that modifying a nested value in the copy does not affect the original:

```ruby
hash = { a: 1, b: { c: 2, d: [3, 4] } }
dup = hash.deep_dup

dup[:b][:e] = 5
dup[:b][:d] << 5

hash[:b][:e] # => nil       — original is unaffected
hash[:b][:d] # => [3, 4]    — original array is unaffected
dup[:b][:e]  # => 5
dup[:b][:d]  # => [3, 4, 5]
```

NOTE: Defined in `active_support/core_ext/object/deep_dup.rb`.

[Hash#deep_dup]: https://api.rubyonrails.org/classes/Hash.html#method-i-deep_dup

### Conversions

#### `to_xml`

The [`to_xml`][Hash#to_xml] method returns a string containing an XML representation of a hash:

```ruby
{ foo: 1, bar: 2 }.to_xml
# =>
# <?xml version="1.0" encoding="UTF-8"?>
# <hash>
#   <foo type="integer">1</foo>
#   <bar type="integer">2</bar>
# </hash>
```

To build the XML, the method loops over each key/value pair and decides how to render the node based on the type of the value:

- If the value is a hash, it recurses, using the key as the new root
- If the value is an array, it recurses, using the key as the root and the singularized key as the name for each child
- If the value responds to `to_xml`, that method is called with the key as the root
- Otherwise, the value is rendered as text inside a node named after the key, with a `type` attribute added automatically (unless `:skip_types` is set)

Here's a hash that combines a nested hash, an array, and plain values to illustrate all three cases:

```ruby
{
  name: "Frodo",
  age: 33,
  address: { city: "Hobbiton", region: "The Shire" },
  friends: ["Sam", "Merry", "Pippin"]
}.to_xml
# =>
# <?xml version="1.0" encoding="UTF-8"?>
# <hash>
#   <name>Frodo</name>
#   <age type="integer">33</age>
#   <address>
#     <city>Hobbiton</city>
#     <region>The Shire</region>
#   </address>
#   <friends type="array">
#     <friend>Sam</friend>
#     <friend>Merry</friend>
#     <friend>Pippin</friend>
#   </friends>
# </hash>
```

Notice that `address` becomes its own nested node, while `friends` becomes an array of `friend` elements.

The automatic type attributes follow this mapping:

```ruby
XML_TYPE_NAMES = {
  "Symbol"     => "symbol",
  "Integer"    => "integer",
  "BigDecimal" => "decimal",
  "Float"      => "float",
  "TrueClass"  => "boolean",
  "FalseClass" => "boolean",
  "Date"       => "date",
  "DateTime"   => "datetime",
  "Time"       => "datetime"
}
```

By default the root node is `"hash"`, configurable via the `:root` option. The default XML builder is `Builder::XmlMarkup`, which can be replaced via the `:builder` option. Other options like `:dasherize` are forwarded to the builder.

NOTE: Defined in `active_support/core_ext/hash/conversions.rb`.

[Hash#to_xml]: https://api.rubyonrails.org/classes/Hash.html#method-i-to_xml

### Merging

Ruby's built-in `Hash#merge` combines two hashes, with the argument's values winning on key collisions:

```ruby
{ a: 1, b: 1 }.merge(a: 0, c: 2)
# => { a: 0, b: 1, c: 2 }
```

Active Support adds a few more ways to merge hashes for common scenarios.

#### `reverse_merge` and `reverse_merge!`

Since `merge` favors the argument on collisions, you have to supply default values for an options hash like this:

```ruby
options = { length: 30, omission: "..." }.merge(options)
```

The [`reverse_merge`][Hash#reverse_merge] method lets you express the same thing with the defaults as the argument, which often reads more naturally:

```ruby
options = options.reverse_merge(length: 30, omission: "...")
```

The method [`reverse_merge!`][Hash#reverse_merge!] performs the same merge in place, modifying the caller. [`reverse_update`][Hash#reverse_update] is an alias for it.

NOTE: Defined in `active_support/core_ext/hash/reverse_merge.rb`.

[Hash#reverse_merge!]: https://api.rubyonrails.org/classes/Hash.html#method-i-reverse_merge-21
[Hash#reverse_merge]: https://api.rubyonrails.org/classes/Hash.html#method-i-reverse_merge
[Hash#reverse_update]: https://api.rubyonrails.org/classes/Hash.html#method-i-reverse_update

#### `deep_merge` and `deep_merge!`

With a regular `merge`, if the same key exists in both hashes, the argument's value replaces the original entirely. This might not be desirable when both values are themselves hashes.

The [`deep_merge`][Hash#deep_merge] method handles this case by merging the values that share a key recursively instead of replacing one with the other. For example:

```ruby
{ a: { b: 1 } }.deep_merge(a: { c: 2 })
# => { a: { b: 1, c: 2 } }
```

The [`deep_merge!`][Hash#deep_merge!] method performs the same merge in place.

NOTE: Defined in `active_support/core_ext/hash/deep_merge.rb`.

[Hash#deep_merge!]: https://api.rubyonrails.org/classes/Hash.html#method-i-deep_merge-21
[Hash#deep_merge]: https://api.rubyonrails.org/classes/Hash.html#method-i-deep_merge


### Working with Keys

#### `except!`

Ruby added `except` to `Hash` as a built-in method. It returns a new hash with the given keys removed, leaving the original unchanged:

```ruby
{ a: 1, b: 2 }.except(:a) # => { b: 2 }
```

Active Support adds [`except!`][Hash#except!], the in-place version that removes the keys from the receiver itself:

```ruby
{ a: 1, b: 2 }.except!(:a) # => { b: 2 }
{ a: 1, b: 2 }.except!(:c) # => { a: 1, b: 2 }
```

Both methods work with indifferent access, accepting keys as either strings or symbols:

```ruby
{ a: 1 }.with_indifferent_access.except!(:a)  # => {}
{ a: 1 }.with_indifferent_access.except!("a") # => {}
```

NOTE: Defined in `active_support/core_ext/hash/except.rb`.

[Hash#except!]: https://api.rubyonrails.org/classes/Hash.html#method-i-except-21

#### `stringify_keys` and `stringify_keys!`

The method [`stringify_keys`][Hash#stringify_keys] returns a hash that has a stringified version of the keys in the receiver. It does so by sending `to_s` to them:

```ruby
{ nil => nil, 1 => 1, a: :a }.stringify_keys
# => {"" => nil, "1" => 1, "a" => :a}
```

In case of key collision, the value will be the one most recently inserted into the hash:

```ruby
{ "a" => 1, a: 2 }.stringify_keys
# The result will be
# => {"a"=>2}
```

This method may be useful for example to easily accept both symbols and strings as options. For instance `ActionView::Helpers::FormHelper` defines:

```ruby
def to_checkbox_tag(options = {}, checked_value = "1", unchecked_value = "0")
  options = options.stringify_keys
  options["type"] = "checkbox"
  # ...
end
```

This way the `options["type"]` line can safely access the key as "type", while allowing the user to pass either `:type` or "type".

There's also the bang variant [`stringify_keys!`][Hash#stringify_keys!] that stringifies keys in place.

You can use [`deep_stringify_keys`][Hash#deep_stringify_keys] and [`deep_stringify_keys!`][Hash#deep_stringify_keys!] to stringify all the keys in the given hash and all the hashes nested in it. For example:

```ruby
{ nil => nil, 1 => 1, nested: { a: 3, 5 => 5 } }.deep_stringify_keys
# => {""=>nil, "1"=>1, "nested"=>{"a"=>3, "5"=>5}}
```

NOTE: Defined in `active_support/core_ext/hash/keys.rb`.

[Hash#deep_stringify_keys!]: https://api.rubyonrails.org/classes/Hash.html#method-i-deep_stringify_keys-21
[Hash#deep_stringify_keys]: https://api.rubyonrails.org/classes/Hash.html#method-i-deep_stringify_keys
[Hash#stringify_keys!]: https://api.rubyonrails.org/classes/Hash.html#method-i-stringify_keys-21
[Hash#stringify_keys]: https://api.rubyonrails.org/classes/Hash.html#method-i-stringify_keys

#### `symbolize_keys` and `symbolize_keys!`

The method [`symbolize_keys`][Hash#symbolize_keys] returns a hash that has a symbolized version of the keys in the receiver, where possible. It does so by calling `to_sym` on them:

```ruby
{ nil => nil, 1 => 1, "a" => "a" }.symbolize_keys
# => {nil=>nil, 1=>1, :a=>"a"}
```

In case of key collision, the value will be the one most recently inserted into the hash:

```ruby
{ "a" => 1, a: 2 }.symbolize_keys
# => {:a=>2}
```

This method is useful in allowing both symbols and strings in an options hash. For instance, here's a method in `ActionText::TagHelper`:

```ruby
def rich_textarea_tag(name, value = nil, options = {})
  options = options.symbolize_keys

  options[:input] ||= "trix_input_#{ActionText::TagHelper.id += 1}"
  # ...
end
```

The line with `options[:input]` can safely access the key `:input` as a symbol, and let the user to pass either `:input` or "input".

There's also the bang variant [`symbolize_keys!`][Hash#symbolize_keys!] that symbolizes keys in place.

You can use [`deep_symbolize_keys`][Hash#deep_symbolize_keys] and [`deep_symbolize_keys!`][Hash#deep_symbolize_keys!] to symbolize all the keys in the given hash and all the hashes nested in it. An example of the result is:

```ruby
{ nil => nil, 1 => 1, "nested" => { "a" => 3, 5 => 5 } }.deep_symbolize_keys
# => {nil=>nil, 1=>1, nested:{a:3, 5=>5}}
```

The methods [`to_options`][Hash#to_options] and [`to_options!`][Hash#to_options!] are aliases of `symbolize_keys` and `symbolize_keys!`, respectively.

NOTE: Defined in `active_support/core_ext/hash/keys.rb`.

[Hash#deep_symbolize_keys!]: https://api.rubyonrails.org/classes/Hash.html#method-i-deep_symbolize_keys-21
[Hash#deep_symbolize_keys]: https://api.rubyonrails.org/classes/Hash.html#method-i-deep_symbolize_keys
[Hash#symbolize_keys!]: https://api.rubyonrails.org/classes/Hash.html#method-i-symbolize_keys-21
[Hash#symbolize_keys]: https://api.rubyonrails.org/classes/Hash.html#method-i-symbolize_keys
[Hash#to_options!]: https://api.rubyonrails.org/classes/Hash.html#method-i-to_options-21
[Hash#to_options]: https://api.rubyonrails.org/classes/Hash.html#method-i-to_options

#### `assert_valid_keys`

The [`assert_valid_keys`][Hash#assert_valid_keys] method checks that the hash contains only the keys provided as arguments. If any unexpected key is found, it raises an `ArgumentError`. This is useful for validating options hashes passed to methods.

```ruby
{ a: 1 }.assert_valid_keys(:a)        # => passes
{ a: 1 }.assert_valid_keys(:a, :b)    # => passes
{ a: 1, b: 2 }.assert_valid_keys(:a)  # => ArgumentError: Unknown key: :b. Valid keys are: :a
{ a: 1 }.assert_valid_keys("a")       # => ArgumentError: Unknown key: :a. Valid keys are: "a"
```

Note that key type matters, so `:a` and `"a"` are considered different keys.

Rails uses this internally in Active Record when building associations to reject unknown options before they cause confusing errors later on:

```ruby
has_many :posts, dependent: :destroy, unknown_option: true
# => ArgumentError: Unknown key: :unknown_option
```

NOTE: Defined in `active_support/core_ext/hash/keys.rb`.

[Hash#assert_valid_keys]: https://api.rubyonrails.org/classes/Hash.html#method-i-assert_valid_keys

### Working with Values

#### `deep_transform_values` and `deep_transform_values!`

The [`deep_transform_values`][Hash#deep_transform_values] method returns a new hash with every value transformed by the given block. Unlike Ruby's built-in `transform_values`, which only operates on the top level values, `deep_transform_values` recurses into nested hashes and arrays:

```ruby
hash = { person: { name: "Frodo", age: 33, hobbies: ["reading", "walking"] } }

hash.deep_transform_values { |value| value.to_s.upcase }
# => { person: { name: "FRODO", age: "33", hobbies: ["READING", "WALKING"] } }
```

The integer `33` and the strings inside the nested array are all transformed.

The [`deep_transform_values!`][Hash#deep_transform_values!] variant performs the same transformation in place, modifying the original hash.

NOTE: Defined in `active_support/core_ext/hash/deep_transform_values.rb`.

[Hash#deep_transform_values!]: https://api.rubyonrails.org/classes/Hash.html#method-i-deep_transform_values-21
[Hash#deep_transform_values]: https://api.rubyonrails.org/classes/Hash.html#method-i-deep_transform_values

Extensions to `Range`
---------------------

### `to_fs`

Active Support defines `Range#to_fs` as an alternative to `to_s` that understands an optional format argument, such as `:db`:

```ruby
(Date.today..Date.tomorrow).to_fs
# => "2009-10-25..2009-10-26"

(Date.today..Date.tomorrow).to_fs(:db)
# => "BETWEEN '2009-10-25' AND '2009-10-26'"
```

As shown in the example above, the `:db` format generates a `BETWEEN` SQL clause. This is useful in Active Record queries to support range values in conditions.

NOTE: Defined in `active_support/core_ext/range/conversions.rb`.

### `===` and `include?`

Ruby's `Range#===` and `Range#include?` check whether a single value falls within a range:

```ruby
(2..3).include?(Math::E) # => true  — Math::E is 2.718...
```

Active Support extends both methods to also accept another range as the argument. In this case the check becomes this: does the receiver range fully contain the argument range? Both the start and end of the argument must fall within the receiver:

```ruby
(1..10) === (3..7)   # => true   — 3 and 7 are both within 1..10
(1..10) === (0..7)   # => false  — 0 is outside 1..10
(1..10) === (3..11)  # => false  — 11 is outside 1..10
(1...9) === (3..9)   # => false  — 9 is excluded from 1...9
```

[`include?`][Range#include?] behaves identically:

```ruby
(1..10).include?(3..7)   # => true
(1..10).include?(0..7)   # => false
(1..10).include?(3..11)  # => false
(1...9).include?(3..9)   # => false
```

Ruby's built-in `Range#cover?` (since Ruby 2.6) accepts range agruments and provides equivalent functionality without Active Support:

```ruby
(1..10).cover?(3..7)   # => true
(1..10).cover?(0..7)   # => false
(1..10).cover?(3..11)  # => false
(1...9).cover?(3..9)   # => false
```

NOTE: Defined in `active_support/core_ext/range/compare_range.rb`.

### `overlaps?`

The method [`Range#overlaps?`][Range#overlaps?] checks whether two given ranges have overlapping values:

```ruby
(1..10).overlaps?(7..11)  # => true
(1..10).overlaps?(0..7)   # => true
(1..10).overlaps?(11..27) # => false
```

NOTE: Ruby 3.3 added `Range#overlap?` (without the "s") to Ruby core, inspired by Active Support's `overlaps?`. One behavioral difference is that Ruby's `overlap?` explicitly returns `false` when either range is empty, while `overlaps?` may behave differently in those edge cases. For new code, prefer Ruby's built-in `overlap?`.

NOTE: Defined in `active_support/core_ext/range/overlap.rb`.

[Range#overlaps?]: https://api.rubyonrails.org/classes/Range.html#method-i-overlaps-3F


Working with `Date`, `Time`, and `DateTime`
------------------------------------------

Ruby provides three classes for representing dates and times: `Date`,
`DateTime`, and `Time`. The `Date` class represents calendar days and has no
time component. The `DateTime` class is a subclass of `Date` and adds
hours/minutes/seconds to dates. The `Time` class is independent of `Date` and
`DateTime` (extends `Object`) and handles timezones as well as daylight saving
time.

Active Support extends all three classes with a set of convenience methods. Many
methods, such as `prev_day` and `beginning_of_week`, are defined once in a
common module
[`DateAndTime::Calculations`](https://api.rubyonrails.org/classes/DateAndTime/Calculations.html).

TIP: Most Rails developers face the question of which class to use when. The
answer comes down to one practical distinction: `Time` understands time zones
and daylight saving time, while `DateTime` does not. In most modern
applications, you are better off using `Time` (or more specifically
`ActiveSupport::TimeWithZone`, which is what `Time.current` returns). Treat
`DateTime` as a legacy class kept around for compatibility. Use `Date` whenever
you only care about a calendar day and have no need for a time component at all.

This section covers the convenience methods Active Support adds across all three
classes, and points out where the classes diverge and the choice of class
matters.

NOTE: The calculation methods have edge cases in October 1582, since days 5..14
do not exist due to the [caldendar
reform](https://en.wikipedia.org/wiki/Gregorian_calendar). The date classes
behave correctly around this date, for example, `Date.new(1582, 10, 4).tomorrow`
returns "Fri, 15 Oct 1582" and so on.

### Creating Dates and Times

Active Support adds `Date.current`, `Time.current`, and `DateTime.current` to create Date and Time objects, in addition to the built in Ruby constructors such as `Date.new`, `Time.new`, and `DateTime.new`. The advantage of the Active support methods is that they are time zone aware.

NOTE: Date and Time objects can also be created from Strings, see the [Date and Time Conversions For Strings](#date-and-time-conversions-for-strings).

#### `Date.current`

The Ruby method `Date.today` returns today's date based on the *system time zone*, which is the time zone of the server your Rails application runs on.

Active Support defines [`Date.current`][Date.current] as an alternative that returns today's date in the **user's time zone** if one has been set via `Time.zone`. This distinction matters in production applications that serve users across different time zones.

Consider a server running in UTC and a user in Tokyo (UTC+9). At 11pm UTC on April 20th, it is already April 21st in Tokyo. In this situation:

```ruby
Date.today    # => Mon, 20 Apr 2026  (server system time, UTC)
Date.current  # => Tue, 21 Apr 2026  (user's time zone, Tokyo)
```

This means `Date.today` could return what the user considers yesterday. Always use `Date.current` in application code when the result should reflect the user's local date.

Active Support also defines [`Date.yesterday`][Date.yesterday] and [`Date.tomorrow`][Date.tomorrow], as well as a set of predicate methods relative to `Date.current`:

```ruby
date.past?        # => true if date is before Date.current
date.today?       # => true if date is Date.current
date.tomorrow?    # => true if date is Date.current + 1
date.future?      # => true if date is after Date.current
date.on_weekday?  # => true if date is Monday through Friday
date.on_weekend?  # => true if date is Saturday or Sunday
```

WARNING: Always use `Date.current` rather than `Date.today` when making date comparisons in user facing application code. Using `Date.today` ignores the user's time zone and can produce incorrect results.

NOTE: Defined in `active_support/core_ext/date/calculations.rb`.

[Date.current]: https://api.rubyonrails.org/classes/Date.html#method-c-current
[Date.tomorrow]: https://api.rubyonrails.org/classes/Date.html#method-c-tomorrow
[Date.yesterday]: https://api.rubyonrails.org/classes/Date.html#method-c-yesterday
[DateAndTime::Calculations#future?]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-future-3F
[DateAndTime::Calculations#on_weekday?]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-on_weekday-3F
[DateAndTime::Calculations#on_weekend?]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-on_weekend-3F
[DateAndTime::Calculations#past?]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-past-3F

#### `Time.current`

The Ruby method `Time.now` returns the current time based on the **system time zone**, which is the time zone of the server your Rails app runs on.

Active Support defines [`Time.current`][Time.current] as an alternative that returns the current time in the **user's time zone** if one has been set via `Time.zone`. This mirrors the same distinction between `Date.today` and `Date.current`.

Active Support also defines the following instance predicates, all relative to `Time.current`:

```ruby
time = Time.current

time.past?      # => false
time.today?     # => true
time.tomorrow?  # => false
time.next_day?  # => false
time.yesterday? # => false
time.prev_day?  # => false
time.future?    # => false
```

NOTE: Use `Time.current` rather than `Time.now` in user-facing code. `Time.now` ignores the user's time zone and can produce incorrect results.

NOTE: Defined in `active_support/core_ext/time/calculations.rb`.

[DateAndTime::Calculations#next_day?]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-next_day-3F
[DateAndTime::Calculations#prev_day?]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-prev_day-3F
[DateAndTime::Calculations#today?]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-today-3F
[DateAndTime::Calculations#tomorrow?]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-tomorrow-3F
[DateAndTime::Calculations#yesterday?]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-yesterday-3F

#### `DateTime.current`

Active Support defines [`DateTime.current`][DateTime.current] to be like `Time.now.to_datetime`, except that it honors the user time zone, if defined. The instance predicates [`past?`][DateAndTime::Calculations#past?] and [`future?`][DateAndTime::Calculations#future?] are defined relative to `DateTime.current`.

```ruby
DateTime.current # => Tue, 05 May 2026 12:00:00 +0000

DateTime.current.past?   # => false
DateTime.current.future? # => false

DateTime.new(2025, 1, 1).past?   # => true
DateTime.new(2027, 1, 1).future? # => true
```

NOTE: Defined in `active_support/core_ext/date_time/calculations.rb`.

[DateTime.current]: https://api.rubyonrails.org/classes/DateTime.html#method-c-current

#### Methods that Return Time or DateTime

The following methods return a `Time` object if possible, otherwise a `DateTime`. If set, they honor the user time zone.

##### `beginning_of_day`, `end_of_day`

The methods [`beginning_of_day`][Date#beginning_of_day] and [`end_of_day`][Date#end_of_day] return a the timestamps with `00:00:00` and `23:59:59`, respectively:

```ruby
date = Date.new(2026, 5, 5)
date.beginning_of_day # => Tue May 05 00:00:00 +0000 2026

date = Date.new(2026, 5, 5)
date.end_of_day # => Tue May 05 23:59:59 +0000 2026
```

`beginning_of_day` is aliased to [`at_beginning_of_day`][Date#at_beginning_of_day], [`midnight`][Date#midnight], [`at_midnight`][Date#at_midnight].

NOTE: Defined in `active_support/core_ext/date/calculations.rb`.

[Date#at_beginning_of_day]: https://api.rubyonrails.org/classes/Date.html#method-i-at_beginning_of_day
[Date#at_midnight]: https://api.rubyonrails.org/classes/Date.html#method-i-at_midnight
[Date#beginning_of_day]: https://api.rubyonrails.org/classes/Date.html#method-i-beginning_of_day
[Date#end_of_day]: https://api.rubyonrails.org/classes/Date.html#method-i-end_of_day
[Date#midnight]: https://api.rubyonrails.org/classes/Date.html#method-i-midnight

INFO: `beginning_of_hour`, `end_of_hour`, `beginning_of_minute`, and `end_of_minute` are implemented for `Time` and `DateTime` but **not** `Date` as it does not make sense to request the beginning or end of an hour or minute on a `Date` instance.

##### `beginning_of_hour`, `end_of_hour`

The methods [`beginning_of_hour`][DateTime#beginning_of_hour] and [`end_of_hour`][DateTime#end_of_hour] return timestamps at `hh:00:00` and `hh:59:59`, respectively:

```ruby
date = DateTime.new(2026, 5, 5, 19, 55, 25)
date.beginning_of_hour # => Tue May 05 19:00:00 +0000 2026
date.end_of_hour       # => Tue May 05 19:59:59 +0000 2026
```

`beginning_of_hour` is aliased to [`at_beginning_of_hour`][DateTime#at_beginning_of_hour].

NOTE: Defined in `active_support/core_ext/date_time/calculations.rb`.

##### `beginning_of_minute`, `end_of_minute`

The methods [`beginning_of_minute`][DateTime#beginning_of_minute] and [`end_of_minute`][DateTime#end_of_minute] return timestamps at `hh:mm:00` and `hh:mm:59`, respectively:

```ruby
date = DateTime.new(2026, 5, 5, 19, 55, 25)
date.beginning_of_minute # => Tue May 05 19:55:00 +0000 2026
date.end_of_minute       # => Tue May 05 19:55:59 +0000 2026
```

`beginning_of_minute` is aliased to [`at_beginning_of_minute`][DateTime#at_beginning_of_minute].

NOTE: Defined in `active_support/core_ext/date_time/calculations.rb`.

[DateTime#at_beginning_of_minute]: https://api.rubyonrails.org/classes/DateTime.html#method-i-at_beginning_of_minute
[DateTime#beginning_of_minute]: https://api.rubyonrails.org/classes/DateTime.html#method-i-beginning_of_minute
[DateTime#end_of_minute]: https://api.rubyonrails.org/classes/DateTime.html#method-i-end_of_minute

##### `ago`, `since`

The method [`ago`][Date#ago] receives a number of seconds as argument and returns a timestamp those many seconds ago from midnight:

```ruby
date = Date.current # => Tue, 05 May 2026
date.ago(1)         # => Mon, 04 May 2026 23:59:59 EDT -04:00
```

Similarly, [`since`][Date#since] moves forward:

```ruby
date = Date.current # => Tue, 05 May 2026
date.since(1)       # => Tue, 05 May 2026 00:00:01 EDT -04:00
```

NOTE: Defined in `active_support/core_ext/date/calculations.rb`.

[Date#ago]: https://api.rubyonrails.org/classes/Date.html#method-i-ago
[Date#since]: https://api.rubyonrails.org/classes/Date.html#method-i-since

### Calculations

#### `years_ago`, `years_since`

The method [`years_ago`][DateAndTime::Calculations#years_ago] receives a number of years and returns the same date those many years ago:

```ruby
date = Date.new(2026, 5, 5)
date.years_ago(10) # => Sun, 05 May 2016
```

The method [`years_since`][DateAndTime::Calculations#years_since] moves forward in time:

```ruby
date = Date.new(2026, 5, 5)
date.years_since(10) # => Fri, 05 May 2036
```

If such a day does not exist, the last day of the corresponding month is returned:

```ruby
Date.new(2024, 2, 29).years_ago(1)   # => Wed, 28 Feb 2023
Date.new(2024, 2, 29).years_since(2) # => Sat, 28 Feb 2026
```

The method [`last_year`][DateAndTime::Calculations#last_year] is short-hand for `years_ago`.

NOTE: Defined in `active_support/core_ext/date_and_time/calculations.rb`.

[DateAndTime::Calculations#last_year]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-last_year
[DateAndTime::Calculations#years_ago]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-years_ago
[DateAndTime::Calculations#years_since]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-years_since

#### `months_ago`, `months_since`

The methods [`months_ago`][DateAndTime::Calculations#months_ago] and [`months_since`][DateAndTime::Calculations#months_since] work analogously for months:

```ruby
Date.new(2026, 5, 5).months_ago(2)   # => Sun, 05 Mar 2026
Date.new(2026, 5, 5).months_since(2) # => Sat, 05 Jul 2026
```

If such a day does not exist, the last day of the corresponding month is returned:

```ruby
Date.new(2026, 3, 31).months_ago(1)   # => Sat, 28 Feb 2026
Date.new(2026, 1, 31).months_since(1) # => Sat, 28 Feb 2026
```

The method [`last_month`][DateAndTime::Calculations#last_month] is short-hand for `months_ago`.

NOTE: Defined in `active_support/core_ext/date_and_time/calculations.rb`.

[DateAndTime::Calculations#last_month]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-last_month
[DateAndTime::Calculations#months_ago]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-months_ago
[DateAndTime::Calculations#months_since]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-months_since

#### `weeks_ago`, `weeks_since`

The method [`weeks_ago`][DateAndTime::Calculations#weeks_ago] and [`weeks_since`][DateAndTime::Calculations#week_since] work analogously for weeks:

```ruby
Date.new(2026, 5, 5).weeks_ago(1)   # => Tue, 28 Apr 2026
Date.new(2026, 5, 5).weeks_since(2) # => Tue, 19 May 2026
```

NOTE: Defined in `active_support/core_ext/date_and_time/calculations.rb`.

[DateAndTime::Calculations#weeks_ago]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-weeks_ago
[DateAndTime::Calculations#weeks_since]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-weeks_since

WARNING: If the `since` or `ago` methods produces a time outside the range that `Time` can represent, a `DateTime` object is returned instead. This is unlikely to affect most applications running on 64-bit systems, but if your code depends on the returned object being a `Time` (for example by calling Time-specific methods), you may see unexpected behavior when working with dates far in the past or future.

#### `seconds_since_midnight` and `seconds_until_end_of_day`

The [`seconds_since_midnight`][Time#seconds_since_midnight] method returns the number of seconds elapsed since midnight on `Time` and `DateTime`. It is not defined on `Date`, since a date has no time-of-day component to measure.

```ruby
now = DateTime.current     # => Tue, 05 May 2026 12:00:00 +0000
now.seconds_since_midnight # => 43200

now = Time.current         # => Tue, 05 May 2026 12:00:00 UTC +00:00
now.seconds_since_midnight # => 43200.0
```

The [`seconds_until_end_of_day`][Time#seconds_until_end_of_day] method is the complement, it returns the number of seconds remaining until 23:59:59:

```ruby
now = Time.current             # => Tue, 05 May 2026 12:00:00 UTC +00:00
now.seconds_until_end_of_day   # => 43199
```

NOTE: Defined in `active_support/core_ext/date_time/calculations.rb` and `active_support/core_ext/time/calculations.rb`.

[DateTime#seconds_since_midnight]: https://api.rubyonrails.org/classes/DateTime.html#method-i-seconds_since_midnight
[Time#seconds_since_midnight]: https://api.rubyonrails.org/classes/Time.html#method-i-seconds_since_midnight
[Time#seconds_until_end_of_day]: https://api.rubyonrails.org/classes/Time.html#method-i-seconds_until_end_of_day

#### `advance`

The most generic way to jump to another date or time is [`advance`][Date#advance] (also defined as [`DateTime#advance`][DateTime#advance] and [`Time#advance`][Time#advance]). It receives a hash of units to move by and returns a new value shifted accordingly.

On `Date`, `advance` accepts `:years`, `:months`, `:weeks`, and `:days`:

```ruby
d = Date.new(2026, 5, 5)
d.advance(years: 1, weeks: 2)  # => Wed, 19 May 2027
d.advance(months: 2, days: -2) # => Mon, 06 Jul 2026
```

On `DateTime` and `Time`, `advance` accepts `:hours`, `:minutes`, and `:seconds` as well:

```ruby
d = DateTime.current  # => Tue, 05 May 2026 12:00:00 +0000
d.advance(years: 1, months: 1, days: 1, hours: 1, minutes: 1, seconds: 1)
# => Fri, 06 Jun 2027 13:01:01 +0000

t = Time.current      # => Tue, 05 May 2026 12:00:00 UTC +00:00
t.advance(years: 1, months: 1, days: 1, hours: 1, minutes: 1, seconds: 1)
# => Fri, 06 Jun 2027 13:01:01 UTC +00:00
```

In both cases, the date level keys are processed *before* the time level keys. This ordering matters as advancing in a different order can produce different results in edge cases:

```ruby
d = DateTime.new(2026, 2, 28, 23, 59, 59)
d.advance(months: 1, seconds: 1)
# => Sun, 29 Mar 2026 00:00:00 +0000

d.advance(seconds: 1).advance(months: 1)
# => Wed, 01 Apr 2026 00:00:00 +0000
```

WARNING: `DateTime` is not DST-aware, so advancing across a daylight saving boundary can result in an incorrect point in time with no warning or error. `Time`, by contrast, handles this correctly:

```ruby
# Clocks spring forward at 2am in New York on March 8, 2026
t = Time.local(2026, 3, 8, 1, 59, 59)
t.advance(seconds: 1)
# => Sun Mar 08 03:00:00 -0400 2026   (correctly skips the DST gap)
```

NOTE: Defined in `active_support/core_ext/date/calculations.rb`, `active_support/core_ext/date_time/calculations.rb`, and `active_support/core_ext/time/calculations.rb`.

[Date#advance]: https://api.rubyonrails.org/classes/Date.html#method-i-advance
[DateTime#advance]: https://api.rubyonrails.org/classes/DateTime.html#method-i-advance
[Time#advance]: https://api.rubyonrails.org/classes/Time.html#method-i-advance

#### `change`

The [`change`][Date#change] method (also defined as [`DateTime#change`][DateTime#change] and [`Time#change`][Time#change]) returns a new date or time based on the receiver, with only the specified parameters swapped out, keeping everything else the same.

On `Date`, `change` accepts `:year`, `:month`, and `:day`:

```ruby
Date.new(2026, 5, 5).change(year: 2027, month: 3)
# => Fri, 05 Mar 2027
```

On `DateTime` and `Time`, `change` also accepts `:hour`, `:min`, `:sec`, and `:offset`. `Time` additionally accepts `:usec`:

```ruby
now = DateTime.current  # => Tue, 05 May 2026 12:00:00 +0000
now.change(year: 2027)
# => Wed, 05 May 2027 12:00:00 +0000

now = Time.current      # => Tue, 05 May 2026 12:00:00 UTC +00:00
now.change(usec: 500)
# => Tue, 05 May 2026 12:00:00.000500 UTC +00:00
```

If hours are zeroed, minutes and seconds are zeroed too unless explicitly provided. Similarly, if minutes are zeroed, seconds are zeroed too unless explicitly provided:

```ruby
now.change(hour: 0)  # => Tue, 05 May 2026 00:00:00 UTC +00:00
now.change(min: 0)   # => Tue, 05 May 2026 12:00:00 UTC +00:00
```

NOTE: Defined in `active_support/core_ext/date/calculations.rb`, `active_support/core_ext/date_time/calculations.rb`, and `active_support/core_ext/time/calculations.rb`.

[Date#change]: https://api.rubyonrails.org/classes/Date.html#method-i-change
[DateTime#change]: https://api.rubyonrails.org/classes/DateTime.html#method-i-change
[Time#change]: https://api.rubyonrails.org/classes/Time.html#method-i-change

### Stepping Through Time

#### `prev_day`, `next_day`

The methods [`prev_day`][Time#prev_day] and [`next_day`][Time#next_day] return the time in the last or next day:

```ruby
t = Time.new(2026, 5, 5)  # => 2026-05-05 00:00:00 +0000
t.prev_day                # => 2026-05-04 00:00:00 +0000
t.next_day                # => 2026-05-06 00:00:00 +0000
```

NOTE: Defined in `active_support/core_ext/time/calculations.rb`.

[Time#next_day]: https://api.rubyonrails.org/classes/Time.html#method-i-next_day
[Time#prev_day]: https://api.rubyonrails.org/classes/Time.html#method-i-prev_day

#### `prev_month`, `next_month`

The methods [`prev_month`][Time#prev_month] and [`next_month`][Time#next_month] return the time with the same day in the last or next month:

```ruby
t = Time.new(2026, 5, 5)  # => 2026-05-05 00:00:00 +0000
t.prev_month              # => 2026-04-05 00:00:00 +0000
t.next_month              # => 2026-06-05 00:00:00 +0000
```

If such a day does not exist, the last day of the corresponding month is returned:

```ruby
Time.new(2026, 5, 31).prev_month # => 2026-04-30 00:00:00 +0000
Time.new(2026, 3, 31).prev_month # => 2026-02-28 00:00:00 +0000
Time.new(2026, 5, 31).next_month # => 2026-06-30 00:00:00 +0000
Time.new(2026, 1, 31).next_month # => 2026-02-28 00:00:00 +0000
```

NOTE: Defined in `active_support/core_ext/time/calculations.rb`.

[Time#next_month]: https://api.rubyonrails.org/classes/Time.html#method-i-next_month
[Time#prev_month]: https://api.rubyonrails.org/classes/Time.html#method-i-prev_month

#### `prev_year`, `next_year`

The methods [`prev_year`][Time#prev_year] and [`next_year`][Time#next_year] return a time with the same day/month in the last or next year:

```ruby
t = Time.new(2026, 5, 5)  # => 2026-05-05 00:00:00 +0000
t.prev_year               # => 2025-05-05 00:00:00 +0000
t.next_year               # => 2027-05-05 00:00:00 +0000
```

If date is the 29th of February of a leap year, you obtain the 28th:

```ruby
t = Time.new(2024, 2, 29)  # => 2024-02-29 00:00:00 +0000
t.prev_year                # => 2023-02-28 00:00:00 +0000
t.next_year                # => 2025-02-28 00:00:00 +0000
```

NOTE: Defined in `active_support/core_ext/time/calculations.rb`.

[Time#next_year]: https://api.rubyonrails.org/classes/Time.html#method-i-next_year
[Time#prev_year]: https://api.rubyonrails.org/classes/Time.html#method-i-prev_year

#### `prev_quarter`, `next_quarter`

The methods [`prev_quarter`][DateAndTime::Calculations#prev_quarter] and [`next_quarter`][DateAndTime::Calculations#next_quarter] return the date with the same day in the previous or next quarter:

```ruby
t = Time.local(2026, 5, 5)  # => 2026-05-05 00:00:00 +0000
t.prev_quarter              # => 2026-02-05 00:00:00 +0000
t.next_quarter              # => 2026-08-05 00:00:00 +0000
```

If such a day does not exist, the last day of the corresponding month is returned:

```ruby
Time.local(2026, 7, 31).prev_quarter  # => 2026-04-30 00:00:00 +0000
Time.local(2026, 5, 31).prev_quarter  # => 2026-02-28 00:00:00 +0000
Time.local(2026, 10, 31).prev_quarter # => 2026-07-31 00:00:00 +0000
Time.local(2026, 11, 30).next_quarter # => 2027-03-01 00:00:00 +0000
```

`prev_quarter` is aliased to [`last_quarter`][DateAndTime::Calculations#last_quarter].

NOTE: Defined in `active_support/core_ext/date_and_time/calculations.rb`.

[DateAndTime::Calculations#last_quarter]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-last_quarter
[DateAndTime::Calculations#next_quarter]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-next_quarter
[DateAndTime::Calculations#prev_quarter]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-prev_quarter

#### `prev_week`, `next_week`

The method [`next_week`][DateAndTime::Calculations#next_week] accepts a day name as a symbol and returns the date of that day in the following week. The default day is `:monday`, unless `config.beginning_of_week` has been set to something else:

```ruby
d = Date.new(2026, 5, 5)  # => Tue, 05 May 2026
d.next_week               # => Mon, 11 May 2026
d.next_week(:saturday)    # => Sat, 16 May 2026
```

The method [`prev_week`][DateAndTime::Calculations#prev_week] works the same way but returns the date in the previous week. It is also aliased as `last_week`:

```ruby
d.prev_week               # => Mon, 27 Apr 2026
d.prev_week(:saturday)    # => Sat, 02 May 2026
d.prev_week(:friday)      # => Fri, 01 May 2026
```

Both methods respect the `config.beginning_of_week` setting if configured.

NOTE: Defined in `active_support/core_ext/date_and_time/calculations.rb`.

[Date.beginning_of_week]: https://api.rubyonrails.org/classes/Date.html#method-c-beginning_of_week
[DateAndTime::Calculations#last_week]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-last_week
[DateAndTime::Calculations#next_week]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-next_week
[DateAndTime::Calculations#prev_week]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-prev_week

#### `monday`, `sunday`

The methods [`monday`][DateAndTime::Calculations#monday] and
[`sunday`][DateAndTime::Calculations#sunday] return the dates for the previous
Monday (or the same day if it is Monday) and next Sunday (or the same day if it
is Sunday), respectively.

```ruby
d = Date.new(2026, 05, 05)    # => Tue, 05 May 2026
d.monday                      # => Mon, 04 May 2026
d.sunday                      # => Sun, 10 May 2026
```

NOTE: Defined in `active_support/core_ext/date_and_time/calculations.rb`.

[DateAndTime::Calculations#monday]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-monday
[DateAndTime::Calculations#sunday]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-sunday

### Beginnings and Ends

#### `beginning_of_week`, `end_of_week`

The methods [`beginning_of_week`][DateAndTime::Calculations#beginning_of_week]
and [`end_of_week`][DateAndTime::Calculations#end_of_week] return the dates for
the beginning and end of the week, respectively.

Weeks are assumed to start on Monday, but that can be changed passing an
argument to `Date.beginning_of_week` or by setting
[`config.beginning_of_week`][].

```ruby
d = Date.new(2026, 05, 05)    # => Tue, 05 May 2026
d.beginning_of_week           # => Mon, 04 May 2026
d.end_of_week                 # => Sun, 10 May 2026
d.beginning_of_week(:sunday)  # => Sun, 03 May 2026
d.end_of_week(:sunday)        # => Sat, 09 May 2026
```

There are alias for `beginning_of_week` to
[`at_beginning_of_week`][DateAndTime::Calculations#at_beginning_of_week] and
`end_of_week` to [`at_end_of_week`][DateAndTime::Calculations#at_end_of_week].

NOTE: Defined in `active_support/core_ext/date_and_time/calculations.rb`.

[`config.beginning_of_week`]: configuring.html#config-beginning-of-week
[DateAndTime::Calculations#at_beginning_of_week]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-at_beginning_of_week
[DateAndTime::Calculations#at_end_of_week]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-at_end_of_week
[DateAndTime::Calculations#beginning_of_week]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-beginning_of_week
[DateAndTime::Calculations#end_of_week]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-end_of_week

#### `beginning_of_month`, `end_of_month`

The methods [`beginning_of_month`][DateAndTime::Calculations#beginning_of_month]
and [`end_of_month`][DateAndTime::Calculations#end_of_month] return the dates
for the beginning and end of the month:

```ruby
d = Date.new(2026, 5, 5)  # => Tue, 05 May 2026
d.beginning_of_month      # => Fri, 01 May 2026
d.end_of_month            # => Sun, 31 May 2026
```

There are aliases for `beginning_of_month` to [`at_beginning_of_month`][DateAndTime::Calculations#at_beginning_of_month], and `end_of_month` to [`at_end_of_month`][DateAndTime::Calculations#at_end_of_month].

NOTE: Defined in `active_support/core_ext/date_and_time/calculations.rb`.

[DateAndTime::Calculations#at_beginning_of_month]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-at_beginning_of_month
[DateAndTime::Calculations#at_end_of_month]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-at_end_of_month
[DateAndTime::Calculations#beginning_of_month]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-beginning_of_month
[DateAndTime::Calculations#end_of_month]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-end_of_month

#### `beginning_of_quarter`, `end_of_quarter`, `quarter`

The method [`quarter`][DateAndTime::Calculations#quarter] returns the quarter of the receiver's calendar year:

```ruby
d = Date.new(2026, 5, 5)  # => Tue, 05 May 2026
d.quarter                 # => 2
```

The methods
[`beginning_of_quarter`][DateAndTime::Calculations#beginning_of_quarter] and
[`end_of_quarter`][DateAndTime::Calculations#end_of_quarter] return the dates
for the beginning and end of the quarter of the receiver's calendar year:

```ruby
d = Date.new(2026, 5, 5)  # => Tue, 05 May 2026
d.beginning_of_quarter    # => Wed, 01 Apr 2026
d.end_of_quarter          # => Tue, 30 Jun 2026
```

There are aliases for `beginning_of_quarter` to
[`at_beginning_of_quarter`][DateAndTime::Calculations#at_beginning_of_quarter],
and `end_of_quarter` to
[`at_end_of_quarter`][DateAndTime::Calculations#at_end_of_quarter].

NOTE: Defined in `active_support/core_ext/date_and_time/calculations.rb`.

[DateAndTime::Calculations#quarter]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-quarter
[DateAndTime::Calculations#at_beginning_of_quarter]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-at_beginning_of_quarter
[DateAndTime::Calculations#at_end_of_quarter]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-at_end_of_quarter
[DateAndTime::Calculations#beginning_of_quarter]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-beginning_of_quarter
[DateAndTime::Calculations#end_of_quarter]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-end_of_quarter

#### `beginning_of_year`, `end_of_year`

The methods [`beginning_of_year`][DateAndTime::Calculations#beginning_of_year] and [`end_of_year`][DateAndTime::Calculations#end_of_year] return the dates for the beginning and end of the year:

```ruby
d = Date.new(2026, 5, 5)  # => Tue, 05 May 2026
d.beginning_of_year       # => Thu, 01 Jan 2026
d.end_of_year             # => Thu, 31 Dec 2026
```

There are aliases for `beginning_of_year` to
[`at_beginning_of_year`][DateAndTime::Calculations#at_beginning_of_year], and
`end_of_year` to [`at_end_of_year`][DateAndTime::Calculations#at_end_of_year].

NOTE: Defined in `active_support/core_ext/date_and_time/calculations.rb`.

[DateAndTime::Calculations#at_beginning_of_year]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-at_beginning_of_year
[DateAndTime::Calculations#at_end_of_year]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-at_end_of_year
[DateAndTime::Calculations#beginning_of_year]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-beginning_of_year
[DateAndTime::Calculations#end_of_year]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-end_of_year

#### `beginning_of_day`, `end_of_day`

The [`beginning_of_day`][Date#beginning_of_day] and `end_of_day` methods return a value representing the start (`00:00:00`) and end (`23:59:59`) of the day. On `Date`, this actually converts the receiver into a time-zone-aware `Time`/`DateTime`, since a bare date has no time component to set:

```ruby
date = Date.new(2026, 5, 5)
date.beginning_of_day # => Tue, 05 May 2026 00:00:00 UTC +00:00
date.end_of_day        # => Tue, 05 May 2026 23:59:59 UTC +00:00

time = Time.new(2026, 5, 5, 14, 30)
time.beginning_of_day # => Tue, 05 May 2026 00:00:00 UTC +00:00
time.end_of_day        # => Tue, 05 May 2026 23:59:59 UTC +00:00
```

`beginning_of_day` is aliased as `at_beginning_of_day`, `midnight`, and `at_midnight`.

NOTE: Available on `Date`, `DateTime`, and `Time`.

[Date#beginning_of_day]: https://api.rubyonrails.org/classes/Date.html#method-i-beginning_of_day

#### `beginning_of_hour`, `end_of_hour`

The [`beginning_of_hour`][Time#beginning_of_hour] and `end_of_hour` methods return a value representing the start (`hh:00:00`) and end (`hh:59:59`) of the current hour:

```ruby
time = Time.new(2026, 5, 5, 14, 37, 25)
time.beginning_of_hour # => Tue, 05 May 2026 14:00:00 UTC +00:00
time.end_of_hour        # => Tue, 05 May 2026 14:59:59 UTC +00:00
```

`beginning_of_hour` is aliased as `at_beginning_of_hour`.

NOTE: Available on `Time` and `DateTime` only. `Date` has no hour component, so these methods do not apply to it.

[Time#beginning_of_hour]: https://api.rubyonrails.org/classes/Time.html#method-i-beginning_of_hour

#### `beginning_of_minute`, `end_of_minute`

The [`beginning_of_minute`][Time#beginning_of_minute] and `end_of_minute` methods return a value representing the start (`hh:mm:00`) and end (`hh:mm:59`) of the current minute:

```ruby
time = Time.new(2026, 5, 5, 14, 37, 25)
time.beginning_of_minute # => Tue, 05 May 2026 14:37:00 UTC +00:00
time.end_of_minute        # => Tue, 05 May 2026 14:37:59 UTC +00:00
```

`beginning_of_minute` is aliased as `at_beginning_of_minute`.

NOTE: Available on `Time` and `DateTime` only.

[Time#beginning_of_minute]: https://api.rubyonrails.org/classes/Time.html#method-i-beginning_of_minute

#### `all_day`, `all_week`, `all_month`, `all_quarter`, and `all_year`

The method [`all_day`][DateAndTime::Calculations#all_day] returns a time range representing the whole day of the current time, from `00:00:00` to `23:59:59`:

```ruby
now = Time.current
# => Tue, 05 May 2026 12:00:00 UTC +00:00
now.all_day
# => Tue, 05 May 2026 00:00:00 UTC +00:00..Tue, 05 May 2026 23:59:59 UTC +00:00
```

NOTE: The return type a `Range` of `ActiveSupport::TimeWithZone` objects.

Similarly, [`all_week`][DateAndTime::Calculations#all_week], [`all_month`][DateAndTime::Calculations#all_month], [`all_quarter`][DateAndTime::Calculations#all_quarter], and [`all_year`][DateAndTime::Calculations#all_year] return ranges spanning their respective calendar periods, each from `00:00:00` on the first day to `23:59:59` on the last:

```ruby
now = Time.current
# => Tue, 05 May 2026 12:00:00 UTC +00:00
now.all_week
# => Mon, 04 May 2026 00:00:00 UTC +00:00..Sun, 10 May 2026 23:59:59 UTC +00:00
now.all_week(:sunday)
# => Sun, 03 May 2026 00:00:00 UTC +00:00..Sat, 09 May 2026 23:59:59 UTC +00:00
now.all_month
# => Fri, 01 May 2026 00:00:00 UTC +00:00..Sun, 31 May 2026 23:59:59 UTC +00:00
now.all_quarter
# => Wed, 01 Apr 2026 00:00:00 UTC +00:00..Tue, 30 Jun 2026 23:59:59 UTC +00:00
now.all_year
# => Thu, 01 Jan 2026 00:00:00 UTC +00:00..Thu, 31 Dec 2026 23:59:59 UTC +00:00
```

NOTE: Defined in `active_support/core_ext/date_and_time/calculations.rb`.

[DateAndTime::Calculations#all_day]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-all_day
[DateAndTime::Calculations#all_month]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-all_month
[DateAndTime::Calculations#all_quarter]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-all_quarter
[DateAndTime::Calculations#all_week]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-all_week
[DateAndTime::Calculations#all_year]: https://api.rubyonrails.org/classes/DateAndTime/Calculations.html#method-i-all_year
[Time.current]: https://api.rubyonrails.org/classes/Time.html#method-c-current

### Time Zones and UTC

#### `Time.zone`

Rails applications can configure a single application-level time zone via `config.time_zone`. Active Support exposes the configured zone through the [`Time.zone`][Time.zone] method, which returns an `ActiveSupport::TimeZone` instance:

```ruby
Time.zone
# => #<ActiveSupport::TimeZone:... @name="Eastern Time (US & Canada)">
```

This is what's used by `Time.current` and the related methods, without a configured `Time.zone`, Rails would fall back to the system's local time zone.

#### `ActiveSupport::TimeWithZone`

The methods below related to `Time.zone` return `ActiveSupport::TimeWithZone`
objects (rather than plain `Time`), anchored to the configured zone. A
`TimeWithZone` behaves like `Time` for nearly all practical purposes
(arithmetic, comparisons, formatting) but carries its time zone with it, so
calculations like `+ 1.day` or `.beginning_of_month` stay correctly anchored to
that zone, including across daylight saving transitions.

```ruby
Time.zone.now
# => Tue, 05 May 2026 08:00:00 EDT -04:00

Time.zone.local(2026, 5, 5, 14, 30, 0)
# => Tue, 05 May 2026 14:30:00 EDT -04:00

Time.zone.parse("2026-05-05 14:30:00")
# => Tue, 05 May 2026 14:30:00 EDT -04:00

Time.zone.at(1778337000)
# => Tue, 05 May 2026 08:30:00 EDT -04:00
```

NOTE: `ActiveSupport::TimeZone` and `ActiveSupport::TimeWithZone` represent different things. A `TimeZone` is the zone itself, a named configuration like "Eastern Time (US & Canada)," with no specific time attached. A `TimeWithZone` is an actual timestamp, that you get back from methods like `Time.zone.now` or `in_time_zone`. The `TimeWithZone` represents a timestamp and carries the zone with it as well.

#### `in_time_zone`

While `Time.zone` always refers to the application's single configured zone, the [`in_time_zone`][DateTime#in_time_zone] method lets you convert any `Time`, `DateTime`, or `Date` into an `ActiveSupport::TimeWithZone` for *any* zone you choose:

```ruby
Time.zone = "Hawaii"
DateTime.new(2026, 1, 1).in_time_zone
# => Wed, 31 Dec 2025 14:00:00 HST -10:00

DateTime.new(2026, 1, 1).in_time_zone("Alaska")
# => Wed, 31 Dec 2025 15:00:00 AKST -09:00
```

This is useful when you need to display a time in a zone other than the application default. For example, showing an event time in the time zone the user selected.

#### `dst?`

The [`dst?`][Time#dst?] method returns `true` if the receiver falls within daylight saving time for its zone:

```ruby
Time.zone = "Eastern Time (US & Canada)"

Time.zone.local(2026, 1, 1).dst? # => false  — January is standard time
Time.zone.local(2026, 7, 1).dst? # => true   — July is daylight saving time
```

#### `utc` and `utc?`

The method [`utc`][DateTime#utc] returns the same moment in time as the receiver, converted to UTC:

```ruby
now = DateTime.current # => Tue, 05 May 2026 08:00:00 -0400
now.utc                # => Tue, 05 May 2026 12:00:00 +0000
```

This method is also aliased as [`getutc`][DateTime#getutc].

[`utc?`][DateTime#utc?] returns `true` if the receiver is already expressed in UTC:

```ruby
now = DateTime.current # => Tue, 05 May 2026 08:00:00 -0400
now.utc?               # => false
now.utc.utc?           # => true
```

NOTE: Defined in `active_support/core_ext/date_time/calculations.rb` and `active_support/core_ext/time/calculations.rb`.

[Time.zone]: https://api.rubyonrails.org/classes/Time.html#method-c-zone
[DateTime#in_time_zone]: https://api.rubyonrails.org/classes/DateTime.html#method-i-in_time_zone
[Time#dst?]: https://api.rubyonrails.org/classes/Time.html#method-i-dst-3F
[DateTime#getutc]: https://api.rubyonrails.org/classes/DateTime.html#method-i-getutc
[DateTime#utc]: https://api.rubyonrails.org/classes/DateTime.html#method-i-utc
[DateTime#utc?]: https://api.rubyonrails.org/classes/DateTime.html#method-i-utc-3F

### Duration

The [`ActiveSupport::Duration`][ActiveSupport::Duration] objects are the values returned by `1.day`, `2.weeks`, `3.months`, and such. Those durations can be added to or subtracted from `Date`, `DateTime`, and `Time` objects:

```ruby
Date.current + 1.year     # => a Date one year from today
Time.current - 1.week     # => a Time one week ago
DateTime.current + 3.days # => a DateTime three days from now
```

Under the hood, this arithmetic translates into calls to `since` or
`advance`,which means they correctly handle calendar edge cases. For example,
the Gregorian calendar reform skipped 10 days in October 1582, the `Duration`
arithmetic respects this:

```ruby
Date.new(1582, 10, 4) + 1.day
# => Fri, 15 Oct 1582
```

The key difference between the three classes is daylight saving time (DST)
awareness. `Time` understands DST, so duration arithmetic on a `Time` correctly
accounts for clocks moving forward or backward. `Date` and `DateTime` have no
concept of DST, so the same arithmetic on those classes simply shifts by a fixed
calendar amount without adjusting for any time change:

```ruby
# Clocks spring forward at 2am in New York on March 8, 2026
t = Time.local(2026, 3, 8, 1, 59, 59)
t + 1.second
# => Sun Mar 08 03:00:00 -0400 2026   (correctly skips the DST gap)

dt = DateTime.new(2026, 3, 8, 1, 59, 59)
dt + 1.second
# => 2026-03-08T02:00:00+00:00        (no DST adjustment — just adds a second)
```

This is the one reason to prefer `Time` (or `ActiveSupport::TimeWithZone`) over `DateTime` whenever you're doing time-of-day arithmetic that might span a DST transition.

NOTE: Defined in `active_support/core_ext/date/calculations.rb`, `active_support/core_ext/date_time/calculations.rb`, and `active_support/core_ext/time/calculations.rb`.

[ActiveSupport::Duration]: https://api.rubyonrails.org/classes/ActiveSupport/Duration.html

Exception Class Extensions
--------------------------

### NameError

Active Support adds [`missing_name?`][NameError#missing_name?] to `NameError`, which checks whether the exception was raised because of a specific constant name.

The name can be given as a symbol or a string, and each is matched differently:

- A symbol is matched against only the bare constant name, the last segment, with no namespace.
- A string is matched against the fully qualified constant name, the complete path, including any namespace.

```ruby
begin
  Garage::Vehicle
rescue NameError => e
  e.missing_name?(:Vehicle)            # => true   (bare name matches, namespace ignored)
  e.missing_name?(:"Garage::Vehicle")  # => false  (bare name lookup, doesn't match "Vehicle")
  e.missing_name?("Vehicle")           # => false  (not the full path)
  e.missing_name?("Garage::Vehicle")   # => true   (exact full path)
end
```

Use a symbol if you only know the short name of the constant you're checking for. Use a string if you know (and want to match) the exact namespaced path.

TIP: A symbol can also represent a fully qualified name, like `:"ActiveRecord::Base"` — this works for convenience, not because symbols carry namespace information.

The `missing_name?` method is useful for distinguishing between "this constant doesn't exist, which is fine" and "a real error occurred while loading something." For example, Rails optimistically tries to load a controller's matching helper module. If the helper module simply doesn't exist, that's fine and the error can be silenced. But if the helper file exists and itself raises a `NameError` due to an unrelated typo, that error needs to propagate:

```ruby
def default_helper_module!
  module_name = name.delete_suffix("Controller")
  helper module_name.underscore
rescue NameError => e
  raise e unless e.missing_name?("#{module_name}Helper")
end
```

NOTE: Defined in `active_support/core_ext/name_error.rb`.

[NameError#missing_name?]: https://api.rubyonrails.org/classes/NameError.html#method-i-missing_name-3F

### LoadError

Active Support adds [`is_missing?`][LoadError#is_missing?] to `LoadError`. Given a file path, it checks whether the exception was raised because that specific file could not be found (the `.rb` extension is optional in the check):

```ruby
begin
  require "articles_helper"
rescue LoadError => e
  e.is_missing?("articles_helper") # => true
end
```

This serves the same purpose as `missing_name?` does for `NameError`, but at the file level. When Rails tries to load a controller's helper file, it's fine if that file simply doesn't exist. But if the file exists and itself fails to load a missing dependency, that error should propagate rather than being silently swallowed:

```ruby
def default_helper_module!
  module_name = name.delete_suffix("Controller")
  module_path = module_name.underscore
  helper module_path
rescue LoadError => e
  raise e unless e.is_missing?("helpers/#{module_path}_helper")
rescue NameError => e
  raise e unless e.missing_name?("#{module_name}Helper")
end
```

NOTE: Defined in `active_support/core_ext/load_error.rb`.

[LoadError#is_missing?]: https://api.rubyonrails.org/classes/LoadError.html#method-i-is_missing-3F

Other Extensions
----------------

### BigDecimal

Active Support sets the default specifier for `BigDecimal#to_s` to `"F"`, so calling `to_s` without arguments returns a plain floating point representation rather than scientific notation:

```ruby
BigDecimal(5.00, 6).to_s      # => "5.0"
BigDecimal(5.00, 6).to_s("e") # => "0.5E1" ("e" for scientific notation)
```

### `Digest::UUID`

Active Support adds the `Digest::UUID` module for generating UUIDs (Universally Unique Identifiers) in several standard formats defined by RFC 4122. Ruby's standard library only provides `SecureRandom.uuid` for generating a random v4 UUID. Everything else in this section, including deterministic UUIDs, namespace constants, and the nil UUID, is added by Active Support.

#### `uuid_v4`

[`Digest::UUID.uuid_v4`][Digest::UUID.uuid_v4] generates a random UUID. It is a convenience wrapper around Ruby's built-in `SecureRandom.uuid`:

```ruby
Digest::UUID.uuid_v4 # => "b16f4bc7-2960-4e47-9d3f-a19c6f7174bd"
Digest::UUID.uuid_v4 # => "e08f6f8e-9a1c-4b3d-8e2a-7f5d9c1b4e6a"
```

#### `uuid_v3` and `uuid_v5`

The methods [`uuid_v3`][Digest::UUID.uuid_v3] and [`uuid_v5`][Digest::UUID.uuid_v5] generate *deterministic* UUIDs. They always return the same UUID for a given namespace and name combination. This makes them useful for generating stable identifiers from known inputs, like a URL or a domain name.

`uuid_v3` uses MD5 hashing, `uuid_v5` uses SHA1 and is generally preferred since SHA1 is more collision-resistant:

```ruby
Digest::UUID.uuid_v5(Digest::UUID::DNS_NAMESPACE, "www.example.com")
# => "37a76e34-f88c-57d7-a277-d464c7a2ff19"

Digest::UUID.uuid_v5(Digest::UUID::DNS_NAMESPACE, "www.example.com")
# => "37a76e34-f88c-57d7-a277-d464c7a2ff19"  — same every time

Digest::UUID.uuid_v3(Digest::UUID::DNS_NAMESPACE, "www.example.com")
# => "9073926b-929f-31c2-abc9-fad77ae3e8eb"
```

Active Support provides four built-in namespace constants:

```ruby
Digest::UUID::DNS_NAMESPACE  # for domain names
Digest::UUID::URL_NAMESPACE  # for URLs
Digest::UUID::OID_NAMESPACE  # for ISO object identifiers
Digest::UUID::X500_NAMESPACE # for X.500 distinguished names
```

#### `uuid_from_hash`

The [`uuid_from_hash`][Digest::UUID.uuid_from_hash] method is the underlying method that `uuid_v3` and `uuid_v5` call. It accepts a hash class explicitly, you can pass `OpenSSL::Digest::MD5` for a v3 UUID or `OpenSSL::Digest::SHA1` for a v5 UUID:

```ruby
Digest::UUID.uuid_from_hash(OpenSSL::Digest::SHA1, Digest::UUID::URL_NAMESPACE, "https://example.com")
# => a deterministic UUID based on the SHA1 hash of the namespace + name
```

#### `nil_uuid`

Thee [`nil_uuid`][Digest::UUID.nil_uuid] returns the special nil UUID — all 128 bits set to zero:

```ruby
Digest::UUID.nil_uuid # => "00000000-0000-0000-0000-000000000000"
```

NOTE: Defined in `active_support/core_ext/digest/uuid.rb`.

[Digest::UUID.uuid_v4]: https://api.rubyonrails.org/classes/Digest/UUID.html#method-c-uuid_v4
[Digest::UUID.uuid_v3]: https://api.rubyonrails.org/classes/Digest/UUID.html#method-c-uuid_v3
[Digest::UUID.uuid_v5]: https://api.rubyonrails.org/classes/Digest/UUID.html#method-c-uuid_v5
[Digest::UUID.uuid_from_hash]: https://api.rubyonrails.org/classes/Digest/UUID.html#method-c-uuid_from_hash
[Digest::UUID.nil_uuid]: https://api.rubyonrails.org/classes/Digest/UUID.html#method-c-nil_uuid

### ERB::Util (`html_escape`)
 
The method [`html_escape`][ERB::Util#html_escape] escapes HTML tag characters, such as `<`, `>`, `&`, and `"`, in a string. Active Support's version behaves the same as Ruby's but returns an HTML-safe string, so Rails' template engine knows not to escape it again when rendering:

```ruby
ERB::Util.html_escape("is a > 0 & a < 10?")
# => "is a &gt; 0 &amp; a &lt; 10?"

ERB::Util.html_escape("<script>alert('xss')</script>")
# => "&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;"
```

`html_escape` is aliased as `h`, which is the form most commonly seen in ERB templates:

```erb
<%= h @user.name %>
```

There is also [`html_escape_once`][ERB::Util#html_escape_once], it escapes HTML entities without double-escaping content that is already escaped:

```ruby
ERB::Util.html_escape_once("1 < 2 &amp; 3")
# => "1 &lt; 2 &amp; 3"  — the existing &amp; is preserved, not double-escaped
```

This is useful when content may have already been partially escaped and you want to ensure it is safe without corrupting it.

NOTE: Defined in `active_support/core_ext/erb/util.rb`.

[ERB::Util#html_escape]: https://api.rubyonrails.org/classes/ERB/Util.html#method-i-html_escape
[ERB::Util#html_escape_once]: https://api.rubyonrails.org/classes/ERB/Util.html#method-i-html_escape_once

### File (``atomic_write`)

Ruby's standard `File.write` method can leave a file in a partially written state if another process reads it mid-write. The [`File.atomic_write`][File.atomic_write] method is an Active Support addition that solves this. It writes to a temporary file first and then renames it to the target path in a single atomic operation, so any reader always sees either the old complete file or the new complete file, never a half written one.

The method takes a filename and yields a file handle:

```ruby
File.atomic_write(joined_asset_path) do |cache|
  cache.write(join_asset_file_contents(asset_paths))
end
```

Action Pack uses this to write asset cache files like `all.css`, where serving a partial file to a browser would cause errors.

Under the hood, `atomic_write` writes to a temporary file in the system's temp directory. When the block completes, the temp file is renamed to the target path (a POSIX-atomic operation). If the target file already exists, it is overwritten and its ownership and permissions are preserved where possible.

A few things to be aware of:

- You cannot append to a file with `atomic_write`, it's write-only.
- If the target file has an ACL (Access Control List) set, it will be recalculated after the write due to the `chmod` operation `atomic_write` performs.
- If ownership or permissions cannot be copied, the error is silently skipped and the filesystem's defaults apply.

NOTE: An ACL (Access Control List) is a set of fine-grained user and process permissions that go beyond standard Unix read/write/execute bits. If your application relies on ACL rules on files, be aware they may be modified after an atomic write.

You can pass a custom directory for the temporary file as the second argument:

```ruby
File.atomic_write(target_path, "/my/tmp/dir") do |file|
  file.write(content)
end
```

NOTE: Defined in `active_support/core_ext/file/atomic.rb`.

[File.atomic_write]: https://api.rubyonrails.org/classes/File.html#method-c-atomic_write

### Pathname (`existence`)

The [`existence`][Pathname#existence] method returns the receiver if the named file exists otherwise returns `nil`. It is useful for idioms like this:

```ruby
content = Pathname.new("file").existence&.read
```

NOTE: Defined in `active_support/core_ext/pathname/existence.rb`.

[Pathname#existence]: https://api.rubyonrails.org/classes/Pathname.html#method-i-existence

### Regexp (`multiline?`)

By default, the `.` character in a Ruby regular expression matches any character except a newline. Adding the `/m` flag changes this so that `.` matches newlines too — this is called multiline mode.

The [`multiline?`][Regexp#multiline?] method returns `true` if the regexp has the `/m` flag set:

```ruby
%r{.}.multiline?                              # => false
%r{.}m.multiline?                             # => true
Regexp.new(".").multiline?                    # => false
Regexp.new(".", Regexp::MULTILINE).multiline? # => true
```

Rails uses this in the routing code to disallow multiline regexps in route requirements. A route constraint like `constraints id: /foo.bar/` should match only within a single line, allowing `.` to match newlines could cause a route to match unintended paths. Rails enforces this with:

```ruby
def verify_regexp_requirements(requirements)
  if requirement.multiline?
    raise ArgumentError, "Regexp multiline option is not allowed in routing requirements: #{requirement.inspect}"
  end
end
```

NOTE: Defined in `active_support/core_ext/regexp.rb`.

[Regexp#multiline?]: https://api.rubyonrails.org/classes/Regexp.html#method-i-multiline-3F

### SecureRandom (`base_*`)

Active Support adds two methods to Ruby's `SecureRandom` module for generating random strings in specific character sets. Ruby's built-in `SecureRandom.hex` and `SecureRandom.alphanumeric` are general-purpose. The Active support additions give you more control over the exact alphabet used, which matters for things like tokens, slugs, and identifiers.

#### `base58`

The [`base58`][SecureRandom.base58] method generates a random string using the Base58 alphabet: digits `0-9`, uppercase `A-Z`, and lowercase `a-z`, with the visually ambiguous characters `0`, `O`, `I`, and `l` removed to reduce transcription errors:

```ruby
SecureRandom.base58     # => "4kUgL2pdQMSCQtjE"  (16 characters, default)
SecureRandom.base58(24) # => "AGt8sPzCFkjz8x7ExbD4etv9"
```

The removal of ambiguous characters makes Base58 well-suited for human-readable tokens that users may need to read aloud or type manually.

WARNING: MySQL and some other databases use case-insensitive collations by default, which means `base58` tokens that differ only in case may be treated as identical. If you store `base58` tokens in a database with case-insensitive collation, ensure the column uses a case-sensitive collation, or consider `base36` instead.

#### `base36`

Thee [`base36`][SecureRandom.base36] method generates a random string using only digits `0-9` and lowercase letters `a-z`:

```ruby
SecureRandom.base36     # => "hgmtp5k3fm8dqxv7"  (16 characters, default)
SecureRandom.base36(24) # => "3jqv9zp2mxfk7t8nyd4wsr6c"
```

Because the alphabet is entirely lowercase, `base36` tokens are safe to store in case-insensitive database columns without risk of collisions.

NOTE: Defined in `active_support/core_ext/securerandom.rb`.

[SecureRandom.base58]: https://api.rubyonrails.org/classes/SecureRandom.html#method-c-base58
[SecureRandom.base36]: https://api.rubyonrails.org/classes/SecureRandom.html#method-c-base36

