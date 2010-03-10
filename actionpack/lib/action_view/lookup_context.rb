require 'active_support/core_ext/object/try'
require 'active_support/core_ext/object/blank'

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
        value = Array(value.presence || yield)
        value |= [nil] unless options[:allow_nil] == false
        value
      end
    end

    register_detail(:formats) { Mime::SET.symbols }
    register_detail(:locale)  { [I18n.locale] }

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
    end

    def initialize(view_paths, details = {})
      @details_key = nil
      self.view_paths = view_paths
      self.details = details
    end

    module ViewPaths
      attr_reader :view_paths

      # Whenever setting view paths, makes a copy so we can manipulate then in
      # instance objects as we wish.
      def view_paths=(paths)
        @view_paths = ActionView::Base.process_view_paths(paths)
      end

      def find(name, prefix = nil, partial = false)
        @view_paths.find(name, prefix, partial || false, details, details_key)
      end

      def find_all(name, prefix = nil, partial = false)
        @view_paths.find_all(name, prefix, partial || false, details, details_key)
      end

      def exists?(name, prefix = nil, partial = false)
        @view_paths.exists?(name, prefix, partial || false, details, details_key)
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
      attr_reader :details

      def details=(details)
        @details = normalize_details(details)
        @details_key = nil if @details_key && @details_key.details != @details
      end

      def details_key
        @details_key ||= DetailsKey.get(@details)
      end

      # Shortcut to read formats from details.
      def formats
        @details[:formats].compact
      end

      # Shortcut to set formats in details.
      def formats=(value)
        self.details = @details.merge(:formats => value)
      end

      # Shortcut to read locale.
      def locale
        I18n.locale
      end

      # Shortcut to set locale in details and I18n.
      def locale=(value)
        I18n.locale = value

        unless I18n.config.respond_to?(:lookup_context)
          self.details = @details.merge(:locale => value)
        end
      end

      # Update the details keys by merging the given hash into the current
      # details hash. If a block is given, the details are modified just during
      # the execution of the block and reverted to the previous value after.
      def update_details(new_details)
        old_details  = @details
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
        details.freeze
      end
    end

    include Details
    include ViewPaths
  end
end