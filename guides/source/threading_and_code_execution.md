**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Threading and Code Execution in Rails
=====================================

After reading this guide, you will know:

* Where to find concurrent code execution in Rails
* How to integrate manual concurrency within Rails
* How to wrap application code using the Rails Executor
* How to affect application reloading

--------------------------------------------------------------------------------

In-Built Concurrency in Rails
-----------------------------

Rails automatically allows various operations to be performed at the same time
(concurrently) in order for an application to run more efficiently. In this
section, we will explore some of the ways this happens behind the scenes.

When using a threaded web server (such as Rails' default server, Puma) requests
will be served simultaneously as each request is given its own controller
instance.

Threaded Active Job adapters, including the built-in Async adapter, will
likewise execute several jobs at the same time. Action Cable channels are
managed this way too.

Asynchronous Active Record queries are also performed in the background,
allowing other processes to run on the main thread.

The above mechanisms all involve multiple threads, each managing work for a
unique instance of an object (controller, job, channel), while sharing the
global process space (such as classes and their configurations, and global
variables). As long as the code on each thread doesn't modify anything shared,
multiple threads can safely run concurrently.

Rails' in-built concurrency will cover the day-to-day needs of most application
developers, and ensure applications remain generally performant.

NOTE: You can read more about how to configure Rails' concurrency in the
[Framework Behavior](#framework-behavior) section.

### `CurrentAttributes` and Threading

The
[`ActiveSupport::CurrentAttributes`](https://edgeapi.rubyonrails.org/classes/ActiveSupport/CurrentAttributes.html)
class is a special class in Rails that helps you manage temporary,
thread-specific data for each request in your app, and helps make sure this data
is available to the whole system. It keeps this data separate for every request
(even if there are multiple threads running) and makes sure the data is cleaned
up automatically when the request is done.

You can think of this class as a place to store data that you need to access
anywhere in your app without having to pass it around in your code.

To use the `Current` class to store data, first you need to create a file as
shown in the example below, with `attribute` values for the attributes and
models whose values you would like to access throughout your application. You
can also define a method (e.g the `user` method below) which, when called, will
contain set values:

```ruby
# app/models/current.rb
class Current < ActiveSupport::CurrentAttributes
  attribute :account, :user

  resets { Time.zone = nil }

  def user=(user)
    super
    self.account = user.account
    Time.zone    = user.time_zone
  end
end
```

You will now have access to `Current.user` elsewhere in your application. For
example, when authenticating a user:

```ruby
# app/controllers/concerns/authentication.rb
module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate
  end

  private
    def authenticate
      if authenticated_user = User.find_by(id: cookies.encrypted[:user_id])
        Current.user = authenticated_user
      else
        redirect_to new_session_url
      end
    end
end
```

WARNING: It’s easy to put too many attributes in the `Current` class and tangle
your model as a result. `Current` should only be used for a few, top-level
globals, like account, user, and request details.

### Isolated Execution State

The `active_support.isolation_level` value in your `configuration.rb` file
provides you the option to define where Rails internal state should be stored
while tasks are run. If you use a fiber-based server or job processor (e.g.
[`falcon`](https://github.com/socketry/falcon)), you should set this value to
`:fiber`, otherwise it is best to set it to `:thread`.

The next section of this guide details advanced ways of wrapping code to ensure
thread safety, and how extensions and applications with particular concurrency
requirements, such as library maintainers, should do this.

Wrapping Application Code
-------------------------

### The Rails Executor

The Rails Executor inherits from the
[`ActiveSupport::ExecutionWrapper`](https://api.rubyonrails.org/classes/ActiveSupport/ExecutionWrapper.html).
The Executor separates application code from framework code by wrapping code
that you've written and is necessary when threads are being used.

#### Callbacks

The Executor consists of two callbacks: `to_run` and `to_complete`. The `to_run`
callback is called before the application code, and the `to_complete` callback
is called after.

In a default Rails application, the Rails Executor callbacks are used to:

* Track which threads are in safe positions for autoloading and reloading.
* Enable and disable the Active Record query cache.
* Return acquired Active Record connections to the pool.
* Constrain internal cache lifetimes.

#### Code Execution

If you're writing a library or component that will invoke application code, you
should wrap it with a call to the Executor:

```ruby
Rails.application.executor.wrap do
  # call application code here
end
```

TIP: If you repeatedly invoke application code from a long-running process, you
may want to wrap using the [Reloader](#the-reloader) instead.

If your application manually delegates work to other threads, such as via
`Thread.new`, or uses features from the [Concurrent
Ruby](https://github.com/ruby-concurrency/concurrent-ruby) gem that use thread
pools, you should immediately wrap the block, before any application code is
run:

```ruby
Thread.new do
  Rails.application.executor.wrap do
    # your code here
  end
end
```

NOTE: The Concurrent Ruby gem uses a `ThreadPoolExecutor`, which it sometimes
configures with an `executor` option. Despite the name, it is _not_ related to
the Rails Executor.

If it's impractical to wrap the application code in a block (for example, the
Rack API makes this problematic), you can also use the `run!` / `complete!`
pair:

```ruby
Thread.new do
  execution_context = Rails.application.executor.run!
  # your code here
ensure
  execution_context.complete! if execution_context
end
```

NOTE: The Rails Executor is safely re-entrant; it can be called again if it is
already running. In this case, the `wrap` method has no effect.

#### Running

When called, the Rails Executor will put the current thread into `running` mode
in the [Load Interlock](#load-interlock).

This operation will block temporarily if another thread is currently either
autoloading a constant or unloading/reloading the application.

#### Examples of Wrapped Application Code

Any time your library or component needs to invoke code that will run in the
application, the code should be wrapped to ensure thread safety and a consistent
and clean runtime state.

For example, you may be setting a `Current` user (using
[`ActiveSupport::CurrentAttributes`](https://api.rubyonrails.org/classes/ActiveSupport/CurrentAttributes.html)).

```ruby
def log_with_user_context(message)
  Rails.application.executor.wrap do
    Current.user = User.find_by(id: 1)
  end
end
```

You may be triggering an ActiveRecord callback or lifecycle hook in an
application:

```ruby
def perform_task_with_record(record)
  Rails.application.executor.wrap do
    record.save! # Executes before_save, after_save, etc.
  end
end
```

Or enqueuing or performing a background job within the application:

```ruby
def enqueue_background_job(job_class, *args)
  Rails.application.executor.wrap do
    job_class.perform_later(*args)
  end
end
```

These are just a few of many possible use cases, including rendering views or
templates, broadcasting via [`Action Cable`](action_cable_overview.html) or
using [`Rails.cache`](caching_with_rails.html).

### The Reloader

Like the Executor, the
[Reloader](https://api.rubyonrails.org/classes/ActiveSupport/Reloader.html) also
wraps application code. The Reloader is only suitable where a long-running
framework-level process repeatedly calls into application code, such as for a
web server or job queue.

NOTE: Rails automatically wraps web requests and Active Job workers, so you'll
rarely need to invoke the Reloader for yourself. Always consider whether the
Executor is a better fit for your use case.

If the Executor is not already active on the current thread, the Reloader will
invoke it for you, so you only need to call one. This also guarantees that
everything the Reloader does, including all its callback executions, occurs
wrapped inside the Executor.

```ruby
Rails.application.reloader.wrap do
  # call application code here
end
```

#### Callbacks

Before entering the wrapped block, the Reloader will check whether the running
application needs to be reloaded (because a model's source file has been
modified, for example). If it determines a reload is required, it will wait
until it's safe, and then do so, before continuing. When the application is
configured to always reload regardless of whether any changes are detected, the
reload is instead performed at the end of the block.

The Reloader also provides `to_run` and `to_complete` callbacks; they are
invoked at the same points as those of the Executor, but only when the current
execution has initiated an application reload. When no reload is deemed
necessary, the Reloader will invoke the wrapped block with no other callbacks.

#### Class Unload

The most significant part of the reloading process is the 'class unload', where
all autoloaded classes are removed, ready to be loaded again. This will occur
immediately before either the `to_run` or `to_complete` callback, depending on
the
[`reload_classes_only_on_change`](configuring.html#config-reload-classes-only-on-change)
setting.

Often, additional reloading actions need to be performed either just before or
just after the Class Unload, so the Reloader also provides
[`before_class_unload`](https://api.rubyonrails.org/classes/ActiveSupport/Reloader.html#method-c-before_class_unload)
and
[`after_class_unload`](https://api.rubyonrails.org/classes/ActiveSupport/Reloader.html#method-c-after_class_unload)
callbacks.

#### Concurrency

Only long-running "top level" processes should invoke the Reloader, because if
it determines a reload is needed, it will block until all other threads have
completed any Executor invocations.

If this were to occur in a "child" thread, with a waiting parent inside the
Executor, it would cause an unavoidable deadlock: the reload must occur before
the child thread is executed, but it cannot be safely performed while the parent
thread is mid-execution. Child threads should use the Executor instead.

Framework Behavior
------------------

The Rails framework components use the Executor and the Reloader to manage their
own concurrency needs too.

[`ActionDispatch::Executor`](https://api.rubyonrails.org/classes/ActionDispatch/Executor.html)
and
[`ActionDispatch::Reloader`](https://api.rubyonrails.org/classes/ActionDispatch/Reloader.html)
are Rack middlewares that wrap requests with a supplied Executor or Reloader,
respectively. They are automatically included in the default application stack.
The Reloader will ensure any arriving HTTP request is served with a
freshly-loaded copy of the application if any code changes have occurred.

Active Job also wraps its job executions with the Reloader, loading the latest
code to execute each job as it comes off the queue.

Action Cable uses the Executor instead. A Cable connection is linked to a
specific instance of a class, which means it's not possible to reload for every
arriving WebSocket message. Only the message handler is wrapped, though; a
long-running Cable connection does not prevent a reload that's triggered by a
new incoming request or job. Instead, Action Cable also uses the Reloader's
`before_class_unload` callback to disconnect all its connections. When the
client automatically reconnects, it will be interacting with the new version of
the code.

The above are the entry points to the framework, so they are responsible for
ensuring their respective threads are protected, and deciding whether a reload
is necessary. Most other components only need to use the Executor when they
spawn additional threads.

### Configuration

#### Reloader and Executor Configuration

The Reloader only checks for file changes when
[`config.enable_reloading`](configuring.html#config-enable-reloading) and
[`config.reload_classes_only_on_change`](configuring.html#config-reload-classes-only-on-change)
are both `true`. These are the defaults in the `development` environment.

When `config.enable_reloading` is `false` (in `production`, by default), the
Reloader is only a pass-through to the Executor.

The Executor always has important work to do, like database connection
management. When `config.enable_reloading` is `false` and `config.eager_load` is
`true` (`production` defaults), no reloading will occur, so it does not need the
[Load Interlock](#load-interlock). With the default settings in the
`development` environment, the Executor will use the Load Interlock to ensure
constants are only loaded when it is safe.

You can read more about the Load Interlock in the following section.

Load Interlock
--------------

The Reloading Interlock ensures that code reloading can be performed safely in a
multi-threaded runtime environment.

It is only safe to perform an unload/reload when no application code is in
mid-execution: after the reload, the `User` constant, for example, may point to
a different class. Without this rule, a poorly-timed reload would mean
`User.new.class == User`, or even `User == User`, could be false.

The Reloading Interlock addresses this constraint by keeping track of which
threads are currently running application code, and ensuring that reloading
waits until no other threads are executing application code.


### `permit_concurrent_loads`

The Executor automatically acquires a `running` lock for the duration of its
block, and autoload knows when to upgrade to a `load` lock, and switch back to
`running` again afterwards.

Other blocking operations performed inside the Executor block (which includes
all application code), however, can needlessly retain the `running` lock. If
another thread encounters a constant it must autoload, this can cause a
deadlock.

For example, assuming `User` is not yet loaded, the following will deadlock:

```ruby
Rails.application.executor.wrap do
  th = Thread.new do
    Rails.application.executor.wrap do
      User # inner thread waits here; it cannot load
           # User while another thread is running
    end
  end

  th.join # outer thread waits here, holding 'running' lock
end
```

To prevent this deadlock, the outer thread can `permit_concurrent_loads`. By
calling this method, the thread guarantees it will not dereference any
possibly-autoloaded constant inside the supplied block. The safest way to meet
that promise is to put it as close as possible to the blocking call:

```ruby
Rails.application.executor.wrap do
  th = Thread.new do
    Rails.application.executor.wrap do
      User # inner thread can acquire the 'load' lock,
           # load User, and continue
    end
  end

  ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
    th.join # outer thread waits here, but has no lock
  end
end
```

Another example, using Concurrent Ruby:

```ruby
Rails.application.executor.wrap do
  futures = 3.times.collect do |i|
    Concurrent::Promises.future do
      Rails.application.executor.wrap do
        # do work here
      end
    end
  end

  values = ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
    futures.collect(&:value)
  end
end
```

### ActionDispatch::DebugLocks

If your application is deadlocking and you think the Load Interlock may be
involved, you can temporarily add the ActionDispatch::DebugLocks middleware to
`config/application.rb`:

```ruby
config.middleware.insert_before Rack::Sendfile,
                                  ActionDispatch::DebugLocks
```

If you then restart the application and re-trigger the deadlock condition,
`/rails/locks` will show a summary of all threads currently known to the
interlock, which lock level they are holding or awaiting, and their current
backtrace.

Generally a deadlock will be caused by the interlock conflicting with some other
external lock or blocking input/output call. Once you find it, you can wrap it
with `permit_concurrent_loads`.
