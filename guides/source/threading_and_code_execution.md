**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Threading and Code Execution in Rails
=====================================

After reading this guide, you will know:

* Where to find automatically concurrent code execution in Rails
* How to integrate manual concurrency within Rails
* How to wrap all application code using the Rails Executor
* How to affect application reloading

--------------------------------------------------------------------------------

Concurrency in Rails
--------------------

Rails automatically allows various operations to be performed at the same time (concurrently) in order for an application to run more efficiently. In this section, we will explore some of the ways this happens behind the scenes.

When using a threaded web server, such as Rails' default server, Puma, multiple HTTP
requests will be served simultaneously. Rails provides each request with its own
controller instance.

Threaded Active Job adapters, including the built-in Async adapter, will likewise
execute several jobs at the same time. Action Cable channels are managed this
way too.

The above mechanisms all involve multiple threads, each managing work for a unique
instance of some object (controller, job, channel), while sharing the global
process space (such as classes and their configurations, and global variables).
As long as your code doesn't modify any of those shared things, the other threads are mostly irrelevant to it.

The rest of this guide goes into more detail about threading in Rails,
and how extensions and applications with particular requirements can use it.

NOTE: You can read more about Rails' in-built concurrency, and how to configure it, in the [Framework Behavior](#framework-behavior) section.

The Rails Executor
------------------

