module ActionDispatch
  module Routing
    module DSL
      class AbstractScope
        # Mount a Rack-based application to be used within the application.
        #
        #   mount SomeRackApp, at: "some_route"
        #
        # Alternatively:
        #
        #   mount(SomeRackApp => "some_route")
        #
        # For options, see +match+, as +mount+ uses it internally.
        #
        # All mounted applications come with routing helpers to access them.
        # These are named after the class specified, so for the above example
        # the helper is either +some_rack_app_path+ or +some_rack_app_url+.
        # To customize this helper's name, use the +:as+ option:
        #
        #   mount(SomeRackApp => "some_route", as: "exciting")
        #
        # This will generate the +exciting_path+ and +exciting_url+ helpers
        # which can be used to navigate to this mounted app.
        def mount(app, options = nil)
          if options
            path = options.delete(:at)
          else
            unless Hash === app
              raise ArgumentError, "must be called with mount point"
            end

            options = app
            app, path = options.find { |k, _| k.respond_to?(:call) }
            options.delete(app) if app
          end

          raise "A rack application must be specified" unless path

          options[:as]  ||= app_name(app)
          target_as       = name_for_action(options[:as], path)
          options[:via] ||= :all

          match(path, options.merge(:to => app, :anchor => false, :format => false))

          define_generate_prefix(app, target_as)
          self
        end

        protected
          def app_name(app)
            return unless app.respond_to?(:routes)

            if app.respond_to?(:railtie_name)
              app.railtie_name
            else
              class_name = app.class.is_a?(Class) ? app.name : app.class.name
              ActiveSupport::Inflector.underscore(class_name).tr("/", "_")
            end
          end

          def define_generate_prefix(app, name)
            return unless app.respond_to?(:routes) && app.routes.respond_to?(:define_mounted_helper)

            _route = @set.named_routes.routes[name.to_sym]
            _routes = @set
            app.routes.define_mounted_helper(name)
            app.routes.extend Module.new {
              def mounted?; true; end
              define_method :find_script_name do |options|
                super(options) || begin
                prefix_options = options.slice(*_route.segment_keys)
                # we must actually delete prefix segment keys to avoid passing them to next url_for
                _route.segment_keys.each { |k| options.delete(k) }
                _routes.url_helpers.send("#{name}_path", prefix_options)
                end
              end
            }
          end

          def prefix_name_for_action(as, action) #:nodoc:
            if as
              prefix = as
            # elsif !canonical_action?(action, @scope[:scope_level])
            #   prefix = action
            end
            prefix.to_s.tr('-', '_') if prefix
          end

          def name_for_action(as, action) #:nodoc:
            prefix = prefix_name_for_action(as, action)
            prefix = normalize_name(prefix) if prefix
            name_prefix = self.as

            # if parent_resource
            #   return nil unless as || action

            #   collection_name = parent_resource.collection_name
            #   member_name = parent_resource.member_name
            # end

            # name = case @scope[:scope_level]
            # when :nested
            #   [name_prefix, prefix]
            # when :collection
            #   [prefix, name_prefix, collection_name]
            # when :new
            #   [prefix, :new, name_prefix, member_name]
            # when :member
            #   [prefix, name_prefix, member_name]
            # when :root
            #   [name_prefix, collection_name, prefix]
            # else
            #   [name_prefix, member_name, prefix]
            # end

            name = [name_prefix, prefix]

            if candidate = name.select(&:present?).join("_").presence
              # If a name was not explicitly given, we check if it is valid
              # and return nil in case it isn't. Otherwise, we pass the invalid name
              # forward so the underlying router engine treats it and raises an exception.
              if as.nil?
                candidate unless @set.routes.find { |r| r.name == candidate } || candidate !~ /\A[_a-z]/i
              else
                candidate
              end
            end
          end
      end
    end
  end
end
