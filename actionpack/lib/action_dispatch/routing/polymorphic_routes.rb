module ActionDispatch
  module Routing
    # Polymorphic URL helpers are methods for smart resolution to a named route call when
    # given an Active Record model instance. They are to be used in combination with
    # ActionController::Resources.
    #
    # These methods are useful when you want to generate correct URL or path to a RESTful
    # resource without having to know the exact type of the record in question.
    #
    # Nested resources and/or namespaces are also supported, as illustrated in the example:
    #
    #   polymorphic_url([:admin, @article, @comment])
    #
    # results in:
    #
    #   admin_article_comment_url(@article, @comment)
    #
    # == Usage within the framework
    #
    # Polymorphic URL helpers are used in a number of places throughout the \Rails framework:
    #
    # * <tt>url_for</tt>, so you can use it with a record as the argument, e.g.
    #   <tt>url_for(@article)</tt>;
    # * ActionView::Helpers::FormHelper uses <tt>polymorphic_path</tt>, so you can write
    #   <tt>form_for(@article)</tt> without having to specify <tt>:url</tt> parameter for the form
    #   action;
    # * <tt>redirect_to</tt> (which, in fact, uses <tt>url_for</tt>) so you can write
    #   <tt>redirect_to(post)</tt> in your controllers;
    # * ActionView::Helpers::AtomFeedHelper, so you don't have to explicitly specify URLs
    #   for feed entries.
    #
    # == Prefixed polymorphic helpers
    #
    # In addition to <tt>polymorphic_url</tt> and <tt>polymorphic_path</tt> methods, a
    # number of prefixed helpers are available as a shorthand to <tt>:action => "..."</tt>
    # in options. Those are:
    #
    # * <tt>edit_polymorphic_url</tt>, <tt>edit_polymorphic_path</tt>
    # * <tt>new_polymorphic_url</tt>, <tt>new_polymorphic_path</tt>
    #
    # Example usage:
    #
    #   edit_polymorphic_path(@post)              # => "/posts/1/edit"
    #   polymorphic_path(@post, :format => :pdf)  # => "/posts/1.pdf"
    #
    # == Using with mounted engines
    #
    # If you use mounted engine, there is a possibility that you will need to use
    # polymorphic_url pointing at engine's routes. To do that, just pass proxy used
    # to reach engine's routes as a first argument:
    #
    # For example:
    #
    # polymorphic_url([blog, @post])  # it will call blog.post_path(@post)
    # form_for([blog, @post])         # => "/blog/posts/1
    #
    module PolymorphicRoutes
      # Constructs a call to a named RESTful route for the given record and returns the
      # resulting URL string. For example:
      #
      #   # calls post_url(post)
      #   polymorphic_url(post) # => "http://example.com/posts/1"
      #   polymorphic_url([blog, post]) # => "http://example.com/blogs/1/posts/1"
      #   polymorphic_url([:admin, blog, post]) # => "http://example.com/admin/blogs/1/posts/1"
      #   polymorphic_url([user, :blog, post]) # => "http://example.com/users/1/blog/posts/1"
      #   polymorphic_url(Comment) # => "http://example.com/comments"
      #
      # ==== Options
      #
      # * <tt>:action</tt> - Specifies the action prefix for the named route:
      #   <tt>:new</tt> or <tt>:edit</tt>. Default is no prefix.
      # * <tt>:routing_type</tt> - Allowed values are <tt>:path</tt> or <tt>:url</tt>.
      #   Default is <tt>:url</tt>.
      #
      # ==== Examples
      #
      #   # an Article record
      #   polymorphic_url(record)  # same as article_url(record)
      #
      #   # a Comment record
      #   polymorphic_url(record)  # same as comment_url(record)
      #
      #   # it recognizes new records and maps to the collection
      #   record = Comment.new
      #   polymorphic_url(record)  # same as comments_url()
      #
      #   # the class of a record will also map to the collection
      #   polymorphic_url(Comment) # same as comments_url()
      #
      def polymorphic_url(record_or_hash_or_array, options = {})
        if record_or_hash_or_array.kind_of?(Array)
          record_or_hash_or_array = record_or_hash_or_array.compact
          if record_or_hash_or_array.first.is_a?(ActionDispatch::Routing::RoutesProxy)
            proxy = record_or_hash_or_array.shift
          end
          record_or_hash_or_array = record_or_hash_or_array[0] if record_or_hash_or_array.size == 1
        end

        record = extract_record(record_or_hash_or_array)
        record = record.to_model if record.respond_to?(:to_model)

        args = Array === record_or_hash_or_array ?
          record_or_hash_or_array.dup :
          [ record_or_hash_or_array ]

        inflection = if options[:action] && options[:action].to_s == "new"
          args.pop
          :singular
        elsif (record.respond_to?(:persisted?) && !record.persisted?)
          args.pop
          :plural
        elsif record.is_a?(Class)
          args.pop
          :plural
        else
          :singular
        end

        args.delete_if {|arg| arg.is_a?(Symbol) || arg.is_a?(String)}
        named_route = build_named_route_call(record_or_hash_or_array, inflection, options)

        url_options = options.except(:action, :routing_type)
        unless url_options.empty?
          args.last.kind_of?(Hash) ? args.last.merge!(url_options) : args << url_options
        end

        (proxy || self).send(named_route, *args)
      end

      # Returns the path component of a URL for the given record. It uses
      # <tt>polymorphic_url</tt> with <tt>:routing_type => :path</tt>.
      def polymorphic_path(record_or_hash_or_array, options = {})
        polymorphic_url(record_or_hash_or_array, options.merge(:routing_type => :path))
      end

      %w(edit new).each do |action|
        module_eval <<-EOT, __FILE__, __LINE__ + 1
          def #{action}_polymorphic_url(record_or_hash, options = {})         # def edit_polymorphic_url(record_or_hash, options = {})
            polymorphic_url(                                                  #   polymorphic_url(
              record_or_hash,                                                 #     record_or_hash,
              options.merge(:action => "#{action}"))                          #     options.merge(:action => "edit"))
          end                                                                 # end
                                                                              #
          def #{action}_polymorphic_path(record_or_hash, options = {})        # def edit_polymorphic_path(record_or_hash, options = {})
            polymorphic_url(                                                  #   polymorphic_url(
              record_or_hash,                                                 #     record_or_hash,
              options.merge(:action => "#{action}", :routing_type => :path))  #     options.merge(:action => "edit", :routing_type => :path))
          end                                                                 # end
        EOT
      end

      private
        def action_prefix(options)
          options[:action] ? "#{options[:action]}_" : ''
        end

        def routing_type(options)
          options[:routing_type] || :url
        end

        def build_named_route_call(records, inflection, options = {})
          if records.is_a?(Array)
            record = records.pop
            route = records.map do |parent|
              if parent.is_a?(Symbol) || parent.is_a?(String)
                parent
              else
                ActiveModel::Naming.singular_route_key(parent)
              end
            end
          else
            record = extract_record(records)
            route  = []
          end

          if record.is_a?(Symbol) || record.is_a?(String)
            route << record
          elsif record
            if inflection == :singular
              route << ActiveModel::Naming.singular_route_key(record)
            else
              route << ActiveModel::Naming.route_key(record)
            end
          else
            raise ArgumentError, "Nil location provided. Can't build URI."
          end

          route << routing_type(options)

          action_prefix(options) + route.join("_")
        end

        def extract_record(record_or_hash_or_array)
          case record_or_hash_or_array
            when Array; record_or_hash_or_array.last
            when Hash;  record_or_hash_or_array[:id]
            else        record_or_hash_or_array
          end
        end
    end
  end
end

