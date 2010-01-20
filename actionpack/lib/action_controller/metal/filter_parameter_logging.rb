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
        ActionDispatch::Http::ParametersFilter.filter_parameters(*filter_words, &block)
      end
    end
    
  protected
    
    def filter_parameters(params)
      request.send(:process_parameter_filter, params)
    end
  end
end
