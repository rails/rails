module ActionController
  module FilterParameterLogging
    extend ActiveSupport::Concern

    include AbstractController::Logger

    included do
      include InstanceMethodsForNewBase
    end

    module ClassMethods
      # Replace sensitive parameter data from the request log.
      # Filters parameters that have any of the arguments as a substring.
      # Looks in all subhashes of the param hash for keys to filter.
      # If a block is given, each key and value of the parameter hash and all
      # subhashes is passed to it, the value or key
      # can be replaced using String#replace or similar method.
      #
      # Examples:
      #   filter_parameter_logging
      #   => Does nothing, just slows the logging process down
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
        parameter_filter = Regexp.new(filter_words.collect{ |s| s.to_s }.join('|'), true) if filter_words.length > 0

        define_method(:filter_parameters) do |unfiltered_parameters|
          filtered_parameters = {}

          unfiltered_parameters.each do |key, value|
            if key =~ parameter_filter
              filtered_parameters[key] = '[FILTERED]'
            elsif value.is_a?(Hash)
              filtered_parameters[key] = filter_parameters(value)
            elsif value.is_a?(Array)
              filtered_parameters[key] = value.collect do |item|
                filter_parameters(item)
              end
            elsif block_given?
              key = key.dup
              value = value.dup if value
              yield key, value
              filtered_parameters[key] = value
            else
              filtered_parameters[key] = value
            end
          end

          filtered_parameters
        end
        protected :filter_parameters
      end
    end

    module InstanceMethodsForNewBase
      # TODO : Fix the order of information inside such that it's exactly same as the old base
      def process(*)
        ret = super

        if logger
          parameters = respond_to?(:filter_parameters) ? filter_parameters(params) : params.dup
          parameters = parameters.except!(:controller, :action, :format, :_method, :only_path)

          unless parameters.empty?
            # TODO : Move DelayedLog to AS
            log = AbstractController::Logger::DelayedLog.new { "  Parameters: #{parameters.inspect}" }
            logger.info(log)
          end
        end

        ret
      end
    end

    private

    # TODO : This method is not needed for the new base
    def log_processing_for_parameters
      parameters = respond_to?(:filter_parameters) ? filter_parameters(params) : params.dup
      parameters = parameters.except!(:controller, :action, :format, :_method)

      logger.info "  Parameters: #{parameters.inspect}" unless parameters.empty?
    end
  end
end
