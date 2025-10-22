# frozen_string_literal: true

require "active_support/parameter_filter"

module ActiveSupport
  class TagStack # :nodoc:
    EMPTY_TAGS = {}.freeze
    FIBER_KEY = :event_reporter_tags

    class << self
      def tags
        Fiber[FIBER_KEY] || EMPTY_TAGS
      end

      def with_tags(*args, **kwargs)
        existing_tags = tags
        tags = existing_tags.dup
        tags.merge!(resolve_tags(args, kwargs))
        new_tags = tags.freeze

        begin
          Fiber[FIBER_KEY] = new_tags
          yield
        ensure
          Fiber[FIBER_KEY] = existing_tags
        end
      end

      private
        def resolve_tags(args, kwargs)
          tags = args.each_with_object({}) do |arg, tags|
            case arg
            when String
              tags[arg.to_sym] = true
            when Symbol
              tags[arg] = true
            when Hash
              arg.each { |key, value| tags[key.to_sym] = value }
            else
              tags[arg.class.name.to_sym] = arg
            end
          end
          kwargs.each { |key, value| tags[key.to_sym] = value }
          tags
        end
    end
  end

  class EventContext # :nodoc:
    EMPTY_CONTEXT = {}.freeze
    FIBER_KEY = :event_reporter_context

    class << self
      def context
        Fiber[FIBER_KEY] || EMPTY_CONTEXT
      end

      def set_context(context_hash)
        new_context = self.context.dup
        context_hash.each { |key, value| new_context[key.to_sym] = value }

        Fiber[FIBER_KEY] = new_context.freeze
      end

      def clear
        Fiber[FIBER_KEY] = EMPTY_CONTEXT
      end
    end
  end

  # = Active Support \Event Reporter
  #
  # +ActiveSupport::EventReporter+ provides an interface for reporting structured events to subscribers.
  #
  # To report an event, you can use the +notify+ method:
  #
  #   Rails.event.notify("user_created", { id: 123 })
  #   # Emits event:
  #   #  {
  #   #    name: "user_created",
  #   #    payload: { id: 123 },
  #   #    timestamp: 1738964843208679035,
  #   #    source_location: { filepath: "path/to/file.rb", lineno: 123, label: "UserService#create" }
  #   #  }
  #
  # The +notify+ API can receive either an event name and a payload hash, or an event object. Names are coerced to strings.
  #
  # === Event Objects
  #
  # If an event object is passed to the +notify+ API, it will be passed through to subscribers as-is, and the name of the
  # object's class will be used as the event name.
  #
  #   class UserCreatedEvent
  #     def initialize(id:, name:)
  #       @id = id
  #       @name = name
  #     end
  #
  #     def serialize
  #       {
  #         id: @id,
  #         name: @name
  #       }
  #     end
  #   end
  #
  #   Rails.event.notify(UserCreatedEvent.new(id: 123, name: "John Doe"))
  #   # Emits event:
  #   #  {
  #   #    name: "UserCreatedEvent",
  #   #    payload: #<UserCreatedEvent:0x111>,
  #   #    timestamp: 1738964843208679035,
  #   #    source_location: { filepath: "path/to/file.rb", lineno: 123, label: "UserService#create" }
  #   #  }
  #
  # An event is any Ruby object representing a schematized event. While payload hashes allow arbitrary,
  # implicitly-structured data, event objects are intended to enforce a particular schema.
  #
  # Subscribers are responsible for serializing event objects.
  #
  # === Subscribers
  #
  # Subscribers must implement the +emit+ method, which will be called with the event hash.
  #
  # The event hash has the following keys:
  #
  #   name: String (The name of the event)
  #   payload: Hash, Object (The payload of the event, or the event object itself)
  #   tags: Hash (The tags of the event)
  #   context: Hash (The context of the event)
  #   timestamp: Float (The timestamp of the event, in nanoseconds)
  #   source_location: Hash (The source location of the event, containing the filepath, lineno, and label)
  #
  # Subscribers are responsible for encoding events to their desired format before emitting them to their
  # target destination, such as a streaming platform, a log device, or an alerting service.
  #
  #   class JSONEventSubscriber
  #     def emit(event)
  #       json_data = JSON.generate(event)
  #       LogExporter.export(json_data)
  #     end
  #   end
  #
  #   class LogSubscriber
  #     def emit(event)
  #       payload = event[:payload].map { |key, value| "#{key}=#{value}" }.join(" ")
  #       source_location = event[:source_location]
  #       log = "[#{event[:name]}] #{payload} at #{source_location[:filepath]}:#{source_location[:lineno]}"
  #       Rails.logger.info(log)
  #     end
  #   end
  #
  # Note that event objects are passed through to subscribers as-is, and may need to be serialized before being encoded:
  #
  #   class UserCreatedEvent
  #     def initialize(id:, name:)
  #       @id = id
  #       @name = name
  #     end
  #
  #     def serialize
  #       {
  #         id: @id,
  #         name: @name
  #       }
  #     end
  #   end
  #
  #   class LogSubscriber
  #     def emit(event)
  #       payload = event[:payload]
  #       json_data = JSON.generate(payload.serialize)
  #       LogExporter.export(json_data)
  #     end
  #   end
  #
  # ==== Filtered Subscriptions
  #
  # Subscribers can be configured with an optional filter proc to only receive a subset of events:
  #
  #   # Only receive events with names starting with "user."
  #   Rails.event.subscribe(user_subscriber) { |event| event[:name].start_with?("user.") }
  #
  #   # Only receive events with specific payload types
  #   Rails.event.subscribe(audit_subscriber) { |event| event[:payload].is_a?(AuditEvent) }
  #
  # === Debug Events
  #
  # You can use the +debug+ method to report an event that will only be reported if the
  # event reporter is in debug mode:
  #
  #   Rails.event.debug("my_debug_event", { foo: "bar" })
  #
  # === Tags
  #
  # To add additional context to an event, separate from the event payload, you can add
  # tags via the +tagged+ method:
  #
  #   Rails.event.tagged("graphql") do
  #     Rails.event.notify("user_created", { id: 123 })
  #   end
  #
  #   # Emits event:
  #   #  {
  #   #    name: "user_created",
  #   #    payload: { id: 123 },
  #   #    tags: { graphql: true },
  #   #    context: {},
  #   #    timestamp: 1738964843208679035,
  #   #    source_location: { filepath: "path/to/file.rb", lineno: 123, label: "UserService#create" }
  #   #  }
  #
  # === Context Store
  #
  # You may want to attach metadata to every event emitted by the reporter. While tags
  # provide domain-specific context for a series of events, context is scoped to the job / request
  # and should be used for metadata associated with the execution context.
  # Context can be set via the +set_context+ method:
  #
  #   Rails.event.set_context(request_id: "abcd123", user_agent: "TestAgent")
  #   Rails.event.notify("user_created", { id: 123 })
  #
  #   # Emits event:
  #   #  {
  #   #    name: "user_created",
  #   #    payload: { id: 123 },
  #   #    tags: {},
  #   #    context: { request_id: "abcd123", user_agent: "TestAgent" },
  #   #    timestamp: 1738964843208679035,
  #   #    source_location: { filepath: "path/to/file.rb", lineno: 123, label: "UserService#create" }
  #   #  }
  #
  # Context is reset automatically before and after each request.
  #
  # A custom context store can be configured via +config.active_support.event_reporter_context_store+.
  #
  #     # config/application.rb
  #     config.active_support.event_reporter_context_store = CustomContextStore
  #
  #     class CustomContextStore
  #       class << self
  #         def context
  #           # Return the context.
  #         end
  #
  #         def set_context(context_hash)
  #           # Append context_hash to the existing context store.
  #         end
  #
  #         def clear
  #           # Delete the stored context.
  #         end
  #       end
  #     end
  #
  # The Event Reporter standardizes on symbol keys for all payload data, tags, and context store entries.
  # String keys are automatically converted to symbols for consistency.
  #
  #   Rails.event.notify("user.created", { "id" => 123 })
  #   # Emits event:
  #   #  {
  #   #    name: "user.created",
  #   #    payload: { id: 123 },
  #   #  }
  #
  # === Security
  #
  # When reporting events, Hash-based payloads are automatically filtered to remove sensitive data based on {Rails.application.filter_parameters}[https://guides.rubyonrails.org/configuring.html#config-filter-parameters].
  #
  # If an {event object}[rdoc-ref:EventReporter@Event+Objects] is given instead, subscribers will need to filter sensitive data themselves, e.g. with ActiveSupport::ParameterFilter.
  class EventReporter
    # Sets whether to raise an error if a subscriber raises an error during
    # event emission, or when unexpected arguments are passed to +notify+.
    attr_writer :raise_on_error

    attr_writer :debug_mode # :nodoc:

    attr_reader :subscribers # :nodoc

    class << self
      attr_accessor :context_store # :nodoc:
    end

    self.context_store = EventContext

    def initialize(*subscribers, raise_on_error: false)
      @subscribers = []
      subscribers.each { |subscriber| subscribe(subscriber) }
      @debug_mode = false
      @raise_on_error = raise_on_error
    end

    # Registers a new event subscriber. The subscriber must respond to
    #
    #   emit(event: Hash)
    #
    # The event hash will have the following keys:
    #
    #   name: String (The name of the event)
    #   payload: Hash, Object (The payload of the event, or the event object itself)
    #   tags: Hash (The tags of the event)
    #   context: Hash (The context of the event)
    #   timestamp: Float (The timestamp of the event, in nanoseconds)
    #   source_location: Hash (The source location of the event, containing the filepath, lineno, and label)
    #
    # An optional filter proc can be provided to only receive a subset of events:
    #
    #   Rails.event.subscribe(subscriber) { |event| event[:name].start_with?("user.") }
    #   Rails.event.subscribe(subscriber) { |event| event[:payload].is_a?(UserEvent) }
    #
    def subscribe(subscriber, &filter)
      unless subscriber.respond_to?(:emit)
        raise ArgumentError, "Event subscriber #{subscriber.class.name} must respond to #emit"
      end
      @subscribers << { subscriber: subscriber, filter: filter }
    end

    # Unregister an event subscriber. Accepts either a subscriber or a class.
    #
    #   subscriber = MyEventSubscriber.new
    #   Rails.event.subscribe(subscriber)
    #
    #   Rails.event.unsubscribe(subscriber)
    #   # or
    #   Rails.event.unsubscribe(MyEventSubscriber)
    def unsubscribe(subscriber)
      @subscribers.delete_if { |s| subscriber === s[:subscriber] }
    end

    # Reports an event to all registered subscribers. An event name and payload can be provided:
    #
    #     Rails.event.notify("user.created", { id: 123 })
    #     # Emits event:
    #     #  {
    #     #    name: "user.created",
    #     #    payload: { id: 123 },
    #     #    tags: {},
    #     #    context: {},
    #     #    timestamp: 1738964843208679035,
    #     #    source_location: { filepath: "path/to/file.rb", lineno: 123, label: "UserService#create" }
    #     #  }
    #
    # Alternatively, an event object can be provided:
    #
    #   Rails.event.notify(UserCreatedEvent.new(id: 123))
    #   # Emits event:
    #   #  {
    #   #    name: "UserCreatedEvent",
    #   #    payload: #<UserCreatedEvent:0x111>,
    #   #    tags: {},
    #   #    context: {},
    #   #    timestamp: 1738964843208679035,
    #   #    source_location: { filepath: "path/to/file.rb", lineno: 123, label: "UserService#create" }
    #   #  }
    #
    # ==== Arguments
    #
    # * +:payload+ - The event payload when using string/symbol event names.
    #
    # * +:caller_depth+ - The stack depth to use for source location (default: 1).
    #
    # * +:kwargs+ - Additional payload data when using string/symbol event names.
    def notify(name_or_object, payload = nil, caller_depth: 1, **kwargs)
      name = resolve_name(name_or_object)
      payload = resolve_payload(name_or_object, payload, **kwargs)

      event = {
        name: name,
        payload: payload,
        tags: TagStack.tags,
        context: context_store.context,
        timestamp: Process.clock_gettime(Process::CLOCK_REALTIME, :nanosecond),
      }

      caller_location = caller_locations(caller_depth, 1)&.first

      if caller_location
        source_location = {
          filepath: caller_location.path,
          lineno: caller_location.lineno,
          label: caller_location.label,
        }
        event[:source_location] = source_location
      end

      @subscribers.each do |subscriber_entry|
        subscriber = subscriber_entry[:subscriber]
        filter = subscriber_entry[:filter]

        next if filter && !filter.call(event)

        subscriber.emit(event)
      rescue => subscriber_error
        if raise_on_error?
          raise
        else
          ActiveSupport.error_reporter.report(subscriber_error, handled: true)
        end
      end

      nil
    end

    # Temporarily enables debug mode for the duration of the block.
    # Calls to +debug+ will only be reported if debug mode is enabled.
    #
    #   Rails.event.with_debug do
    #     Rails.event.debug("sql.query", { sql: "SELECT * FROM users" })
    #   end
    def with_debug
      prior = Fiber[:event_reporter_debug_mode]
      Fiber[:event_reporter_debug_mode] = true
      yield
    ensure
      Fiber[:event_reporter_debug_mode] = prior
    end

    # Check if debug mode is currently enabled. Debug mode is enabled on the reporter
    # via +with_debug+, and in local environments.
    def debug_mode?
      @debug_mode || Fiber[:event_reporter_debug_mode]
    end

    # Report an event only when in debug mode. For example:
    #
    #   Rails.event.debug("sql.query", { sql: "SELECT * FROM users" })
    #
    # ==== Arguments
    #
    # * +:payload+ - The event payload when using string/symbol event names.
    #
    # * +:caller_depth+ - The stack depth to use for source location (default: 1).
    #
    # * +:kwargs+ - Additional payload data when using string/symbol event names.
    def debug(name_or_object, payload = nil, caller_depth: 1, **kwargs)
      if debug_mode?
        if block_given?
          notify(name_or_object, payload, caller_depth: caller_depth + 1, **kwargs.merge(yield))
        else
          notify(name_or_object, payload, caller_depth: caller_depth + 1, **kwargs)
        end
      end
    end

    # Add tags to events to supply additional context. Tags operate in a stack-oriented manner,
    # so all events emitted within the block inherit the same set of tags. For example:
    #
    #   Rails.event.tagged("graphql") do
    #     Rails.event.notify("user.created", { id: 123 })
    #   end
    #
    #   # Emits event:
    #   # {
    #   #    name: "user.created",
    #   #    payload: { id: 123 },
    #   #    tags: { graphql: true },
    #   #    context: {},
    #   #    timestamp: 1738964843208679035,
    #   #    source_location: { filepath: "path/to/file.rb", lineno: 123, label: "UserService#create" }
    #   #  }
    #
    # Tags can be provided as arguments or as keyword arguments, and can be nested:
    #
    #   Rails.event.tagged("graphql") do
    #   # Other code here...
    #     Rails.event.tagged(section: "admin") do
    #       Rails.event.notify("user.created", { id: 123 })
    #     end
    #   end
    #
    #   # Emits event:
    #   #  {
    #   #    name: "user.created",
    #   #    payload: { id: 123 },
    #   #    tags: { section: "admin", graphql: true },
    #   #    context: {},
    #   #    timestamp: 1738964843208679035,
    #   #    source_location: { filepath: "path/to/file.rb", lineno: 123, label: "UserService#create" }
    #   #  }
    #
    # The +tagged+ API can also receive a tag object:
    #
    #   graphql_tag = GraphqlTag.new(operation_name: "user_created", operation_type: "mutation")
    #   Rails.event.tagged(graphql_tag) do
    #     Rails.event.notify("user.created", { id: 123 })
    #   end
    #
    #   # Emits event:
    #   #  {
    #   #    name: "user.created",
    #   #    payload: { id: 123 },
    #   #    tags: { "GraphqlTag": #<GraphqlTag:0x111> },
    #   #    context: {},
    #   #    timestamp: 1738964843208679035,
    #   #    source_location: { filepath: "path/to/file.rb", lineno: 123, label: "UserService#create" }
    #   #  }
    def tagged(*args, **kwargs, &block)
      TagStack.with_tags(*args, **kwargs, &block)
    end

    # Sets context data that will be included with all events emitted by the reporter.
    # Context data should be scoped to the job or request, and is reset automatically
    # before and after each request and job.
    #
    #   Rails.event.set_context(user_agent: "TestAgent")
    #   Rails.event.set_context(job_id: "abc123")
    #   Rails.event.tagged("graphql") do
    #     Rails.event.notify("user_created", { id: 123 })
    #   end
    #
    #   # Emits event:
    #   #  {
    #   #    name: "user_created",
    #   #    payload: { id: 123 },
    #   #    tags: { graphql: true },
    #   #    context: { user_agent: "TestAgent", job_id: "abc123" },
    #   #    timestamp: 1738964843208679035
    #   #    source_location: { filepath: "path/to/file.rb", lineno: 123, label: "UserService#create" }
    #   #  }
    def set_context(context)
      context_store.set_context(context)
    end

    # Clears all context data.
    def clear_context
      context_store.clear
    end

    # Returns the current context data.
    def context
      context_store.context
    end

    def reload_payload_filter # :nodoc:
      @payload_filter = nil
      payload_filter
    end

    private
      def raise_on_error?
        @raise_on_error
      end

      def context_store
        self.class.context_store
      end

      def payload_filter
        @payload_filter ||= begin
          mask = ActiveSupport::ParameterFilter::FILTERED
          ActiveSupport::ParameterFilter.new(ActiveSupport.filter_parameters, mask: mask)
        end
      end

      def resolve_name(name_or_object)
        case name_or_object
        when String, Symbol
          name_or_object.to_s
        else
          name_or_object.class.name
        end
      end

      def resolve_payload(name_or_object, payload, **kwargs)
        case name_or_object
        when String, Symbol
          handle_unexpected_args(name_or_object, payload, kwargs) if payload && kwargs.any?
          if kwargs.any?
            payload_filter.filter(kwargs.transform_keys(&:to_sym))
          elsif payload
            payload_filter.filter(payload.transform_keys(&:to_sym))
          end
        else
          handle_unexpected_args(name_or_object, payload, kwargs) if payload || kwargs.any?
          name_or_object
        end
      end

      def handle_unexpected_args(name_or_object, payload, kwargs)
        message = <<~MESSAGE
          Rails.event.notify accepts either an event object, a payload hash, or keyword arguments.
          Received: #{name_or_object.inspect}, #{payload.inspect}, #{kwargs.inspect}
        MESSAGE

        if raise_on_error?
          raise ArgumentError, message
        else
          ActiveSupport.error_reporter.report(ArgumentError.new(message), handled: true)
        end
      end
  end
end
