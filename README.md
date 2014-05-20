# Active Job -- Make work happen later

Active Job is a framework for declaring jobs and making them run on a variety
of queueing backends. These jobs can be everything from regularly scheduled
clean-ups, billing charges, or mailings. Anything that can be chopped up into
small units of work and run in parallel, really.

It also serves as the backend for [ActionMailer's #deliver_later functionality](https://github.com/rails/activejob/issues/13)
that makes it easy to turn any mailing into a job for running later. That's
one of the most common jobs in a modern web application: Sending emails outside
of the request-response cycle, so the user doesn't have to wait on it.

The main point is to ensure that all Rails apps will have a job infrastructure
in place, even if it's in the form of an "immediate runner". We can then have
framework features and other gems build on top of that, without having to worry
about API differences between Delayed Job and Resque. Picking your queuing 
backend becomes more of an operational concern, then. And you'll be able to
switch between them without having to rewrite your jobs.


## Usage

Set the queue adapter for Active Job:

``` ruby
ActiveJob::Base.queue_adapter = :inline # default queue adapter
# Adapters currently supported: :delayed_job, :que, :queue_classic, :resque,
#                               :sidekiq, :sneakers, :sucker_punch
```

Declare a job like so:

```ruby
class MyJob < ActiveJob::Base
  queue_as :my_jobs

  def perform(record)
    record.do_work
  end
end
```

Enqueue a job like so:

```ruby
MyJob.enqueue record
```

That's it!


## GlobalID support

Active Job supports [GlobalID serialization](https://github.com/rails/activemodel-globalid/) for parameters. This makes it possible
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
by default has been mixed into Active Record classes.


## Supported queueing systems

We currently have adapters for:

* [Delayed Job](https://github.com/collectiveidea/delayed_job)
* [Que](https://github.com/chanks/que)
* [QueueClassic](https://github.com/ryandotsmith/queue_classic)
* [Resque 1.x](https://github.com/resque/resque)
* [Sidekiq](https://github.com/mperham/sidekiq)
* [Sneakers](https://github.com/jondot/sneakers)
* [Sucker Punch](https://github.com/brandonhilkert/sucker_punch)

We would like to have adapters for:

* [Resque 2.x](https://github.com/resque/resque) (see [#7](https://github.com/rails/activejob/issues/7))


## Under development as a gem, targeted for Rails inclusion

Active Job is currently being developed in a separate repository until it's
ready to be merged in with Rails. The current plan is to have Active Job
be part of the Rails 4.2 release, but plans may change depending on when
this framework stabilizes and feels ready.


## License

Active Job is released under the MIT license:

* http://www.opensource.org/licenses/MIT
