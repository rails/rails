**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON https://guides.rubyonrails.org.**

Active Job Basics
=================

This guide provides you with all you need to get started in creating,
enqueuing and executing background jobs.

After reading this guide, you will know:

* How to create jobs.
* How to enqueue jobs.
* How to run jobs in the background.
* How to send emails from your application asynchronously.

--------------------------------------------------------------------------------

What is Active Job?
-------------------

Active Job is a framework for declaring jobs and making them run on a variety
of queuing backends. These jobs can be everything from regularly scheduled
clean-ups, to billing charges, to mailings. Anything that can be chopped up
into small units of work and run in parallel.


The Purpose of Active Job
-----------------------------

The main point is to ensure that all Rails apps will have a job infrastructure
in place. We can then have framework features and other gems build on top of that,
without having to worry about API differences between various job runners such as
Delayed Job and Resque. Picking your queuing backend becomes more of an operational
concern, then. And you'll be able to switch between them without having to rewrite
your jobs.

NOTE: Rails by default comes with an asynchronous queuing implementation that
runs jobs with an in-process thread pool. Jobs will run asynchronously, but any
jobs in the queue will be dropped upon restart.


Create and Enqueue Jobs
-----------------------

This section will provide a step-by-step guide to creating a job and enqueuing it.

### Create the Job

Active Job provides a Rails generator to create jobs. The following will create a
job in `app/jobs` (with an attached test case under `test/jobs`):

```bash
$ bin/rails generate job guests_cleanup
invoke  test_unit
create    test/jobs/guests_cleanup_job_test.rb
create  app/jobs/guests_cleanup_job.rb
```

You can also create a job that will run on a specific queue:

```bash
$ bin/rails generate job guests_cleanup --queue urgent
```

If you don't want to use a generator, you could create your own file inside of
`app/jobs`, just make sure that it inherits from `ApplicationJob`.

Here's what a job looks like:

```ruby
class GuestsCleanupJob < ApplicationJob
  queue_as :default

  def perform(*guests)
    # Do something later
  end
end
```

Note that you can define `perform` with as many arguments as you want.

If you already have an abstract class and its name differs from `ApplicationJob`, you can pass
the `--parent` option to indicate you want a different abstract class:

```bash
$ bin/rails generate job process_payment --parent=payment_job
```

```ruby
class ProcessPaymentJob < PaymentJob
  queue_as :default

  def perform(*args)
    # Do something later
  end
end
```

### Enqueue the Job

Enqueue a job using [`perform_later`][] and, optionally, [`set`][]. Like so:

```ruby
# Enqueue a job to be performed as soon as the queuing system is
# free.
GuestsCleanupJob.perform_later guest
```

```ruby
# Enqueue a job to be performed tomorrow at noon.
GuestsCleanupJob.set(wait_until: Date.tomorrow.noon).perform_later(guest)
```

```ruby
# Enqueue a job to be performed 1 week from now.
GuestsCleanupJob.set(wait: 1.week).perform_later(guest)
```

```ruby
# `perform_now` and `perform_later` will call `perform` under the hood so
# you can pass as many arguments as defined in the latter.
GuestsCleanupJob.perform_later(guest1, guest2, filter: 'some_filter')
```

That's it!

[`perform_later`]: https://api.rubyonrails.org/classes/ActiveJob/Enqueuing/ClassMethods.html#method-i-perform_later
[`set`]: https://api.rubyonrails.org/classes/ActiveJob/Core/ClassMethods.html#method-i-set

### Enqueue Jobs in Bulk

