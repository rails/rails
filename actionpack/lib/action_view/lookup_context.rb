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
    self.registered_details = []

    def self.register_detail(name, options = {}, &block)
      self.registered_details << name

      Setters.send :define_method, :"_#{name}_defaults", &block
      Setters.module_eval <<-METHOD, __FILE__, __LINE__ + 1
        def #{name}=(value)
          value = Array(value.presence || _#{name}_defaults)
          #{"value << nil unless value.include?(nil)" unless options[:allow_nil] == false}

          unless value == @details[:#{name}]
            @details_key, @details = nil, @details.merge(:#{name} => value)
            @details.freeze
          end
        end
      METHOD
    end

    # Holds raw setters for the registered details.
    module Setters #:nodoc:
    end

    register_detail(:formats) { Mime::SET.symbols }
    register_detail(:locale)  { [I18n.locale] }

    class DetailsKey #:nodoc:
      alias :eql? :equal?
      alias :object_hash :hash

      attr_reader :hash
      @details_keys = Hash.new

      def self.get(details)
        @details_keys[details] ||= new
      end

      def initialize
        @hash = object_hash
      end
    end

    def initialize(view_paths, details = {})
      @details, @details_key = {}, nil
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
        @view_paths.find(name, prefix, partial, details, details_key)
      end
      alias :find_template :find

      def find_all(name, prefix = nil, partial = false)
        @view_paths.find_all(name, prefix, partial, details, details_key)
      end

      def exists?(name, prefix = nil, partial = false)
        @view_paths.exists?(name, prefix, partial, details, details_key)
      end
      alias :template_exists? :exists?

      # Add fallbacks to the view paths. Useful in cases you are rendering a :file.
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

      def details=(given_details)
        registered_details.each { |key| send(:"#{key}=", given_details[key]) }
      end

      def details_key
        @details_key ||= DetailsKey.get(@details)
      end

      # Shortcut to read formats from details.
      def formats
        @details[:formats].compact
      end

      # Overload formats= to reject [:"*/*"] values.
      def formats=(value, freeze=true)
        value = nil if value == [:"*/*"]
        super(value)
      end

      # Shortcut to read locale.
      def locale
        I18n.locale
      end

      # Overload locale= to also set the I18n.locale. If the current I18n.config object responds
      # to i18n_config, it means that it's has a copy of the original I18n configuration and it's
      # acting as proxy, which we need to skip.
      def locale=(value)
        value = value.first if value.is_a?(Array)
        config = I18n.config.respond_to?(:i18n_config) ? I18n.config.i18n_config : I18n.config
        config.locale = value if value
        super(I18n.locale)
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
            @details = old_details
          end
        end
      end
    end

    include Setters
    include Details
    include ViewPaths
  end
end