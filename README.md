# Active Job -- Make work happen later

Active Job is a framework for declaring jobs and making them run on a variety
of queueing backends. These jobs can be everything from regularly scheduled
clean-ups, billing charges, or mailings. Anything that can be chopped up into
small units of work and run in parallel, really.

It also serves as the backend for [ActionMailer's #deliver_later functionality][https://github.com/rails/activejob/issues/13]
that makes it easy to turn any mailing into a job for running later. That's
one of the most common jobs in a modern web application: Sending emails outside
of the request-response cycle, so the user doesn't have to wait on it.


## Usage

Declare a job like so:

```ruby
class MyJob < ActiveJob::Base
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

Active Job supports [GlobalID serialization][https://github.com/rails/activemodel-globalid/] for parameters. This makes it possible
to pass live Active Record objects to your job instead of class/id pairs, which
you then have to manually deserialize. Before, jobs would look like this:

```ruby
class TrashableCleanupJob
  def perfom(trashable_class, trashable_id, depth)
    trashable = trashable_class.constantize.find(trashable_id)
    trashable.cleanup(depth)
  end
end
```

Now you can simply do:

```ruby
class TrashableCleanupJob
  def perfom(trashable, depth)
    trashable.cleanup(depth)
  end
end
```

This works with any class that mixes in ActiveModel::GlobalIdentification, which
by default has been mixed into Active Record classes.


## Supported queueing systems

We currently have adapters for:

* Resque 1.x
* Sidekiq
* Sucker Punch
* Delayed Job

We would like to have adapters for:

* beanstalkd
* rabbitmq


## Under development as a gem, targeted for Rails inclusion

Active Job is currently being developed in a separate repository until it's
ready to be merged in with Rails. The current plan is to have Active Job
be part of the Rails 4.2 release, but plans may change depending on when
this framework stabilizes and feels ready.


## License

Active Job is released under the MIT license:

* http://www.opensource.org/licenses/MIT