You can enqueue multiple jobs at once using [`perform_all_later`](https://api.rubyonrails.org/classes/ActiveJob.html#method-c-perform_all_later). For more details see [Bulk Enqueuing](#bulk-enqueuing).

Job Execution
-------------

For enqueuing and executing jobs in production you need to set up a queuing backend,
that is to say, you need to decide on a 3rd-party queuing library that Rails should use.
Rails itself only provides an in-process queuing system, which only keeps the jobs in RAM.
If the process crashes or the machine is reset, then all outstanding jobs are lost with the
default async backend. This may be fine for smaller apps or non-critical jobs, but most
production apps will need to pick a persistent backend.

### Backends

Active Job has built-in adapters for multiple queuing backends (Sidekiq,
Resque, Delayed Job, and others). To get an up-to-date list of the adapters
see the API Documentation for [`ActiveJob::QueueAdapters`][].

[`ActiveJob::QueueAdapters`]: https://api.rubyonrails.org/classes/ActiveJob/QueueAdapters.html

### Setting the Backend

You can easily set your queuing backend with [`config.active_job.queue_adapter`]:

```ruby
# config/application.rb
module YourApp
  class Application < Rails::Application
    # Be sure to have the adapter's gem in your Gemfile
    # and follow the adapter's specific installation
    # and deployment instructions.
    config.active_job.queue_adapter = :sidekiq
  end
end
```

You can also configure your backend on a per job basis:

```ruby
class GuestsCleanupJob < ApplicationJob
  self.queue_adapter = :resque
  # ...
end

# Now your job will use `resque` as its backend queue adapter, overriding what
# was configured in `config.active_job.queue_adapter`.
```

[`config.active_job.queue_adapter`]: configuring.html#config-active-job-queue-adapter

### Starting the Backend

Since jobs run in parallel to your Rails application, most queuing libraries
require that you start a library-specific queuing service (in addition to
starting your Rails app) for the job processing to work. Refer to library
documentation for instructions on starting your queue backend.

Here is a noncomprehensive list of documentation:

- [Sidekiq](https://github.com/mperham/sidekiq/wiki/Active-Job)
- [Resque](https://github.com/resque/resque/wiki/ActiveJob)
- [Sneakers](https://github.com/jondot/sneakers/wiki/How-To:-Rails-Background-Jobs-with-ActiveJob)
- [Sucker Punch](https://github.com/brandonhilkert/sucker_punch#active-job)
- [Queue Classic](https://github.com/QueueClassic/queue_classic#active-job)
- [Delayed Job](https://github.com/collectiveidea/delayed_job#active-job)
- [Que](https://github.com/que-rb/que#additional-rails-specific-setup)
- [Good Job](https://github.com/bensheldon/good_job#readme)
- [Solid Queue](https://github.com/basecamp/solid_queue?tab=readme-ov-file#solid-queue)

Queues
------

Most adapters support multiple queues. With Active Job you can schedule
the job to run on a specific queue using [`queue_as`][]:

```ruby
class GuestsCleanupJob < ApplicationJob
  queue_as :low_priority
  # ...
end
```

You can prefix the queue name for all your jobs using
[`config.active_job.queue_name_prefix`][] in `application.rb`:

```ruby
# config/application.rb
module YourApp
  class Application < Rails::Application
    config.active_job.queue_name_prefix = Rails.env
  end
end
```

```ruby
# app/jobs/guests_cleanup_job.rb
class GuestsCleanupJob < ApplicationJob
  queue_as :low_priority
  # ...
end

# Now your job will run on queue production_low_priority on your
# production environment and on staging_low_priority
# on your staging environment
```

You can also configure the prefix on a per job basis.

```ruby
class GuestsCleanupJob < ApplicationJob
  queue_as :low_priority
  self.queue_name_prefix = nil
  # ...
end

# Now your job's queue won't be prefixed, overriding what
# was configured in `config.active_job.queue_name_prefix`.
```

The default queue name prefix delimiter is '\_'.  This can be changed by setting
[`config.active_job.queue_name_delimiter`][] in `application.rb`:

```ruby
# config/application.rb
module YourApp
  class Application < Rails::Application
    config.active_job.queue_name_prefix = Rails.env
    config.active_job.queue_name_delimiter = '.'
  end
end
```

```ruby
# app/jobs/guests_cleanup_job.rb
class GuestsCleanupJob < ApplicationJob
  queue_as :low_priority
  # ...
end

# Now your job will run on queue production.low_priority on your
# production environment and on staging.low_priority
# on your staging environment
```

To control the queue from the job level you can pass a block to `queue_as`. The
block will be executed in the job context (so it can access `self.arguments`),
and it must return the queue name:

```ruby
class ProcessVideoJob < ApplicationJob
  queue_as do
    video = self.arguments.first
    if video.owner.premium?
      :premium_videojobs
    else
      :videojobs
    end
  end

  def perform(video)
    # Do process video
  end
end
```

```ruby
ProcessVideoJob.perform_later(Video.last)
```

If you want more control on what queue a job will be run you can pass a `:queue`
option to `set`:

```ruby
MyJob.set(queue: :another_queue).perform_later(record)
```

NOTE: Make sure your queuing backend "listens" on your queue name. For some
backends you need to specify the queues to listen to.

[`config.active_job.queue_name_delimiter`]: configuring.html#config-active-job-queue-name-delimiter
[`config.active_job.queue_name_prefix`]: configuring.html#config-active-job-queue-name-prefix
[`queue_as`]: https://api.rubyonrails.org/classes/ActiveJob/QueueName/ClassMethods.html#method-i-queue_as

Priority
--------------

Some adapters support priorities at the job level, where jobs can be prioritized relative to others in the queue or across all queues.

You can schedule a job to run with a specific priority using [`queue_with_priority`][]:

```ruby
class GuestsCleanupJob < ApplicationJob
  queue_with_priority 10
  # ...
end
```

Note that this will not have any effect with adapters that do not support priorities.

Similar to `queue_as`, you can also pass a block to `queue_with_priority` to be evaluated in the job context:

```ruby
class ProcessVideoJob < ApplicationJob
  queue_with_priority do
    video = self.arguments.first
    if video.owner.premium?
      0
    else
      10
    end
  end

  def perform(video)
    # Process video
  end
end
```

```ruby
ProcessVideoJob.perform_later(Video.last)
```

You can also pass a `:priority` option to `set`:

```ruby
MyJob.set(priority: 50).perform_later(record)
```

[`queue_with_priority`]: https://api.rubyonrails.org/classes/ActiveJob/QueuePriority/ClassMethods.html#method-i-queue_with_priority

Callbacks
---------

Active Job provides hooks to trigger logic during the life cycle of a job. Like
other callbacks in Rails, you can implement the callbacks as ordinary methods
and use a macro-style class method to register them as callbacks:

```ruby
class GuestsCleanupJob < ApplicationJob
  queue_as :default

  around_perform :around_cleanup

  def perform
    # Do something later
  end

  private
    def around_cleanup
      # Do something before perform
      yield
      # Do something after perform
    end
end
```

The macro-style class methods can also receive a block. Consider using this
style if the code inside your block is so short that it fits in a single line.
For example, you could send metrics for every job enqueued:

```ruby
class ApplicationJob < ActiveJob::Base
  before_enqueue { |job| $statsd.increment "#{job.class.name.underscore}.enqueue" }
end
```

### Available Callbacks

* [`before_enqueue`][]
* [`around_enqueue`][]
* [`after_enqueue`][]
* [`before_perform`][]
* [`around_perform`][]
* [`after_perform`][]

[`before_enqueue`]: https://api.rubyonrails.org/classes/ActiveJob/Callbacks/ClassMethods.html#method-i-before_enqueue
[`around_enqueue`]: https://api.rubyonrails.org/classes/ActiveJob/Callbacks/ClassMethods.html#method-i-around_enqueue
[`after_enqueue`]: https://api.rubyonrails.org/classes/ActiveJob/Callbacks/ClassMethods.html#method-i-after_enqueue
[`before_perform`]: https://api.rubyonrails.org/classes/ActiveJob/Callbacks/ClassMethods.html#method-i-before_perform
[`around_perform`]: https://api.rubyonrails.org/classes/ActiveJob/Callbacks/ClassMethods.html#method-i-around_perform
[`after_perform`]: https://api.rubyonrails.org/classes/ActiveJob/Callbacks/ClassMethods.html#method-i-after_perform

Please note that when enqueuing jobs in bulk using `perform_all_later`,
callbacks such as `around_enqueue` will not be triggered on the individual jobs.
See [Bulk Enqueuing Callbacks](#bulk-enqueue-callbacks).

Bulk Enqueuing
--------------

You can enqueue multiple jobs at once using
[`perform_all_later`](https://api.rubyonrails.org/classes/ActiveJob.html#method-c-perform_all_later).
Bulk enqueuing reduces the number of round trips to the queue data store (like
Redis or a database), making it a more performant operation than enqueuing the
same jobs individually.

`perform_all_later` is a top-level API on Active Job. It accepts instantiated
jobs as arguments (note that this is different from `perform_later`).
`perform_all_later` does call `perform` under the hood. The arguments passed to
`new` will be passed on to `perform` when it's eventually called.

Here is an example calling `perform_all_later` with `GuestCleanupJob` instances:

```ruby
# Create jobs to pass to `perform_all_later`.
# The arguments to `new` are passed on to `perform`
guest_cleanup_jobs = Guest.all.map { |guest| GuestsCleanupJob.new(guest) }

# Will enqueue a separate job for each instance of `GuestCleanupJob`
ActiveJob.perform_all_later(guest_cleanup_jobs)

# Can also use `set` method to configure options before bulk enqueuing jobs.
guest_cleanup_jobs = Guest.all.map { |guest| GuestsCleanupJob.new(guest).set(wait: 1.day) }

ActiveJob.perform_all_later(guest_cleanup_jobs)
```

`perform_all_later` logs the number of jobs successfully enqueued, for example
if `Guest.all.map` above resulted in 3 `guest_cleanup_jobs`, it would log
`Enqueued 3 jobs to Async (3 GuestsCleanupJob)` (assuming all were enqueued).

The return value of `perform_all_later` is `nil`. Note that this is different
from `perform_later`, which returns the instance of the queued job class.

### Enqueue Multiple Active Job Classes

With `perform_all_later`, it's also possible to enqueue different Active Job
class instances in the same call. For example:

```ruby
class ExportDataJob < ApplicationJob
  def perform(*args)
    # Export data
  end
end

class NotifyGuestsJob < ApplicationJob
  def perform(*guests)
    # Email guests
  end
end

# Instantiate job instances
cleanup_job = GuestsCleanupJob.new(guest)
export_job = ExportDataJob.new(data)
notify_job = NotifyGuestsJob.new(guest)

# Enqueues job instances from multiple classes at once
ActiveJob.perform_all_later(cleanup_job, export_job, notify_job)
```

### Bulk Enqueue Callbacks

When enqueuing jobs in bulk using `perform_all_later`, callbacks such as
`around_enqueue` will not be triggered on the individual jobs. This behavior is
in line with other Active Record bulk methods. Since callbacks run on individual
jobs, they can't take advantage of the bulk nature of this method.

However, the `perform_all_later` method does fire an
[`enqueue_all.active_job`](active_support_instrumentation.html#enqueue-all-active-job)
event which you can subscribe to using `ActiveSupport::Notifications`.

The method
[`successfully_enqueued?`](https://api.rubyonrails.org/classes/ActiveJob/Core.html#method-i-successfully_enqueued-3F)
can be used to find out if a given job was successfully enqueued.

### Queue Backend Support

For `perform_all_later`, bulk enqueuing needs to be backed by the [queue
backend](#backends).

For example, Sidekiq has a `push_bulk` method, which can push a large number of
jobs to Redis and prevent the round trip network latency. GoodJob also supports
bulk enqueuing with the `GoodJob::Bulk.enqueue` method. The new queue backend
[`Solid Queue`](https://github.com/basecamp/solid_queue/pull/93) has added
support for bulk enqueuing as well.

If the queue backend does *not* support bulk enqueuing, `perform_all_later` will
enqueue jobs one by one.

Action Mailer
------------

One of the most common jobs in a modern web application is sending emails outside
of the request-response cycle, so the user doesn't have to wait on it. Active Job
is integrated with Action Mailer so you can easily send emails asynchronously:

```ruby
# If you want to send the email now use #deliver_now
UserMailer.welcome(@user).deliver_now

# If you want to send the email through Active Job use #deliver_later
UserMailer.welcome(@user).deliver_later
```

NOTE: Using the asynchronous queue from a Rake task (for example, to
send an email using `.deliver_later`) will generally not work because Rake will
likely end, causing the in-process thread pool to be deleted, before any/all
of the `.deliver_later` emails are processed. To avoid this problem, use
`.deliver_now` or run a persistent queue in development.


Internationalization
--------------------

Each job uses the `I18n.locale` set when the job was created. This is useful if you send
emails asynchronously:

```ruby
I18n.locale = :eo

UserMailer.welcome(@user).deliver_later # Email will be localized to Esperanto.
```


Supported Types for Arguments
----------------------------

ActiveJob supports the following types of arguments by default:

  - Basic types (`NilClass`, `String`, `Integer`, `Float`, `BigDecimal`, `TrueClass`, `FalseClass`)
  - `Symbol`
  - `Date`
  - `Time`
  - `DateTime`
  - `ActiveSupport::TimeWithZone`
  - `ActiveSupport::Duration`
  - `Hash` (Keys should be of `String` or `Symbol` type)
  - `ActiveSupport::HashWithIndifferentAccess`
  - `Array`
  - `Range`
  - `Module`
  - `Class`

### GlobalID

Active Job supports [GlobalID](https://github.com/rails/globalid/blob/main/README.md) for parameters. This makes it possible to pass live
Active Record objects to your job instead of class/id pairs, which you then have
to manually deserialize. Before, jobs would look like this:

```ruby
class TrashableCleanupJob < ApplicationJob
  def perform(trashable_class, trashable_id, depth)
    trashable = trashable_class.constantize.find(trashable_id)
    trashable.cleanup(depth)
  end
end
```

Now you can simply do:

```ruby
class TrashableCleanupJob < ApplicationJob
  def perform(trashable, depth)
    trashable.cleanup(depth)
  end
end
```

This works with any class that mixes in `GlobalID::Identification`, which
by default has been mixed into Active Record classes.

### Serializers

You can extend the list of supported argument types. You just need to define your own serializer:

```ruby
# app/serializers/money_serializer.rb
class MoneySerializer < ActiveJob::Serializers::ObjectSerializer
  # Checks if an argument should be serialized by this serializer.
  def serialize?(argument)
    argument.is_a? Money
  end

  # Converts an object to a simpler representative using supported object types.
  # The recommended representative is a Hash with a specific key. Keys can be of basic types only.
  # You should call `super` to add the custom serializer type to the hash.
  def serialize(money)
    super(
      "amount" => money.amount,
      "currency" => money.currency
    )
  end

  # Converts serialized value into a proper object.
  def deserialize(hash)
    Money.new(hash["amount"], hash["currency"])
  end
end
```

and add this serializer to the list:

```ruby
# config/initializers/custom_serializers.rb
Rails.application.config.active_job.custom_serializers << MoneySerializer
```

Note that autoloading reloadable code during initialization is not supported. Thus it is recommended
to set-up serializers to be loaded only once, e.g. by amending `config/application.rb` like this:

```ruby
# config/application.rb
module YourApp
  class Application < Rails::Application
    config.autoload_once_paths << Rails.root.join('app', 'serializers')
  end
end
```

Exceptions
----------

Exceptions raised during the execution of the job can be handled with
[`rescue_from`][]:

```ruby
class GuestsCleanupJob < ApplicationJob
  queue_as :default

  rescue_from(ActiveRecord::RecordNotFound) do |exception|
    # Do something with the exception
  end

  def perform
    # Do something later
  end
end
```

If an exception from a job is not rescued, then the job is referred to as "failed".

[`rescue_from`]: https://api.rubyonrails.org/classes/ActiveSupport/Rescuable/ClassMethods.html#method-i-rescue_from

### Retrying or Discarding Failed Jobs

A failed job will not be retried, unless configured otherwise.

It's possible to retry or discard a failed job by using [`retry_on`] or
[`discard_on`], respectively. For example:

```ruby
class RemoteServiceJob < ApplicationJob
  retry_on CustomAppException # defaults to 3s wait, 5 attempts

  discard_on ActiveJob::DeserializationError

  def perform(*args)
    # Might raise CustomAppException or ActiveJob::DeserializationError
  end
end
```

[`discard_on`]: https://api.rubyonrails.org/classes/ActiveJob/Exceptions/ClassMethods.html#method-i-discard_on
[`retry_on`]: https://api.rubyonrails.org/classes/ActiveJob/Exceptions/ClassMethods.html#method-i-retry_on

### Deserialization

GlobalID allows serializing full Active Record objects passed to `#perform`.

If a passed record is deleted after the job is enqueued but before the `#perform`
method is called Active Job will raise an [`ActiveJob::DeserializationError`][]
exception.

[`ActiveJob::DeserializationError`]: https://api.rubyonrails.org/classes/ActiveJob/DeserializationError.html

Job Testing
--------------

You can find detailed instructions on how to test your jobs in the
[testing guide](testing.html#testing-jobs).

Debugging
---------

If you need help figuring out where jobs are coming from, you can enable [verbose logging](debugging_rails_applications.html#verbose-enqueue-logs).
