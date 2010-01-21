require 'active_support/core_ext/hash/keys'

module ActionDispatch
  module Http
    module FilterParameters
      extend ActiveSupport::Concern

      INTERNAL_PARAMS = %w(controller action format _method only_path)

      module ClassMethods
        # Specify sensitive parameters which will be replaced from the request log.
        # Filters parameters that have any of the arguments as a substring.
        # Looks in all subhashes of the param hash for keys to filter.
        # If a block is given, each key and value of the parameter hash and all
        # subhashes is passed to it, the value or key
        # can be replaced using String#replace or similar method.
        #
        # Examples:
        #
        #   ActionDispatch::Request.filter_parameters :password
        #   => replaces the value to all keys matching /password/i with "[FILTERED]"
        #
        #   ActionDispatch::Request.filter_parameters :foo, "bar"
        #   => replaces the value to all keys matching /foo|bar/i with "[FILTERED]"
        #
        #   ActionDispatch::Request.filter_parameters do |k,v|
        #     v.reverse! if k =~ /secret/i
        #   end
        #   => reverses the value to all keys matching /secret/i
        #
        #   ActionDispatch::Request.filter_parameters(:foo, "bar") do |k,v|
        #     v.reverse! if k =~ /secret/i
        #   end
        #   => reverses the value to all keys matching /secret/i, and
        #      replaces the value to all keys matching /foo|bar/i with "[FILTERED]"
        def filter_parameters(*filter_words, &block)
          raise "You must filter at least one word" if filter_words.empty?

          parameter_filter = Regexp.new(filter_words.join('|'), true)

          define_method(:process_parameter_filter) do |original_params|
            filtered_params = {}

            original_params.each do |key, value|
              if key =~ parameter_filter
                value = '[FILTERED]'
              elsif value.is_a?(Hash)
                value = process_parameter_filter(value)
              elsif value.is_a?(Array)
                value = value.map { |i| process_parameter_filter(i) }
              elsif block_given?
                key = key.dup
                value = value.dup if value.duplicable?
                yield key, value
              end

              filtered_params[key] = value
            end

            filtered_params.except!(*INTERNAL_PARAMS)
          end

          protected :process_parameter_filter
        end
      end

      # Return a hash of parameters with all sensitive data replaced.
      def filtered_parameters
        @filtered_parameters ||= process_parameter_filter(parameters)
      end
      alias :fitered_params :filtered_parameters

      # Return a hash of request.env with all sensitive data replaced.
      # TODO Josh should white list env to remove stuff like rack.input and rack.errors
      def filtered_env
        filtered_env = @env.dup
        filtered_env.each do |key, value|
          if (key =~ /RAW_POST_DATA/i)
            filtered_env[key] = '[FILTERED]'
          elsif value.is_a?(Hash)
            filtered_env[key] = process_parameter_filter(value)
          end
        end
        filtered_env
      end

    protected

      def process_parameter_filter(original_parameters)
        original_parameters.except(*INTERNAL_PARAMS)
      end
    end
  end
end