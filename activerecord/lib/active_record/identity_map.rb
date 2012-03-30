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
  # Active Record Identity Map does not track associations yet. For example:
  #
  #   comment = @post.comments.first
  #   comment.post = nil
  #   @post.comments.include?(comment) #=> true
  #
  # Ideally, the example above would return false, removing the comment object from the
  # post association when the association is nullified. This may cause side effects, as
  # in the situation below, if Identity Map is enabled:
  #
  #   Post.has_many :comments, :dependent => :destroy
  #
  #   comment = @post.comments.first
  #   comment.post = nil
  #   comment.save
  #   Post.destroy(@post.id)
  #
  # Without using Identity Map, the code above will destroy the @post object leaving
  # the comment object intact. However, once we enable Identity Map, the post loaded
  # by Post.destroy is exactly the same object as the object @post. As the object @post
  # still has the comment object in @post.comments, once Identity Map is enabled, the
  # comment object will be accidently removed.
  #
  # This inconsistency is meant to be fixed in future Rails releases.
  #
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

      def get(klass, primary_key)
        record = repository[klass.symbolized_sti_name][primary_key]

        if record.is_a?(klass)
          ActiveSupport::Notifications.instrument("identity.active_record",
            :line => "From Identity Map (id: #{primary_key})",
            :name => "#{klass} Loaded",
            :connection_id => object_id)

          record
        else
          nil
        end
      end

      def add(record)
        repository[record.class.symbolized_sti_name][record.id] = record if contain_all_columns?(record)
      end

      def remove(record)
        repository[record.class.symbolized_sti_name].delete(record.id)
      end

      def remove_by_id(symbolized_sti_name, id)
        repository[symbolized_sti_name].delete(id)
      end

      def clear
        repository.clear
      end

      private

        def contain_all_columns?(record)
          (record.class.column_names - record.attribute_names).empty?
        end
    end

    # Reinitialize an Identity Map model object from +coder+.
    # +coder+ must contain the attributes necessary for initializing an empty
    # model object.
    def reinit_with(coder)
      @attributes_cache = {}
      dirty      = @changed_attributes.keys
      attributes = self.class.initialize_attributes(coder['attributes'].except(*dirty))
      @attributes.update(attributes)
      @changed_attributes.update(coder['attributes'].slice(*dirty))
      @changed_attributes.delete_if{|k,v| v.eql? @attributes[k]}

      run_callbacks :find

      self
    end

    class Middleware
      class Body #:nodoc:
        def initialize(target, original)
          @target   = target
          @original = original
        end

        def each(&block)
          @target.each(&block)
        end

        def close
          @target.close if @target.respond_to?(:close)
        ensure
          IdentityMap.enabled = @original
          IdentityMap.clear
        end
      end

      def initialize(app)
        @app = app
      end

      def call(env)
        enabled = IdentityMap.enabled
        IdentityMap.enabled = true
        status, headers, body = @app.call(env)
        [status, headers, Body.new(body, enabled)]
      end
    end
  end
end