The Rails Executor inherits from the [`ActiveSupport::ExecutionWrapper`](https://api.rubyonrails.org/classes/ActiveSupport/ExecutionWrapper.html). The Executor separates application code from framework code by wrapping code that you've written.

The Executor consists of two callbacks: `to_run` and `to_complete`. The `to_run`
callback is called before the application code, and the `to_complete` callback is
called after.

### Callbacks

In a default Rails application, the Rails Executor callbacks are used to:

* track which threads are in safe positions for autoloading and reloading
* enable and disable the Active Record query cache
* return acquired Active Record connections to the pool
* constrain internal cache lifetimes

### Wrapping Code Execution

If you're writing a library or component that will invoke application code, you
should wrap it with a call to the Executor:

```ruby
Rails.application.executor.wrap do
  # call application code here
end
```

TIP: If you repeatedly invoke application code from a long-running process, you
may want to wrap using the [Reloader](#reloader) instead.

Each thread should be wrapped before it runs application code, so if your
application manually delegates work to other threads, such as via `Thread.new`,
or uses features from the [Concurrent Ruby](https://github.com/ruby-concurrency/concurrent-ruby) gem that use thread pools, you should immediately wrap
the block:

```ruby
Thread.new do
  Rails.application.executor.wrap do
    # your code here
  end
end
```

NOTE: The Concurrent Ruby gem uses a `ThreadPoolExecutor`, which it sometimes configures
with an `executor` option. Despite the name, it is unrelated to the Rails Executor.

If it's impractical to wrap the application code in a block (for
example, the Rack API makes this problematic), you can also use the `run!` /
`complete!` pair:

```ruby
Thread.new do
  execution_context = Rails.application.executor.run!
  # your code here
ensure
  execution_context.complete! if execution_context
end
```

NOTE: The Rails Executor is safely re-entrant; it can be called again if it is already running. In this case, the `wrap` method would have no effect.

The Executor will put the current thread into `running` mode in the [Reloading
Interlock](#reloading-interlock). This operation will block temporarily if another
thread is currently unloading/reloading the application.

Reloader
--------

Like the Executor, the [Reloader](https://api.rubyonrails.org/classes/ActiveSupport/Reloader.html) also wraps application code. If the Executor is
not already active on the current thread, the Reloader will invoke it for you,
so you only need to call one. This also guarantees that everything the Reloader
does, including all its callback executions, occurs wrapped inside the
Executor.

```ruby
Rails.application.reloader.wrap do
  # call application code here
end
```

NOTE: The Reloader is only suitable where a long-running framework-level process
repeatedly calls into application code, such as for a web server or job queue.
Rails automatically wraps web requests and Active Job workers, so you'll rarely
need to invoke the Reloader for yourself. Always consider whether the Executor
is a better fit for your use case.

### Callbacks

Before entering the wrapped block, the Reloader will check whether the running
application needs to be reloaded -- for example, because a model's source file has
been modified. If it determines a reload is required, it will wait until it's
safe, and then do so, before continuing. When the application is configured to
always reload regardless of whether any changes are detected, the reload is
instead performed at the end of the block.

The Reloader also provides `to_run` and `to_complete` callbacks; they are
invoked at the same points as those of the Executor, but only when the current
execution has initiated an application reload. When no reload is deemed
necessary, the Reloader will invoke the wrapped block with no other callbacks.

### Class Unload

The most significant part of the reloading process is the 'class unload', where
all autoloaded classes are removed, ready to be loaded again. This will occur
immediately before either the `to_run` or `to_complete` callback, depending on the
[`reload_classes_only_on_change`](configuring.html#config-reload-classes-only-on-change) setting.

Often, additional reloading actions need to be performed either just before or
just after the Class Unload, so the Reloader also provides [`before_class_unload`](https://api.rubyonrails.org/classes/ActiveSupport/Reloader.html#method-c-before_class_unload)
and [`after_class_unload`](https://api.rubyonrails.org/classes/ActiveSupport/Reloader.html#method-c-after_class_unload) callbacks.

### Concurrency

Only long-running "top level" processes should invoke the Reloader, because if
it determines a reload is needed, it will block until all other threads have
completed any Executor invocations.

If this were to occur in a "child" thread, with a waiting parent inside the
Executor, it would cause an unavoidable deadlock: the reload must occur before
the child thread is executed, but it cannot be safely performed while the parent
thread is mid-execution. Child threads should use the Executor instead.

Framework Behavior
------------------

The Rails framework components use these tools to manage their own concurrency
needs too.

`ActionDispatch::Executor` and `ActionDispatch::Reloader` are Rack middlewares
that wrap requests with a supplied Executor or Reloader, respectively. They
are automatically included in the default application stack. The Reloader will
ensure any arriving HTTP request is served with a freshly-loaded copy of the
application if any code changes have occurred.

Active Job also wraps its job executions with the Reloader, loading the latest
code to execute each job as it comes off the queue.

Action Cable uses the Executor instead: because a Cable connection is linked to
a specific instance of a class, it's not possible to reload for every arriving
WebSocket message. Only the message handler is wrapped, though; a long-running
Cable connection does not prevent a reload that's triggered by a new incoming
request or job. Instead, Action Cable also uses the Reloader's `before_class_unload`
callback to disconnect all its connections. When the client automatically
reconnects, it will be speaking to the new version of the code.

The above are the entry points to the framework, so they are responsible for
ensuring their respective threads are protected, and deciding whether a reload
is necessary. Other components only need to use the Executor when they spawn
additional threads.

### Configuration

The Reloader only checks for file changes when [`config.enable_reloading`](configuring.html#config-enable-reloading) is
`true` and so is [`config.reload_classes_only_on_change`](configuring.html#config-reload-classes-only-on-change). These are the defaults in the
`development` environment.

When `config.enable_reloading` is `false` (in `production`, by default), the
Reloader is only a pass-through to the Executor.

The Executor always has important work to do, like database connection
management. When `config.enable_reloading` is `false` and `config.eager_load` is
`true` (`production` defaults), no reloading will occur, so it does not need the
Reloading Interlock. With the default settings in the `development` environment, the
Executor will use the Reloading Interlock to ensure code reloading is performed safely.

Reloading Interlock
-------------------

The Reloading Interlock ensures that code reloading can be performed safely in a
multi-threaded runtime environment.

It is only safe to perform an unload/reload when no application code is in
mid-execution: after the reload, the `User` constant, for example, may point to
a different class. Without this rule, a poorly-timed reload would mean
`User.new.class == User`, or even `User == User`, could be false.

The Reloading Interlock addresses this constraint by keeping track of which
threads are currently running application code, and ensuring that reloading
waits until no other threads are executing application code.


