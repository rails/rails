module ActionView
  # LookupContext is the object responsible to hold all information required to lookup
  # templates, i.e. view paths and details. The LookupContext is also responsible to
  # generate a key, given to view paths, used in the resolver cache lookup. Since
  # this key is generated just once during the request, it speeds up all cache accesses.
  class LookupContext #:nodoc:
    attr_reader :details, :view_paths

    mattr_accessor :fallbacks
    @@fallbacks = [FileSystemResolver.new(""), FileSystemResolver.new("/")]

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
      @details, @details_key = details, nil
      self.view_paths = view_paths
    end

    # Shortcut to read formats from details.
    def formats
      @details[:formats]
    end

    # Shortcut to set formats in details.
    def formats=(value)
      self.details = @details.merge(:formats => Array(value))
    end

    # Whenever setting view paths, makes a copy so we can manipulate then in
    # instance objects as we wish.
    def view_paths=(paths)
      @view_paths = ActionView::Base.process_view_paths(paths)
    end

    # Setter for details. Everything this method is invoked, we need to nullify
    # the details key if it changed.
    def details=(details)
      @details = details
      @details_key = nil if @details_key && @details_key.details != details
    end

    def details_key
      @details_key ||= DetailsKey.get(details) unless details.empty?
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

    # Added fallbacks to the view paths. Useful in cases you are rendering a file.
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

    def find_template(name, prefix = nil, partial = false)
      @view_paths.find(name, details, prefix, partial || false, details_key)
    end

    def template_exists?(name, prefix = nil, partial = false)
      @view_paths.exists?(name, details, prefix, partial || false, details_key)
    end
  end
end