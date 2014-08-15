Active Job Basics
=================

This guide provides you with all you need to get started in creating,
enqueueing and executing background jobs.

After reading this guide, you will know:

* How to create jobs.
* How to enqueue jobs.
* How to run jobs in the background.
* How to send emails from your application async.

--------------------------------------------------------------------------------

Introduction
------------

Active Job is a framework for declaring jobs and making them run on a variety
of queueing backends. These jobs can be everything from regularly scheduled
clean-ups, billing charges, or mailings. Anything that can be chopped up
into small units of work and run in parallel, really.


The Purpose of the Active Job
-----------------------------
The main point is to ensure that all Rails apps will have a job infrastructure
in place, even if it's in the form of an "immediate runner". We can then have
framework features and other gems build on top of that, without having to
worry about API differences between Delayed Job and Resque. Picking your
queuing backend becomes more of an operational concern, then. And you'll
be able to switch between them without having to rewrite your jobs.


Creating a Job
--------------

This section will provide a step-by-step guide to creating a job and enqueue it.

### Create the Job

Active Job provides a Rails generator to create jobs. The following will create a
job in app/jobs:

```bash
$ bin/rails generate job guests_cleanup
create  app/jobs/guests_cleanup_job.rb
```

You can also create a job that will run on a specific queue:

```bash
$ bin/rails generate job guests_cleanup --queue urgent
create  app/jobs/guests_cleanup_job.rb
```

As you can see, you can generate jobs just like you use other generators with
Rails.

If you don't want to use a generator, you could create your own file inside of
app/jobs, just make sure that it inherits from `ActiveJob::Base`.

Here's how a job looks like:

```ruby
class GuestsCleanupJob < ActiveJob::Base
  queue_as :default

  def perform
    # Do something later
  end
end
```

### Enqueue the Job

Enqueue a job like so:

```ruby
MyJob.enqueue record  # Enqueue a job to be performed as soon the queueing system is free.
```

```ruby
MyJob.enqueue_at Date.tomorrow.noon, record  # Enqueue a job to be performed tomorrow at noon.
```

```ruby
MyJob.enqueue_in 1.week, record # Enqueue a job to be performed 1 week from now.
```

That's it!


Job Execution
-------------

If not adapter is set, the job is immediately executed.

### Backends

Active Job has adapters for the following queueing backends:

