**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Composite Primary Keys
======================

This guide is an introduction to composite primary keys for database tables.

After reading this guide you will be able to:

* Know what composite primary keys are and when to use them
* Declare composite primary keys and create migrations
* Query models with composite primary keys
* Enable associations with composite primary keys
* Create forms for models that use composite primary keys
* Extract composite primary keys from controller parameters
* Use database fixtures for tables with composite primary keys

--------------------------------------------------------------------------------

What are Composite Primary Keys?
--------------------------------

Sometimes a single column's value isn't enough to uniquely identify every row
of a table, and a combination of two or more columns is required.
This can be the case when using a legacy database schema without a single `id`
column as a primary key, or when altering schemas for sharding or multitenancy.

Composite primary keys (CPK) increase complexity and can be slower than a
single primary key column. Ensure your use case requires a composite primary key
before using one.

### Using `query_constraints` as an Alternative

In cases where your table has a conventional `id` column but you want Active Record to scope queries using an additional column — common in multi-tenant applications — you can use `query_constraints` instead of redefining the primary key entirely:

```ruby
class Order < ApplicationRecord
  query_constraints :shop_id, :id
end
```

This keeps `id` as the primary key at the database level while instructing Active Record to always include `shop_id` in queries, updates, and deletes. It's a lighter-weight option when you don't need a true composite primary key but want Rails to treat a combination of columns as the effective identity.


Declaring Composite Primary Keys and Creating Migrations
--------------------------------------------------------

To create a table with a composite primary key, you can pass an array to the `primary_key:` option in the migration file:

```ruby
class CreateProducts < ActiveRecord::Migration[8.2]
  def change
    create_table :products, primary_key: [:store_id, :sku] do |t|
      t.integer :store_id
      t.string :sku
      t.text :description
      t.timestamps
    end
  end
end
```

After running the migration above, your `schema.rb` file will reflect the composite key:

```ruby
# db/schema.rb
create_table "products", primary_key: [:store_id, :sku], force: :cascade do |t|
  t.integer "store_id", null: false
  t.string "sku", null: false
  t.text "description"
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false
end
```

NOTE: When using a composite primary key, uniqueness is enforced by the combination of columns rather than a single auto-incrementing `id`. In the above example, `store_id` would typically be a foreign key to a `stores` table, and `sku` would be a string the application provides (like "ABC-123"). Neither needs to be auto-generated, their combination is what's unique. However, if your CPK contains no conventional `id` column, you are responsible for ensuring uniqueness, through application logic, UUIDs, etc.

