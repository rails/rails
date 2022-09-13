**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON https://guides.rubyonrails.org.**

Error Reporting in Rails Applications
========================

This guide introduces ways to manage exceptions that occur in Ruby on Rails applications.

After reading this guide, you will know:

* How to use Rails' error reporter to capture and report errors.

(Because error reporting libraries are mainly for production use, this guide is mostly for production environment too.
However, you may want to test related setup in development by temporarily activating the libraries locally.)

--------------------------------------------------------------------------------

Error Reporter
------------------------

The [error reporter](https://api.rubyonrails.org/classes/ActiveSupport/ErrorReporter.html) collects exceptions occur in Ruby on Rails applications and reports them to registered subscribers.

The goals are to

1. Automatically capture and report any unhandled exception from a controller or a job.

2. Replace such manual rescue in applications and libraries

```rb
begin
  do_something
rescue SomethingIsBroken => error
  MyErrorReportingService.notify(error)
end
```

with

```rb
Rails.error.handle(SomethingIsBroken) do
  do_something
end
```

This approach provides several benefits:

* Application or error reporting libraries don't need to insert a Rack middleware to capture unhandled exceptions from requests anymore.
* To ActiveSupport-aware libraries, this can be used to report errors to the host application.
* It decouples application code from error reporting libraries.
* It reduces boilerplate code for handling exceptions.
* Error reporting libraries will need less monkey-patches and be less intrusive to applications.

### Subscribe To The Reporter

An error subscriber is expected to have a `report` method that takes an exception object and a few options.
For example:

```rb
# config/initializers/error_subscriber.rb
class ErrorSubscriber
  def report(error, handled:, severity:, context:, source: nil)
    MyErrorReportingService.report_error(error, context: context, handled: handled, level: severity)
  end
end
```

After defining the subscriber class, you can register its instance with the [`#subscribe`](https://api.rubyonrails.org/classes/ActiveSupport/ErrorReporter.html#method-i-subscribe) method:

```rb
Rails.error.subscribe(ErrorSubscriber.new)
```

To test the error subscriber, try this in Rails console:

```
irb(main):001:0> Rails.error.handle { raise }
```

And see if the error is reported to the service you use.

#### Libraries Subscribe To Rails Reporter

Some libraries may provide their own subscriber classes. Please check their documentation for more information.

- [Sentry](https://sentry.io/) ([document](https://github.com/getsentry/sentry-ruby/blob/master/sentry-rails/lib/sentry/rails/error_subscriber.rb))

### Capture and Report Errors

You can wrap your code inside a block with the reporting APIs, which will report the exceptions surface from the block.

To report and **swallow** the error, use [`Rails.error.handle`](https://api.rubyonrails.org/classes/ActiveSupport/ErrorReporter.html#method-i-handle):

```rb
Rails.error.handle do
  1 + '1' # raises TypeError
end
1 + 1 # This will be execute
```

The error will be reported with `handled: true`

To report but **not swallow** the error, use [`Rails.error.record`](https://api.rubyonrails.org/classes/ActiveSupport/ErrorReporter.html#method-i-record):

```rb
Rails.error.record do
  1 + '1' # raises TypeError
end
1 + 1 # This won't be executed
```

The error will be reported with `handled: false`

If you decide to rescue the exception manually, you can also report it with [`Rails.error.report`](https://api.rubyonrails.org/classes/ActiveSupport/ErrorReporter.html#method-i-report):

```rb
begin
  # code
rescue StandardError => e
  Rails.error.report(e)
end
```

#### Options

All 3 reporting APIs (`#handle`, `#record`, and `#report`) support the same options:

- `handled`: a `Boolean` to tell if the error was handled
- `severity`: a `Symbol` about the severity of the exception. Expected values are: `:error`, `:warning`, and `:info`
- `context`: a `Hash` to provide more context about the error, like request headers or record attributes
- `source`: a `String` about the source of the exception. Default is `"application"`
    - You can use it to skip exceptions from certain sources

### Setting Context

In addition to setting context through the `context` option, you can also use the [`#set_context`](https://api.rubyonrails.org/classes/ActiveSupport/ErrorReporter.html#method-i-set_context) API. For example:

```rb
Rails.error.set_context(section: "checkout", user_id: @user.id)
```

The context set this way will be merged with the `context` option

```rb
Rails.error.set_context(a: 1)
Rails.error.handle(context: { b: 2 }) { raise }
# the reported context will be: {:a=>1, :b=>2}
```

### For Libraries

Libraries can easily register their subscribers in `Railtie`:

```rb
module MySdk
  class Railtie < ::Rails::Railtie
    initializer "error_subscribe.my_sdk" do
      Rails.error.subscribe(MyErrorSubscriber.new)
    end
  end
end
```