* [Backburner](https://github.com/nesquena/backburner)
* [Delayed Job](https://github.com/collectiveidea/delayed_job)
* [Qu](https://github.com/bkeepers/qu)
* [Que](https://github.com/chanks/que)
* [QueueClassic](https://github.com/ryandotsmith/queue_classic)
* [Resque 1.x](https://github.com/resque/resque)
* [Sidekiq](https://github.com/mperham/sidekiq)
* [Sneakers](https://github.com/jondot/sneakers)
* [Sucker Punch](https://github.com/brandonhilkert/sucker_punch)

#### Backends Features

<table cellpadding="3" cellspacing="0">
  <tbody>
    <tr>
      <td>&nbsp;</td>
      <td><strong>Async</strong></td>
      <td><strong>Queues</strong></td>
      <td><strong>Delayed</strong></td>
      <td><strong>Priorities</strong></td>
      <td><strong>Timeout</strong></td>
      <td><strong>Retries</strong></td>
    </tr>
    <tr>
      <td><strong>Backburner</strong></td>
      <td>Yes</td>
      <td>Yes</td>
      <td>Yes</td>
      <td>Yes</td>
      <td>Job</td>
      <td>Global</td>
    </tr>
    <tr>
      <td><strong>Delayed Job</strong></td>
      <td>Yes</td>
      <td>Yes</td>
      <td>Yes</td>
      <td>Job</td>
      <td>Global</td>
      <td>Global</td>
    </tr>
    <tr>
      <td><strong>Que</strong></td>
      <td>Yes</td>
      <td>Yes</td>
      <td>Yes</td>
      <td>Job</td>
      <td>No</td>
      <td>Job</td>
    </tr>
    <tr>
      <td><strong>Queue Classic</strong></td>
      <td>Yes</td>
      <td>Yes</td>
      <td>Gem</td>
      <td>No</td>
      <td>No</td>
      <td>No</td>
    </tr>
    <tr>
      <td><strong>Resque</strong></td>
      <td>Yes</td>
      <td>Yes</td>
      <td>Gem</td>
      <td>Queue</td>
      <td>Global</td>
      <td>?</td>
    </tr>
    <tr>
      <td><strong>Sidekiq</strong></td>
      <td>Yes</td>
      <td>Yes</td>
      <td>Yes</td>
      <td>Queue</td>
      <td>No</td>
      <td>Job</td>
    </tr>
    <tr>
      <td><strong>Sneakers</strong></td>
      <td>Yes</td>
      <td>Yes</td>
      <td>No</td>
      <td>Queue</td>
      <td>Queue</td>
      <td>No</td>
    </tr>
    <tr>
      <td><strong>Sucker Punch</strong></td>
      <td>Yes</td>
      <td>Yes</td>
      <td>Yes</td>
      <td>No</td>
      <td>No</td>
      <td>No</td>
    </tr>
    <tr>
      <td><strong>Active Job</strong></td>
      <td>Yes</td>
      <td>Yes</td>
      <td>WIP</td>
      <td>No</td>
      <td>No</td>
      <td>No</td>
    </tr>
    <tr>
      <td><strong>Active Job Inline</strong></td>
      <td>No</td>
      <td>Yes</td>
      <td>N/A</td>
      <td>N/A</td>
      <td>N/A</td>
      <td>N/A</td>
    </tr>
  </tbody>
</table>


### Change Backends

You can easy change your adapter:

```ruby
# be sure to have the adapter gem in your Gemfile and follow the adapter specific
# installation and deployment instructions
YourApp::Application.config.active_job.queue_adapter = :sidekiq
```

Queues
------

Most of the adapters supports multiple queues. With Active Job you can schedule the job
to run on a specific queue:

```ruby
class GuestsCleanupJob < ActiveJob::Base
  queue_as :low_prio
  #....
end
```

NOTE: Make sure your queueing backend "listens" on your queue name. For some backends
you need to specify the queues to listen to.


Callbacks
---------

Active Job provides hooks during the lifecycle of a job. Callbacks allows you to trigger
logic during the lifecycle of a job.

### Available callbacks

* before_enqueue
* around_enqueue
* after_enqueue
* before_perform
* around_perform
* after_perform

### Usage

```ruby
class GuestsCleanupJob < ActiveJob::Base
  queue_as :default

  before_enqueue do |job|
    # do somthing with the job instance
  end

  around_perform do |job, block|
    # do something before perform
    block.call
    # do something after perform
  end

  def perform
    # Do something later
  end
end

```

GlobalID
--------
Active Job supports GlobalID for parameters. This makes it possible
to pass live Active Record objects to your job instead of class/id pairs, which
you then have to manually deserialize. Before, jobs would look like this:

```ruby
class TrashableCleanupJob
  def perform(trashable_class, trashable_id, depth)
    trashable = trashable_class.constantize.find(trashable_id)
    trashable.cleanup(depth)
  end
end
```

Now you can simply do:

```ruby
class TrashableCleanupJob
  def perform(trashable, depth)
    trashable.cleanup(depth)
  end
end
```

This works with any class that mixes in ActiveModel::GlobalIdentification, which
by default has been mixed into Active Model classes.


Exceptions
----------
Active Job provides a way to catch exceptions raised during the execution of the
job:

```ruby

class GuestsCleanupJob < ActiveJob::Base
  queue_as :default

  rescue_from(ActiveRecord:NotFound) do |exception|
   # do something with the exception
  end

  def perform
    # Do something later
  end
end
```
