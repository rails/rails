**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Caching with Rails
==================

This guide is an introduction to speeding up your Rails application with
caching.

After reading this guide, you will know:

* What caching is.
* The types of caching strategies.
* How to manage cache dependencies.
* How to configure Solid Cache and other cache stores.

--------------------------------------------------------------------------------

What is Caching?
----------------

Caching means storing content generated during the request-response cycle and
reusing it when responding to similar requests. It avoids doing an expensive
operation more than once - think of it like saving the result of something
expensive so you can look it up later instead of recomputing it.

Caching is one of the most effective ways to boost an application's performance.
It allows websites running on modest infrastructure, a single server with a
single database, to sustain thousands of concurrent users.

Rails provides a set of caching features out of the box which allows you to not
only cache data, but also to tackle challenges like cache expiration, cache
dependencies, and cache invalidation.


Setup
-----

By default, [Action Controller
Caching](https://api.rubyonrails.org/classes/ActionController/Caching.html) is
enabled only in the production environment. However, you can play around with
caching locally by running `bin/rails dev:cache`, or by setting
[`config.action_controller.perform_caching`][] to `true` in
`config/environments/development.rb`.

```bash
$ bin/rails dev:cache
Development mode is now being cached.
$ bin/rails dev:cache
Development mode is no longer being cached.
```

NOTE: Changing the value of `config.action_controller.perform_caching` only
affects caching provided by Action Controller. It will not impact [low-level
caching](#low-level-caching-using-rails-cache).

By default, new Rails applications use
[`:memory_store`](#activesupport-cache-memorystore) as the cache store in
development. If you want to use Solid Cache in development, set the
`cache_store` configuration in `config/environments/development.rb`:

```ruby
config.cache_store = :solid_cache_store
```

and make sure the `cache` database is configured, created, and migrated:

```yaml
development:
  primary:
    <<: *default
    database: storage/development.sqlite3
  cache:
    <<: *default
    database: storage/development_cache.sqlite3
    migrations_paths: db/cache_migrate
```

After configuring the database, run `bin/rails db:prepare` so the cache tables
are created.

TIP: To disable caching set `cache_store` to
[`:null_store`](#activesupport-cache-nullstore)

[`config.action_controller.perform_caching`]:
    configuring.html#config-action-controller-perform-caching

Types of Caching
----------------

Rails provides several different caching strategies to suit different needs and
use cases. Each approach has its own benefits and is useful in different
scenarios.

### Low-Level Caching using `Rails.cache`

Rails' low-level caching mechanism, accessed with `Rails.cache`, stores
serializable values such as API responses, computed values, and expensive query
results. This lets you cache individual pieces of data without caching an entire
view.

`Rails.cache.fetch` handles both _reading from_ and _writing to_ the cache. When
called with a single argument, it fetches and returns the cached value for the
given key. If a block is passed, the block is executed only on a cache miss. The
block's return value is written to the cache under the given cache key and
returned. In case of cache hit, the cached value is returned directly without
executing the block.

For example:

```ruby
# Fetch a value with a block to set a default if it doesn’t exist
welcome_message = Rails.cache.fetch("welcome_message") { "Welcome to Rails!" }
puts welcome_message # Output: Welcome to Rails!
```

INFO: A cache hit means Rails found an existing value in the cache and could
reuse it. A cache miss means the value was not in the cache yet, so Rails had to
generate it and store it. Cache misses are normal, especially when an entry
expires, the cache is cleared, or a key is used for the first time.

For more advanced use cases, `Rails.cache.fetch` also accepts options such as
`race_condition_ttl`, which can help prevent a cache stampede by briefly reusing
a recently expired entry while one process rebuilds it. The full set of options
is documented in
[`ActiveSupport::Cache::Store`](https://api.rubyonrails.org/classes/ActiveSupport/Cache/Store.html).

Alternatively, you can specify whether you want to read or write from the cache
using `Rails.cache.read` and `Rails.cache.write`. You can delete a key using
`Rails.cache.delete`.

```ruby
# Store a value in the cache
Rails.cache.write("greeting", "Hello, world!")

# Retrieve the value from the cache
greeting = Rails.cache.read("greeting")
puts greeting # Output: Hello, world!

# Fetch a value with a block to set a default if it doesn’t exist
welcome_message = Rails.cache.fetch("welcome_message") { "Welcome to Rails!" }
puts welcome_message # Output: Welcome to Rails!

# Delete a value from the cache
Rails.cache.delete("greeting")
```

If you need to remove everything from the current cache store, you can call
`Rails.cache.clear`. This is most useful in development or when you explicitly
want to reset the cache. In production, clearing the entire cache can cause a
sudden increase in work while entries are rebuilt.

You can use Hashes and Arrays of values as cache keys.

```ruby
# This is a valid cache key
Rails.cache.read(site: "mysite", owners: [owner_1, owner_2])
```

Cache keys can be any object that responds to `cache_key` or `to_param`. If you
need custom keys, you can implement `cache_key` on your own classes. Active
Record models already generate cache keys based on the model name and record ID.

Consider the following example. An application has a `Product` model with an
instance method that looks up the product's price on a competitor's website. The
data returned by this method would be a good fit for low-level caching:

```ruby
class Product < ApplicationRecord
  def competing_price
    Rails.cache.fetch("#{cache_key_with_version}/competing_price", expires_in: 12.hours) do
      Competitor::API.find_price(id)
    end
  end
end
```

Notice that in the example above we used the `cache_key_with_version` method, so
the resulting cache key will be something like
`products/233-20140225082222765838000/competing_price`. `cache_key_with_version`
generates a string based on the model's class name, `id`, and `updated_at`
attributes, in the form `<model class name>/<resource id>-<resource
updated_at>`. This is a common convention and has the benefit of invalidating
the cache whenever the product is updated.

INFO: The keys you use on `Rails.cache` will not be the same as those actually
used with the storage engine. They may be modified with a namespace or altered
to fit technology backend constraints. This means, for instance, that you can't
save values with `Rails.cache` and then try to pull them out with the
[`dalli`](https://github.com/petergoldstein/dalli) gem. However, you also don't
need to worry about exceeding the memcached size limit or violating syntax
rules.

#### Avoid Caching Instances of Active Record Objects

You should __avoid__ storing a list of Active Record objects in the cache:

```ruby
# super_admins is an expensive SQL query, so don't run it too often
Rails.cache.fetch("super_admin_users", expires_in: 12.hours) do
  User.super_admins.to_a
end
```

In the example above, the instance of the `User`, representing `superusers`,
could change, and the attributes on it could differ, or the record could be
deleted. In development, this also works unreliably with cache stores that
reload code when you make changes.

Instead, cache the ID of the resource or some other primitive data type. For
example:

```ruby
ids = Rails.cache.fetch("super_admin_user_ids", expires_in: 12.hours) do
  User.super_admins.pluck(:id)
end
User.where(id: ids).to_a
```

### Fragment Caching

Dynamic web applications build pages with a variety of components not all of
which have the same caching characteristics. For example, a static component,
such as a site logo, will have a longer caching duration compared to other more
dynamic components. To cache and expire different parts of the page separately
you can use Fragment Caching.

Fragment Caching allows a fragment of view logic to be wrapped in a cache block
and served out of the cache store when the next request comes in.

For example, if you wanted to cache each product on a page, you could do the
following:

```html+erb
<% @products.each do |product| %>
  <% cache product do %>
    <%= render product %>
  <% end %>
<% end %>
```

When your application receives its first request to this page, Rails will write
a new cache entry with a unique key. The key looks something like this:

```
views/products/index:bea67108094918eeba42cd4a6e786901/products/1
```

The string of characters in the middle is a template tree digest. It is a hash
computed from the contents of the view fragment you are caching. If you change
that fragment, such as by updating the HTML, the digest changes and Rails will
treat it as a different cache entry.

A cache version, derived from the product record, is stored in the cache entry.
When the product is touched, the cache version changes, and any cached fragments
that contain the previous version are ignored.

Separating the cache key from the cache version allows Rails to reuse the cache
key, instead of creating a new entry every time. No matter how frequently the
product is touched, Rails writes to the same cache key. This reduces the total
cache size because outdated cache entries are overwritten with the new entry.

TIP: Cache stores like [Memcached](https://memcached.org) automatically evict
old cache entries when they need to reclaim space.

If you want to cache a fragment under certain conditions, you can use `cache_if`
or `cache_unless`:

```erb
<% cache_if admin?, product do %>
  <%= render product %>
<% end %>
```

#### Collection Caching

The `render` helper can also cache each template in a collection. Instead of
checking the cache one item at a time in an `each` loop, Rails can fetch the
cached entries for the whole collection at once. You enable this by passing
`cached: true` when rendering the collection:

```html+erb
<%= render partial: 'products/product', collection: @products, cached: true %>
```

Cached entries from previous renders will be read in a single multi-fetch.
Templates that are not yet cached will be rendered and written to the cache, so
they can be fetched the same way on the next render.

The cache key can be configured. In the example below, it is prefixed with the
current locale to ensure that different localizations of the product page do not
overwrite each other:

```html+erb
<%= render partial: 'products/product',
           collection: @products,
           cached: ->(product) { [I18n.locale, product] } %>
```

You can also configure `cached` with an options hash that accepts `expires_in`
and `key`, so you can control the cache key and expiration explicitly.

```html+erb
<%= render partial: 'products/product',
           collection: @products,
           cached: { expires_in: 1.hour, key: ->(product) { [I18n.locale, product] } } %>
```

#### Managing Dependencies

When using fragment caching, you need to define template dependencies so Rails
can invalidate cached fragments correctly. Rails can infer many common cases,
but when rendering happens in helpers or through less direct `render` calls, you
may need to declare dependencies explicitly.

##### Implicit Dependencies

Rails can infer many template dependencies directly from `render` calls in the
template. For example, the
[`ActionView::Digestor`](https://api.rubyonrails.org/classes/ActionView/Digestor.html)
can understand calls like these:

```ruby
render partial: "comments/comment", collection: commentable.comments
render "comments/comments"
render("comments/comments")

render "header" # translates to render("comments/header")

render(@topic)         # translates to render("topics/topic")
render(topics)         # translates to render("topics/topic")
render(message.topics) # translates to render("topics/topic")
```

Some render calls need more information before Rails can infer the template
dependency. For example, when you pass a custom collection like this:

```ruby
render @project.documents.where(published: true)
```

You'll need to rewrite it to name the partial and collection explicitly:

```ruby
render partial: "documents/document", collection: @project.documents.where(published: true)
```

##### Explicit Dependencies

Sometimes Rails cannot see a template dependency on its own. This usually
happens when the `render` call is hidden inside a helper method.

```html+erb
<%= render_sortable_todolists @project.todolists %>
```

In that case, declare the dependency explicitly with a special comment:

```html+erb
<%# Template Dependency: todolists/todolist %>
<%= render_sortable_todolists @project.todolists %>
```

In some cases, such as a [single table
inheritance](association_basics.html#single-table-inheritance) setup, a helper
may render different partials from the same directory. Instead of listing each
template individually, you can use a wildcard to match the whole directory:

```html+erb
<%# Template Dependency: events/* %>
<%= render_categorizable_events @person.events %>
```

There is also a special comment for collection caching when the cache call is
hidden inside a helper. If the partial template does not start with a clean
cache call, you can add this comment anywhere in the template:

```html+erb
<%# Template Collection: notification %>
<% my_helper_that_calls_cache(some_arg, notification) do %>
  <%= notification.name %>
<% end %>
```

##### External Dependencies

Changes outside the template file can also affect the cached output. For
example, if a cached block calls a helper method, updating that helper will not
change the template digest automatically.

When that happens, update the template in some way so its digest changes too.
One simple approach is to add or update a comment like this:

```html+erb
<%# Helper Dependency Updated: Jul 28, 2015 at 7pm %>
<%= some_helper_method(person) %>
```

### Russian Doll Caching

You may want to nest cached fragments inside other cached fragments. This is
called Russian doll caching.

The advantage of Russian doll caching is that if a single product is updated,
all the other inner fragments can be reused when regenerating the outer
fragment.

As explained in the previous section, a cached fragment will become stale if the
`updated_at` value changes for a record it directly depends on. However, that
does not automatically expire any outer fragment that contains it.

For example, take the following view:

```erb
<% cache product do %>
  <%= render product.reviews %>
<% end %>
```

Which in turn renders this view:

```erb
<% cache review do %>
  <%= render review %>
<% end %>
```

If a `review` changes, its `updated_at` value changes too, which expires that
fragment. But the `product` record's `updated_at` does not change automatically,
so the outer fragment can still serve stale data. To fix this, tie the models
together with the `touch` method:

```ruby
class Product < ApplicationRecord
  has_many :reviews
end

class Review < ApplicationRecord
  belongs_to :product, touch: true
end
```

With `touch` set to `true`, any action which changes `updated_at` for a review
record will also change it for the associated product, thereby expiring the
cache.

### Shared Partial Caching

You can share partials, and their cached output, across templates with different
[MIME
types](https://developer.mozilla.org/en-US/docs/Web/HTTP/Basics_of_HTTP/MIME_types).
For example, the same partial can be reused from both HTML and JavaScript
templates. When Rails resolves `render partial:`, it can use a partial without
an explicit format in more than one response format. Both HTML and JavaScript
requests can use the following code:

```ruby
render(partial: "hotels/hotel", collection: @hotels, cached: true)
```

This will load a file named `hotels/_hotel.html.erb`.

Another option is to specify the `formats` option explicitly.

```ruby
render(partial: "hotels/hotel", collection: @hotels, formats: :html, cached: true)
```

This will load `hotels/_hotel.html.erb` even when it is rendered from a template
with a different MIME type, such as a JavaScript template.

### Conditional GETs

Conditional GETs let a server tell the browser that a response has not changed
since the last request, so the browser can reuse its cached copy.

This is useful when a browser or intermediary cache may already have a recent
copy of a response and you want to avoid sending the full response body again.

They work with the `If-None-Match` and `If-Modified-Since` request headers,
using an [ETag](#strong-vs-weak-etags) and/or a last-modified timestamp to check
whether the response is still fresh. If the browser's copy matches the server's
version, the server can return `304 Not Modified` with no response body.

It is the server's responsibility to evaluate those headers and decide whether
to send a full response. Rails makes this straightforward:

```ruby
class ProductsController < ApplicationController
  def show
    @product = Product.find(params[:id])

    # If the request is stale according to the given timestamp and etag value
    # (i.e. it needs to be processed again) then execute this block
    if stale?(last_modified: @product.updated_at.utc, etag: @product.cache_key_with_version)
      respond_to do |wants|
        # ... normal response processing
      end
    end

    # If the request is fresh (i.e. it's not modified) then you don't need to do
    # anything. The default render checks for this using the parameters
    # used in the previous call to stale? and will automatically send a
    # :not_modified. So that's it, you're done.
  end
end
```

Instead of an options hash, you can also simply pass in a model. Rails will use
the `updated_at` and `cache_key_with_version` methods for setting
`last_modified` and `etag`:

```ruby
class ProductsController < ApplicationController
  def show
    @product = Product.find(params[:id])

    if stale?(@product)
      respond_to do |wants|
        # ... normal response processing
      end
    end
  end
end
```

If you don't have any special response processing and are using the default
rendering mechanism (i.e. you're not using `respond_to` or calling render
yourself) then you've got an easy helper in `fresh_when`:

```ruby
class ProductsController < ApplicationController
  # This will automatically send back a :not_modified if the request is fresh,
  # and will render the default template (product.*) if it's stale.

  def show
    @product = Product.find(params[:id])
    fresh_when last_modified: @product.published_at.utc, etag: @product
  end
end
```

Instead of an options hash, you can also pass in a model. Rails will use the
`updated_at` and `cache_key_with_version` methods for setting `last_modified`
and `etag`:

```ruby
class ProductsController < ApplicationController
  def show
    @product = Product.find(params[:id])
    fresh_when @product
  end
end
```

When both `last_modified` and `etag` are set, the behavior depends on
`config.action_dispatch.strict_freshness`. If it is `true`, only the `etag` is
considered, as specified by RFC 7232 section 6. If it is `false`, both headers
are checked and the response is considered fresh only if they both match.

#### Strong vs. Weak ETags

An ETag is a token (often a hash) that uniquely represents a particular version
of a response body. If the server sends an ETag, the browser can later send it
back to ask "is this still the same?" without fetching the full response.

Rails generates weak ETags by default. Weak ETags allow semantically equivalent
responses to share the same ETag even if their response bodies do not match
byte-for-byte. This can be useful when minor representation differences occur
that do not change the meaning of the response, such as insignificant whitespace
or formatting changes.

Weak ETags have a leading `W/` to differentiate them from strong ETags.

```
W/"618bbc92e2d35ea1945008b42799b0e7" -> Weak ETag
"618bbc92e2d35ea1945008b42799b0e7" -> Strong ETag
```

Unlike weak ETags, a strong ETag means the response body must match exactly,
byte for byte. This is useful for `Range` requests on large files such as videos
or PDFs. Some CDNs also require strong ETags. If you need to generate a strong
ETag, you can do so as follows:

```ruby
class ProductsController < ApplicationController
  def show
    @product = Product.find(params[:id])
    fresh_when last_modified: @product.published_at.utc, strong_etag: @product
  end
end
```

You can also set the strong ETag directly on the response.

```ruby
response.strong_etag = response.body # => "618bbc92e2d35ea1945008b42799b0e7"
```

Sometimes you want to cache a response that effectively never changes, such as a
static page. In that case, you can use the `http_cache_forever` helper so
browsers and proxies cache it for a very long time.

By default cached responses will be private, cached only on the user's web
browser. To allow proxies to cache the response, set `public: true` to indicate
that they can serve the cached response to all users.

This helper sets `last_modified` to `Time.new(2011, 1, 1).utc` and applies a
very long `Cache-Control` lifetime.

WARNING: Use this method carefully. Browsers and proxies will keep reusing the
response until it changes at a different URL or the cache is cleared.

```ruby
class HomeController < ApplicationController
  def index
    http_cache_forever(public: true) do
      render
    end
  end
end
```

### SQL Caching

Query caching is an Active Record feature that caches the result set returned by
each query. If the same query runs again during the same request or execution
context, Active Record can reuse the stored result instead of asking the
database again.

For example:

```ruby
class ProductsController < ApplicationController
  def index
    # Run a find query
    @products = Product.all

    # ...

    # Run the same query again
    @products = Product.all
  end
end
```

The second time the same query runs, it does not hit the database. Active Record
reads the cached result from memory instead. However, each retrieval still
instantiates new model objects from that cached result.

NOTE: Query caches are created at the start of an action and destroyed at the
end of that action, so they persist only for the duration of the request. If
you'd like to store query results in a more persistent fashion, use low-level
caching.

Default Store: Solid Cache
--------------------------

Solid Cache is a database-backed Active Support cache store. It is the default
cache store for new Rails applications. Solid Cache is a good fit when you want
a larger, more durable cache without running a separate cache service such as
Redis or Memcached.

Solid Cache uses a FIFO (First In, First Out) caching strategy, where the first
item added to the cache is the first one to be removed when the cache reaches
its limit. This approach is simpler but less efficient compared to an LRU (Least
Recently Used) cache, which removes the least recently accessed items first,
better optimizing for frequently used data. However, Solid Cache compensates for
the lower efficiency of FIFO by allowing the cache to live longer, reducing the
frequency of invalidations.

New Rails applications generated with Rails 8.0 and later include Solid Cache by
default. However, if you'd prefer not to use it, you can skip Solid Cache:

```bash
$ bin/rails new app_name --skip-solid
```

NOTE: Using the `--skip-solid` flag skips all parts of the Solid Trifecta (Solid
Cache, Solid Queue, and Solid Cable). If you still want to use some of them, you
can install them separately. For example, if you want to use Solid Queue and
Solid Cable but not Solid Cache, you can follow the installation guides for
[Solid Queue](https://github.com/rails/solid_queue#installation) and [Solid
Cable](https://github.com/rails/solid_cable#installation).

### Configuring the Database

To use Solid Cache, you can configure the database connection in your
`config/database.yml` file. Here's an example configuration for a SQLite
database:

```yaml
production:
  primary:
    <<: *default
    database: storage/production.sqlite3
  cache:
    <<: *default
    database: storage/production_cache.sqlite3
    migrations_paths: db/cache_migrate
```

In this configuration, the `cache` database is used to store cached data. You
can also specify a different database adapter, like MySQL or PostgreSQL, if you
prefer.

```yaml
production:
  primary: &primary_production
    <<: *default
    database: app_production
    username: app
    password: <%= ENV["APP_DATABASE_PASSWORD"] %>
  cache:
    <<: *primary_production
    database: app_production_cache
    migrations_paths: db/cache_migrate
```

If `database` or [`databases`](#sharding-the-cache) is not specified in the
cache configuration, Solid Cache uses the `ActiveRecord::Base` connection pool.
That means cache reads and writes participate in any surrounding database
transaction.

To use Solid Cache as your cache store, configure the environment accordingly:

```ruby
# config/environments/production.rb
config.cache_store = :solid_cache_store
```

You can [access the cache by calling
`Rails.cache`](#low-level-caching-using-rails-cache).


### Customizing the Cache Store

Solid Cache can be customized through `config/cache.yml`:

```yaml
default: &default
  store_options:
    # Cap age of oldest cache entry to fulfill retention policies
    max_age: <%= 60.days.to_i %>
    max_size: <%= 256.megabytes %>
    namespace: <%= Rails.env %>
```

For the full list of keys under `store_options`, see [Cache
configuration](https://github.com/rails/solid_cache#cache-configuration).

Here, you can adjust the `max_age` and `max_size` options to control the age and
size of the cache entries.

### Handling Cache Expiration

Solid Cache tracks cache writes by incrementing a counter with each write. When
the counter reaches 50% of the `expiry_batch_size` from the [Cache
configuration](https://github.com/rails/solid_cache#cache-configuration), a
background task is triggered to handle cache expiry. This approach ensures cache
records expire faster than they are written when the cache needs to shrink.

The background task only runs when there are writes, so the process stays idle
when the cache is not being updated. If you prefer to run the expiry process in
a background job instead of a thread, set `expiry_method` from the [Cache
configuration](https://github.com/rails/solid_cache#cache-configuration) to
`:job`.

### Sharding the Cache

If you need more scalability, Solid Cache supports sharding, splitting the cache
across multiple databases. This spreads the load, making your cache even more
powerful. To enable sharding, add multiple cache databases to your
`database.yml`:

```yaml
# config/database.yml
production:
  cache_shard1:
    database: cache1_production
    host: cache1-db
  cache_shard2:
    database: cache2_production
    host: cache2-db
  cache_shard3:
    database: cache3_production
    host: cache3-db
```

Additionally, you must specify the shards in the cache configuration:

```yaml
# config/cache.yml
production:
  databases: [cache_shard1, cache_shard2, cache_shard3]
```

### Encryption

Solid Cache supports encryption to protect sensitive data. To enable encryption,
set the `encrypt` value in your cache configuration:

```yaml
# config/cache.yml
production:
  encrypt: true
```

You will need to set up your application to use [Active Record
Encryption](active_record_encryption.html).

Other Cache Stores
------------------

Rails provides different stores for the cached data (with the exception of SQL
Caching).

### Configuration

You can set up a different cache store by setting the `config.cache_store`
configuration option. Other parameters can be passed as arguments to the cache
store's constructor:

```ruby
config.cache_store = :memory_store, { size: 64.megabytes }
```

Alternatively, you can set `ActionController::Base.cache_store` outside a
configuration block.

You can access the cache by calling `Rails.cache`.

#### Connection Pool Options

[`:mem_cache_store`](#activesupport-cache-memcachestore) and
[`:redis_cache_store`](#activesupport-cache-rediscachestore) are configured to
use connection pooling. This means that if you're using Puma, or another
threaded server, you can have multiple threads performing queries to the cache
store at the same time.

If you want to disable connection pooling, set the `:pool` option to `false`
when configuring the cache store:

```ruby
config.cache_store = :mem_cache_store, "cache.example.com", { pool: false }
```

You can also override default pool settings by providing individual options to
the `:pool` option:

```ruby
config.cache_store = :mem_cache_store, "cache.example.com", { pool: { size: 32, timeout: 1 } }
```

* `:size` - This option sets the number of connections per process (defaults to
  5).

* `:timeout` - This option sets the number of seconds to wait for a connection
  (defaults to 5). If no connection is available within the timeout, a
  `Timeout::Error` will be raised.

### `ActiveSupport::Cache::Store`

[`ActiveSupport::Cache::Store`][] provides the foundation for interacting with
the cache in Rails. This is an abstract class, and you cannot use it on its own.
Instead, you must use a concrete implementation of the class tied to a storage
engine. Rails ships with several implementations, documented below.

The main API methods are [`read`][ActiveSupport::Cache::Store#read],
[`write`][ActiveSupport::Cache::Store#write],
[`delete`][ActiveSupport::Cache::Store#delete],
[`exist?`][ActiveSupport::Cache::Store#exist?], and
[`fetch`][ActiveSupport::Cache::Store#fetch].

Options passed to the cache store's constructor will be treated as default
options for the appropriate API methods.

[`ActiveSupport::Cache::Store`]:
    https://api.rubyonrails.org/classes/ActiveSupport/Cache/Store.html
[ActiveSupport::Cache::Store#delete]:
    https://api.rubyonrails.org/classes/ActiveSupport/Cache/Store.html#method-i-delete
[ActiveSupport::Cache::Store#exist?]:
    https://api.rubyonrails.org/classes/ActiveSupport/Cache/Store.html#method-i-exist-3F
[ActiveSupport::Cache::Store#fetch]:
    https://api.rubyonrails.org/classes/ActiveSupport/Cache/Store.html#method-i-fetch
[ActiveSupport::Cache::Store#read]:
    https://api.rubyonrails.org/classes/ActiveSupport/Cache/Store.html#method-i-read
[ActiveSupport::Cache::Store#write]:
    https://api.rubyonrails.org/classes/ActiveSupport/Cache/Store.html#method-i-write

### `ActiveSupport::Cache::MemoryStore`

[`ActiveSupport::Cache::MemoryStore`][] keeps entries in memory in the same Ruby
process. The cache store has a bounded size specified by sending the `:size`
option to the initializer (default is 32Mb). When the cache exceeds the allotted
size, a cleanup will occur and the least recently used entries will be removed.

```ruby
config.cache_store = :memory_store, { size: 64.megabytes }
```

If you're running multiple Ruby on Rails server processes (which is the case if
you're using Phusion Passenger or Puma in clustered mode), then your Rails
server process instances won't be able to share cache data with each other. This
cache store is not appropriate for large application deployments. However, it
can work well for small, low traffic sites with only a couple of server
processes, as well as development and test environments.

New Rails applications use this cache store in development by default.

NOTE: Since processes will not share cache data when using `:memory_store`,
changes made in a Rails console affect only that console process, not any
running server processes.

[`ActiveSupport::Cache::MemoryStore`]:
    https://api.rubyonrails.org/classes/ActiveSupport/Cache/MemoryStore.html

### `ActiveSupport::Cache::FileStore`

[`ActiveSupport::Cache::FileStore`][] uses the file system to store entries. You
must specify the path to the directory where the cache files will be stored when
initializing the cache.

```ruby
config.cache_store = :file_store, "/path/to/cache/directory"
```

With this cache store, multiple server processes on the same host can share a
cache. This cache store is appropriate for low to medium traffic sites that are
served off one or two hosts. Server processes running on different hosts could
share a cache by using a shared file system, but that setup is not recommended.

As the cache will grow until the disk is full, it is recommended to periodically
clear out old entries.


[`ActiveSupport::Cache::FileStore`]:
    https://api.rubyonrails.org/classes/ActiveSupport/Cache/FileStore.html

### `ActiveSupport::Cache::MemCacheStore`

[`ActiveSupport::Cache::MemCacheStore`][] uses [`memcached`][] to provide a
centralized cache for your application. Rails uses the bundled `dalli` gem by
default. It can provide a single shared cache cluster with high performance and
redundancy.

When initializing the cache, you should specify the addresses for all memcached
servers in your cluster, or ensure the `MEMCACHE_SERVERS` environment variable
has been set appropriately.

```ruby
config.cache_store = :mem_cache_store, "cache-1.example.com", "cache-2.example.com"
```

If neither are specified, it will assume memcached is running on localhost on
the default port (`127.0.0.1:11211`), but this is not an ideal setup for larger
sites.

```ruby
config.cache_store = :mem_cache_store # Will fallback to $MEMCACHE_SERVERS, then 127.0.0.1:11211
```

See the [`Dalli::Client`
documentation](https://www.rubydoc.info/gems/dalli/Dalli/Client#initialize-instance_method)
for supported address types.

The [`write`][ActiveSupport::Cache::MemCacheStore#write] (and `fetch`) method on
this cache accepts additional options that take advantage of features specific
to memcached.

[`ActiveSupport::Cache::MemCacheStore`]:
    https://api.rubyonrails.org/classes/ActiveSupport/Cache/MemCacheStore.html
[`memcached`]: https://memcached.org/
[ActiveSupport::Cache::MemCacheStore#write]:
    https://api.rubyonrails.org/classes/ActiveSupport/Cache/MemCacheStore.html#method-i-write

### `ActiveSupport::Cache::RedisCacheStore`

[`ActiveSupport::Cache::RedisCacheStore`][] takes advantage of [Redis][] support
for automatic eviction when it reaches max memory, allowing it to behave much
like a Memcached cache server.

NOTE: Redis does not expire keys by default, so you should use a dedicated Redis
cache server and avoid filling your persistent Redis instance with volatile
cache data. See the [Redis cache server setup
guide](https://redis.io/topics/lru-cache) for more details.

For a cache-only Redis server, set `maxmemory-policy` to one of the variants of
allkeys. Least-frequently-used eviction (`allkeys-lfu`) is a good default
choice.

Set cache read and write timeouts relatively low. Regenerating a cached value is
often faster than waiting more than a second to retrieve it. Both read and write
timeouts default to 1 second, but may be set lower if your network is
consistently low-latency.

By default, the cache store will attempt to reconnect to Redis once if the
connection fails during a request.

Cache reads and writes never raise exceptions; they just return `nil` instead,
behaving as if there was nothing in the cache. To gauge whether your cache is
hitting exceptions, you may provide an `error_handler` to report to an exception
gathering service. It must accept three keyword arguments: `method`, the cache
store method that was originally called; `returning`, the value that was
returned to the user, typically `nil`; and `exception`, the exception that was
rescued.

To get started, add the redis gem to your Gemfile:

```ruby
gem "redis"
```

Finally, add the configuration in the relevant `config/environments/*.rb` file:

```ruby
config.cache_store = :redis_cache_store, { url: ENV["REDIS_URL"] }
```

A more complex, production Redis cache store may look something like this:

```ruby
cache_servers = %w(redis://cache-01:6379/0 redis://cache-02:6379/0)
config.cache_store = :redis_cache_store, { url: cache_servers,

  connect_timeout:    30,  # Defaults to 1 second
  read_timeout:       0.2, # Defaults to 1 second
  write_timeout:      0.2, # Defaults to 1 second
  reconnect_attempts: 2,   # Defaults to 1

  error_handler: -> (method:, returning:, exception:) {
    # Report errors to Sentry as warnings
    Sentry.capture_exception exception, level: "warning",
      tags: { method: method, returning: returning }
  }
}
```

[`ActiveSupport::Cache::RedisCacheStore`]:
    https://api.rubyonrails.org/classes/ActiveSupport/Cache/RedisCacheStore.html
[Redis]: https://redis.io/

### `ActiveSupport::Cache::NullStore`

[`ActiveSupport::Cache::NullStore`][] does not persist cached values across
requests. It is meant for use in development and test environments. It can be
very useful when you have code that interacts directly with `Rails.cache` but
caching interferes with seeing the results of code changes.

```ruby
config.cache_store = :null_store
```

[`ActiveSupport::Cache::NullStore`]:
    https://api.rubyonrails.org/classes/ActiveSupport/Cache/NullStore.html

### Custom Cache Stores

You can create your own custom cache store by simply extending
`ActiveSupport::Cache::Store` and implementing the appropriate methods. This
way, you can swap in any number of caching technologies into your Rails
application.

To use a custom cache store, simply set the cache store to a new instance of
your custom class.

```ruby
config.cache_store = MyCacheStore.new
```

Advanced Caching Patterns
-------------------------

### Caching in Background Jobs and Other Non-Request Contexts

Caching is not limited to controller actions. You can also use `Rails.cache` in
background jobs, service objects, scripts, and other application code.

Low-level caching works the same way in these contexts as it does in a request:

```ruby
class ReportJob < ApplicationJob
  def perform(account)
    Rails.cache.fetch([account, "daily-report"], expires_in: 1.hour) do
      account.generate_daily_report
    end
  end
end
```

Some caching behavior, however, depends on being inside a Rails execution
context. Features such as the Active Record query cache and other per-execution
state are set up automatically for normal Rails-managed requests and jobs.

If you run application code yourself from a custom thread or long-running
script, wrap it with `Rails.application.executor.wrap` so Rails can manage that
state correctly:

```ruby
Rails.application.executor.wrap do
  Rails.cache.fetch("stats", expires_in: 5.minutes) { expensive_calculation }
end
```

For more on the Executor and non-request code execution, see [Threading and Code
Execution in Rails](threading_and_code_execution.html).

### Local Cache

Some cache stores support a local cache layer. This keeps recently read values
in memory for the duration of a request or block, so repeated reads for the same
key can be served without going back to the underlying cache store.

This is especially useful with remote cache stores such as Redis or Memcached,
where avoiding repeated network round trips can improve performance.

In a normal Rails request, the local cache is managed for you by middleware. You
can also use it manually around a block:

```ruby
Rails.cache.with_local_cache do
  Rails.cache.read("hot-key")
  Rails.cache.read("hot-key")
end
```

The local cache is temporary and scoped to the current execution. It does not
replace your main cache store, and values written there are not shared across
requests, jobs, or processes.
