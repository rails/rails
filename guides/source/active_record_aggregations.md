**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Active Record Aggregations
==========================

This guide covers how Rails supports aggregations in Active Record models.

After reading this guide, you will know:

* What are value objects and how to define them.
* How to use Value Objects with Active Record aggregations.
* How to query and manipulate aggregated attributes.

--------------------------------------------------------------------------------

What is Active Record Aggregations?
-----------------------------------

In many domains, simple columns like strings and integers are not expressive enough on their own.
You may want to introduce a [*value object*](#what-are-value-objects-questionmark) to represent a richer concept in your domain.

For example:

- a `Money` class to represent monetary values,
- an `Address` class for postal addresses,
- a `Dimension` class for measurements,
- or even complex numbers.

**Active Record Aggregations** provides a way to map these `value objects` attributes to database columns using
the [`composed_of`](https://api.rubyonrails.org/classes/ActiveRecord/Aggregations/ClassMethods.html) method.
It is used to express `is-composed-of` relationships.

For example:

- An `Account` *is composed of* `Money`.
- A `User` *is composed of* `Address`.
- A `Product` *is composed of* `Dimension`.

What are Value Objects?
-----------------------

Value objects are immutable and interchangeable objects that represent a single value or concept, so no setter methods are allowed.
This improves clarity, keeps business rules close to the data they describe, and avoids the pitfalls of using
raw primitive data-types throughout your models and business logic.
They are often used to encapsulate related attributes and behavior, such as Money object can represent `$100`, and
Address object can represent `123 Main St, Springfield, IL`.

### Value Object Comparison

Any two value objects with the same attributes or calculative equal values are considered equal.

For example:

* two `Money` objects with the same amount and currency are considered equal, even if they are different instances.
* Also, two money objects with different amounts but equal value when exchanged to the same currency are considered equal.

While defining a value object, you typically override the `==` and `<=>` methods to compare the attributes of the objects.
Also, you define a way to convert between different units if applicable.

NOTE: Entity objects like descendants of `ApplicationRecord` are not value objects, as they have a distinct identity and
lifecycle. They are uniquely identified by their primary keys or object ids.

### Benefits of Using Value Objects

Using value objects in your application can provide several benefits:

* **Maintainability**: Value objects can help to keep your code organized and maintainable by separating concerns and
    reducing duplication. Instead of juggling raw strings and integers everywhere, you use meaningful types.

* **Immutability**: Value objects are typically immutable, which can help to prevent unintended side effects and make your code more predictable.

* **Reduced Complexity**: Value objects can make your code more expressive and easier to understand by encapsulating related attributes and behavior.

### Defining a Value Object

A value object is typically defined as a plain Ruby class that includes the `Comparable` module. They are importantly
immutable and do not let you change the value after creation.

Instead, you need to create a new instance with the new value.
The immutable requirement is enforced by Active Record by freezing any object assigned as a value object. Attempting to
change it afterward will result in a `RuntimeError`.

```ruby

class Money
  include Comparable
  attr_reader :amount, :currency
  EXCHANGE_RATES = { "USD_TO_DKK" => 6, "USD_TO_EUR" => 0.85, "EUR_TO_USD" => 1.17 } # define other exchange rates as needed

  def initialize(amount, currency = "USD")
    @amount, @currency = amount, currency
  end

  def exchange_to(other_currency)
    exchanged_amount = (amount * EXCHANGE_RATES["#{currency}_TO_#{other_currency}"]).floor
    Money.new(exchanged_amount, other_currency)
  end

  def ==(other_money)
    amount == other_money.amount && currency == other_money.currency
  end

  def <=>(other_money)
    if currency == other_money.currency
      amount <=> other_money.amount
    else
      amount <=> other_money.exchange_to(currency).amount
    end
  end
end
```

Let's define another kind of value object, an Address:

```ruby

class Address
  attr_reader :street, :city, :state, :zip

  def initialize(street, city, state, zip)
    @street, @city, @state, @zip = street, city, state, zip
  end

  def ==(other_address)
    street  == other_address.street &&
      city  == other_address.city &&
      state == other_address.state &&
      zip   == other_address.zip
  end

  def close_to?(other_address)
    city == other_address.city && state == other_address.state
  end
end
```

TIP: Read more about value objects on [c2.com/cgi/wiki?ValueObject](https://www.c2.com/cgi/wiki?ValueObject) and on the dangers of not
keeping value objects immutable on [c2.com/cgi/wiki?ValueObjectsShouldBeImmutable](https://www.c2.com/cgi/wiki?ValueObjectsShouldBeImmutable).

Using Value Objects with Active Record
--------------------------------------

Active Record provides the `composed_of` macro(class method) to map value objects to database columns.
You can use `composed_of` in your Active Record models to define the relationship between the model and the value
object.
The `composed_of` method takes the name of the value object and a hash of options to configure the mapping.

Each call to the macro defines how the value objects are constructed from the model attributes when model instances
are built or loaded from the database, and how the model attributes are set when a value object is assigned to the
model.

### Basic Usage

Let's say you have a `Product` model that has `price_cents` and `price_currency` columns in the database, and you want
to use a `Money` value object to represent the price of the product.

You can define the `Product` model like this:

```ruby
class Product < ApplicationRecord
  composed_of :price,
              class_name: "Money",
              mapping: { price_cents: :amount, price_currency: :currency },
              # mapping: [%w(price_cents amount), %w(price_currency currency)],  # alternative syntax
              constructor: Proc.new { |amount, currency| Money.new(amount || 0, currency || "USD") },
              converter: Proc.new { |value| value.is_a?(Money) ? value : Money.new(value) }
end
```

It is recommended to store money values as integers in the smallest currency unit (e.g. cents) to avoid
floating point precision issues so using `price_cents` field name instead of `price`.

This will map the `price` attribute of the `Product` model to a `Money` object, using the `price_cents`
and `price_currency` columns in the database.

* **The `constructor` option**: is a Proc that defines how to create a new `Money` object from the model attributes. The default constructor will call `Money.new` with the mapped attributes.
* **The `converter` option**: takes a symbol specifying a class method define in `:class_name` class or takes a Proc that defines how to convert a value assigned to the `price` attribute to a `Money` object.
  Basically it needs you to define a way to convert non-`Money` values to `Money` objects. Converter class method or proc is only called if value passed is not already a `Money` object.

Now you can use the `price` attribute of the `Product` model as a `Money` object:

```ruby
product = Product.new(price: Money.new(1000, "USD"))
product.price.amount                    # => 1000
product.price.currency                  # => "USD"
product.price_cents                     # => 1000
product.price_currency                  # => "USD"
product.price                           # => Money value object

# Updating price
product.price = Money.new(2000, "EUR")
product.price.amount                    # => 2000
product.price.currency                  # => "EUR"
product.price_cents                     # => 2000
product.price_currency                  # => "EUR"

# assigning non-Money value, it will use the converter proc to convert it to Money object
product.price = 3000
product.price.amount                    # => 3000
product.price.currency                  # => "USD" (default currency from constructor)
product.price_cents                     # => 3000
product.price_currency                  # => "USD"
product.price.exchange_to("EUR")        # => Money.new(2550, "EUR")

# comparing prices
product.price > Money.new(1500, "USD")  # => true
product.price > Money.new(2700, "EUR")  # => false (1 EUR == 1.17 USD)
product.price == Money.new(3000, "USD") # => true
```

### Using with Other Value Objects

You can use `composed_of` with any value object, not just `Money`.
For example, let's say you have a `User` model that has `street`, `city`, `state`, and `zip` columns in the database,
and you want to use an `Address` value object to represent the user's address.
You can define the `User` model like this:

```ruby

class User < ApplicationRecord
  composed_of :address,
              class_name: "Address",
              mapping: [%w(street street), %w(city city), %w(state state), %w(zip zip)],
              constructor: Proc.new { |street, city, state, zip| Address.new(street || "", city || "", state || "", zip || "") },
              converter: Proc.new { |value| value.is_a?(Address) ? value : Address.new(value) }
end
```

Now you can use the `address` attribute of the `User` model as an `Address` object:

```ruby
user = User.new(address: Address.new("123 Main St", "Springfield", "IL", "62701"))
user.address.street # => "123 Main St"
user.address.city   # => "Springfield"
user.address.state  # => "IL"
user.address.zip    # => "62701"
user.street         # => "123 Main St"
user.city           # => "Springfield"
user.state          # => "IL"
user.zip            # => "62701"

user.address = Address.new("456 Elm St", "Springfield", "IL", "62702")
user.address.street # => "456 Elm St"
user.address.city   # => "Springfield"
user.address.state  # => "IL"
user.address.zip    # => "62702"
user.street         # => "456 Elm St"
user.city           # => "Springfield"
user.state          # => "IL"
user.zip            # => "62702"
```

Querying Aggregated Attributes
-----------------------------------------------

You can make simple queries using the aggregated attributes.
When you query using an aggregated attribute, Active Record will translate the query to use the underlying
table columns.

```ruby
Product.where(price: Money.new(2000, "USD"))
# => SELECT "products".* FROM "products" WHERE "products"."price_cents" = 2000 AND "products"."price_currency" = 'USD'

User.where(address: Address.new("456 Elm St", "Springfield", "IL", "62702"))
# => SELECT "users".* FROM "users" WHERE "users"."street" = '456 Elm St' AND "users"."city" = 'Springfield' AND "users"."state" = 'IL' AND "users"."zip" = '62702'
```

Please see the [caveats section below](#querying-for-same-value-with-different-value-attributes) for more details on querying with values in different units.

Usage in Scopes and Validations
-------------------------------

You can also use the aggregated attributes in scopes and validations:

```ruby
class Product < ApplicationRecord
  composed_of :price,
              class_name: "Money",
              mapping: [%w(price_cents amount), %w(price_currency currency)]
  validates   :price, presence: true
  scope       :expensive, -> { where(price: Money.new(2000, "USD")) }
end
```

Since you cannot use aggregated attribute(like `price`) directly in database queries,
so you need to use the underlying table columns(like `price_cents`) in scopes for complex queries.

```ruby
  scope       :expensive, -> { where("price_cents > ?", 1000) }
```

Other Option Examples
---------------------

Here are some examples of value objects you might build using Active Record Aggregations in your app:

```ruby
composed_of :temperature, mapping: { reading: :celsius }
composed_of :balance, class_name: "Money", mapping: { balance: :amount }
composed_of :address, mapping: { address_street: :street, address_city: :city }
composed_of :address, mapping: [%w(address_street street), %w(address_city city)]
composed_of :gps_location
composed_of :gps_location, allow_nil: true
composed_of :ip_address,
            class_name: "IPAddr",
            mapping: { ip: :to_i },
            constructor: Proc.new { |ip| IPAddr.new(ip, Socket::AF_INET) },
            converter: Proc.new { |ip| ip.is_a?(Integer) ? IPAddr.new(ip, Socket::AF_INET) : IPAddr.new(ip.to_s) }
```


Caveats
-------

### Querying for Same Value with Different Value Attributes

Let's say we have a `Duration` value object that represents a time duration in seconds, minutes, or hours.

```ruby
class Duration
  include Comparable
  attr_reader :value, :unit
  UNITS_IN_SECONDS = { sec: 1, min: 60, hr: 3600 }

  def initialize(value, unit = :seconds)
    @value, @unit = value, unit
  end

  def to_seconds
    value * UNITS_IN_SECONDS[unit]
  end

  def ==(other_duration)
    to_seconds == other_duration.to_seconds
  end

  def <=>(other_duration)
    to_seconds <=> other_duration.to_seconds
  end
end
```

while comparing two `Duration` objects, they are considered equal if they represent same duration in seconds.

```ruby
Duration.new(60, :sec) == Duration.new(1, :min)
# => true

Duration.new(7200, :sec) == Duration.new(2, :hr)
# => true
```

Now let's define a `Task` model that has `duration_value` and `duration_unit` columns in the database, and you want
to use a `Duration` value object to represent the duration of the task.

```ruby
class Task < ApplicationRecord
  composed_of :duration, mapping: { duration_value: :value, duration_unit: :unit }
end
```

When you create two `Task` records with different `Duration` objects with different units that represent the same duration,
and later make query using one of those `Duration` objects, it will not return both records as some of us might expect.

```ruby
Duration.new(120, :min) == Duration.new(2, :hr)
# => true

Task.create duration: Duration.new(120, :min)
# => #<Task:0x000000011f6337e0 id: 1, duration_value: 120, duration_unit: "min">

Task.create duration: Duration.new(2, :hr)
# => #<Task:0x000000011be96e18 id: 2, duration_value: 2, duration_unit: "hr">

Task.where(duration: Duration.new(2, :hr))
# => SELECT "tasks".* FROM "tasks" WHERE "tasks"."duration_value" = 2 AND "tasks"."duration_unit" = 'hr'
# => [#<Task:0x000000011be95a18 id: 2, duration_value: 2, duration_unit: "hr">]
```

#### Workaround

So to make such queries work as expected, you can choose to store the value in a single unit in the database,
like how banks maintain accounts in a particular currency only. So whenever new transaction comes in different currency,
it is converted to the account currency before storing. This way you can avoid such issues.

In our example, we can store the duration in seconds only and convert it back to the desired unit when reading.


### Dirty Tracking Method for Aggregated Attributes

Active Record Aggregations does not define dirty tracking methods for aggregated attributes directly.
Instead, it relies on the underlying table attributes to track changes.

For example:

```ruby
product       = Product.find(1)
product.price = Money.new(2000, "EUR")
product.changed?                          # => true
product.changes_to_save                   # => {"price_cents"=>[1000, 2000], "price_currency"=>["USD", "EUR"]}

product.price_changed?                    # => NoMethodError (no direct price_changed?)
product.price.amount_changed?             # => NoMethodError

product.price_cents_changed?              # => true
```


Conclusion
----------

Active Record aggregations provide a powerful way to work with value objects in your Rails applications.
By using the [`composed_of`](https://api.rubyonrails.org/classes/ActiveRecord/Aggregations/ClassMethods.html) method, you can easily map value objects to database columns, allowing
you to encapsulate related attributes and behavior in a single object.

This can help to improve the readability and maintainability of your code, as well as making it easier to
work with complex data structures.
