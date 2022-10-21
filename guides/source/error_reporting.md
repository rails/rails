**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON https://guides.rubyonrails.org.**

Error Reporting in Rails Applications
========================

This guide introduces ways to manage exceptions that occur in Ruby on Rails applications.

After reading this guide, you will know:

* How to use Rails' error reporter to capture and report errors.
* How to create custom subscribers for your error-reporting service.

--------------------------------------------------------------------------------

Error Reporting
------------------------

The Rails [error reporter](https://api.rubyonrails.org/classes/ActiveSupport/ErrorReporter.html) provides a standard way to collect exceptions that occur in your application and report them to your preferred service or location.

The error reporter aims to replace boilerplate error-handling code like this:

```ruby
begin
  do_something
rescue SomethingIsBroken => error
  MyErrorReportingService.notify(error)
end
```

with a consistent interface:

```ruby
Rails.error.handle(SomethingIsBroken) do
  do_something
end
```

Rails wraps all executions (such as HTTP requests, jobs, and `rails runner` invocations) in the error reporter, so any unhandled errors raised in your app will automatically be reported to your error-reporting service via their subscribers.

This means that third-party error-reporting libraries no longer need to insert a Rack middleware or do any monkey-patching to capture unhandled exceptions. Libraries that use ActiveSupport can also use this to non-intrusively report warnings that would previously have been lost in logs.

Using the Rails' error reporter is not required. All other means of capturing errors still work.

### Subscribing to the Reporter

To use the error reporter, you need a _subscriber_. A subscriber is any object with a `report` method. When an error occurs in your application or is manually reported, the Rails error reporter will call this method with the error object and some options.

Some error-reporting libraries, such as [Sentry's](https://github.com/getsentry/sentry-ruby/blob/e18ce4b6dcce2ebd37778c1e96164684a1e9ebfc/sentry-rails/lib/sentry/rails/error_subscriber.rb) and [Honeybadger's](https://docs.honeybadger.io/lib/ruby/integration-guides/rails-exception-tracking/), automatically register a subscriber for you. Consult your provider's documentation for more details.

You may also create a custom subscriber. For example:

```ruby
# config/initializers/error_subscriber.rb
class ErrorSubscriber
  def report(error, handled:, severity:, context:, source: nil)
    MyErrorReportingService.report_error(error, context: context, handled: handled, level: severity)
  end
end
```

After defining the subscriber class, register it by calling [`Rails.error.subscribe`](https://api.rubyonrails.org/classes/ActiveSupport/ErrorReporter.html#method-i-subscribe) method:

```ruby
Rails.error.subscribe(ErrorSubscriber.new)
```

You can register as many subscribers as you wish. Rails will call them in turn, in the order in which they were registered.

Note: The Rails error-reporter will always call registered subscribers, regardless of your environment. However, many error-reporting services only report errors in production by default. You should configure and test your setup across environments as needed.

### Using the Error Reporter

There are three ways you can use the error reporter:

#### Reporting and Swallowing Errors
[`Rails.error.handle`](https://api.rubyonrails.org/classes/ActiveSupport/ErrorReporter.html#method-i-handle) will report any error raised within the block. It will then **swallow** the error, and the rest of your code outside the block will continue as normal.

```ruby
result = Rails.error.handle do
  1 + '1' # raises TypeError
end
result # => nil
1 + 1 # This will be executed
```

If no error is raised in the block, `Rails.error.handle` will return the result of the block, otherwise it will return `nil`. You can override this by providing a `fallback`:

```ruby
user = Rails.error.handle(fallback: -> { User.anonymous }) do
  User.find_by(params[:id])
end
```

#### Reporting and Re-raising Errors
[`Rails.error.record`](https://api.rubyonrails.org/classes/ActiveSupport/ErrorReporter.html#method-i-record) will report errors to all registered subscribers and then re-raise the error, meaning that the rest of your code won't execute.

```ruby
Rails.error.record do
  1 + '1' # raises TypeError
end
1 + 1 # This won't be executed
```

If no error is raised in the block, `Rails.error.record` will return the result of the block.

#### Manually Reporting Errors
You can also manually report errors by calling [`Rails.error.report`](https://api.rubyonrails.org/classes/ActiveSupport/ErrorReporter.html#method-i-report):

```ruby
begin
  # code
rescue StandardError => e
  Rails.error.report(e)
end
```

Any options you pass will be passed on the error subscribers.

### Error-reporting Options

All 3 reporting APIs (`#handle`, `#record`, and `#report`) support the following options, which are then passed along to all registered subscribers:

- `handled`: a `Boolean` to indicate if the error was handled. This is set to `true` by default. `#record` sets this to `false`.
- `severity`: a `Symbol` describing the severity of the error. Expected values are: `:error`, `:warning`, and `:info`. `#handle` sets this to `:warning`, while `#record` sets it to `:error`.
- `context`: a `Hash` to provide more context about the error, like request or user details
- `source`: a `String` about the source of the error. The default source is `"application"`. Errors reported by internal libraries may set other sources; the Redis cache library may use `"redis_cache_store.active_support"`, for instance. Your subscriber can use the source to ignore errors you aren't interested in.

```ruby
Rails.error.handle(context: {user_id: user.id}, severity: :info) do
  # ...
end
```

### Filtering by Error Classes

With `Rails.error.handle` and `Rails.error.record`, you can also choose to only report errors of certain classes. For example:

```ruby
Rails.error.handle(IOError) do
  1 + '1' # raises TypeError
end
1 + 1 # TypeErrors are not IOErrors, so this will *not* be executed
```

Here, the `TypeError` will not be captured by the Rails error reporter. Only instances of  `IOError` and its descendants will be reported. Any other errors will be raised as normal.

### Setting Context Globally

In addition to setting context through the `context` option, you can use the [`#set_context`](https://api.rubyonrails.org/classes/ActiveSupport/ErrorReporter.html#method-i-set_context) API. For example:

```ruby
Rails.error.set_context(section: "checkout", user_id: @user.id)
```

Any context set this way will be merged with the `context` option

```ruby
Rails.error.set_context(a: 1)
Rails.error.handle(context: { b: 2 }) { raise }
# The reported context will be: {:a=>1, :b=>2}
Rails.error.handle(context: { b: 3 }) { raise }
# The reported context will be: {:a=>1, :b=>3}
```

### For Libraries

Error-reporting libraries can register their subscribers in a `Railtie`:

```ruby
module MySdk
  class Railtie < ::Rails::Railtie
    initializer "error_subscribe.my_sdk" do
      Rails.error.subscribe(MyErrorSubscriber.new)
    end
  end
end
```

If you register an error subscriber, but still have other error mechanisms like a Rack middleware, you may end up with errors reported multiple times. You should either remove your other mechanisms or adjust your report functionality so it skips reporting an exception it has seen before.
