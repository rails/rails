module ActionController
  module FilterParameterLogging
    extend ActiveSupport::Concern

    module ClassMethods
      # Replace sensitive parameter data from the request log.
      # Filters parameters that have any of the arguments as a substring.
      # Looks in all subhashes of the param hash for keys to filter.
      # If a block is given, each key and value of the parameter hash and all
      # subhashes is passed to it, the value or key
      # can be replaced using String#replace or similar method.
      #
      # Examples:
      #
      #   filter_parameter_logging :password
      #   => replaces the value to all keys matching /password/i with "[FILTERED]"
      #
      #   filter_parameter_logging :foo, "bar"
      #   => replaces the value to all keys matching /foo|bar/i with "[FILTERED]"
      #
      #   filter_parameter_logging { |k,v| v.reverse! if k =~ /secret/i }
      #   => reverses the value to all keys matching /secret/i
      #
      #   filter_parameter_logging(:foo, "bar") { |k,v| v.reverse! if k =~ /secret/i }
      #   => reverses the value to all keys matching /secret/i, and
      #      replaces the value to all keys matching /foo|bar/i with "[FILTERED]"
      def filter_parameter_logging(*filter_words, &block)
        raise "You must filter at least one word from logging" if filter_words.empty?

        parameter_filter = Regexp.new(filter_words.join('|'), true)

        define_method(:filter_parameters) do |original_params|
          filtered_params = {}

          original_params.each do |key, value|
            if key =~ parameter_filter
              value = '[FILTERED]'
            elsif value.is_a?(Hash)
              value = filter_parameters(value)
            elsif value.is_a?(Array)
              value = value.map { |item| filter_parameters(item) }
            elsif block_given?
              key = key.dup
              value = value.dup if value.duplicable?
              yield key, value
            end

            filtered_params[key] = value
          end

          filtered_params
        end
        protected :filter_parameters
      end

    protected

      # Overwrite log_process_action to include parameters information.
      # If this method is invoked, it means logger is defined, so don't
      # worry with such scenario here.
      def log_process_action(controller) #:nodoc:
        params = controller.send(:filter_parameters, controller.request.params)
        logger.info "  Parameters: #{params.inspect}" unless params.empty?
        super
      end
    end

    INTERNAL_PARAMS = [:controller, :action, :format, :_method, :only_path]

  protected

    def filter_parameters(params)
      params.dup.except!(*INTERNAL_PARAMS)
    end

  end
end
