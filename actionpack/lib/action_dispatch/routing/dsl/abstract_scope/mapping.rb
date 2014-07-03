module ActionDispatch
  module Routing
    class Constraints < Endpoint #:nodoc:
      attr_reader :app, :constraints

      def initialize(app, constraints, dispatcher_p)
        # Unwrap Constraints objects.  I don't actually think it's possible
        # to pass a Constraints object to this constructor, but there were
        # multiple places that kept testing children of this object.  I
        # *think* they were just being defensive, but I have no idea.
        if app.is_a?(self.class)
          constraints += app.constraints
          app = app.app
        end

        @dispatcher = dispatcher_p

        @app, @constraints, = app, constraints
      end

      def dispatcher?; @dispatcher; end

      def matches?(req)
        @constraints.all? do |constraint|
          (constraint.respond_to?(:matches?) && constraint.matches?(req)) ||
            (constraint.respond_to?(:call) && constraint.call(*constraint_args(constraint, req)))
        end
      end

      def serve(req)
        return [ 404, {'X-Cascade' => 'pass'}, [] ] unless matches?(req)

        if dispatcher?
          @app.serve req
        else
          @app.call req.env
        end
      end

      private
        def constraint_args(constraint, request)
          constraint.arity == 1 ? [request] : [request.path_parameters, request]
        end
    end

    
    class Mapping #:nodoc:
      ANCHOR_CHARACTERS_REGEX = %r{\A(\\A|\^)|(\\Z|\\z|\$)\Z}

      attr_reader :requirements, :conditions, :defaults
      attr_reader :to, :default_controller, :default_action, :as, :anchor

      def self.build(scope, path, options)
        options = scope.options.merge(options) if scope.options

        options.delete :only
        options.delete :except
        options.delete :shallow_path
        options.delete :shallow_prefix
        options.delete :shallow

        defaults = (scope.defaults || {}).merge options.delete(:defaults) || {}

        new scope, path, defaults, options
      end

      def initialize(scope, path, defaults, options)
        @requirements, @conditions = {}, {}
        @defaults = defaults

        @to                 = options.delete :to
        @default_controller = options.delete(:controller) || scope.controller
        @default_action     = options.delete(:action) || scope.action
        @as                 = options.delete :as
        @anchor             = options.delete :anchor

        formatted = options.delete :format
        via = Array(options.delete(:via) { [] })
        options_constraints = options.delete :constraints

        path = normalize_path! path, formatted
        ast  = path_ast path
        path_params = path_params ast

        options = normalize_options!(options, formatted, path_params, ast, scope.module)


        split_constraints(path_params, scope.constraints) if scope.constraints
        constraints = constraints(options, path_params)

        split_constraints path_params, constraints

        @blocks = blocks(options_constraints, scope.blocks)

        if options_constraints.is_a?(Hash)
          split_constraints path_params, options_constraints
          options_constraints.each do |key, default|
            if URL_OPTIONS.include?(key) && (String === default || Fixnum === default)
              @defaults[key] ||= default
            end
          end
        end

        normalize_format!(formatted)

        @conditions[:path_info] = path
        @conditions[:parsed_path_info] = ast

        add_request_method(via, @conditions)
        normalize_defaults!(options)
      end

      def to_route
        [ app(@blocks), conditions, requirements, defaults, as, anchor ]
      end

      private

        def normalize_path!(path, format)
          path = Mapper.normalize_path(path)

          if format == true
            "#{path}.:format"
          elsif optional_format?(path, format)
            "#{path}(.:format)"
          else
            path
          end
        end

        def optional_format?(path, format)
          format != false && !path.include?(':format') && !path.end_with?('/')
        end

        def normalize_options!(options, formatted, path_params, path_ast, modyoule)
          # Add a constraint for wildcard route to make it non-greedy and match the
          # optional format part of the route by default
          if formatted != false
            path_ast.grep(Journey::Nodes::Star) do |node|
              options[node.name.to_sym] ||= /.+?/
            end
          end

          if path_params.include?(:controller)
            raise ArgumentError, ":controller segment is not allowed within a namespace block" if modyoule

            # Add a default constraint for :controller path segments that matches namespaced
            # controllers with default routes like :controller/:action/:id(.:format), e.g:
            # GET /admin/products/show/1
            # => { controller: 'admin/products', action: 'show', id: '1' }
            options[:controller] ||= /.+?/
          end

          if to.respond_to? :call
            options
          else
            to_endpoint = split_to to
            controller  = to_endpoint[0] || default_controller
            action      = to_endpoint[1] || default_action

            controller = add_controller_module(controller, modyoule)

            options.merge! check_controller_and_action(path_params, controller, action)
          end
        end

        def split_constraints(path_params, constraints)
          constraints.each_pair do |key, requirement|
            if path_params.include?(key) || key == :controller
              verify_regexp_requirement(requirement) if requirement.is_a?(Regexp)
              @requirements[key] = requirement
            else
              @conditions[key] = requirement
            end
          end
        end

        def normalize_format!(formatted)
          if formatted == true
            @requirements[:format] ||= /.+/
          elsif Regexp === formatted
            @requirements[:format] = formatted
            @defaults[:format] = nil
          elsif String === formatted
            @requirements[:format] = Regexp.compile(formatted)
            @defaults[:format] = formatted
          end
        end

        def verify_regexp_requirement(requirement)
          if requirement.source =~ ANCHOR_CHARACTERS_REGEX
            raise ArgumentError, "Regexp anchor characters are not allowed in routing requirements: #{requirement.inspect}"
          end

          if requirement.multiline?
            raise ArgumentError, "Regexp multiline option is not allowed in routing requirements: #{requirement.inspect}"
          end
        end

        def normalize_defaults!(options)
          options.each_pair do |key, default|
            unless Regexp === default
              @defaults[key] = default
            end
          end
        end

        def verify_callable_constraint(callable_constraint)
          unless callable_constraint.respond_to?(:call) || callable_constraint.respond_to?(:matches?)
            raise ArgumentError, "Invalid constraint: #{callable_constraint.inspect} must respond to :call or :matches?"
          end
        end

        def add_request_method(via, conditions)
          return if via == [:all]

          if via.empty?
            msg = "You should not use the `match` method in your router without specifying an HTTP method.\n" \
                  "If you want to expose your action to both GET and POST, add `via: [:get, :post]` option.\n" \
                  "If you want to expose your action to GET, use `get` in the router:\n" \
                  "  Instead of: match \"controller#action\"\n" \
                  "  Do: get \"controller#action\""
            raise ArgumentError, msg
          end

          conditions[:request_method] = via.map { |m| m.to_s.dasherize.upcase }
        end

        def app(blocks)
          return to if Redirect === to

          if to.respond_to?(:call)
            Constraints.new(to, blocks, false)
          else
            if blocks.any?
              Constraints.new(dispatcher, blocks, true)
            else
              dispatcher
            end
          end
        end

        def check_controller_and_action(path_params, controller, action)
          hash = check_part(:controller, controller, path_params, {}) do |part|
            translate_controller(part) {
              message = "'#{part}' is not a supported controller name. This can lead to potential routing problems."
              message << " See http://guides.rubyonrails.org/routing.html#specifying-a-controller-to-use"

              raise ArgumentError, message
            }
          end

          check_part(:action, action, path_params, hash) { |part|
            part.is_a?(Regexp) ? part : part.to_s
          }
        end

        def check_part(name, part, path_params, hash)
          if part
            hash[name] = yield(part)
          else
            unless path_params.include?(name)
              message = "Missing :#{name} key on routes definition, please check your routes."
              raise ArgumentError, message
            end
          end
          hash
        end

        def split_to(to)
          case to
          when Symbol
            ActiveSupport::Deprecation.warn "defining a route where `to` is a symbol is deprecated.  Please change \"to: :#{to}\" to \"action: :#{to}\""
            [nil, to.to_s]
          when /#/    then to.split('#')
          when String
            ActiveSupport::Deprecation.warn "defining a route where `to` is a controller without an action is deprecated.  Please change \"to: :#{to}\" to \"controller: :#{to}\""
            [to, nil]
          else
            []
          end
        end

        def add_controller_module(controller, modyoule)
          if modyoule && !controller.is_a?(Regexp)
            if controller =~ %r{\A/}
              controller[1..-1]
            else
              [modyoule, controller].compact.join("/")
            end
          else
            controller
          end
        end

        def translate_controller(controller)
          return controller if Regexp === controller
          return controller.to_s if controller =~ /\A[a-z_0-9][a-z_0-9\/]*\z/

          yield
        end

        def blocks(options_constraints, scope_blocks)
          if options_constraints && !options_constraints.is_a?(Hash)
            verify_callable_constraint(options_constraints)
            [options_constraints]
          else
            scope_blocks || []
          end
        end

        def constraints(options, path_params)
          constraints = {}
          required_defaults = []
          options.each_pair do |key, option|
            if Regexp === option
              constraints[key] = option
            else
              required_defaults << key unless path_params.include?(key)
            end
          end
          @conditions[:required_defaults] = required_defaults
          constraints
        end

        def path_params(ast)
          ast.grep(Journey::Nodes::Symbol).map { |n| n.name.to_sym }
        end

        def path_ast(path)
          parser = Journey::Parser.new
          parser.parse path
        end

        def dispatcher
          Routing::RouteSet::Dispatcher.new(defaults)
        end
    end
  end
end
