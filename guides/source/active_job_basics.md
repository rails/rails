**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON
<https://guides.rubyonrails.org>.**

Active Job Basics
=================

This guide provides you with all you need to get started in creating, enqueuing
and executing background jobs.

After reading this guide, you will know:

* How to create and enqueue jobs.
* How to configure and use Solid Queue.
* How to run jobs in the background.
* How to send emails from your application asynchronously.
* How to write jobs that pause and resume progress during deploys.

--------------------------------------------------------------------------------

What is Active Job?
-------------------

The Active Job Rails framework allows you to declare background jobs and execute
them on a queuing backend. It provides a consistent, high-level interface for
common asynchronous tasks such as sending emails, processing data, or performing
periodic maintenance tasks.

The goal of background jobs is to move long-running or non-critical work out of
the HTTP request-response cycle and into a background queue (such as the default
Solid Queue), and keep the web requests fast and responsive. This separation
allows applications to perform work asynchronously, scale background processing
independently, and execute multiple tasks in parallel without blocking user
interactions.

Creating Jobs
-------------

This section provides a step-by-step guide for defining a job Ruby class and
then using the `perform_*` method to enqueue work to be executed in the
background.

### Defining a Job

Active Job provides a Rails generator to create jobs. The following will create
a job in the `app/jobs` directory (with tests under `test/jobs`):

```bash
$ bin/rails generate job guests_cleanup
invoke  test_unit
create    test/jobs/guests_cleanup_job_test.rb
create  app/jobs/guests_cleanup_job.rb
```

If you don't want to use a generator, you can create your own file inside of
`app/jobs` and define a class that inherits from `ApplicationJob`.

Here's what a job looks like:

```ruby
class GuestsCleanupJob < ApplicationJob
  queue_as :default

  def perform(*guests)
    # Do something later
  end
end
```

Note that you can define the `perform` method inside a job class with as many
arguments as you want.

If your application uses a custom abstract job base class instead of
`ApplicationJob`, you can use the `--parent` option with the generator. The
parent class must itself inherit from `ApplicationJob`. This can be useful for
grouping related functionality in one place.

