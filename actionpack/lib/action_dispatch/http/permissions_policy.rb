# frozen_string_literal: true

require "active_support/core_ext/object/deep_dup"

module ActionDispatch #:nodoc:
  class PermissionsPolicy
    class Middleware
      CONTENT_TYPE = "Content-Type"
      # The Feature-Policy header has been renamed to Permissions-Policy.
      # The Permissions-Policy requires a different implementation and isn't
      # yet supported by all browsers. To avoid having to rename this
      # middleware in the future we use the new name for the middleware but
      # keep the old header name and implementation for now.
      POLICY       = "Feature-Policy"

      def initialize(app)
        @app = app
      end

      def call(env)
        request = ActionDispatch::Request.new(env)
        _, headers, _ = response = @app.call(env)

        return response if policy_present?(headers)

        if policy = request.permissions_policy
          headers[POLICY] = policy.build(request.controller_instance)
        end

        if policy_empty?(policy)
          headers.delete(POLICY)
        end

        response
      end

      private
        def policy_present?(headers)
          headers[POLICY]
        end

        def policy_empty?(policy)
          policy&.directives&.empty?
        end
    end

    module Request
      POLICY = "action_dispatch.permissions_policy"

      def permissions_policy
        get_header(POLICY)
      end

      def permissions_policy=(policy)
        set_header(POLICY, policy)
      end
    end

    MAPPINGS = {
      self: "'self'",
      none: "'none'",
    }.freeze

    # List of available permissions can be found at
    # https://github.com/w3c/webappsec-permissions-policy/blob/master/features.md#policy-controlled-features
    DIRECTIVES = {
      accelerometer:        "accelerometer",
      ambient_light_sensor: "ambient-light-sensor",
      autoplay:             "autoplay",
      camera:               "camera",
      encrypted_media:      "encrypted-media",
      fullscreen:           "fullscreen",
      geolocation:          "geolocation",
      gyroscope:            "gyroscope",
      magnetometer:         "magnetometer",
      microphone:           "microphone",
      midi:                 "midi",
      payment:              "payment",
      picture_in_picture:   "picture-in-picture",
      speaker:              "speaker",
      usb:                  "usb",
      vibrate:              "vibrate",
      vr:                   "vr",
    }.freeze

    private_constant :MAPPINGS, :DIRECTIVES

    attr_reader :directives

    def initialize
      @directives = {}
      yield self if block_given?
    end

    def initialize_copy(other)
      @directives = other.directives.deep_dup
    end

    DIRECTIVES.each do |name, directive|
      define_method(name) do |*sources|
        if sources.first
          @directives[directive] = apply_mappings(sources)
        else
          @directives.delete(directive)
        end
      end
    end

    def build(context = nil)
      build_directives(context).compact.join("; ")
    end

    private
      def apply_mappings(sources)
        sources.map do |source|
          case source
          when Symbol
            apply_mapping(source)
          when String, Proc
            source
          else
            raise ArgumentError, "Invalid HTTP permissions policy source: #{source.inspect}"
          end
        end
      end

      def apply_mapping(source)
        MAPPINGS.fetch(source) do
          raise ArgumentError, "Unknown HTTP permissions policy source mapping: #{source.inspect}"
        end
      end

      def build_directives(context)
        @directives.map do |directive, sources|
          if sources.is_a?(Array)
            "#{directive} #{build_directive(sources, context).join(' ')}"
          elsif sources
            directive
          else
            nil
          end
        end
      end

      def build_directive(sources, context)
        sources.map { |source| resolve_source(source, context) }
      end

      def resolve_source(source, context)
        case source
        when String
          source
        when Symbol
          source.to_s
        when Proc
          if context.nil?
            raise RuntimeError, "Missing context for the dynamic permissions policy source: #{source.inspect}"
          else
            context.instance_exec(&source)
          end
        else
          raise RuntimeError, "Unexpected permissions policy source: #{source.inspect}"
        end
      end
  end
end
