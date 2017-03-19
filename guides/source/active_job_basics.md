**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON http://guides.rubyonrails.org.**

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


Introduction
------------

Active Job is a framework for declaring jobs and making them run on a variety
of queuing backends. These jobs can be everything from regularly scheduled
clean-ups, to billing charges, to mailings. Anything that can be chopped up
into small units of work and run in parallel, really.


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


Creating a Job
--------------

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

### Enqueue the Job

Enqueue a job like so:

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

Job Execution
-------------

For enqueuing and executing jobs in production you need to set up a queuing backend,
that is to say you need to decide for a 3rd-party queuing library that Rails should use.
Rails itself only provides an in-process queuing system, which only keeps the jobs in RAM.
If the process crashes or the machine is reset, then all outstanding jobs are lost with the
default async backend. This may be fine for smaller apps or non-critical jobs, but most
production apps will need to pick a persistent backend.

### Backends

Active Job has built-in adapters for multiple queuing backends (Sidekiq,
Resque, Delayed Job and others). To get an up-to-date list of the adapters
see the API Documentation for [ActiveJob::QueueAdapters](http://api.rubyonrails.org/classes/ActiveJob/QueueAdapters.html).

### Setting the Backend

You can easily set your queuing backend:

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

You can also configure your backend on a per job basis.

```ruby
class GuestsCleanupJob < ApplicationJob
  self.queue_adapter = :resque
  #....
end

# Now your job will use `resque` as it's backend queue adapter overriding what
# was configured in `config.active_job.queue_adapter`.
```

### Starting the Backend

Since jobs run in parallel to your Rails application, most queuing libraries
require that you start a library-specific queuing service (in addition to
starting your Rails app) for the job processing to work. Refer to library
documentation for instructions on starting your queue backend.

Here is a noncomprehensive list of documentation:

- [Sidekiq](https://github.com/mperham/sidekiq/wiki/Active-Job)
- [Resque](https://github.com/resque/resque/wiki/ActiveJob)
- [Sucker Punch](https://github.com/brandonhilkert/sucker_punch#active-job)
- [Queue Classic](https://github.com/QueueClassic/queue_classic#active-job)

Queues
------

Most of the adapters support multiple queues. With Active Job you can schedule
the job to run on a specific queue:

```ruby
class GuestsCleanupJob < ApplicationJob
  queue_as :low_priority
  #....
end
```

You can prefix the queue name for all your jobs using
`config.active_job.queue_name_prefix` in `application.rb`:

```ruby
# config/application.rb
module YourApp
  class Application < Rails::Application
    config.active_job.queue_name_prefix = Rails.env
  end
end

# app/jobs/guests_cleanup_job.rb
class GuestsCleanupJob < ApplicationJob
  queue_as :low_priority
  #....
end

# Now your job will run on queue production_low_priority on your
# production environment and on staging_low_priority
# on your staging environment
```

The default queue name prefix delimiter is '\_'.  This can be changed by setting
`config.active_job.queue_name_delimiter` in `application.rb`:

```ruby
# config/application.rb
module YourApp
  class Application < Rails::Application
    config.active_job.queue_name_prefix = Rails.env
    config.active_job.queue_name_delimiter = '.'
  end
end

# app/jobs/guests_cleanup_job.rb
class GuestsCleanupJob < ApplicationJob
  queue_as :low_priority
  #....
end

# Now your job will run on queue production.low_priority on your
# production environment and on staging.low_priority
# on your staging environment
```

If you want more control on what queue a job will be run you can pass a `:queue`
option to `#set`:

```ruby
MyJob.set(queue: :another_queue).perform_later(record)
```

To control the queue from the job level you can pass a block to `#queue_as`. The
block will be executed in the job context (so you can access `self.arguments`)
and you must return the queue name:

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

ProcessVideoJob.perform_later(Video.last)
```

NOTE: Make sure your queuing backend "listens" on your queue name. For some
backends you need to specify the queues to listen to.


Callbacks
---------

Active Job provides hooks during the life cycle of a job. Callbacks allow you to
trigger logic during the life cycle of a job.

### Available callbacks

* `before_enqueue`
* `around_enqueue`
* `after_enqueue`
* `before_perform`
* `around_perform`
* `after_perform`

### Usage

```ruby
class GuestsCleanupJob < ApplicationJob
  queue_as :default

  before_enqueue do |job|
    # Do something with the job instance
  end

  around_perform do |job, block|
    # Do something before perform
    block.call
    # Do something after perform
  end

  def perform
    # Do something later
  end
end
```


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


Internationalization
--------------------

Each job uses the `I18n.locale` set when the job was created. Useful if you send
emails asynchronously:

```ruby
I18n.locale = :eo

UserMailer.welcome(@user).deliver_later # Email will be localized to Esperanto.
```


GlobalID
--------

Active Job supports GlobalID for parameters. This makes it possible to pass live
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


Exceptions
----------

Active Job provides a way to catch exceptions raised during the execution of the
job:

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

### Deserialization

GlobalID allows serializing full Active Record objects passed to `#perform`.

If a passed record is deleted after the job is enqueued but before the `#perform`
method is called Active Job will raise an `ActiveJob::DeserializationError`
exception.

Job Testing
--------------

You can find detailed instructions on how to test your jobs in the
[testing guide](testing.html#testing-jobs).
