# frozen_string_literal: true

require "active_support/core_ext/object/deep_dup"

module ActionDispatch #:nodoc:
  class ContentSecurityPolicy
    class Middleware
      CONTENT_TYPE = "Content-Type"
      POLICY = "Content-Security-Policy"
      POLICY_REPORT_ONLY = "Content-Security-Policy-Report-Only"

      def initialize(app)
        @app = app
      end

      def call(env)
        request = ActionDispatch::Request.new env
        _, headers, _ = response = @app.call(env)

        return response if policy_present?(headers)

        if policy = request.content_security_policy
          nonce = request.content_security_policy_nonce
          nonce_directives = request.content_security_policy_nonce_directives
          context = request.controller_instance || request
          headers[header_name(request)] = policy.build(context, nonce, nonce_directives, headers[CONTENT_TYPE])
        end

        response
      end

      private
        def header_name(request)
          if request.content_security_policy_report_only
            POLICY_REPORT_ONLY
          else
            POLICY
          end
        end

        def policy_present?(headers)
          headers[POLICY] || headers[POLICY_REPORT_ONLY]
        end
    end

    module Request
      POLICY = "action_dispatch.content_security_policy"
      POLICY_REPORT_ONLY = "action_dispatch.content_security_policy_report_only"
      NONCE_GENERATOR = "action_dispatch.content_security_policy_nonce_generator"
      NONCE = "action_dispatch.content_security_policy_nonce"
      NONCE_DIRECTIVES = "action_dispatch.content_security_policy_nonce_directives"

      def content_security_policy
        get_header(POLICY)
      end

      def content_security_policy=(policy)
        set_header(POLICY, policy)
      end

      def content_security_policy_report_only
        get_header(POLICY_REPORT_ONLY)
      end

      def content_security_policy_report_only=(value)
        set_header(POLICY_REPORT_ONLY, value)
      end

      def content_security_policy_nonce_generator
        get_header(NONCE_GENERATOR)
      end

      def content_security_policy_nonce_generator=(generator)
        set_header(NONCE_GENERATOR, generator)
      end

      def content_security_policy_nonce_directives
        get_header(NONCE_DIRECTIVES)
      end

      def content_security_policy_nonce_directives=(generator)
        set_header(NONCE_DIRECTIVES, generator)
      end

      def content_security_policy_nonce
        if content_security_policy_nonce_generator
          if nonce = get_header(NONCE)
            nonce
          else
            set_header(NONCE, generate_content_security_policy_nonce)
          end
        end
      end

      private
        def generate_content_security_policy_nonce
          content_security_policy_nonce_generator.call(self)
        end
    end

    attr_reader :formats

    def initialize
      @formats = Hash.new { |h,k| h[k] = Format.new }
      yield self if block_given?
    end

    def initialize_copy(other)
      @formats = other.formats.deep_dup
    end

    (Mime::SET.map(&:to_sym) + [:any]).each do |type|
      class_eval(<<-METHOD, __FILE__, __LINE__ + 1)
        def #{type}
          if block_given?
            yield @formats[:#{type}]
          else
            @formats[:#{type}]
          end
        end
      METHOD
    end

    def build(context = nil, nonce = nil, nonce_directives = nil, content_type = "text/html")
      mime_type = Mime::Type.parse(content_type).first
      format = @formats.fetch(mime_type.to_sym, @formats[:html])
      format.build(context, nonce, nonce_directives, @formats[:any].directives)
    end

    def method_missing(method, *args)
      if html.respond_to?(method)
        html.send(method, *args)
      else
        super
      end
    end

    def respond_to_missing?(method, include_private = false)
      html.respond_to?(method, include_private) || super
    end

    class Format
      MAPPINGS = {
        self:           "'self'",
        unsafe_eval:    "'unsafe-eval'",
        unsafe_inline:  "'unsafe-inline'",
        none:           "'none'",
        http:           "http:",
        https:          "https:",
        data:           "data:",
        mediastream:    "mediastream:",
        blob:           "blob:",
        filesystem:     "filesystem:",
        report_sample:  "'report-sample'",
        strict_dynamic: "'strict-dynamic'",
        ws:             "ws:",
        wss:            "wss:"
      }.freeze

      DIRECTIVES = {
        base_uri:        "base-uri",
        child_src:       "child-src",
        connect_src:     "connect-src",
        default_src:     "default-src",
        font_src:        "font-src",
        form_action:     "form-action",
        frame_ancestors: "frame-ancestors",
        frame_src:       "frame-src",
        img_src:         "img-src",
        manifest_src:    "manifest-src",
        media_src:       "media-src",
        object_src:      "object-src",
        prefetch_src:    "prefetch-src",
        script_src:      "script-src",
        script_src_attr: "script-src-attr",
        script_src_elem: "script-src-elem",
        style_src:       "style-src",
        style_src_attr:  "style-src-attr",
        style_src_elem:  "style-src-elem",
        worker_src:      "worker-src"
      }.freeze

      DEFAULT_NONCE_DIRECTIVES = %w[script-src style-src].freeze

      private_constant :MAPPINGS, :DIRECTIVES, :DEFAULT_NONCE_DIRECTIVES

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

      def block_all_mixed_content(enabled = true)
        if enabled
          @directives["block-all-mixed-content"] = true
        else
          @directives.delete("block-all-mixed-content")
        end
      end

      def plugin_types(*types)
        if types.first
          @directives["plugin-types"] = types
        else
          @directives.delete("plugin-types")
        end
      end

      def report_uri(uri)
        @directives["report-uri"] = [uri]
      end

      def require_sri_for(*types)
        if types.first
          @directives["require-sri-for"] = types
        else
          @directives.delete("require-sri-for")
        end
      end

      def sandbox(*values)
        if values.empty?
          @directives["sandbox"] = true
        elsif values.first
          @directives["sandbox"] = values
        else
          @directives.delete("sandbox")
        end
      end

      def upgrade_insecure_requests(enabled = true)
        if enabled
          @directives["upgrade-insecure-requests"] = true
        else
          @directives.delete("upgrade-insecure-requests")
        end
      end

      def build(context = nil, nonce = nil, nonce_directives = nil, global_directives = {})
        nonce_directives = DEFAULT_NONCE_DIRECTIVES if nonce_directives.nil?
        build_directives(context, nonce, nonce_directives, global_directives).compact.join("; ")
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
              raise ArgumentError, "Invalid content security policy source: #{source.inspect}"
            end
          end
        end

        def apply_mapping(source)
          MAPPINGS.fetch(source) do
            raise ArgumentError, "Unknown content security policy source mapping: #{source.inspect}"
          end
        end

        def build_directives(context, nonce, nonce_directives, global_directives)
          @directives.reverse_merge(global_directives).sort.map do |directive, sources|
            if sources.is_a?(Array)
              if nonce && nonce_directive?(directive, nonce_directives)
                "#{directive} #{build_directive(sources, context).join(' ')} 'nonce-#{nonce}'"
              else
                "#{directive} #{build_directive(sources, context).join(' ')}"
              end
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
              raise RuntimeError, "Missing context for the dynamic content security policy source: #{source.inspect}"
            else
              resolved = context.instance_exec(&source)
              resolved.is_a?(Symbol) ? apply_mapping(resolved) : resolved
            end
          else
            raise RuntimeError, "Unexpected content security policy source: #{source.inspect}"
          end
        end

        def nonce_directive?(directive, nonce_directives)
          nonce_directives.include?(directive)
        end
    end
  end
end
