require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/hash/keys'
require 'active_support/core_ext/object/duplicable'

module ActionDispatch
  module Http
    # Allows you to specify sensitive parameters which will be replaced from
    # the request log by looking in all subhashes of the param hash for keys
    # to filter. If a block is given, each key and value of the parameter
    # hash and all subhashes is passed to it, the value or key can be replaced
    # using String#replace or similar method.
    #
    # Examples:
    #
    #   env["action_dispatch.parameter_filter"] = [:password]
    #   => replaces the value to all keys matching /password/i with "[FILTERED]"
    #
    #   env["action_dispatch.parameter_filter"] = [:foo, "bar"]
    #   => replaces the value to all keys matching /foo|bar/i with "[FILTERED]"
    #
    #   env["action_dispatch.parameter_filter"] = lambda do |k,v|
    #     v.reverse! if k =~ /secret/i
    #   end
    #   => reverses the value to all keys matching /secret/i
    #
    module FilterParameters
      extend ActiveSupport::Concern

      @@compiled_parameter_filter_for = {}

      # Return a hash of parameters with all sensitive data replaced.
      def filtered_parameters
        @filtered_parameters ||= if filtering_parameters?
          process_parameter_filter(parameters)
        else
          parameters.dup
        end
      end
      alias :fitered_params :filtered_parameters

      # Return a hash of request.env with all sensitive data replaced.
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

      def filtering_parameters? #:nodoc:
        @env["action_dispatch.parameter_filter"].present?
      end

      def process_parameter_filter(params) #:nodoc:
        compiled_parameter_filter_for(@env["action_dispatch.parameter_filter"]).call(params)
      end

      def compile_parameter_filter(filters) #:nodoc:
        strings, regexps, blocks = [], [], []

        filters.each do |item|
          case item
          when NilClass
          when Proc
            blocks << item
          when Regexp
            regexps << item
          else
            strings << item.to_s
          end
        end

        regexps << Regexp.new(strings.join('|'), true) unless strings.empty?
        [regexps, blocks]
      end

      def compiled_parameter_filter_for(filters) #:nodoc:
        @@compiled_parameter_filter_for[filters] ||= begin
          regexps, blocks = compile_parameter_filter(filters)

          lambda do |original_params|
            filtered_params = {}

            original_params.each do |key, value|
              if regexps.find { |r| key =~ r }
                value = '[FILTERED]'
              elsif value.is_a?(Hash)
                value = process_parameter_filter(value)
              elsif value.is_a?(Array)
                value = value.map { |v| v.is_a?(Hash) ? process_parameter_filter(v) : v }
              elsif blocks.present?
                key = key.dup
                value = value.dup if value.duplicable?
                blocks.each { |b| b.call(key, value) }
              end

              filtered_params[key] = value
            end

            filtered_params
          end
        end
      end

    end
  end
end