Rails also supports declaring composite primary keys at the model level via [`self.primary_key`](https://api.rubyonrails.org/classes/ActiveRecord/AttributeMethods/PrimaryKey/ClassMethods.html) method:

```ruby
class Order < ApplicationRecord
  self.primary_key = [:store_id, :sku]
end
```

This tells Active Record that records are uniquely identified by the combination of both columns, not a single `id`.

In most cases, you don't need to declare a composite primary key with
`self.primary_key` in your model at all. If you define the CPK in your migration
and use the default `schema.rb` format, Rails will read the primary key from the
schema automatically at boot time and your model will work.

On the other hand, if your application uses `structure.sql` instead of `schema.rb` or if you're connecting to a legacy or external database that was not created by your migrations, you can use `self.primary_key` to explicitly declare a composite primary key.

Querying Models
---------------

### Using `#find`

If your table uses a composite primary key, you'll need to pass an array
when using `#find` to locate a record:

```irb
# Find the product with store_id 3 and sku "XYZ12345"
irb> product = Product.find([3, "XYZ12345"])
=> #<Product store_id: 3, sku: "XYZ12345", description: "Yellow socks">
```

The SQL equivalent of the above is:

```sql
SELECT * FROM products WHERE store_id = 3 AND sku = "XYZ12345"
```

To find multiple records with composite IDs, pass an array of arrays to `#find`:

```irb
# Find the products with primary keys [1, "ABC98765"] and [7, "ZZZ11111"]
irb> products = Product.find([[1, "ABC98765"], [7, "ZZZ11111"]])
=> [
  #<Product store_id: 1, sku: "ABC98765", description: "Red Hat">,
  #<Product store_id: 7, sku: "ZZZ11111", description: "Green Pants">
]
```

The SQL equivalent of the above is:

```sql
SELECT * FROM products WHERE (store_id = 1 AND sku = 'ABC98765' OR store_id = 7 AND sku = 'ZZZ11111')
```

Models with composite primary keys will also use the full composite primary key
when ordering:


```irb
irb> product = Product.first
=> #<Product store_id: 1, sku: "ABC98765", description: "Red Hat">
```

The SQL equivalent of the above is:

```sql
SELECT * FROM products ORDER BY products.store_id ASC, products.sku ASC LIMIT 1
```

### Using `#where`

Hash conditions for `#where` may be specified in a tuple-like syntax.
This can be useful for querying composite primary key relations:

```ruby
Product.where(Product.primary_key => [[1, "ABC98765"], [7, "ZZZ11111"]])
```

#### Conditions with `:id`

When specifying conditions on methods like `find_by` and `where`, the use
of `id` will match against an `:id` attribute on the model. This is different
from `find`, where the ID passed in should be a primary key value.

Take caution when using `find_by(id:)` on models where `:id` is not the primary
key, such as composite primary key models. See the [Active Record Querying](active_record_querying.html#conditions-with-id)
guide to learn more.

Associations between Models with Composite Primary Keys
-------------------------------------------------------

Rails can often infer the primary key-foreign key relationships between
associated models. However, when dealing with composite primary keys, Rails
typically defaults to using only part of the composite key, usually the `id`
column, unless explicitly instructed otherwise. This default behavior only works
if the model's composite primary key contains the `:id` column, _and_ the column
is unique for all records.

Consider the following example:

```ruby
class Order < ApplicationRecord
  self.primary_key = [:shop_id, :id]
  has_many :books
end

class Book < ApplicationRecord
  belongs_to :order
end
```

In this setup, `Order` has a composite primary key consisting of `[:shop_id,
:id]`, and `Book` belongs to `Order`. Rails will assume that the `:id` column
should be used as the primary key for the association between an order and its
books. It will infer that the foreign key column on the books table is
`:order_id`.

Below we create an `Order` and a `Book` associated with it:

```ruby
order = Order.create!(id: [1, 2], status: "pending")
book = order.books.create!(title: "A Cool Book")
```

To access the book's order, we reload the association:

```ruby
book.reload.order
```

When doing so, Rails will generate the following SQL to access the order:

```sql
SELECT * FROM orders WHERE id = 2
```

You can see that Rails uses the order's `id` in its query, rather than both the
`shop_id` and the `id`. In this case, the `id` is sufficient because the model's
composite primary key does in fact contain the `:id` column, _and_ the column is
unique for all records.

However, if the above requirements are not met or you would like to use the full
composite primary key in associations, you can set the `foreign_key:` option on
the association. This option specifies a composite foreign key on the
association; all columns in the foreign key will be used when querying the
associated record(s). For example:

```ruby
class Author < ApplicationRecord
  self.primary_key = [:first_name, :last_name]
  has_many :books, foreign_key: [:first_name, :last_name]
end

class Book < ApplicationRecord
  belongs_to :author, foreign_key: [:author_first_name, :author_last_name]
end
```

In this setup, `Author` has a composite primary key consisting of `[:first_name,
:last_name]`, and `Book` belongs to `Author` with a composite foreign key
`[:author_first_name, :author_last_name]`.

Create an `Author` and a `Book` associated with it:

```ruby
author = Author.create!(first_name: "Jane", last_name: "Doe")
book = author.books.create!(title: "A Cool Book", author_first_name: "Jane", author_last_name: "Doe")
```

To access the book's author, we reload the association:

```ruby
book.reload.author
```

Rails will now use the `:first_name` _and_ `:last_name` from the composite
primary key in the SQL query:

```sql
SELECT * FROM authors WHERE first_name = 'Jane' AND last_name = 'Doe'
```

Forms
-----

Forms may also be built for composite primary key models.
See the [Form Helpers][] guide for more information on the form builder syntax.

[Form Helpers]: form_helpers.html

Given a `@book` model object with a composite key `[:author_id, :id]`:

```ruby
@book = Book.find([2, 25])
# => #<Book id: 25, title: "Some book", author_id: 2>
```

The following form:

```erb
<%= form_with model: @book do |form| %>
  <%= form.text_field :title %>
  <%= form.submit %>
<% end %>
```

Outputs:

```html
<form action="/books/2_25" method="post" accept-charset="UTF-8" >
  <input name="authenticity_token" type="hidden" value="..." />
  <input type="text" name="book[title]" id="book_title" value="My book" />
  <input type="submit" name="commit" value="Update Book" data-disable-with="Update Book">
</form>
```

Note the generated URL contains the `author_id` and `id` delimited by an
underscore. Once submitted, the controller can extract primary key values from
the parameters and update the record. See the next section for more details.

Controller Parameters
---------------------

Composite key parameters contain multiple values in one parameter.
For this reason, we need to be able to extract each value and pass them to
Active Record. We can leverage the `extract_value` method for this use-case.

Given the following controller:

```ruby
class BooksController < ApplicationController
  def show
    # Extract the composite ID value from URL parameters.
    id = params.extract_value(:id)
    # Find the book using the composite ID.
    @book = Book.find(id)
    # use the default rendering behavior to render the show view.
  end
end
```

And the following route:

```ruby
get "/books/:id", to: "books#show"
```

When a user opens the URL `/books/4_2`, the controller will extract the
composite key value `["4", "2"]` and pass it to `Book.find` to render the right
record in the view. The `extract_value` method may be used to extract arrays
out of any delimited parameters.

Fixtures
--------

Fixtures for composite primary key tables are fairly similar to normal tables.
When using an id column, the column may be omitted as usual:

```ruby
class Book < ApplicationRecord
  self.primary_key = [:author_id, :id]
  belongs_to :author
end
```

```yml
# books.yml
alices_adventure_in_wonderland:
  author_id: <%= ActiveRecord::FixtureSet.identify(:lewis_carroll) %>
  title: "Alice's Adventures in Wonderland"
```

However, in order to support composite primary key relationships,
you must use the `composite_identify` method:

```ruby
class BookOrder < ApplicationRecord
  self.primary_key = [:shop_id, :id]
  belongs_to :order, foreign_key: [:shop_id, :order_id]
  belongs_to :book, foreign_key: [:author_id, :book_id]
end
```

```yml
# book_orders.yml
alices_adventure_in_wonderland_in_books:
  author: lewis_carroll
  book_id: <%= ActiveRecord::FixtureSet.composite_identify(
              :alices_adventure_in_wonderland, Book.primary_key)[:id] %>
  shop: book_store
  order_id: <%= ActiveRecord::FixtureSet.composite_identify(
              :books, Order.primary_key)[:id] %>
```
