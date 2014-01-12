Caching with Rails: An overview
===============================

This guide will teach you what you need to know about avoiding that expensive round-trip to your database and returning what you need to return to the web clients in the shortest time possible.

After reading this guide, you will know:

* Page and action caching (moved to separate gems as of Rails 4).
* Fragment caching.
* Alternative cache stores.
* Conditional GET support.

--------------------------------------------------------------------------------

Basic Caching
-------------

This is an introduction to three types of caching techniques: page, action and
fragment caching. Rails provides by default fragment caching. In order to use
page and action caching, you will need to add `actionpack-page_caching` and
`actionpack-action_caching` to your Gemfile.

To start playing with caching you'll want to ensure that `config.action_controller.perform_caching` is set to `true`, if you're running in development mode. This flag is normally set in the corresponding `config/environments/*.rb` and caching is disabled by default for development and test, and enabled for production.

```ruby
config.action_controller.perform_caching = true
```

### Page Caching

Page caching is a Rails mechanism which allows the request for a generated page to be fulfilled by the webserver (i.e. Apache or nginx), without ever having to go through the Rails stack at all. Obviously, this is super-fast. Unfortunately, it can't be applied to every situation (such as pages that need authentication) and since the webserver is literally just serving a file from the filesystem, cache expiration is an issue that needs to be dealt with.

