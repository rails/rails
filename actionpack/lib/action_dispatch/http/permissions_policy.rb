# frozen_string_literal: true

require "active_support/core_ext/object/deep_dup"

module ActionDispatch # :nodoc:
  # Configures the HTTP
  # {Feature-Policy}[https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Feature-Policy]
  # response header to specify which browser features the current document and
  # its iframes can use.
  #
  # Example global policy:
  #
  #   Rails.application.config.permissions_policy do |policy|
  #     policy.camera      :none
  #     policy.gyroscope   :none
  #     policy.microphone  :none
  #     policy.usb         :none
  #     policy.fullscreen  :self
  #     policy.payment     :self, "https://secure.example.com"
  #   end
  #
  class PermissionsPolicy
    class Middleware
      CONTENT_TYPE       = "Content-Type"
      # The Feature-Policy header has been renamed to Permissions-Policy.
      # Since the Permissions-Policy isn't yet supported by all browsers,
      # this middleware inserts both headers. For now `POLICY` still refers
      # to the old header name. This will change in the future, when
      # Permissions-Policy is supported by all browsers.
      POLICY             = "Feature-Policy"
      PERMISSIONS_POLICY = "Permissions-Policy"

      def initialize(app)
        @app = app
      end

      def call(env)
        _, headers, _ = response = @app.call(env)

        return response unless html_response?(headers)
        return response if policy_present?(headers)

        request = ActionDispatch::Request.new(env)

        if policy = request.permissions_policy
          headers[PERMISSIONS_POLICY] = PermissionsPolicyHeader.build(policy, request.controller_instance)
          headers[POLICY] = FeaturePolicyHeader.build(policy, request.controller_instance)
        end

        if policy_empty?(policy)
          headers.delete(PERMISSIONS_POLICY)
          headers.delete(POLICY)
        end

        response
      end

      private
        def html_response?(headers)
          if content_type = headers[CONTENT_TYPE]
            content_type.include?("html")
          end
        end

        def policy_present?(headers)
          headers[PERMISSIONS_POLICY] || headers[POLICY]
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

    module PermissionsPolicyHeader
      MAPPINGS = {
        self: "self",
        none: "",
        all: "*",
      }.freeze

      module_function

      def build(policy, context = nil)
        build_directives(policy, context).compact.join(", ")
      end

      def build_directives(policy, context)
        policy.directives.map do |directive, s|
          sources = apply_mappings(s)
          if sources.is_a?(Array)
            allow_list = build_allow_list(sources, context)
            if allow_list.include?(MAPPINGS[:none])
              "#{directive}=()"
            elsif allow_list.include?(MAPPINGS[:all])
              "#{directive}=#{MAPPINGS[:all]}"
            else
              "#{directive}=(#{allow_list.join(' ')})"
            end
          elsif sources
            directive
          else
            nil
          end
        end
      end

      def build_allow_list(sources, context)
        sources.map { |source| resolve_source(source, context) }
      end

      def resolve_source(source, context)
        case source
        when String
          if MAPPINGS.value?(source)
            source
          else
            "\"#{source}\""
          end
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
    end

    module FeaturePolicyHeader
      MAPPINGS = {
        self: "'self'",
        none: "'none'",
        all: "*",
      }.freeze

      module_function

      def build(policy, context = nil)
        build_directives(policy, context).compact.join("; ")
      end

      def build_directives(policy, context)
        policy.directives.map do |directive, s|
          sources = apply_mappings(s)
          if sources.is_a?(Array)
            allow_list = build_allow_list(sources, context)
            if allow_list.include?(MAPPINGS[:none])
              "#{directive} #{MAPPINGS[:none]}"
            elsif allow_list.include?(MAPPINGS[:all])
              "#{directive} #{MAPPINGS[:all]}"
            else
              "#{directive} #{allow_list.join(' ')}"
            end
          elsif sources
            directive
          else
            nil
          end
        end
      end

      def build_allow_list(sources, context)
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
    end

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
      hid:                  "hid",
      idle_detection:       "idle_detection",
      magnetometer:         "magnetometer",
      microphone:           "microphone",
      midi:                 "midi",
      payment:              "payment",
      picture_in_picture:   "picture-in-picture",
      screen_wake_lock:     "screen-wake-lock",
      serial:               "serial",
      sync_xhr:             "sync-xhr",
      usb:                  "usb",
      web_share:            "web-share",
    }.freeze

    SOURCES = [:self, :none, :all].freeze

    private_constant :DIRECTIVES, :SOURCES

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
          validate_sources(sources)
          @directives[directive] = sources
        else
          @directives.delete(directive)
        end
      end
    end

    %w[speaker vibrate vr].each do |directive|
      define_method(directive) do |*sources|
        ActionDispatch.deprecator.warn(<<~MSG)
          The `#{directive}` permissions policy directive is deprecated
          and will be removed in Rails 7.2.

          There is no browser support for this directive, and no plan
          for browser support in the future. You can just remove this
          directive from your application.
        MSG

        if sources.first
          validate_sources(sources)
          @directives[directive] = sources
        else
          @directives.delete(directive)
        end
      end
    end

    private
      def validate_sources(sources)
        sources.map do |source|
          case source
          when Symbol
            unless SOURCES.include?(source)
              raise ArgumentError, "Unknown HTTP permissions policy source mapping: #{source.inspect}"
            end
          when String, Proc
            true
          else
            raise ArgumentError, "Invalid HTTP permissions policy source: #{source.inspect}"
          end
        end
      end
  end
end
