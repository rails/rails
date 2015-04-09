module ActiveJob
  # == Active Job adapters
  #
  # Active Job has adapters for the following queueing backends:
  #
  # * {Backburner}[https://github.com/nesquena/backburner]
  # * {Delayed Job}[https://github.com/collectiveidea/delayed_job]
  # * {Qu}[https://github.com/bkeepers/qu]
  # * {Que}[https://github.com/chanks/que]
  # * {queue_classic}[https://github.com/QueueClassic/queue_classic]
  # * {Resque 1.x}[https://github.com/resque/resque/tree/1-x-stable]
  # * {Sidekiq}[http://sidekiq.org]
  # * {Sneakers}[https://github.com/jondot/sneakers]
  # * {Sucker Punch}[https://github.com/brandonhilkert/sucker_punch]
  #
  # === Backends Features
  #
  #   |                   | Async | Queues | Delayed   | Priorities | Timeout | Retries |
  #   |-------------------|-------|--------|-----------|------------|---------|---------|
  #   | Backburner        | Yes   | Yes    | Yes       | Yes        | Job     | Global  |
  #   | Delayed Job       | Yes   | Yes    | Yes       | Job        | Global  | Global  |
  #   | Qu                | Yes   | Yes    | No        | No         | No      | Global  |
  #   | Que               | Yes   | Yes    | Yes       | Job        | No      | Job     |
  #   | queue_classic     | Yes   | Yes    | No*       | No         | No      | No      |
  #   | Resque            | Yes   | Yes    | Yes (Gem) | Queue      | Global  | Yes     |
  #   | Sidekiq           | Yes   | Yes    | Yes       | Queue      | No      | Job     |
  #   | Sneakers          | Yes   | Yes    | No        | Queue      | Queue   | No      |
  #   | Sucker Punch      | Yes   | Yes    | No        | No         | No      | No      |
  #   | Active Job Inline | No    | Yes    | N/A       | N/A        | N/A     | N/A     |
  #   | Active Job        | Yes   | Yes    | Yes       | No         | No      | No      |
  #
  # ==== Async
  #
  # Yes: The Queue Adapter runs the jobs in a separate or forked process.
  #
  # No: The job is run in the same process.
  #
  # ==== Queues
  #
  # Yes: Jobs may set which queue they are run in with queue_as or by using the set method.
  #
  # ==== Delayed
  #
  # Yes: The adapter lets jobs run in the future through perform_later.
  #
  # (Gem): An additional gem is required to use perform_later with this adapter.
  #
  # No: The adapter will run jobs at the next opportunity and can not use perform_later.
  #
  # N/A: The adapter does not run in a separate process.
  #
  # NOTE:
  # queue_classic does not support Job scheduling. However you can implement this
  # yourself or you can use the queue_classic-later gem. See the documentation for
  # ActiveJob::QueueAdapters::QueueClassicAdapter.
  #
  # ==== Priorities
  #
  # The order in which jobs are processed can be configured differently depending on the adapter.
  #
  # Job: Any class inheriting from the adapter may set it's own priority relative to other jobs. Set on the job object.
  #
  # Queue: The adapter can set the priority of it's queues, when setting a queue with Active Job this will be respected.
  #
  # Yes: Allows the priority of a job to be set on the job object, at the queue level or as a default during configuration. 
  #
  # No: Does not allow the priority of jobs to be configured.
  #
  # N/A: The adapter does not run in a separate process.
  #
  # ==== Timeout
  #
  # Whether a job will stop after a maximum allotted time.
  #
  # Job: The timeout for each job is set per instance of the adapter class.
  #
  # Queue: The adapter allows all jobs on a queue to timeout after a set time.
  #
  # Global: The adapter is configured that all jobs have a maximum run time.
  #
  # N/A: This adapter does not run in a separate process.
  #
  # ==== Retries
  #
  # Job: The number of retries can be set per instance of the job class.
  #
  # Yes: The Number of retries can be configured at a global, instance or on the queue.
  # Or the adapter may present failed jobs as objects that can be restarted.
  #
  # Global: The adapter has a global number of retries.
  # N/A: The adapter does not run in a separate process.
  
  module QueueAdapters
    extend ActiveSupport::Autoload

    autoload :InlineAdapter
    autoload :BackburnerAdapter
    autoload :DelayedJobAdapter
    autoload :QuAdapter
    autoload :QueAdapter
    autoload :QueueClassicAdapter
    autoload :ResqueAdapter
    autoload :SidekiqAdapter
    autoload :SneakersAdapter
    autoload :SuckerPunchAdapter
    autoload :TestAdapter

    ADAPTER = 'Adapter'.freeze
    private_constant :ADAPTER

    class << self
      def lookup(name)
        const_get(name.to_s.camelize << ADAPTER)
      end
    end
  end
end