INFO: Page Caching has been removed from Rails 4. See the [actionpack-page_caching gem](https://github.com/rails/actionpack-page_caching). See [DHH's key-based cache expiration overview](http://37signals.com/svn/posts/3113-how-key-based-cache-expiration-works) for the newly-preferred method.

### Action Caching

Page Caching cannot be used for actions that have before filters - for example, pages that require authentication. This is where Action Caching comes in. Action Caching works like Page Caching except the incoming web request hits the Rails stack so that before filters can be run on it before the cache is served. This allows authentication and other restrictions to be run while still serving the result of the output from a cached copy.

INFO: Action Caching has been removed from Rails 4. See the [actionpack-action_caching gem](https://github.com/rails/actionpack-action_caching). See [DHH's key-based cache expiration overview](http://37signals.com/svn/posts/3113-how-key-based-cache-expiration-works) for the newly-preferred method.

### Fragment Caching

Life would be perfect if we could get away with caching the entire contents of a page or action and serving it out to the world. Unfortunately, dynamic web applications usually build pages with a variety of components not all of which have the same caching characteristics. In order to address such a dynamically created page where different parts of the page need to be cached and expired differently, Rails provides a mechanism called Fragment Caching.

Fragment Caching allows a fragment of view logic to be wrapped in a cache block and served out of the cache store when the next request comes in.

As an example, if you wanted to show all the orders placed on your website in real time and didn't want to cache that part of the page, but did want to cache the part of the page which lists all products available, you could use this piece of code:

```html+erb
<% Order.find_recent.each do |o| %>
  <%= o.buyer.name %> bought <%= o.product.name %>
<% end %>

<% cache do %>
  All available products:
  <% Product.all.each do |p| %>
    <%= link_to p.name, product_url(p) %>
  <% end %>
<% end %>
```

The cache block in our example will bind to the action that called it and is written out to the same place as the Action Cache, which means that if you want to cache multiple fragments per action, you should provide an `action_suffix` to the cache call:

```html+erb
<% cache(action: 'recent', action_suffix: 'all_products') do %>
  All available products:
```

and you can expire it using the `expire_fragment` method, like so:

```ruby
expire_fragment(controller: 'products', action: 'recent', action_suffix: 'all_products')
```

If you don't want the cache block to bind to the action that called it, you can also use globally keyed fragments by calling the `cache` method with a key:

```erb
<% cache('all_available_products') do %>
  All available products:
<% end %>
```

This fragment is then available to all actions in the `ProductsController` using the key and can be expired the same way:

```ruby
expire_fragment('all_available_products')
```
If you want to avoid expiring the fragment manually, whenever an action updates a product, you can define a helper method:

```ruby
module ProductsHelper
  def cache_key_for_products
    count          = Product.count
    max_updated_at = Product.maximum(:updated_at).try(:utc).try(:to_s, :number)
    "products/all-#{count}-#{max_updated_at}"
  end
end
```

This method generates a cache key that depends on all products and can be used in the view:

```erb
<% cache(cache_key_for_products) do %>
  All available products:
<% end %>
```

If you want to cache a fragment under certain condition you can use `cache_if` or `cache_unless` 

```erb
<% cache_if (condition, cache_key_for_products) do %>
  All available products:
<% end %>
```

You can also use an Active Record model as the cache key:

```erb
<% Product.all.each do |p| %>
  <% cache(p) do %>
    <%= link_to p.name, product_url(p) %>
  <% end %>
<% end %>
```

Behind the scenes, a method called `cache_key` will be invoked on the model and it returns a string like `products/23-20130109142513`. The cache key includes the model name, the id and finally the updated_at timestamp. Thus it will automatically generate a new fragment when the product is updated because the key changes.

You can also combine the two schemes which is called "Russian Doll Caching":

```erb
<% cache(cache_key_for_products) do %>
  All available products:
  <% Product.all.each do |p| %>
    <% cache(p) do %>
      <%= link_to p.name, product_url(p) %>
    <% end %>
  <% end %>
<% end %>
```

It's called "Russian Doll Caching" because it nests multiple fragments. The advantage is that if a single product is updated, all the other inner fragments can be reused when regenerating the outer fragment.

### SQL Caching

Query caching is a Rails feature that caches the result set returned by each query so that if Rails encounters the same query again for that request, it will use the cached result set as opposed to running the query against the database again.

For example:

```ruby
class ProductsController < ApplicationController

  def index
    # Run a find query
    @products = Product.all

    ...

    # Run the same query again
    @products = Product.all
  end

end
```

Cache Stores
------------

Rails provides different stores for the cached data created by <b>action</b> and <b>fragment</b> caches.

TIP: Page caches are always stored on disk.

### Configuration

You can set up your application's default cache store by calling `config.cache_store=` in the Application definition inside your `config/application.rb` file or in an Application.configure block in an environment specific configuration file (i.e. `config/environments/*.rb`). The first argument will be the cache store to use and the rest of the argument will be passed as arguments to the cache store constructor.

```ruby
config.cache_store = :memory_store
```

NOTE: Alternatively, you can call `ActionController::Base.cache_store` outside of a configuration block.

You can access the cache by calling `Rails.cache`.

### ActiveSupport::Cache::Store

This class provides the foundation for interacting with the cache in Rails. This is an abstract class and you cannot use it on its own. Rather you must use a concrete implementation of the class tied to a storage engine. Rails ships with several implementations documented below.

The main methods to call are `read`, `write`, `delete`, `exist?`, and `fetch`. The fetch method takes a block and will either return an existing value from the cache, or evaluate the block and write the result to the cache if no value exists.

There are some common options used by all cache implementations. These can be passed to the constructor or the various methods to interact with entries.

* `:namespace` - This option can be used to create a namespace within the cache store. It is especially useful if your application shares a cache with other applications.

* `:compress` - This option can be used to indicate that compression should be used in the cache. This can be useful for transferring large cache entries over a slow network.

* `:compress_threshold` - This options is used in conjunction with the `:compress` option to indicate a threshold under which cache entries should not be compressed. This defaults to 16 kilobytes.

* `:expires_in` - This option sets an expiration time in seconds for the cache entry when it will be automatically removed from the cache.

* `:race_condition_ttl` - This option is used in conjunction with the `:expires_in` option. It will prevent race conditions when cache entries expire by preventing multiple processes from simultaneously regenerating the same entry (also known as the dog pile effect). This option sets the number of seconds that an expired entry can be reused while a new value is being regenerated. It's a good practice to set this value if you use the `:expires_in` option.

### ActiveSupport::Cache::MemoryStore

This cache store keeps entries in memory in the same Ruby process. The cache store has a bounded size specified by the `:size` options to the initializer (default is 32Mb). When the cache exceeds the allotted size, a cleanup will occur and the least recently used entries will be removed.

```ruby
config.cache_store = :memory_store, { size: 64.megabytes }
```

If you're running multiple Ruby on Rails server processes (which is the case if you're using mongrel_cluster or Phusion Passenger), then your Rails server process instances won't be able to share cache data with each other. This cache store is not appropriate for large application deployments, but can work well for small, low traffic sites with only a couple of server processes or for development and test environments.

### ActiveSupport::Cache::FileStore

This cache store uses the file system to store entries. The path to the directory where the store files will be stored must be specified when initializing the cache.

```ruby
config.cache_store = :file_store, "/path/to/cache/directory"
```

With this cache store, multiple server processes on the same host can share a cache. Servers processes running on different hosts could share a cache by using a shared file system, but that set up would not be ideal and is not recommended. The cache store is appropriate for low to medium traffic sites that are served off one or two hosts.

Note that the cache will grow until the disk is full unless you periodically clear out old entries.

This is the default cache store implementation.

### ActiveSupport::Cache::MemCacheStore

This cache store uses Danga's `memcached` server to provide a centralized cache for your application. Rails uses the bundled `dalli` gem by default. This is currently the most popular cache store for production websites. It can be used to provide a single, shared cache cluster with very high performance and redundancy.

When initializing the cache, you need to specify the addresses for all memcached servers in your cluster. If none is specified, it will assume memcached is running on the local host on the default port, but this is not an ideal set up for larger sites.

The `write` and `fetch` methods on this cache accept two additional options that take advantage of features specific to memcached. You can specify `:raw` to send a value directly to the server with no serialization. The value must be a string or number. You can use memcached direct operation like `increment` and `decrement` only on raw values. You can also specify `:unless_exist` if you don't want memcached to overwrite an existing entry.

```ruby
config.cache_store = :mem_cache_store, "cache-1.example.com", "cache-2.example.com"
```

### ActiveSupport::Cache::EhcacheStore

If you are using JRuby you can use Terracotta's Ehcache as the cache store for your application. Ehcache is an open source Java cache that also offers an enterprise version with increased scalability, management, and commercial support. You must first install the jruby-ehcache-rails3 gem (version 1.1.0 or later) to use this cache store.

```ruby
config.cache_store = :ehcache_store
```

When initializing the cache, you may use the `:ehcache_config` option to specify the Ehcache config file to use (where the default is "ehcache.xml" in your Rails config directory), and the :cache_name option to provide a custom name for your cache (the default is rails_cache).

In addition to the standard `:expires_in` option, the `write` method on this cache can also accept the additional `:unless_exist` option, which will cause the cache store to use Ehcache's `putIfAbsent` method instead of `put`, and therefore will not overwrite an existing entry. Additionally, the `write` method supports all of the properties exposed by the [Ehcache Element class](http://ehcache.org/apidocs/net/sf/ehcache/Element.html) , including:

| Property                    | Argument Type       | Description                                                 |
| --------------------------- | ------------------- | ----------------------------------------------------------- |
| elementEvictionData         | ElementEvictionData | Sets this element's eviction data instance.                 |
| eternal                     | boolean             | Sets whether the element is eternal.                        |
| timeToIdle, tti             | int                 | Sets time to idle                                           |
| timeToLive, ttl, expires_in | int                 | Sets time to Live                                           |
| version                     | long                | Sets the version attribute of the ElementAttributes object. |

These options are passed to the `write` method as Hash options using either camelCase or underscore notation, as in the following examples:

```ruby
Rails.cache.write('key', 'value', time_to_idle: 60.seconds, timeToLive: 600.seconds)
caches_action :index, expires_in: 60.seconds, unless_exist: true
```

For more information about Ehcache, see [http://ehcache.org/](http://ehcache.org/) .
For more information about Ehcache for JRuby and Rails, see [http://ehcache.org/documentation/jruby.html](http://ehcache.org/documentation/jruby.html)

### ActiveSupport::Cache::NullStore

This cache store implementation is meant to be used only in development or test environments and it never stores anything. This can be very useful in development when you have code that interacts directly with `Rails.cache`, but caching may interfere with being able to see the results of code changes. With this cache store, all `fetch` and `read` operations will result in a miss.

```ruby
config.cache_store = :null_store
```

### Custom Cache Stores

You can create your own custom cache store by simply extending `ActiveSupport::Cache::Store` and implementing the appropriate methods. In this way, you can swap in any number of caching technologies into your Rails application.

To use a custom cache store, simple set the cache store to a new instance of the class.

```ruby
config.cache_store = MyCacheStore.new
```

### Cache Keys

The keys used in a cache can be any object that responds to either `:cache_key` or to `:to_param`. You can implement the `:cache_key` method on your classes if you need to generate custom keys. Active Record will generate keys based on the class name and record id.

You can use Hashes and Arrays of values as cache keys.

```ruby
# This is a legal cache key
Rails.cache.read(site: "mysite", owners: [owner_1, owner_2])
```

The keys you use on `Rails.cache` will not be the same as those actually used with the storage engine. They may be modified with a namespace or altered to fit technology backend constraints. This means, for instance, that you can't save values with `Rails.cache` and then try to pull them out with the `memcache-client` gem. However, you also don't need to worry about exceeding the memcached size limit or violating syntax rules.

Conditional GET support
-----------------------

Conditional GETs are a feature of the HTTP specification that provide a way for web servers to tell browsers that the response to a GET request hasn't changed since the last request and can be safely pulled from the browser cache.

They work by using the `HTTP_IF_NONE_MATCH` and `HTTP_IF_MODIFIED_SINCE` headers to pass back and forth both a unique content identifier and the timestamp of when the content was last changed. If the browser makes a request where the content identifier (etag) or last modified since timestamp matches the server's version then the server only needs to send back an empty response with a not modified status.

It is the server's (i.e. our) responsibility to look for a last modified timestamp and the if-none-match header and determine whether or not to send back the full response. With conditional-get support in Rails this is a pretty easy task:

```ruby
class ProductsController < ApplicationController

  def show
    @product = Product.find(params[:id])

    # If the request is stale according to the given timestamp and etag value
    # (i.e. it needs to be processed again) then execute this block
    if stale?(last_modified: @product.updated_at.utc, etag: @product.cache_key)
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

Instead of an options hash, you can also simply pass in a model, Rails will use the `updated_at` and `cache_key` methods for setting `last_modified` and `etag`:

```ruby
class ProductsController < ApplicationController
  def show
    @product = Product.find(params[:id])
    respond_with(@product) if stale?(@product)
  end
end
```

If you don't have any special response processing and are using the default rendering mechanism (i.e. you're not using respond_to or calling render yourself) then you've got an easy helper in fresh_when:

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
