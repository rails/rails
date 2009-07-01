module Rails
  # Needs to be duplicated from Active Support since its needed before Active
  # Support is available. Here both Options and Hash are namespaced to prevent
  # conflicts with other implementations AND with the classes residing in Active Support.
  # ---
  # TODO: w0t?
  class << self
    # The Configuration instance used to configure the Rails environment
    def configuration
      @@configuration
    end

    def configuration=(configuration)
      @@configuration = configuration
    end

    def initialized?
      @initialized || false
    end

    def initialized=(initialized)
      @initialized ||= initialized
    end

    def logger
      if defined?(RAILS_DEFAULT_LOGGER)
        RAILS_DEFAULT_LOGGER
      else
        nil
      end
    end

    def backtrace_cleaner
      @@backtrace_cleaner ||= begin
        # Relies on ActiveSupport, so we have to lazy load to postpone definition until AS has been loaded
        require 'rails/backtrace_cleaner'
        Rails::BacktraceCleaner.new
      end
    end

    def root
      Pathname.new(RAILS_ROOT) if defined?(RAILS_ROOT)
    end

    def env
      @_env ||= ActiveSupport::StringInquirer.new(RAILS_ENV)
    end

    def cache
      RAILS_CACHE
    end

    def version
      VERSION::STRING
    end

    def public_path
      @@public_path ||= self.root ? File.join(self.root, "public") : "public"
    end

    def public_path=(path)
      @@public_path = path
    end
  end

  class OrderedOptions < Array #:nodoc:
    def []=(key, value)
      key = key.to_sym

      if pair = find_pair(key)
        pair.pop
        pair << value
      else
        self << [key, value]
      end
    end

    def [](key)
      pair = find_pair(key.to_sym)
      pair ? pair.last : nil
    end

    def method_missing(name, *args)
      if name.to_s =~ /(.*)=$/
        self[$1.to_sym] = args.first
      else
        self[name]
      end
    end

  private
    def find_pair(key)
      self.each { |i| return i if i.first == key }
      return false
    end
  end
end