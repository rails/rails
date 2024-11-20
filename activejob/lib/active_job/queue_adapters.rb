# frozen_string_literal: true

module ActiveJob
  # = Active Job adapters
  #
  # Active Job has adapters for the following queuing backends:
  #
  # * {Backburner}[https://github.com/nesquena/backburner]
  # * {Delayed Job}[https://github.com/collectiveidea/delayed_job]
  # * {Que}[https://github.com/chanks/que]
  # * {queue_classic}[https://github.com/QueueClassic/queue_classic]
  # * {Resque}[https://github.com/resque/resque]
  # * {Sidekiq}[https://sidekiq.org]
  # * {Sneakers}[https://github.com/jondot/sneakers]
  # * Please Note: We are not accepting pull requests for new adapters. See the {README}[link:files/activejob/README_md.html] for more details.
  #
  # For testing and development Active Job has three built-in adapters:
  #
  # * {Active Job Async}[https://api.rubyonrails.org/classes/ActiveJob/QueueAdapters/AsyncAdapter.html]
  # * {Active Job Inline}[https://api.rubyonrails.org/classes/ActiveJob/QueueAdapters/InlineAdapter.html]
  # * {Active Job Test}[https://api.rubyonrails.org/classes/ActiveJob/QueueAdapters/TestAdapter.html]
  #
  # === Backends Features
  #
  #   |                   | Async | Queues | Delayed    | Priorities | Timeout | Retries |
  #   |-------------------|-------|--------|------------|------------|---------|---------|
  #   | Backburner        | Yes   | Yes    | Yes        | Yes        | Job     | Global  |
  #   | Delayed Job       | Yes   | Yes    | Yes        | Job        | Global  | Global  |
  #   | Que               | Yes   | Yes    | Yes        | Job        | No      | Job     |
  #   | queue_classic     | Yes   | Yes    | Yes*       | No         | No      | No      |
  #   | Resque            | Yes   | Yes    | Yes (Gem)  | Queue      | Global  | Yes     |
  #   | Sidekiq           | Yes   | Yes    | Yes        | Queue      | No      | Job     |
  #   | Sneakers          | Yes   | Yes    | No         | Queue      | Queue   | No      |
  #   | Active Job Async  | Yes   | Yes    | Yes        | No         | No      | No      |
  #   | Active Job Inline | No    | Yes    | N/A        | N/A        | N/A     | N/A     |
  #   | Active Job Test   | No    | Yes    | N/A        | N/A        | N/A     | N/A     |
  #
  # ==== Async
  #
  # Yes: The Queue Adapter has the ability to run the job in a non-blocking manner.
  # It either runs on a separate or forked process, or on a different thread.
  #
  # No: The job is run in the same process.
  #
  # ==== Queues
  #
  # Yes: Jobs may set which queue they are run in with queue_as or by using the set
  # method.
  #
  # ==== Delayed
  #
  # Yes: The adapter will run the job in the future through perform_later.
  #
  # (Gem): An additional gem is required to use perform_later with this adapter.
  #
  # No: The adapter will run jobs at the next opportunity and cannot use perform_later.
  #
  # N/A: The adapter does not support queuing.
  #
  # NOTE:
  # queue_classic supports job scheduling since version 3.1.
  # For older versions you can use the queue_classic-later gem.
  #
  # ==== Priorities
  #
  # The order in which jobs are processed can be configured differently depending
  # on the adapter.
  #
  # Job: Any class inheriting from the adapter may set the priority on the job
  # object relative to other jobs.
  #
  # Queue: The adapter can set the priority for job queues, when setting a queue
  # with Active Job this will be respected.
  #
  # Yes: Allows the priority to be set on the job object, at the queue level or
  # as default configuration option.
  #
  # No: The adapter does not allow the priority of jobs to be configured.
  #
  # N/A: The adapter does not support queuing, and therefore sorting them.
  #
  # ==== Timeout
  #
  # When a job will stop after the allotted time.
  #
  # Job: The timeout can be set for each instance of the job class.
  #
  # Queue: The timeout is set for all jobs on the queue.
  #
  # Global: The adapter is configured that all jobs have a maximum run time.
  #
  # No: The adapter does not allow the timeout of jobs to be configured.
  #
  # N/A: This adapter does not run in a separate process, and therefore timeout
  # is unsupported.
  #
  # ==== Retries
  #
  # Job: The number of retries can be set per instance of the job class.
  #
  # Yes: The Number of retries can be configured globally, for each instance or
  # on the queue. This adapter may also present failed instances of the job class
  # that can be restarted.
  #
  # Global: The adapter has a global number of retries.
  #
  # No: The adapter does not allow the number of retries to be configured.
  #
  # N/A: The adapter does not run in a separate process, and therefore doesn't
  # support retries.
  #
  module QueueAdapters
    extend ActiveSupport::Autoload

    autoload :AbstractAdapter
    autoload :AsyncAdapter
    autoload :InlineAdapter
    autoload :BackburnerAdapter
    autoload :DelayedJobAdapter
    autoload :QueueClassicAdapter
    autoload :ResqueAdapter
    autoload :SidekiqAdapter
    autoload :SneakersAdapter
    autoload :SuckerPunchAdapter
    autoload :TestAdapter

    ADAPTER = "Adapter"
    private_constant :ADAPTER

    class << self
      # Returns adapter for specified name.
      #
      #   ActiveJob::QueueAdapters.lookup(:sidekiq)
      #   # => ActiveJob::QueueAdapters::SidekiqAdapter
      def lookup(name)
        const_get(name.to_s.camelize << ADAPTER)
      end
    end
  end
end