For example, given a custom abstract job class using
[queue_as](https://api.rubyonrails.org/classes/ActiveJob/QueueName/ClassMethods.html#method-i-queue_as):

```ruby
class PaymentJob < ApplicationJob
  queue_as :payments
end
```

You can generate a new job that inherits from it:

```bash
$ bin/rails generate job process_payment --parent=payment_job
```

The above creates a class that will use the `payments` queue:

```ruby
class ProcessPaymentJob < PaymentJob
  def perform(*args)
    # Do something later, uses the "payments" queue
  end
end
```

### Calling the `perform_*` Methods

Once you have defined a job class with a `perform` method, you'd typically call
it using [`perform_later`][] to enqueue the work to be executed on a queuing
backend. Or use [`perform_now`][] if you want the job to execute immediately
without queueing. Both `perform_later` and `perform_now` call `perform` under
the hood.

In the examples below, the methods can be called from anywhere in your Rails
application, most commonly from controllers, models, or other jobs.

```ruby
# To run a job immediately without enqueuing it
GuestsCleanupJob.perform_now(guest)

# To enqueue a job to be performed later
GuestsCleanupJob.perform_later(guest)
```

Use the
[`set`](https://api.rubyonrails.org/classes/ActiveJob/Core/ClassMethods.html#method-i-set)
method to specify exactly when to perform a job.

```ruby
# Enqueue a job to be performed tomorrow at noon
GuestsCleanupJob.set(wait_until: Date.tomorrow.noon).perform_later(guest)

# Enqueue a job to be performed one week from now
GuestsCleanupJob.set(wait: 1.week).perform_later(guest)
```

Since both `perform_now` and `perform_later` forward their arguments to
`perform`, you can pass as many arguments as defined in `perform`, including
keyword arguments:

```ruby
GuestsCleanupJob.perform_later(guest1, guest2, filter: "some_filter")
```

#### Example: Sending Email

One of the most common jobs in a modern web application is sending emails to
users. Active Job can do this outside of the request-response cycle, so the user
doesn't have to wait on it. Active Job is integrated with Action Mailer so you
can easily send emails asynchronously:

```ruby
# If you want to send the email now, use #deliver_now
UserMailer.welcome(@user).deliver_now

# If you want to send the email asynchronously, use #deliver_later
UserMailer.welcome(@user).deliver_later
```

The `deliver_now` and `deliver_later` methods are Action Mailer's counterparts
to `perform_now` and `perform_later`. Under the hood, `deliver_later` works by
enqueuing an `ActionMailer::MailDeliveryJob` — a built-in Active Job job that
Rails provides — which goes through the same queuing pipeline as any job you
define yourself, and will eventually call the `perform` method in your Job
class.

[`perform_now`]:
    https://api.rubyonrails.org/classes/ActiveJob/Execution.html#method-i-perform_now
[`perform_later`]:
 https://api.rubyonrails.org/classes/ActiveJob/Enqueuing/ClassMethods.html#method-i-perform_later
[`set`]:
    https://api.rubyonrails.org/classes/ActiveJob/Core/ClassMethods.html#method-i-set

### Supported Argument Types for `perform`

ActiveJob supports the following types of arguments by default:

  - Basic types (`NilClass`, `String`, `Integer`, `Float`, `BigDecimal`,
    `TrueClass`, `FalseClass`)
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

Active Job supports
[GlobalID](https://github.com/rails/globalid/blob/main/README.md) for arguments.
This makes it possible to pass live Active Record objects to your job instead of
class/id pairs, which you then have to manually deserialize.

For example, instead of having to do something like this:

```ruby
class GuestsCleanupJob < ApplicationJob
  def perform(guests_class, guests_id, depth)
    guests = guests_class.constantize.find(guests_id)
    guest.cleanup(depth)
  end
end
```

Using GlobalID, you can simply do:

```ruby
class GuestsCleanupJob < ApplicationJob
  def perform(guest, depth)
    guest.cleanup(depth)
  end
end
```

This works with any class that mixes in `GlobalID::Identification`, which is
mixed into Active Record by default.

#### Add Custom Types by Defining Serializers

You can extend the list of supported argument types by defining your own
serializer for your custom types. A serializer needs three methods: `serialize`,
`deserialize`, and `klass`.

The `serialize` method converts an object into a simpler representation using
only supported types. The recommended approach is to return a Hash with string
keys, calling `super` to let Active Job merge in the serializer's type
information:

```ruby
# app/serializers/money_serializer.rb
class MoneySerializer < ActiveJob::Serializers::ObjectSerializer
  def serialize(money)
    super(
      "amount" => money.amount,
      "currency" => money.currency
    )
  end

  def deserialize(hash)
    Money.new(hash["amount"], hash["currency"])
  end

  def klass
    Money
  end
end
```

The `deserialize` method receives that hash and reconstructs the original
object. The `klass` method returns the class this serializer handles so Active
Job can use it to determine which serializer to apply to a given argument.

Once a serializer is defined, it needs to be added to the list of serializers
Rails knows about:

```ruby
# config/initializers/custom_serializers.rb
Rails.application.config.active_job.custom_serializers << MoneySerializer
```

Custom Active Job serializers are registered during application initialization
and are expected to remain stable for the lifetime of the process. Reloadable
autoloading is not supported in this context.

To ensure serializers are loaded only once (and not reloaded in development),
place them in an autoload_once_paths directory, such as:

```ruby
# config/application.rb
module YourApp
  class Application < Rails::Application
    config.autoload_once_paths << "#{root}/app/serializers"
  end
end
```

Enqueuing Jobs
--------------

### Naming Queues

With Active Job you can schedule the job to run on a specific queue using
[`queue_as`][]:

```ruby
class GuestsCleanupJob < ApplicationJob
  queue_as :low_priority
  # ...
end
```

When using a generator, you can also create a job that will run on a specific
queue:

```bash
$ bin/rails generate job guests_cleanup --queue low_priority
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
```

Now your job will run on queue `production_low_priority` on your production
environment and on `staging_low_priority` on your staging environment.

You can also configure the prefix on a per job basis.

```ruby
# This will override the global prefix and this job won't be prefixed.
class GuestsCleanupJob < ApplicationJob
  queue_as :low_priority
  self.queue_name_prefix = nil
  # ...
end
```

The default queue name prefix delimiter is '_'.  This can be changed by setting
[`config.active_job.queue_name_delimiter`][] in `application.rb`:

```ruby
# config/application.rb
module YourApp
  class Application < Rails::Application
    config.active_job.queue_name_prefix = Rails.env
    config.active_job.queue_name_delimiter = "."
  end
end
```

```ruby
# app/jobs/guests_cleanup_job.rb
class GuestsCleanupJob < ApplicationJob
  queue_as :low_priority
  # ...
end
```

Now the queue will be named `production.low_priority` or `staging.low_priority`.

You can control the queue at the job level by passing a block to `queue_as`. The
block will be executed in the job context (so it can access `self.arguments`),
and it's return value must be a queue name. For example:

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
last_video = Video.last
ProcessVideoJob.perform_later(last_video)
```

If you want more control on what queue a job will be run you can pass a `:queue`
option to `set`:

```ruby
MyJob.set(queue: :another_queue).perform_later(record)
```

TIP: One way to name queues is based on latency. So instead of "critical",
"default", or "low", queues could be named "within_30_seconds",
"within_5_minutes", and "within_1_hour". This can be enforced like a contract by
configuring your queuing backend to notify your engineering team if a job sits
in a given queue longer than the corresponding time.

NOTE: If you choose to use an [alternate queuing
backend](#alternate-queuing-backends) you may need to specify the queues to
listen to.

[`config.active_job.queue_name_delimiter`]:
    configuring.html#config-active-job-queue-name-delimiter
[`config.active_job.queue_name_prefix`]:
    configuring.html#config-active-job-queue-name-prefix
[`queue_as`]:
    https://api.rubyonrails.org/classes/ActiveJob/QueueName/ClassMethods.html#method-i-queue_as

### Queue Priority

You can schedule a job to run with a specific priority using
`queue_with_priority`:

```ruby
class GuestsCleanupJob < ApplicationJob
  queue_with_priority 10
  # ...
end
```

Solid Queue, the default queuing backend, prioritizes jobs based on the [order
of the queues](#queue-order). If you're using Solid Queue with both queue order
and priority option, the queue order will take precedence, and the priority
option will only apply within each queue.

Other queuing backends may allow jobs to be prioritized relative to others
within the same queue or across multiple queues. You can check the documentation
of your backend for the specifics.

Similar to `queue_as`, you can also pass a block to `queue_with_priority` to be
evaluated in the job context:

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
last_video = Video.last
ProcessVideoJob.perform_later(last_video)
```

You can also pass a `:priority` option to `set`:

```ruby
MyJob.set(priority: 50).perform_later(record)
```

NOTE: If a lower priority number performs before or after a higher priority
number depends on the adapter implementation. Refer to the documentation of your
backend for more information. Adapter authors are encouraged to treat a lower
number as more important, as a convention.

[`queue_with_priority`]:
    https://api.rubyonrails.org/classes/ActiveJob/QueuePriority/ClassMethods.html#method-i-queue_with_priority

### Bulk Enqueuing

You can enqueue multiple jobs at once using
[`perform_all_later`](https://api.rubyonrails.org/classes/ActiveJob.html#method-c-perform_all_later).
Bulk enqueuing reduces the number of round trips to the queue data store (such
as Redis or a database), making it a more performant operation than enqueuing
the same jobs individually.

The `perform_all_later` method accepts instantiated jobs as arguments (note that
this is different from `perform_later`) and calls `perform` under the hood. The
arguments passed to `new`, when creating new job instances, will be passed on to
`perform` when it's eventually called. For example:

```ruby
# Create jobs to pass to `perform_all_later`.
# The arguments to `new` are passed on to `perform`
cleanup_jobs = Guest.all.map { |guest| GuestsCleanupJob.new(guest) }

# Will enqueue a separate job for each instance of `GuestsCleanupJob`
ActiveJob.perform_all_later(cleanup_jobs)

# Can also use `set` method to configure options before bulk enqueuing jobs.
cleanup_jobs = Guest.all.map { |guest| GuestsCleanupJob.new(guest).set(wait: 1.day) }

ActiveJob.perform_all_later(cleanup_jobs)
```

The `perform_all_later` call logs the number of jobs successfully enqueued, for
example if `Guest.all.map` above resulted in 3 `cleanup_jobs`, it would log
`Enqueued 3 jobs to Async (3 GuestsCleanupJob)` (assuming all were enqueued).

The return value of `perform_all_later` is `nil`. Note that this is different
from `perform_later`, which returns the instance of the queued job class.

#### Enqueue Multiple Active Job Classes

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

#### Bulk Enqueue Callbacks

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

#### Queue Backend Support

For `perform_all_later`, bulk enqueuing needs to be backed by the queue backend.
Solid Queue, the default queue backend, supports bulk enqueuing using
`enqueue_all`.

[Other backends](#alternate-queuing-backends) like Sidekiq have a `push_bulk`
method, which the Sidekiq adapter users. internally to push a large number of
jobs to Redis and prevent the round trip network latency. GoodJob also supports
bulk enqueuing with the `GoodJob::Bulk.enqueue` method.

If the queue backend does *not* support bulk enqueuing, `perform_all_later` will
enqueue jobs one by one.

Callbacks
---------

Active Job provides hooks to trigger logic during the life cycle of a job. Like
other callbacks in Rails, you can implement them as ordinary methods and
register them using a class-level method:

```ruby#4
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

These class-level methods also accept a block, which works well when the
callback logic is short enough to fit on a single line. For example, sending
metrics for every enqueued job:

```ruby
class ApplicationJob < ActiveJob::Base
  before_enqueue { |job| Rails.logger.info "Enqueuing #{job.class.name}" }
end
```

### Available Callbacks

There are several callbacks that Active Job supports.

* [`before_enqueue`][] runs before a job is enqueued.
* [`around_enqueue`][] wraps the enqueuing process, allowing logic to run both
  before and after.
* [`after_enqueue`][] runs after a job is enqueued.

For example:

```ruby
class GuestsCleanupJob < ApplicationJob
  before_enqueue { |job| Rails.logger.info "About to enqueue #{job.class.name}" }
  around_enqueue { |job, block| block.call }
  after_enqueue  { |job| Rails.logger.info "Successfully enqueued #{job.class.name}" }
end
```

* [`before_perform`][] runs before a job is performed.
* [`around_perform`][] wraps the perform process, allowing logic to run both
  before and after.
* [`after_perform`][] runs after a job is performed.

For example:

```ruby
class GuestsCleanupJob < ApplicationJob
  before_perform { |job| Rails.logger.info "About to perform #{job.class.name}" }
  around_perform { |job, block| block.call }
  after_perform  { |job| Rails.logger.info "#{job.class.name} performed successfully" }
end
```

Lastly, [`after_discard`][] runs when a job is discarded due to an unhandled
exception:

```ruby
class GuestsCleanupJob < ApplicationJob
  after_discard { |job, exception| Rails.logger.error "#{job.class.name} discarded: #{exception.message}" }
end
```

Please note that when enqueuing jobs in bulk using `perform_all_later`,
callbacks such as `around_enqueue` will not be triggered on the individual jobs.
See [Bulk Enqueuing Callbacks](#bulk-enqueue-callbacks).

[`before_enqueue`]:
 https://api.rubyonrails.org/classes/ActiveJob/Callbacks/ClassMethods.html#method-i-before_enqueue
[`around_enqueue`]:
https://api.rubyonrails.org/classes/ActiveJob/Callbacks/ClassMethods.html#method-i-around_enqueue
[`after_enqueue`]:
    https://api.rubyonrails.org/classes/ActiveJob/Callbacks/ClassMethods.html#method-i-after_enqueue
[`before_perform`]:
https://api.rubyonrails.org/classes/ActiveJob/Callbacks/ClassMethods.html#method-i-before_perform
[`around_perform`]:
https://api.rubyonrails.org/classes/ActiveJob/Callbacks/ClassMethods.html#method-i-around_perform
[`after_perform`]:
https://api.rubyonrails.org/classes/ActiveJob/Callbacks/ClassMethods.html#method-i-after_perform
[`after_discard`]:
https://api.rubyonrails.org/classes/ActiveJob/Exceptions/ClassMethods.html#method-i-after_discard

### Halting Callbacks

You can halt the callback chain by throwing `:abort`. This works the same way as
in Active Record and other Rails callbacks. For example, to prevent a job from
being enqueued based on a condition:

```ruby
class GuestsCleanupJob < ApplicationJob
  before_enqueue do |job|
    throw :abort if ENV.fetch("DISABLE_GUESTS_CLEANUP_JOB", true)
  end

  def perform(guest)
    # ...
  end
end
```

When `:abort` is thrown in a `before_enqueue` callback, the job will not be
enqueued and `perform_later` will return `false`. When thrown in a
`before_perform` callback, the job will not be performed. It will also skip the
execution of any subsequent before, around and after callbacks.

NOTE: Throwing an `:abort` does not trigger `after_discard`. The `after_discard`
callback is specifically tied to the `discard_on` mechanism.

Job Continuations
-----------------

Active Job Continuations allow jobs to be split into resumable steps, so that
long-running jobs can make progress after interruptions. When using
continuations, the job automatically resumes from the last completed step,
instead of restarting from the beginning.

To use continuations, include the `ActiveJob::Continuable` module in your Job
class. You can then define each step inside the `perform` method using
[`step`](https://api.rubyonrails.org/classes/ActiveJob/Continuation/Step.html).

```ruby
class ProcessImportJob < ApplicationJob
  include ActiveJob::Continuable

  def perform(import_id)
    # Always runs on job start, even when resuming from an interrupted step.
    @import = Import.find(import_id)

    # Step defined using a block
    step :initialize do
      @import.initialize
    end

    step :process do
      @import.records.find_each { |record| record.process }
    end

    # Step defined by referencing a method
    step :finalize
  end

  private
    def finalize
      @import.finalize
    end
end
```

Each step can be declared with a block or by referencing a method name. The
block will be called with the step object as an argument. Methods can either
take no arguments or a single argument for the step object.

Steps are executed as soon as they are encountered. Code that is not part of a
step will be executed on each job run. If a job is interrupted, previously
completed steps will be skipped. If a step is in progress, it will be restarted
or resumed with the last recorded cursor if using cursors.

### Using a Cursor

Steps can also use an optional
[cursor](https://api.rubyonrails.org/classes/ActiveJob/Continuation.html#class-ActiveJob::Continuation-label-Cursors)
to track progress *within* the step. The code in the step is responsible for
using the cursor to continue from the appropriate location after an
interruption. For example:

```ruby
class ProcessImportJob < ApplicationJob
  include ActiveJob::Continuable

  def perform(import_id)
    # Always runs on job start, even when resuming from an interrupted step.
    @import = Import.find(import_id)

    # Step with a cursor
    step :process do |step|
      @import.records.find_each(start: step.cursor) do |record|
        record.process
        step.advance!
      end
    end

  end
end
```

In the above example, the cursor tracks the `id` of the last successfully
processed record. If the job is interrupted midway through a large import, it
resumes from where it left off rather than reprocessing records from the
beginning, passing the saved cursor value to `find_each`.

### Job Attributes

The continuable steps may need to share state. Active Job attributes let jobs
declare typed state using the [`Active Model Attributes API`][], so that values
computed in one step are available in later steps. Attribute values are
serialized when the job is interrupted or retried, and restored when the job
resumes. `ActiveJob::Continuable` includes [`ActiveJob::Attributes`][], so
continuable jobs can declare attributes directly.

In the example below, the `payment_token` and `billing_profile_id` attributes
are declared at the class level so their values are preserved across
interruptions. They are computed in `tokenize_payment_instrument` step and used
in the `submit_enrollment` step later:

```ruby
class SubmitEnrollmentJob < ApplicationJob
  include ActiveJob::Continuable

  attribute :payment_token, :string
  attribute :billing_profile_id, :integer

  def perform(enrollment)
    step :tokenize_payment_instrument do
      self.payment_token = PaymentGateway.tokenize(enrollment.user.payment_instrument)
    end

    step :create_billing_profile do
      self.billing_profile_id = BillingProfileApi.create(customer_id: enrollment.user_id)
    end

    # payment_token and billing_profile_id are restored from the serialized
    # job state when resuming here after an interruption.
    step :submit_enrollment do
      submission_id = EnrollmentApi.submit(enrollment, payment_token, billing_profile_id)
      enrollment.update!(status: "processing", submission_id: submission_id)
    end
  end
end
```

Attribute values must be serializable as Active Job supported argument types. For more details, see [`ActiveJob::Attributes`][].

[`Active Model Attributes API`]:
    https://api.rubyonrails.org/classes/ActiveModel/Attributes.html
[`ActiveJob::Attributes`]:
    https://api.rubyonrails.org/classes/ActiveJob/Attributes.html

Job Continuations make it easier to build long-running or multi-phase jobs that
can safely pause and resume without losing progress. For more details, see
[ActiveJob::Continuation](https://api.rubyonrails.org/classes/ActiveJob/Continuation.html).

Default Backend: Solid Queue
------------------------------

Solid Queue is a database-backed queue backend for Active Job and the default
queue backend for Rails version 8.0 onwards. Rather than requiring a separate
infrastructure dependency like Redis, Solid Queue uses your existing database to
persist and process jobs. It supports delayed jobs, job priorities, concurrency
controls, recurring jobs, and bulk enqueuing.

### Setup and Default Configuration

Solid Queue is already configured for production by default. For example, if you
open `config/environments/production.rb`, you will see the following:

```ruby#3
# config/environments/production.rb
# Replace the default in-process and non-durable queuing backend for Active Job.
config.active_job.queue_adapter = :solid_queue
config.solid_queue.connects_to = { database: { writing: :queue } }
```

Additionally, the database connection for the `queue` database is configured in
`config/database.yml`:

```yaml#8
# config/database.yml
# Store production database in the storage/ directory, which by default
# is mounted as a persistent Docker volume in config/deploy.yml.
production:
  primary:
    <<: *default
    database: storage/production.sqlite3
  queue:
    <<: *default
    database: storage/production_queue.sqlite3
    migrations_paths: db/queue_migrate
```

NOTE: The key `queue` from the database configuration needs to match the key
used in the configuration for `config.solid_queue.connects_to` (as highlighted
in the code snippets above).

In order to start using Solid Queue, run `db:prepare` so your database has Solid
Queue related tables:

```bash
$ bin/rails db:prepare
```

TIP: You can find the schema for the `queue` database in `db/queue_schema.rb`,
which is generated automatically. It will contain tables like
`solid_queue_jobs`, `solid_queue_recurring_executions`,
`solid_queue_scheduled_executions`, and more.

Finally, to start the queue and start processing jobs you can run:

```bash
$ bin/jobs start
```

#### Development Environment

Rails provides an asynchronous in-process queuing backend, which keeps the jobs
in memory. With the default `async` adapter, if the process crashes or the
machine is reset, then all outstanding jobs are lost. This can be acceptable for
non-critical jobs in development.

Alternatively, you can use Solid Queue in development. It can be configured in
the same way as in the production environment:

```ruby#3
# config/environments/development.rb
config.active_job.queue_adapter = :solid_queue
config.solid_queue.connects_to = { database: { writing: :queue } }
```

Add `queue` to the development database configuration:

```yml
# config/database.yml
development:
  primary:
    <<: *default
    database: storage/development.sqlite3
  queue:
    <<: *default
    database: storage/development_queue.sqlite3
    migrations_paths: db/queue_migrate
```

### Workers, Dispatchers, Supervisors

Solid Queue uses three types of processes to handle job queueing and execution:

1. Workers poll queues for jobs that are ready to run and execute them.
2. Dispatchers handle scheduled jobs — they check for jobs due to run in the
future and move them into the ready queue for workers to pick up.
3. A Supervisor manages both workers and dispatchers, by forking and monitoring
   them.

When you run `bin/jobs start`, you're starting the supervisor process, which in
turn forks and manages the workers and dispatchers according to the
configuration in `config/queue.yml`. Here is an example of the default
configuration:

```yaml
# config/queue.yml
default: &default
  dispatchers:
    - polling_interval: 1
      batch_size: 500
  workers:
    - queues: "*"
      threads: 3
      processes: <%= ENV.fetch("JOB_CONCURRENCY", 1) %>
      polling_interval: 0.1
```

The configuration in `config/queue.yml` is optional. If no configuration is
provided, Solid Queue will run with one dispatcher and one worker with default
settings. Below are some of the configuration options you can set along with
their default values`:

| **Option**                           | **Description**                                                                                     | **Default Value**                             |
| ------------------------------------ | --------------------------------------------------------------------------------------------------- | --------------------------------------------- |
| **polling_interval**                 | Time in seconds workers/dispatchers wait before checking for more jobs.                             | 1 second (dispatchers), 0.1 seconds (workers) |
| **batch_size**                       | Number of jobs dispatched in a batch.                                                               | 500                                           |
| **concurrency_maintenance_interval** | Time in seconds the dispatcher waits before checking for blocked jobs that can be unblocked.        | 600 seconds                                   |
| **queues**                           | List of queues workers fetch jobs from. Supports `*` for all queues or queue name prefixes.         | `*`                                           |
| **threads**                          | Maximum size of the thread pool for each worker. Determines how many jobs a worker fetches at once. | 3                                             |
| **processes**                        | Number of worker processes forked by the supervisor. Each process can dedicate a CPU core.          | 1                                             |
| **concurrency_maintenance**          | Whether the dispatcher performs concurrency maintenance work.                                       | true                                          |

You can read more about these [configuration options in the Solid Queue
documentation](https://github.com/rails/solid_queue?tab=readme-ov-file#configuration).
There are also [additional configuration
options](https://github.com/rails/solid_queue?tab=readme-ov-file#other-configuration-settings)
that can be set in `config/<environment>.rb` to further configure Solid Queue in
your Rails Application.

### Queue Order and Priority

Solid Queue offers two distinct mechanisms for controlling the order in which
jobs are processed: queue ordering and numeric priorities. Understanding how
they interact is important for getting the behavior you expect.

#### Queue Order

Queue order is the primary way to prioritize work in Solid Queue. The order in
which queues are listed in `config/queue.yml` for a worker determines the
polling order. A worker will not pull jobs from a lower priority queue (listed
later in the array) until all higher priority queues are empty:

```yaml
production:
  workers:
    - queues: [critical, default, low]
      threads: 5
```

With the above configuration, no jobs will be taken from the `default` queue
while the `critical` queue has jobs waiting, and no jobs will be taken from
`low` while either `critical` or `default` has jobs waiting. Solid Queue has
strict ordering (unlike other queuing backend which may allow relative weights
so that lower priority queues still receive a proportional share of processing
time). It is possible for lower queues to be starved if higher queues are
consistently busy.

It is possible to use a wildcard `*` within queue names. For example if the
worker is configured with `queues:[active_storage*, mailers]`, it will fetch
jobs from queues starting with "active_storage", such as  the
`active_storage_analyze` queue and `active_storage_transform` queue. Only when
no jobs remain in the `active_storage`-prefixed queues will workers move on to
the `mailers` queue.

WARNING: Using wildcard queue names (e.g., `queues: active_storage*`) can slow
down polling performance in SQLite and PostgreSQL due to the need for a
`DISTINCT` query to identify all matching queues, which can be slow on large
tables. For better performance, it’s best to specify exact queue names instead
of using wildcards.

#### Numeric Priorities

Numeric priorities apply *within* a single queue. You can assign numeric
priorities to jobs using `queue_with_priority`. Lower numbers indicate higher
priority, with a default of 0:

```ruby
class CriticalReportJob < ApplicationJob
  queue_as :default
  queue_with_priority 0
end

class RoutineCleanupJob < ApplicationJob
  queue_as :default
  queue_with_priority 10
end
```

When both jobs are in the `default` queue, `CriticalReportJob` will be picked up
first. However, numeric priority only applies within a queue. It has no effect
across queues. Queue order takes precedence, if you are using both mechanisms
together.

#### Polling Interval

For Solid Queue the `polling_interval` setting for a worker directly affects how
quickly it picks up new jobs. A high-priority queue paired with a slow polling
interval may not feel very responsive in practice:

```yaml
production:
  workers:
    - queues: critical
      threads: 5
      polling_interval: 0.1  # Poll every 100ms — fast response
    - queues: low
      threads: 2
      polling_interval: 10   # Poll every 10s — fine for low-priority work
```

Tuning `polling_interval` per worker is especially important for time-sensitive
queues.

#### Retries

In Solid Queue, retries need to be configured explicitly using Active Job's
`retry_on`:

```ruby
class ExternalApiJob < ApplicationJob
  retry_on Net::TimeoutError, wait: :exponentially_longer, attempts: 5
  retry_on ActiveRecord::Deadlocked, wait: 2.seconds, attempts: 3

  def perform
    # ...
  end
end
```

This can also be set globally in `ApplicationJob` if you want a default retry
policy across all jobs. Failed jobs that aren't configured with `retry_on` will
go straight to failed executions without retrying.

### Concurrency Controls

Solid Queue extends Active Job with concurrency controls, allowing you to limit
how many jobs of a certain type can run at the same time. This is useful for
protecting shared resources, such as ensuring only one export job runs per
account at a time, or capping the number of concurrent API calls to an external
service.

Concurrency controls are declared using `limits_concurrency` in your job class:

```ruby
class InvoiceExportJob < ApplicationJob
  limits_concurrency to: 1, key: ->(account_id) { "invoice_export_#{account_id}" }, duration: 10.minutes

  def perform(account_id)
    # ...
  end
end
```

In the above example:

- The `:to` option sets the maximum number of jobs that can run concurrently.
- The `:key` lambda computes a concurrency key from the job's arguments. In the
  example above, the limit of 1 applies per account rather than globally.
- The `:duration` option acts as a failsafe. So if a worker dies mid-job and
  fails to release its lock, any blocked jobs become candidates for release once
  duration has elapsed.

When a job with concurrency controls is enqueued, Solid Queue checks a
database-backed lock for the computed key. If the lock is available, the job is
marked ready for execution. If not, the behavior depends on the `:on_conflict`
option. If `on_conflict` is set to `:block` (the default), the job is held in a
blocked state and marked ready only when a running job finishes. The other
option is `:discard`, in which case the job is dropped entirely.

You can also scope limits across *different* job classes using the `:group`
option:

```ruby
class AnalyticsExportJob < ApplicationJob
  limits_concurrency to: 1, key: ->(account_id) { account_id }, group: "account_exports", duration: 10.minutes
end

class InvoiceExportJob < ApplicationJob
  limits_concurrency to: 1, key: ->(account_id) { account_id }, group: "account_exports", duration: 10.minutes
end
```

In the above example, both job classes share the same concurrency limit per the
"account_exports" group, which means only one export of either type will run at
a time for a given account.

NOTE: Concurrency controls do carry overhead since blocked executions must be
tracked and locks created and updated. So they should be used sparingly. For
simple throughput limiting, constraining the number of worker threads per queue
is more efficient.

WARNING: Concurrency controls are not compatible with bulk enqueuing via
`perform_all_later`. Since concurrency-controlled jobs need to be enqueued
one-by-one to respect the configured limits.

### Error handling

Solid Queue raises `SolidQueue::Job::EnqueueError` when an Active Record error
occurs during job enqueuing. This differs from `ActiveJob::EnqueueError`, which
Active Job handles internally by making `perform_later` return `false`. The
practical consequence is that errors become harder to handle for jobs enqueued
by Rails internals or third-party gems like `Turbo::Streams::BroadcastJob`,
since you don't control the call to `perform_later` in those cases. For
recurring tasks, enqueue errors are logged but not raised. See [Errors When
Enqueuing](https://github.com/rails/solid_queue?tab=readme-ov-file#errors-when-enqueuing)
in the Solid Queue documentation for more detail.

If a worker process is killed unexpectedly — for example, with a `KILL` signal —
any in-flight jobs are marked as failed, and errors such as
`SolidQueue::Processes::ProcessExitError` or
`SolidQueue::Processes::ProcessPrunedError` are raised. Heartbeat settings
control how quickly Solid Queue detects and cleans up expired processes. See
[Threads, Processes and
Signals](https://github.com/rails/solid_queue?tab=readme-ov-file#threads-processes-and-signals)
in the Solid Queue documentation for details on configuring this behavior.

If your error tracking service doesn't automatically capture job errors, you can
hook into Active Job's `rescue_from` in `ApplicationJob`:

```ruby
class ApplicationJob < ActiveJob::Base
  rescue_from(Exception) do |exception|
    Rails.error.report(exception)
    raise exception
  end
end
```

If your application uses Action Mailer, note that mailer delivery runs through
`ActionMailer::MailDeliveryJob`, which inherits from `ApplicationJob` but needs
to be handled separately:

```ruby
class ApplicationMailer < ActionMailer::Base
  ActionMailer::MailDeliveryJob.rescue_from(Exception) do |exception|
    Rails.error.report(exception)
    raise exception
  end
end
```

### Transactional Integrity on Jobs

Since Solid Queue can use the same database as your application, it can
participate in the same ACID transactions as your application data. But this
behavior comes with important nuances worth understanding before you rely on it.

When Solid Queue uses the same database as your application, job enqueuing
happens inside the same transaction as any surrounding Active Record operations.
This means a job won't be enqueued if the transaction rolls back, and the
transaction won't commit unless the job enqueue also succeeds. This eliminates a
class of race conditions common with Redis backends (e.g. a job running before
the record it needs has been committed to the database).

However, Rails 8 configures Solid Queue on a *separate database by default*,
precisely to avoid implicit coupling to this behavior. If you build logic that
depends on transactional integrity and later move Solid Queue to its own
database or switch to a different backend, that behavior silently disappears.
The separate database default is the safer choice for most applications.

#### Using `enqueue_after_transaction_commit`

The recommended way to get transactional safety — without depending on both your
app and Solid Queue sharing the same database — is to use
`enqueue_after_transaction_commit`. This defers job enqueuing until the
surrounding Active Record transaction successfully commits, and can be enabled
per job or globally:

```ruby
class ApplicationJob < ActiveJob::Base
  self.enqueue_after_transaction_commit = true
end
```

With this setting, a job enqueued inside a transaction that rolls back will
simply not be enqueued. This gives you the guarantee portably, regardless of
whether Solid Queue shares a database with your app or not.

#### Enqueuing from `after_commit` Callbacks

If you prefer not to use `enqueue_after_transaction_commit`, the alternative is
to always enqueue jobs from `after_commit` callbacks rather than from within
transactions directly:

```ruby
after_commit :schedule_cleanup, on: :create

def schedule_cleanup
  GuestsCleanupJob.perform_later(self)
end
```

This ensures the job is only enqueued once the relevant data is durably
committed to the database.

#### The Risk of Implicit Reliance

The subtle danger is enqueuing a job inside a transaction without either of the
above safeguards in place. In that case, the job may run before the data it
needs is visible to other connections, or it may be enqueued even if the
transaction rolls back. This is easy to overlook if you're accustomed to
Redis-backed backends where this problem doesn't arise in the same form. If
you're unsure whether your code relies on transactional integrity, enabling
`enqueue_after_transaction_commit` globally in `ApplicationJob` is the safest
default.

You can read more about [Transactional Integrity in the Solid Queue
documentation](https://github.com/rails/solid_queue?tab=readme-ov-file#jobs-and-transactional-integrity)

### Recurring Tasks

Solid Queue supports recurring tasks, similar to cron jobs. These tasks are
defined in a configuration file (by default, `config/recurring.yml`) and can be
scheduled at specific times. Here's an example of a task configuration:

```yaml
production:
  a_periodic_job:
    class: MyJob
    args: [42, { status: "custom_status" }]
    schedule: every second
  a_cleanup_task:
    command: "DeletedStuff.clear_all"
    schedule: every day at 9am
```

Each task specifies a `class` or `command` and a `schedule` (parsed using
[Fugit](https://github.com/floraison/fugit)). You can also pass arguments to
jobs, such as in the example for `MyJob` where `args` are passed. This can be
passed as a single argument, a hash, or an array of arguments that can also
include keyword arguments as the last element in the array.

You can learn more about [Recurring
Tasks](https://github.com/rails/solid_queue?tab=readme-ov-file#recurring-tasks)
in the Solid Queue documentation.

Alternate Queuing Backends
--------------------------

While Solid Queue is the default queuing backend in Rails, Active Job is
designed to work seamlessly with different queuing backends. Switching to an
alternative backend, such as [Sidekiq](https://github.com/sidekiq/sidekiq),
[GoodJob](https://github.com/bensheldon/good_job), or
[Resque](https://github.com/resque/resque), requires only a configuration change
(typically with no modifications to your job code), along with adding the
queuing backend's adapter to your Gemfile.

Here is a noncomprehensive list of alternate queuing backends and documentation:

- [Sidekiq](https://github.com/mperham/sidekiq/wiki/Active-Job)
- [Resque](https://github.com/resque/resque/wiki/ActiveJob)
- [Sneakers](https://github.com/jondot/sneakers/wiki/How-To:-Rails-Background-Jobs-with-ActiveJob)
- [Queue Classic](https://github.com/QueueClassic/queue_classic#active-job)
- [Delayed Job](https://github.com/collectiveidea/delayed_job#active-job)
- [Que](https://github.com/que-rb/que#additional-rails-specific-setup)
- [Good Job](https://github.com/bensheldon/good_job#readme)

To switch backends globally, you can set `config.active_job.queue_adapter` in
your application configuration:

```ruby
# config/application.rb
module YourApp
  class Application < Rails::Application
    config.active_job.queue_adapter = :sidekiq
  end
end
```

You can also set the adapter per-environment, which is useful if you want to use
Solid Queue in production but a simpler adapter in development:

```ruby
# config/environments/development.rb
config.active_job.queue_adapter = :async
```

If you want to migrate incrementally, you can set the adapter at the job class
level. This is useful for moving one job at a time rather than switching
everything at once:

```ruby
class MyJob < ApplicationJob
  self.queue_adapter = :sidekiq
end
```

Each backend requires its own gem and typically its own process. Once you add
the adapter's gem to your `Gemfile`, you can refer to the adapter's
documentation for any additional setup — most backends require a separate worker
process to be started alongside your Rails application, and some (like Sidekiq)
require additional infrastructure such as Redis.

Note that switching backends doesn't migrate jobs already sitting in the old
queue. You'll need to drain the old queue before switching, or run both backends
in parallel temporarily to let existing jobs complete.

NOTE: The early releases of Active Job had adapters built-in, but a decision was
later made to let queueing backends providers manage the adapter themselves. Any
backend can be used with Active Job regardless of whether the adapter is built
in or not.

TIP: If you use `config.active_job.queue_name_prefix`, make sure your new
backend's worker configuration listens to the prefixed queue names, not the bare
names.

Monitoring and Handling Failed Jobs
-----------------------------------

### Monitoring With Mission Control

The [Mission Control](https://github.com/rails/mission_control-jobs) engine is a
Rails-based frontend to Active Job adapters to help centralize the monitoring
and management of failed jobs. It provides insights into job status, failure
reasons, and retry behaviors, enabling you to track and resolve issues more
effectively.

For instance, if a job fails to process a large file due to a timeout,
`mission_control-jobs` allows you to inspect the failure, review the job’s
arguments and execution history, and decide whether to retry, requeue, or
discard it.

### Detecting Errors With `rescue_from`

Exceptions raised during the execution of the job can be handled with
[`rescue_from`](https://api.rubyonrails.org/classes/ActiveSupport/Rescuable/ClassMethods.html#method-i-rescue_from):

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

If an exception from a job is not rescued, then the job is referred to as
"failed".

You can enable additional logging to figure out where jobs are coming from with
[verbose logging](debugging_rails_applications.html#verbose-enqueue-logs).

### Retrying or Discarding Failed Jobs

A failed job will not be retried, unless configured otherwise.

It's possible to either retry or discard a failed job by using [`retry_on`] or
[`discard_on`], respectively. For example:

```ruby
class RemoteServiceJob < ApplicationJob
  retry_on CustomAppException # defaults to 3s wait, 5 attempts

  discard_on Net::OpenTimeout

  def perform(*args)
    # Might raise CustomAppException or Net::OpenTimeout
  end
end
```

[`discard_on`]:
    https://api.rubyonrails.org/classes/ActiveJob/Exceptions/ClassMethods.html#method-i-discard_on
[`retry_on`]:
    https://api.rubyonrails.org/classes/ActiveJob/Exceptions/ClassMethods.html#method-i-retry_on

### Missing Records

GlobalID will use the unique identifier to locate the full Active Record object
when calling `#perform`.

If a passed record is deleted after the job is enqueued but before the
`#perform` method is called Active Job will raise an
[`ActiveJob::DeserializationError`](https://api.rubyonrails.org/classes/ActiveJob/DeserializationError.html)
exception.

