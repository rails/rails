module ActionController
  module ContentSecurityPolicy
    extend ActiveSupport::Concern
    include AbstractController::Callbacks

    # A good introduction of CSP: http://www.html5rocks.com/en/tutorials/security/content-security-policy/
    # current CSP draft: http://w3c.github.io/webappsec/specs/content-security-policy/
    #
    # USAGE:
    # content_security_policy.enforce do |csp|
    #   csp.Directive = Source List
    # end
    # or
    # content_security_policy.enforce.Directive = Source List
    #
    # The Source List are all trusted origins that can be load in the browser
    #
    # Two modes
    # enforce: all untrusted resources will not be load in the browser, the policy will be set in HTTP header "Content-Security-Policy"
    # monitor: all untrusted resources will still be load, but will send the violation report back to server, the policy will be set in HTTP header "Content-Security-Policy-Report-Only"
    # For csp reporting, see rails/actionpack/lib/action_dispatch/middleware/content_security_policy_reporting.rb
    #
    #
    # Frequently used Directive:
    # default-src: define the defaults for any directive you leave unspecified.
    #              For example, if default-src is only set to https://example.com, and you didn't specify a img-src directive, then you can load images from https://example.com, and nowhere else.
    # connect-src: limits the origins to which you can connect (via XHR, WebSockets, and EventSource).
    # script-src: list the origins that can serve javascript file
    # style-src: list the origins that can serve stylesheets file
    # font-src: specifies the origins that can serve web fonts. Google’s Web Fonts could be enabled via font-src https://themes.googleusercontent.com
    # frame-src: lists the origins that can be embedded as frames. For example: frame-src https://youtube.com would enable embedding YouTube videos, but no other origins.
    # img-src: defines the origins from which images can be loaded.
    # object-src: allows control over Flash and other plugins.
    #
    # Four keywords in Source List:
    # none: Prevents loading resources from any source.
    # self: Allows loading resources from the same origin (same scheme, host and port).
    # unsafe-inline: Allows use of inline source elements such as style attribute, onclick. Can be used in both style-src and script-src
    # unsafe-eval: Allows unsafe dynamic code evaluation such as JavaScript eval(). Can be used in script-src
    #
    # All these four keywords must be used in symbol :none, :self, :unsafe_inline, :unsafe_eval. Except these for keywords, other source elements must be enclosed in quote(single-quote or double-quote).
    # Other Frequently used source elements:
    # '*' : Wildcard, allows anything
    # 'data:' : Allows loading resources via the data scheme (eg Base64 encoded images).
    # 'https:' : Allows loading resources only over HTTPS on any domain
    #
    # Supporting adding csp policy in three level: applicationController level, controller level and action level.
    # Lower level will inherit the policy from topper level, and can change the policy through API like add-, remove-
    #  1. set a policy using
    #  class ApplicationController < ActionController::Base
    #    content_security_policy.enforce.default_src = :self
    #  end
    #  2. set a policy in img_src and add a policy in default_src
    #  class BlogController < ApplicationController
    #    content_security_policy.enforce do
    #      csp.img_src = :self, 'data:'
    #      csp.add_default_src 'https:'
    #    end
    #  end
    #  3. remove a policy
    #  class BlogController < ApplicationController
    #    content_security_policy.enforce do
    #      csp.img_src = :self, 'data:'
    #      csp.add_default_src 'https:'
    #    end
    #
    #    def show
    #      content_security_policy.enforce.remove_default_src 'https:'
    #    end
    #  end
    #
    #
    # Example:
    # in ApplicationController, set a loose policy works on entire rails application
    # content_security_policy.enforce do |csp|
    #   csp.default_src = :self, 'https:'
    #   csp.img_src = :self, ':data'
    #   csp.font_src = :self, ':data'
    #   csp.object_src = :none
    #   csp.script_src = :self, :unsafe_inline, 'https:'
    #   csp.style_src = :self, 'https:', :unsafe_inline
    # end
    #
    # in BlogController, set a policy stricter than the policy in ApplicationController,
    # For example, you want to load font from the fonts.cdn.example.com, and load image from imgs.cdn.example.com
    # content_security_policy.enforce do |csp|
    #   csp.add_img_src 'imgs.cdn.example.com'
    #   csp.add_font_src 'fonts.cdn.example.com'
    # end
    #
    # in action level of BlogController, set a strictest policy that only works for this action
    # For example, in show action, you want to provide the google plus button and facebook like button
    # def show
    #   content_security_policy.enforce.add_script_src "https://apis.google.com"
    #   content_security_policy.enforce.add_frame_src "https://plusone.google.com"
    #   content_security_policy.enforce.add_frame_src "https://facebook.com"
    # end

    class Builder
      def initialize(enforce = ContentSecurityPolicyConfig.new, monitor = ContentSecurityPolicyConfig.new)
        @enforce = enforce
        @monitor = monitor
      end

      def enforce
        @enforce ||= ContentSecurityPolicyConfig.new
        yield(@enforce) if block_given?
        @enforce
      end

      def monitor
        @monitor ||= ContentSecurityPolicyConfig.new
        yield(@monitor) if block_given?
        @monitor
      end

      def csp_headers
        csp_header = Hash.new
        unless @enforce.policy.empty?
          csp_header.merge!( { 'Content-Security-Policy' => stringify(@enforce.policy)} )
        end

        unless @monitor.policy.empty?
          csp_header.merge!( { 'Content-Security-Policy-Report-Only' => stringify(@monitor.policy)} )
        end
        csp_header
      end

      private
        def stringify(policy)
          policy.map { |key, value|
            stringify_symbol([hyphen(key)] + value).join(" ")
          }.join("; ")
        end

        def hyphen(str)
          str.gsub("_","-")
        end

        def stringify_symbol(value)
          value.map { |item| item.is_a?(Symbol) ? single_quote_keywords(item) : item }
        end

        #transit symbol keywords, which are self,none,unsafe-inline,unsafe-eval, into single-quoted string.
        def single_quote_keywords(symbol)
          "'#{hyphen(symbol.to_s)}'"
        end
    end

    class ContentSecurityPolicyConfig
      attr_reader :policy

      def initialize(policy = Hash.new)
        @policy = policy
      end

      def method_missing(method, *args)
        method = method.to_s
        unless  /^(add|remove)_(.+)$/ =~ method
          directive = tailor_directive(method)
          @policy[directive] = args.flatten
        else
          keywords = method.scan(/^(add|remove)_(.+)$/).flatten
          action, directive= keywords
          args = args.flatten
          case action
            when 'add'
              if @policy.has_key?(directive)
                @policy[directive] += args
              else
                @policy[directive] = args
              end
            when 'remove'
              if @policy.has_key?(directive)
                @policy[directive] -= args
              end
          end
        end
      end

      private
        def tailor_directive(directive)
          directive.sub(/=$/, '')
        end
    end

    module ClassMethods
      def inherited(klass)
        csp = copy_content_security_policy(content_security_policy)
        klass.class_eval { @content_security_policy = csp}
      end

      #copy the policy from applicationController to SubController, or from controller level to action level
      def copy_content_security_policy(csp)
        ContentSecurityPolicy::Builder.new(ContentSecurityPolicyConfig.new(csp.enforce.policy.dup), ContentSecurityPolicyConfig.new(csp.monitor.policy.dup))
      end

      #For both applicationController and sub-controller level
      def content_security_policy
        @content_security_policy ||= ContentSecurityPolicy::Builder.new
      end
    end

    #For action level
    def content_security_policy
      @content_security_policy ||= self.class.copy_content_security_policy(self.class.content_security_policy)
    end

    def process_action(*args)
      result = super
      if content_security_policy.csp_headers.has_key?('Content-Security-Policy')
        response.headers['Content-Security-Policy'] = content_security_policy.csp_headers['Content-Security-Policy']
      end
      if content_security_policy.csp_headers.has_key?('Content-Security-Policy-Report-Only')
        response.headers['Content-Security-Policy-Report-Only'] = content_security_policy.csp_headers['Content-Security-Policy-Report-Only']
      end
      result
    end
  end
end
