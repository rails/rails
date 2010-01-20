require 'active_support/core_ext/hash/keys'

module ActionDispatch
  module Http
    module ParametersFilter
      INTERNAL_PARAMS = %w(controller action format _method only_path)
      
      @@filter_parameters = nil
      @@filter_parameters_block = nil
      
      # Specify sensitive parameters which will be replaced from the request log.
      # Filters parameters that have any of the arguments as a substring.
      # Looks in all subhashes of the param hash for keys to filter.
      # If a block is given, each key and value of the parameter hash and all
      # subhashes is passed to it, the value or key
      # can be replaced using String#replace or similar method.
      #
      # Examples:
      #
      #   ActionDispatch::Http::ParametersFilter.filter_parameters :password
      #   => replaces the value to all keys matching /password/i with "[FILTERED]"
      #
      #   ActionDispatch::Http::ParametersFilter.filter_parameters :foo, "bar"
      #   => replaces the value to all keys matching /foo|bar/i with "[FILTERED]"
      #
      #   ActionDispatch::Http::ParametersFilter.filter_parameters do |k,v|
      #     v.reverse! if k =~ /secret/i
      #   end
      #   => reverses the value to all keys matching /secret/i
      #
      #   ActionDispatch::Http::ParametersFilter.filter_parameters(:foo, "bar") do |k,v|
      #     v.reverse! if k =~ /secret/i
      #   end
      #   => reverses the value to all keys matching /secret/i, and
      #      replaces the value to all keys matching /foo|bar/i with "[FILTERED]"
      def self.filter_parameters(*filter_words, &block)
        raise "You must filter at least one word" if filter_words.empty? and !block_given?
        
        @@filter_parameters = filter_words.empty? ? nil : Regexp.new(filter_words.join('|'), true) 
        @@filter_parameters_block = block
      end
      
      # Return a hash of parameters with all sensitive data replaced.
      def filtered_parameters
        @filtered_parameters ||= process_parameter_filter(parameters)
      end
      alias_method :fitered_params, :filtered_parameters
      
      # Return a hash of request.env with all sensitive data replaced.
      def filtered_env
        @env.merge(@env) do |key, value|
          if (key =~ /RAW_POST_DATA/i)
            '[FILTERED]'
          else
            process_parameter_filter({key => value}, false).values[0]
          end
        end
      end
      
    protected
      
      def process_parameter_filter(original_parameters, validate_block = true)
        if @@filter_parameters or @@filter_parameters_block
          filtered_params = {}
          
          original_parameters.each do |key, value|
            if key =~ @@filter_parameters
              value = '[FILTERED]'
            elsif value.is_a?(Hash)
              value = process_parameter_filter(value)
            elsif value.is_a?(Array)
              value = value.map { |item| process_parameter_filter({key => item}, validate_block).values[0] }
            elsif validate_block and @@filter_parameters_block
              key = key.dup
              value = value.dup if value.duplicable?
              value = @@filter_parameters_block.call(key, value) || value
            end

            filtered_params[key] = value
          end
          filtered_params.except!(*INTERNAL_PARAMS)
        else
          original_parameters.except(*INTERNAL_PARAMS)
        end
      end
    end
  end
end