require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/regexp'

module ActionDispatch
  module Routing
    class Mapping #:nodoc:
      IGNORE_OPTIONS = [:to, :as, :via, :on, :constraints, :defaults, :only, :except, :anchor, :shallow, :shallow_path, :shallow_prefix]
      ANCHOR_CHARACTERS_REGEX = %r{\A(\\A|\^)|(\\Z|\\z|\$)\Z}
      SHORTHAND_REGEX = %r{/[\w/]+$}
      WILDCARD_PATH = %r{\*([^/\)]+)\)?$}

      def initialize(set, scope, path, options)
        @set, @scope = set, scope
        @options = (@scope[:options] || {}).merge(options)
        @path = normalize_path(path)
        normalize_options!
      end

      def to_route
        [ app, conditions, requirements, defaults, @options[:as], @options[:anchor] ]
      end

      private

        def normalize_options!
          path_without_format = @path.sub(/\(\.:format\)$/, '')

          if using_match_shorthand?(path_without_format, @options)
            to_shorthand    = @options[:to].blank?
            @options[:to] ||= path_without_format.gsub(/\(.*\)/, "")[1..-1].sub(%r{/([^/]*)$}, '#\1')
          end

          @options.merge!(default_controller_and_action(to_shorthand))

          requirements.each do |name, requirement|
            # segment_keys.include?(k.to_s) || k == :controller
            next unless Regexp === requirement && !constraints[name]

            if requirement.source =~ ANCHOR_CHARACTERS_REGEX
              raise ArgumentError, "Regexp anchor characters are not allowed in routing requirements: #{requirement.inspect}"
            end
            if requirement.multiline?
              raise ArgumentError, "Regexp multiline option not allowed in routing requirements: #{requirement.inspect}"
            end
          end
        end

        # match "account/overview"
        def using_match_shorthand?(path, options)
          path && (options[:to] || options[:action]).nil? && path =~ SHORTHAND_REGEX
        end

        def normalize_path(path)
          raise ArgumentError, "path is required" if path.blank?
          path = Mapper.normalize_path(path)

          if path.match(':controller')
            raise ArgumentError, ":controller segment is not allowed within a namespace block" if @scope[:module]

            # Add a default constraint for :controller path segments that matches namespaced
            # controllers with default routes like :controller/:action/:id(.:format), e.g:
            # GET /admin/products/show/1
            # => { :controller => 'admin/products', :action => 'show', :id => '1' }
            @options[:controller] ||= /.+?/
          end

          # Add a constraint for wildcard route to make it non-greedy and match the
          # optional format part of the route by default
          if path.match(WILDCARD_PATH) && @options[:format] != false
            @options[$1.to_sym] ||= /.+?/
          end

          if @options[:format] == false
            @options.delete(:format)
            path
          elsif path.include?(":format") || path.end_with?('/')
            path
          elsif @options[:format] == true
            "#{path}.:format"
          else
            "#{path}(.:format)"
          end
        end

        def app
          Constraints.new(
            to.respond_to?(:call) ? to : Routing::RouteSet::Dispatcher.new(:defaults => defaults),
            blocks,
            @set.request_class
          )
        end

        def conditions
          { :path_info => @path }.merge(constraints).merge(request_method_condition)
        end

        def requirements
          @requirements ||= (@options[:constraints].is_a?(Hash) ? @options[:constraints] : {}).tap do |requirements|
            requirements.reverse_merge!(@scope[:constraints]) if @scope[:constraints]
            @options.each { |k, v| requirements[k] = v if v.is_a?(Regexp) }
          end
        end

        def defaults
          @defaults ||= (@options[:defaults] || {}).tap do |defaults|
            defaults.reverse_merge!(@scope[:defaults]) if @scope[:defaults]
            @options.each { |k, v| defaults[k] = v unless v.is_a?(Regexp) || IGNORE_OPTIONS.include?(k.to_sym) }
          end
        end

        def default_controller_and_action(to_shorthand=nil)
          if to.respond_to?(:call)
            { }
          else
            if to.is_a?(String)
              controller, action = to.split('#')
            elsif to.is_a?(Symbol)
              action = to.to_s
            end

            controller ||= default_controller
            action     ||= default_action

            unless controller.is_a?(Regexp) || to_shorthand
              controller = [@scope[:module], controller].compact.join("/").presence
            end

            if controller.is_a?(String) && controller =~ %r{\A/}
              raise ArgumentError, "controller name should not start with a slash"
            end

            controller = controller.to_s unless controller.is_a?(Regexp)
            action     = action.to_s     unless action.is_a?(Regexp)

            if controller.blank? && segment_keys.exclude?("controller")
              raise ArgumentError, "missing :controller"
            end

            if action.blank? && segment_keys.exclude?("action")
              raise ArgumentError, "missing :action"
            end

            hash = {}
            hash[:controller] = controller unless controller.blank?
            hash[:action]     = action unless action.blank?
            hash
          end
        end

        def blocks
          constraints = @options[:constraints]
          if constraints.present? && !constraints.is_a?(Hash)
            [constraints]
          else
            @scope[:blocks] || []
          end
        end

        def constraints
          @constraints ||= requirements.reject { |k, v| segment_keys.include?(k.to_s) || k == :controller }
        end

        def request_method_condition
          if via = @options[:via]
            list = Array(via).map { |m| m.to_s.dasherize.upcase }
            { :request_method => list }
          else
            { }
          end
        end

        def segment_keys
          @segment_keys ||= Journey::Path::Pattern.new(
            Journey::Router::Strexp.compile(@path, requirements, SEPARATORS)
          ).names
        end

        def to
          @options[:to]
        end

        def default_controller
          @options[:controller] || @scope[:controller]
        end

        def default_action
          @options[:action] || @scope[:action]
        end
    end
  end
end
