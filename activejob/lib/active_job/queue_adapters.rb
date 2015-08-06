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
  #   |                   | Async | Queues | Delayed    | Priorities | Timeout | Retries |
  #   |-------------------|-------|--------|------------|------------|---------|---------|
  #   | Backburner        | Yes   | Yes    | Yes        | Yes        | Job     | Global  |
  #   | Delayed Job       | Yes   | Yes    | Yes        | Job        | Global  | Global  |
  #   | Qu                | Yes   | Yes    | No         | No         | No      | Global  |
  #   | Que               | Yes   | Yes    | Yes        | Job        | No      | Job     |
  #   | queue_classic     | Yes   | Yes    | Yes*       | No         | No      | No      |
  #   | Resque            | Yes   | Yes    | Yes (Gem)  | Queue      | Global  | Yes     |
  #   | Sidekiq           | Yes   | Yes    | Yes        | Queue      | No      | Job     |
  #   | Sneakers          | Yes   | Yes    | No         | Queue      | Queue   | No      |
  #   | Sucker Punch      | Yes   | Yes    | No         | No         | No      | No      |
  #   | Active Job Inline | No    | Yes    | N/A        | N/A        | N/A     | N/A     |
  #
  # NOTE:
  # queue_classic supports job scheduling since version 3.1.
  # For older versions you can use the queue_classic-later gem.
  #
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
  end
end
