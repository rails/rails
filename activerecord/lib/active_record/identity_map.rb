module ActiveRecord
  # = Active Record Identity Map
  #
  # Ensures that each object gets loaded only once by keeping every loaded
  # object in a map. Looks up objects using the map when referring to them.
  #
  # More information on Identity Map pattern:
  #   http://www.martinfowler.com/eaaCatalog/identityMap.html
  #
  # == Configuration
  #
  # In order to enable IdentityMap, set <tt>config.active_record.identity_map = true</tt>
  # in your <tt>config/application.rb</tt> file.
  #
  # IdentityMap is disabled by default and still in development (i.e. use it with care).
  #
  # == Associations
  #
  # Active Record Identity Map does not track associations. For example:
  #
  #   comment = @post.comments.first
  #   comment.post = nil
  #   @post.comments.include?(comment) #=> true
  #
  # The @post's comments collection is stale and must be refreshed manually. Keeping bi-
  # directional associations in sync is a task left to the application developer.
  #
  # == Direct SQL
  #
  # It is up to the developer to keep the models already loaded from the database
  # in sync when changes are made to the database via SQL or methods that are sugar
  # for SQL (such as #reset_counters) by calling #reload.
  module IdentityMap

    class << self
      def enabled=(flag)
        Thread.current[:identity_map_enabled] = flag
      end

      def enabled
        Thread.current[:identity_map_enabled]
      end
      alias enabled? enabled

      def repository
        Thread.current[:identity_map] ||= Hash.new { |h,k| h[k] = {} }
      end

      def use
        old, self.enabled = enabled, true

        yield if block_given?
      ensure
        self.enabled = old
        clear
      end

      def without
        old, self.enabled = enabled, false

        yield if block_given?
      ensure
        self.enabled = old
      end

      def get(klass, record_attributes)
        return unless enabled?
        primary_key = klass.primary_key && record_attributes[klass.primary_key]
        return unless primary_key
        return unless has_all_and_only_all_required_attributes?(klass.column_names, record_attributes.keys)

        record = repository[klass.symbolized_sti_name][primary_key.to_s]

        return unless record.is_a?(klass)

        ActiveSupport::Notifications.instrument("identity.active_record",
          :line => "From Identity Map (id: #{primary_key})",
          :name => "#{klass} Loaded",
          :connection_id => object_id)

        record
      end

      def add(record)
        return unless enabled?
        return unless has_all_and_only_all_required_attributes?(record.class.column_names, record.attribute_names)
        repository[record.class.symbolized_sti_name][record.id.to_s] = record
      end

      def remove(record)
        return unless enabled?
        if record.is_a?(Array)
          record.each do |a_record|
            remove(a_record)
          end
        else
          remove_by_id(record.class.symbolized_sti_name, record.id)
        end
      end

      def remove_by_id(symbolized_sti_name, id)
        repository[symbolized_sti_name].delete(id.to_s)
      end

      def clear
        repository.clear
      end

      private

      # We only want the IM to store domain models. If you monkey around with
      # the select clause and bring back more or less attributes than
      # the domain defines, we do not consider this a domain model.
      def has_all_and_only_all_required_attributes?(required_attributes, attributes)
        return false if required_attributes.size != attributes.size
        return (required_attributes & attributes) == required_attributes
      end
    end

    class Middleware
      def initialize(app)
        @app = app
      end

      def call(env)
        enabled = IdentityMap.enabled
        IdentityMap.enabled = true

        response = @app.call(env)
        response[2] = Rack::BodyProxy.new(response[2]) do
          IdentityMap.enabled = enabled
          IdentityMap.clear
        end

        response
      end
    end
  end
end
