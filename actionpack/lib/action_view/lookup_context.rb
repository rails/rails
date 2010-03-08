require 'active_support/core_ext/object/try'

module ActionView
  # LookupContext is the object responsible to hold all information required to lookup
  # templates, i.e. view paths and details. The LookupContext is also responsible to
  # generate a key, given to view paths, used in the resolver cache lookup. Since
  # this key is generated just once during the request, it speeds up all cache accesses.
  class LookupContext #:nodoc:
    mattr_accessor :fallbacks
    @@fallbacks = [FileSystemResolver.new(""), FileSystemResolver.new("/")]

    mattr_accessor :registered_details
    self.registered_details = {}

    def self.register_detail(name, options = {})
      registered_details[name] = lambda do |value|
        value = (value.blank? || options[:accessible] == false) ?
          Array(yield) : Array(value)
        value |= [nil] unless options[:allow_nil] == false
        value
      end
    end

    register_detail(:formats) { Mime::SET.symbols }
    register_detail(:locale, :accessible => false) { [I18n.locale] }
    register_detail(:handlers, :accessible => false) { Template::Handlers.extensions }

    class DetailsKey #:nodoc:
      attr_reader :details
      alias :eql? :equal?

      @details_keys = Hash.new

      def self.get(details)
        @details_keys[details] ||= new(details)
      end

      def initialize(details)
        @details, @hash = details, details.hash
      end

      def outdated?(details)
        @details != details
      end
    end

    def initialize(view_paths, details = {})
      self.view_paths = view_paths
      self.details = details
      @details_key = nil
    end

    module ViewPaths
      attr_reader :view_paths

      # Whenever setting view paths, makes a copy so we can manipulate then in
      # instance objects as we wish.
      def view_paths=(paths)
        @view_paths = ActionView::Base.process_view_paths(paths)
      end

      def find(name, prefix = nil, partial = false)
        key = details_key
        @view_paths.find(name, prefix, partial || false, key.details, key)
      end

      def find_all(name, prefix = nil, partial = false)
        key = details_key
        @view_paths.find_all(name, prefix, partial || false, key.details, key)
      end

      def exists?(name, prefix = nil, partial = false)
        key = details_key
        @view_paths.exists?(name, prefix, partial || false, key.details, key)
      end

      # Add fallbacks to the view paths. Useful in cases you are rendering a file.
      def with_fallbacks
        added_resolvers = 0
        self.class.fallbacks.each do |resolver|
          next if view_paths.include?(resolver)
          view_paths.push(resolver)
          added_resolvers += 1
        end
        yield
      ensure
        added_resolvers.times { view_paths.pop }
      end
    end

    module Details
      def details
        @details = normalize_details(@details)
      end

      def details=(new_details)
        @details = new_details
        details
      end

      # TODO This is too expensive. Revisit this.
      def details_key
        latest_details = self.details
        @details_key   = nil if @details_key.try(:outdated?, latest_details)
        @details_key ||= DetailsKey.get(latest_details)
      end

      # Shortcut to read formats from details.
      def formats
        self.details[:formats]
      end

      # Shortcut to set formats in details.
      def formats=(value)
        self.details = @details.merge(:formats => value)
      end

      # Update the details keys by merging the given hash into the current
      # details hash. If a block is given, the details are modified just during
      # the execution of the block and reverted to the previous value after.
      def update_details(new_details)
        old_details  = self.details
        self.details = old_details.merge(new_details)

        if block_given?
          begin
            yield
          ensure
            self.details = old_details
          end
        end
      end

    protected

      def normalize_details(details)
        details = details.dup
        # TODO: Refactor this concern out of the resolver
        details.delete(:formats) if details[:formats] == [:"*/*"]
        self.class.registered_details.each do |k, v|
          details[k] = v.call(details[k])
        end
        details
      end
    end

    include Details
    include ViewPaths
  end
end