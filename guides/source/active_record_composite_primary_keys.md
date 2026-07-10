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

Composite primary keys (CPK) are designed to allow two or more columns to act as
the unique identifier for a row in a database table. This is useful when a
single column's value isn't enough to uniquely identify every row of a table.
This can occur with legacy database schemas that lack a single `id` primary key,
or in applications where the schema has been designed to partition data across
[multiple databases (sharding)](active_record_multiple_databases.html) or
isolate data per customer or tenant (multitenancy). Composite primary keys is an
Active Record feature that spans migrations, query methods, and associations.

NOTE: Composite primary keys do increase complexity and can be slower than a
single primary key column. Ensure your use case requires a composite primary key
before using one.

### Using `query_constraints` as an Alternative

In cases where your table has a conventional `id` column but you want Active Record to scope queries using an additional column, you can use [`query_constraints`](https://api.rubyonrails.org/classes/ActiveRecord/Persistence/ClassMethods.html#method-i-query_constraints) instead of redefining the primary key entirely. For example:

```ruby
class Developer < ActiveRecord::Base
  query_constraints :company_id, :id
end
```

This keeps `id` as the primary key at the database level while instructing Active Record to always include `company_id` in queries, updates, and deletes for `Developers`.

For example, given a developer record with `company_id: 5`:

```irb
irb> developer = Developer.find_by(company_id: 5, name: "Alice")
=> #<Developer id: 1, company_id: 5, name: "Alice">
```

With `query_constraints`, any subsequent query or update on that record will automatically include `company_id` as well:

```irb
irb> developer.update!(name: "Bob")
```

```sql
UPDATE developers SET name = 'Bob' WHERE company_id = 5 AND id = 1
```

Without `query_constraints`, that same update would only scope on `id`:

```sql
UPDATE developers SET name = 'Bob' WHERE id = 1
```

Query Constraints is a lighter weight option when you don't need a true composite primary key but want Rails to treat a combination of columns as the effective identity when querying.


Declaring Composite Primary Keys and Creating Migrations
--------------------------------------------------------

To create a table with a composite primary key, you can pass an array to the `primary_key:` option in the database migration:

```ruby
class CreateProducts < ActiveRecord::Migration[8.2]
  def change
    create_table :products, primary_key: [:store_id, :sku] do |t|
      t.references :store, null: false, foreign_key: true
      t.string :sku, null: false
      t.text :description
      t.timestamps
    end
  end
end
```

After running the migration above, your `schema.rb` file reflects the composite key:

```ruby
# db/schema.rb
create_table "products", primary_key: [:store_id, :sku], force: :cascade do |t|
  t.bigint "store_id", null: false
  t.string "sku", null: false
  t.text "description"
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false
end

add_foreign_key "products", "stores", column: "store_id", primary_key: "id"
```

When using a composite primary key, uniqueness is enforced by the combination of columns rather than a single auto-incrementing `id`. In the above example, `store_id` is a foreign key to a `stores` table, and `sku` would be a string the application provides (like "ABC-123"). Neither needs to be auto-generated, their combination is what's unique.

NOTE: If your composite primary key contains no conventional `id` column, you are responsible for ensuring uniqueness, through application logic, UUIDs, etc.

Rails also supports declaring composite primary keys at the model level via [`self.primary_key`](https://api.rubyonrails.org/classes/ActiveRecord/AttributeMethods/PrimaryKey/ClassMethods.html) method:

```ruby
class Order < ApplicationRecord
  self.primary_key = [:store_id, :sku]
end
```

This tells Active Record that records are uniquely identified by the combination of both columns, not a single `id`.

In most cases, you don't need to declare this at all. Rails detects the primary
key automatically from the database at runtime. So as long as your migration has
been run, your model will have the composite primary key. You only need
`self.primary_key` if you're connecting to a legacy or external database where
Rails fails to detect the composite primary key correctly, or if you need to
override what the database reports for some other reason.

Querying Models
---------------

### Using `find`

If your table uses a composite primary key, you'll need to pass an array
when using `find` to locate a record. For example, to find the product with `store_id` 3 and `sku` "XYZ12345":

```irb
irb> product = Product.find([3, "XYZ12345"])
=> #<Product store_id: 3, sku: "XYZ12345", description: "Yellow socks">
```

The above Active Record method results in the following SQL:

```sql
SELECT * FROM products WHERE store_id = 3 AND sku = "XYZ12345"
```

NOTE: The `find` method expects the values in the same order as the columns were declared in `primary_key` when querying with composite primary key. Also, if only one value is provided, such as `Product.find(3)`, then Rails raises an `ActiveRecord::RecordNotFound` error.

To find multiple records with composite IDs, you can pass an array of arrays to `find`. For example, to find the products with primary keys [1, "ABC98765"] and [7, "ZZZ11111"]

```irb
irb> products = Product.find([[1, "ABC98765"], [7, "ZZZ11111"]])
=> [
  #<Product store_id: 1, sku: "ABC98765", description: "Red Hat">,
  #<Product store_id: 7, sku: "ZZZ11111", description: "Green Pants">
]
```

The above Active Record method results in the following SQL:

```sql
SELECT * FROM products WHERE ((store_id = 1 AND sku = 'ABC98765') OR (store_id = 7 AND sku = 'ZZZ11111'))
```

Models with composite primary keys will also use the full composite primary key
when ordering:


```irb
irb> product = Product.first
=> #<Product store_id: 1, sku: "ABC98765", description: "Red Hat">
```

The above Active Record method results in the following SQL:

```sql
SELECT * FROM products ORDER BY products.store_id ASC, products.sku ASC LIMIT 1
```

### Using `where`

Hash conditions for `where` can query against multiple composite key values at once by passing an array of value pairs as well:

```ruby
Product.where(Product.primary_key => [[1, "ABC98765"], [7, "ZZZ11111"]])
```

This returns all products matching either `[store_id: 1, sku: "ABC98765"]` or `[store_id: 7, sku: "ZZZ11111"]`.

This generates the following SQL:

```sql
SELECT * FROM products WHERE (store_id = 1 AND sku = 'ABC98765' OR store_id = 7 AND sku = 'ZZZ11111')
```

WARNING: When using  `where` or `find_by`, the key `id` matches against an `:id` attribute on the model only (if the model has one). It does not resolve to the full composite primary key the way `find` does. Use `find` when you want to look up a record by its full composite primary key. See the [Active Record Querying](active_record_querying.html#conditions-with-id) guide for more detail.

Associations between Models with Composite Primary Keys
-------------------------------------------------------

Rails can generally infer the primary key to foreign key relationships between associated models. However, when using composite primary keys, Rails typically defaults to using only part of the composite key (usually the `id` column) unless explicitly instructed otherwise. This default behavior only works if the model's composite primary key contains the `:id` column *and* that column is unique for all records.

Consider the following example:

```ruby
class Order < ApplicationRecord
  self.primary_key = [:store_id, :id]
  has_many :books
end

class Book < ApplicationRecord
  belongs_to :order
end
```

The composite primary key for `Order` is `[:store_id, :id]` but Rails will take just the `:id` column as the primary key for the association, making `order_id` the foreign key on `Book`.

Below we create an `Order` and a `Book` associated with it:

```ruby
order = Order.create!(id: [1, 2], status: "pending")
book = order.books.create!(title: "A Cool Book")
book.reload.order
```

For the last line, Rails generates the following SQL to access the `order`:

```sql
SELECT * FROM orders WHERE id = 2
```

NOTE: When `id` is part of a composite primary key, Active Record's `id` accessor refers to the *entire* composite key rather than the individual `id` column. You assign it as `id: [1, 2]` which maps to `store_id: 1` and `id: 2`. Attempting to assign the `id` to a single value (`Order.create!(store_id: 1, id: 2)`) results in a `TypeError`, which can be a bit surprising.

NOTE: We use `reload` above because we want to see the SQL. Without it,
`book.order` returns the cached version without querying the database, so no SQL
is generated.

You can see that Rails uses the order's `id` in its query, rather than both the `store_id` and the `id`. In this case, the `id` is sufficient because the model's composite primary key does in fact contain the `id` column, *and* the column is unique for all records.

However, if the above requirement is not met, you can explicitly set the `foreign_key` option on the association. Then, all columns specified in the foreign key will be used when querying the associated records.

For example, consider an `Author` model whose composite primary key contains no `:id` column at all:

```ruby
class Author < ApplicationRecord
  self.primary_key = [:first_name, :last_name]
  has_many :books, foreign_key: [:author_first_name, :author_last_name]
end

class Book < ApplicationRecord
  belongs_to :author, foreign_key: [:author_first_name, :author_last_name]
end
```

In this setup, `Book` belongs to `Author` and the a composite foreign key is specified as `[:author_first_name, :author_last_name]`.

Create an `Author` and a `Book` associated with it:

```ruby
author = Author.create!(first_name: "Jane", last_name: "Doe")
book = author.books.create!(title: "A Cool Book")
book.reload.author
```

Rails will now use both `first_name` and `last_name` from the composite primary key in the SQL query for `Author`:

```sql
SELECT * FROM authors WHERE first_name = 'Jane' AND last_name = 'Doe'
```

Forms and Controller Parameters
-------------------------------

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
the parameters and update the record.

### Extracting Composite Primary Key from `params`

Composite key parameters contain multiple values in one parameter.
For this reason, we need to be able to extract each value and pass them to
Active Record. We can leverage the [`extract_value`](https://api.rubyonrails.org/classes/ActionController/Parameters.html#method-i-extract_value) method for this use-case.

Given the following controller:

```ruby
class BooksController < ApplicationController
  def show
    # Extract the composite ID value from URL parameters.
    id = params.extract_value(:id)
    # Find the book using the composite ID.
    @book = Book.find(id)
    # ...
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

Fixtures for composite primary key tables are similar to normal tables.
When using an `id` column, the column may be omitted as usual:

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
  self.primary_key = [:store_id, :id]
  belongs_to :order, foreign_key: [:store_id, :order_id]
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

Performance and Indexing
------------------------

### Column Order Matters

A composite primary key creates a database index on its columns in the order they are declared. A CPK of `[:store_id, :sku]` means the database can efficiently use that index for queries filtering on `store_id` alone, or `store_id` and `sku` together, but not `sku` alone. The leading column should be the one you filter on most frequently. In a multi-tenant application, placing the tenant identifier first (e.g. `store_id`) makes sense, since almost every query will be scoped to a store.

### Index Foreign Key Columns Manually

When another table references a composite primary key, the foreign key columns on that table need their own index. Unlike single column foreign keys, Rails does not add these automatically. Without an explicit index, any join or association query back to the parent table will result in a full table scan.

You can add the index manually in your migration:

```ruby
add_index :books, [:order_store_id, :order_number]
```
