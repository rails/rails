# frozen_string_literal: true

require "concurrent/map"
require "uri"
require "active_support/parameter_filter"

module ActionDispatch
  module Http
    # # Action Dispatch HTTP Filter Parameters
    #
    # Allows you to specify sensitive query string and POST parameters to filter
    # from the request log.
    #
    #     # Replaces values with "[FILTERED]" for keys that match /foo|bar/i.
    #     env["action_dispatch.parameter_filter"] = [:foo, "bar"]
    #
    # For more information about filter behavior, see
    # ActiveSupport::ParameterFilter.
    module FilterParameters
      # :stopdoc:
      ENV_MATCH = [/RAW_POST_DATA/, "rack.request.form_vars"].freeze
      NULL_PARAM_FILTER = ActiveSupport::ParameterFilter.new
      NULL_ENV_FILTER   = ActiveSupport::ParameterFilter.new ENV_MATCH

      # Cache ParameterFilter's because compiling Regexps is expensive and causes extra GC load
      @parameter_filters_cache = Concurrent::Map.new

      class << self
        def parameter_filter_for(filters) # :nodoc:
          if ActiveSupport::Ractors.main?
            # Guard against unbounded growth if an application generates ever-changing filter lists
            @parameter_filters_cache.clear if @parameter_filters_cache.size > 100
            @parameter_filters_cache.compute_if_absent(filters) { ActiveSupport::ParameterFilter.new(filters) }
          else
            ActiveSupport::ParameterFilter.new(filters)
          end
        end

        def filter_query_string(query_string, parameter_filter) # :nodoc:
          query_string.split(/(&)/).map do |part|
            if part.include?(";")
              # Segment filtering runs first because Proc callbacks may have
              # stateful effects even when a full-key mask supersedes the result.
              filtered_segments = part.split(/(;)/).map { |segment| filter_query_part(segment, parameter_filter) }.join
              filter_complete_query_part(part, parameter_filter) || filtered_segments
            else
              filter_query_part(part, parameter_filter)
            end
          end.join("")
        end

        private
          def filter_complete_query_part(part, parameter_filter)
            return unless part.include?("=")

            key, = part.split("=", 2)
            if (decoded_key = decoded_query_key(key))
              matched, mask = parameter_filter.filter_key_without_procs(decoded_key)
              "#{key}=#{mask}" if matched
            else
              "#{key}=#{ActiveSupport::ParameterFilter::FILTERED}"
            end
          end

          def filter_query_part(part, parameter_filter)
            if part.include?("=")
              key, value = part.split("=", 2)
              "#{key}=#{filter_query_value(key, value, parameter_filter)}"
            else
              part
            end
          end

          def filter_query_value(key, value, parameter_filter)
            if (decoded_key = decoded_query_key(key))
              parameter_filter.filter_param(decoded_key, value)
            else
              ActiveSupport::ParameterFilter::FILTERED
            end
          end

          def decoded_query_key(key)
            decoded_key = URI.decode_www_form_component(key)
            decoded_key if decoded_key.valid_encoding?
          rescue ArgumentError
            nil
          end
      end
      # :startdoc:

      def initialize
        super
        @filtered_parameters = nil
        @filtered_env        = nil
        @filtered_path       = nil
        @parameter_filter    = nil
      end

      # Returns a hash of parameters with all sensitive data replaced.
      def filtered_parameters
        @filtered_parameters ||= parameter_filter.filter(parameters)
      rescue ActionDispatch::Http::Parameters::ParseError
        @filtered_parameters = {}
      end

      # Returns a hash of request.env with all sensitive data replaced.
      def filtered_env
        @filtered_env ||= env_filter.filter(@env)
      end

      # Reconstructs a path with all sensitive GET parameters replaced.
      def filtered_path
        @filtered_path ||= query_string.empty? ? path : "#{path}?#{filtered_query_string}"
      end

      # Returns the `ActiveSupport::ParameterFilter` object used to filter in this
      # request.
      def parameter_filter
        @parameter_filter ||= if has_header?("action_dispatch.parameter_filter")
          parameter_filter_for get_header("action_dispatch.parameter_filter")
        else
          NULL_PARAM_FILTER
        end
      end

    private
      def env_filter # :doc:
        user_key = fetch_header("action_dispatch.parameter_filter") {
          return NULL_ENV_FILTER
        }
        parameter_filter_for(Array(user_key) + ENV_MATCH)
      end

      def parameter_filter_for(filters) # :doc:
        FilterParameters.parameter_filter_for(filters)
      end

      def filtered_query_string # :doc:
        FilterParameters.filter_query_string(query_string, parameter_filter)
      end
    end
  end
end
