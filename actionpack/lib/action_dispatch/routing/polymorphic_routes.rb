# frozen_string_literal: true

# :markup: markdown

module ActionDispatch
  module Routing
    # # Action Dispatch Routing PolymorphicRoutes
    #
    # Polymorphic URL helpers are methods for smart resolution to a named route call
    # when given an Active Record model instance. They are to be used in combination
    # with ActionController::Resources.
    #
    # These methods are useful when you want to generate the correct URL or path to
    # a RESTful resource without having to know the exact type of the record in
    # question.
    #
    # Nested resources and/or namespaces are also supported, as illustrated in the
    # example:
    #
    #     polymorphic_url([:admin, @article, @comment])
    #
    # results in:
    #
    #     admin_article_comment_url(@article, @comment)
    #
    # ## Usage within the framework
    #
    # Polymorphic URL helpers are used in a number of places throughout the Rails
    # framework:
    #
    # *   `url_for`, so you can use it with a record as the argument, e.g.
    #     `url_for(@article)`;
    # *   ActionView::Helpers::FormHelper uses `polymorphic_path`, so you can write
    #     `form_with(model: @article)` without having to specify `:url` parameter for the
    #     form action;
    # *   `redirect_to` (which, in fact, uses `url_for`) so you can write
    #     `redirect_to(post)` in your controllers;
    # *   ActionView::Helpers::AtomFeedHelper, so you don't have to explicitly
    #     specify URLs for feed entries.
    #
    #
    # ## Prefixed polymorphic helpers
    #
    # In addition to `polymorphic_url` and `polymorphic_path` methods, a number of
    # prefixed helpers are available as a shorthand to `action: "..."` in options.
    # Those are:
    #
    # *   `edit_polymorphic_url`, `edit_polymorphic_path`
    # *   `new_polymorphic_url`, `new_polymorphic_path`
    #
    #
    # Example usage:
    #
    #     edit_polymorphic_path(@post)           # => "/posts/1/edit"
    #     polymorphic_path(@post, format: :pdf)  # => "/posts/1.pdf"
    #
    # ## Usage with mounted engines
    #
    # If you are using a mounted engine and you need to use a polymorphic_url
    # pointing at the engine's routes, pass in the engine's route proxy as the first
    # argument to the method. For example:
    #
    #     polymorphic_url([blog, @post])  # calls blog.post_path(@post)
    #     form_with(model: [blog, @post]) # => "/blog/posts/1"
    #
    module PolymorphicRoutes
      # Constructs a call to a named RESTful route for the given record and returns
      # the resulting URL string. For example:
      #
      #     # calls post_url(post)
      #     polymorphic_url(post) # => "http://example.com/posts/1"
      #     polymorphic_url([blog, post]) # => "http://example.com/blogs/1/posts/1"
      #     polymorphic_url([:admin, blog, post]) # => "http://example.com/admin/blogs/1/posts/1"
      #     polymorphic_url([user, :blog, post]) # => "http://example.com/users/1/blog/posts/1"
      #     polymorphic_url(Comment) # => "http://example.com/comments"
      #
      # #### Options
      #
      # *   `:action` - Specifies the action prefix for the named route: `:new` or
      #     `:edit`. Default is no prefix.
      # *   `:routing_type` - Allowed values are `:path` or `:url`. Default is `:url`.
      #
      #
      # Also includes all the options from `url_for`. These include such things as
      # `:anchor` or `:trailing_slash`. Example usage is given below:
      #
      #     polymorphic_url([blog, post], anchor: 'my_anchor')
      #       # => "http://example.com/blogs/1/posts/1#my_anchor"
      #     polymorphic_url([blog, post], anchor: 'my_anchor', script_name: "/my_app")
      #       # => "http://example.com/my_app/blogs/1/posts/1#my_anchor"
      #
      # For all of these options, see the documentation for
      # [url_for](rdoc-ref:ActionDispatch::Routing::UrlFor).
      #
      # #### Functionality
      #
      #     # an Article record
      #     polymorphic_url(record)  # same as article_url(record)
      #
      #     # a Comment record
      #     polymorphic_url(record)  # same as comment_url(record)
      #
      #     # it recognizes new records and maps to the collection
      #     record = Comment.new
      #     polymorphic_url(record)  # same as comments_url()
      #
      #     # the class of a record will also map to the collection
      #     polymorphic_url(Comment) # same as comments_url()
      #
      def polymorphic_url(record_or_hash_or_array, options = {})
        if Hash === record_or_hash_or_array
          options = record_or_hash_or_array.merge(options)
          record  = options.delete :id
          return polymorphic_url record, options
        end

        if mapping = polymorphic_mapping(record_or_hash_or_array)
          return mapping.call(self, [record_or_hash_or_array, options], false)
        end

        opts   = options.dup
        action = opts.delete :action
        type   = opts.delete(:routing_type) || :url

        HelperMethodBuilder.polymorphic_method self,
                                               record_or_hash_or_array,
                                               action,
                                               type,
                                               opts
      end

      # Returns the path component of a URL for the given record.
      def polymorphic_path(record_or_hash_or_array, options = {})
        if Hash === record_or_hash_or_array
          options = record_or_hash_or_array.merge(options)
          record  = options.delete :id
          return polymorphic_path record, options
        end

        if mapping = polymorphic_mapping(record_or_hash_or_array)
          return mapping.call(self, [record_or_hash_or_array, options], true)
        end

        opts   = options.dup
        action = opts.delete :action
        type   = :path

        HelperMethodBuilder.polymorphic_method self,
                                               record_or_hash_or_array,
                                               action,
                                               type,
                                               opts
      end

      %w(edit new).each do |action|
        module_eval <<-EOT, __FILE__, __LINE__ + 1
          # frozen_string_literal: true
          def #{action}_polymorphic_url(record_or_hash, options = {})
            polymorphic_url_for_action("#{action}", record_or_hash, options)
          end

          def #{action}_polymorphic_path(record_or_hash, options = {})
            polymorphic_path_for_action("#{action}", record_or_hash, options)
          end
        EOT
      end

      private
        def polymorphic_url_for_action(action, record_or_hash, options)
          polymorphic_url(record_or_hash, options.merge(action: action))
        end

        def polymorphic_path_for_action(action, record_or_hash, options)
          polymorphic_path(record_or_hash, options.merge(action: action))
        end

        def polymorphic_mapping(record)
          if record.respond_to?(:to_model)
            _routes.polymorphic_mappings[record.to_model.model_name.name]
          else
            _routes.polymorphic_mappings[record.class.name]
          end
        end

        class HelperMethodBuilder # :nodoc:
          CACHE = { path: {}, url: {} }

          def self.get(action, type)
            type = type.to_sym
            CACHE[type].fetch(action) { build action, type }
          end

          def self.url;  CACHE[:url][nil]; end
          def self.path; CACHE[:path][nil]; end

          def self.build(action, type)
            prefix = action ? "#{action}_" : ""
            suffix = type
            if action.to_s == "new"
              HelperMethodBuilder.singular prefix, suffix
            else
              HelperMethodBuilder.plural prefix, suffix
            end
          end

          def self.singular(prefix, suffix)
            new(->(name) { name.singular_route_key }, prefix, suffix)
          end

          def self.plural(prefix, suffix)
            new(->(name) { name.route_key }, prefix, suffix)
          end

          def self.polymorphic_method(recipient, record_or_hash_or_array, action, type, options)
            builder = get action, type

            case record_or_hash_or_array
            when Array
              record_or_hash_or_array = record_or_hash_or_array.compact
              if record_or_hash_or_array.empty?
                raise ArgumentError, "Nil location provided. Can't build URI."
              end
              if record_or_hash_or_array.first.is_a?(ActionDispatch::Routing::RoutesProxy)
                recipient = record_or_hash_or_array.shift
              end

              method, args = builder.handle_list record_or_hash_or_array
            when String, Symbol
              method, args = builder.handle_string record_or_hash_or_array
            when Class
              method, args = builder.handle_class record_or_hash_or_array

            when nil
              raise ArgumentError, "Nil location provided. Can't build URI."
            else
              method, args = builder.handle_model record_or_hash_or_array
            end

            if options.empty?
              recipient.public_send(method, *args)
            else
              recipient.public_send(method, *args, options)
            end
          end

          attr_reader :suffix, :prefix

          def initialize(key_strategy, prefix, suffix)
            @key_strategy = key_strategy
            @prefix       = prefix
            @suffix       = suffix
          end

          def handle_string(record)
            [get_method_for_string(record), []]
          end

          def handle_string_call(target, str)
            target.public_send get_method_for_string str
          end

          def handle_class(klass)
            [get_method_for_class(klass), []]
          end

          def handle_class_call(target, klass)
            target.public_send get_method_for_class klass
          end

          def handle_model(record)
            args  = []

            model = record.to_model
            named_route = if model.persisted?
              args << model
              get_method_for_string model.model_name.singular_route_key
            else
              get_method_for_class model
            end

            [named_route, args]
          end

          def handle_model_call(target, record)
            if mapping = polymorphic_mapping(target, record)
              mapping.call(target, [record], suffix == "path")
            else
              method, args = handle_model(record)
              target.public_send(method, *args)
            end
          end

          def handle_list(list)
            record_list = list.dup
            record      = record_list.pop

            args = []

            route = record_list.map do |parent|
              case parent
              when Symbol
                parent.to_s
              when String
                raise(ArgumentError, "Please use symbols for polymorphic route arguments.")
              when Class
                args << parent
                parent.model_name.singular_route_key
              else
                args << parent.to_model
                parent.to_model.model_name.singular_route_key
              end
            end

            route <<
            case record
            when Symbol
              record.to_s
            when String
              raise(ArgumentError, "Please use symbols for polymorphic route arguments.")
            when Class
              @key_strategy.call record.model_name
            else
              model = record.to_model
              if model.persisted?
                args << model
                model.model_name.singular_route_key
              else
                @key_strategy.call model.model_name
              end
            end

            route << suffix

            named_route = prefix + route.join("_")
            [named_route, args]
          end

          private
            def polymorphic_mapping(target, record)
              if record.respond_to?(:to_model)
                target._routes.polymorphic_mappings[record.to_model.model_name.name]
              else
                target._routes.polymorphic_mappings[record.class.name]
              end
            end

            def get_method_for_class(klass)
              name = @key_strategy.call klass.model_name
              get_method_for_string name
            end

            def get_method_for_string(str)
              "#{prefix}#{str}_#{suffix}"
            end

            [nil, "new", "edit"].each do |action|
              CACHE[:url][action]  = build action, "url"
              CACHE[:path][action] = build action, "path"
            end
        end
    end
  end
end
