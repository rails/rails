require 'action_controller/model_naming'

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
    # number of prefixed helpers are available as a shorthand to <tt>action: "..."</tt>
    # in options. Those are:
    #
    # * <tt>edit_polymorphic_url</tt>, <tt>edit_polymorphic_path</tt>
    # * <tt>new_polymorphic_url</tt>, <tt>new_polymorphic_path</tt>
    #
    # Example usage:
    #
    #   edit_polymorphic_path(@post)              # => "/posts/1/edit"
    #   polymorphic_path(@post, format: :pdf)  # => "/posts/1.pdf"
    #
    # == Usage with mounted engines
    #
    # If you are using a mounted engine and you need to use a polymorphic_url
    # pointing at the engine's routes, pass in the engine's route proxy as the first
    # argument to the method. For example:
    #
    #   polymorphic_url([blog, @post])  # calls blog.post_path(@post)
    #   form_for([blog, @post])         # => "/blog/posts/1"
    #
    module PolymorphicRoutes
      include ActionController::ModelNaming

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
      # Also includes all the options from <tt>url_for</tt>. These include such
      # things as <tt>:anchor</tt> or <tt>:trailing_slash</tt>. Example usage
      # is given below:
      #
      #   polymorphic_url([blog, post], anchor: 'my_anchor')
      #     # => "http://example.com/blogs/1/posts/1#my_anchor"
      #   polymorphic_url([blog, post], anchor: 'my_anchor', script_name: "/my_app")
      #     # => "http://example.com/my_app/blogs/1/posts/1#my_anchor"
      #
      # For all of these options, see the documentation for <tt>url_for</tt>.
      #
      # ==== Functionality
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
        recipient = self

        opts = options.except(:action, :routing_type)

        case record_or_hash_or_array
        when Array
          if record_or_hash_or_array.empty? || record_or_hash_or_array.any?(&:nil?)
            raise ArgumentError, "Nil location provided. Can't build URI."
          end
          if record_or_hash_or_array.first.is_a?(ActionDispatch::Routing::RoutesProxy)
            recipient = record_or_hash_or_array.shift
          end

          args        = record_or_hash_or_array.dup
          record_list = record_or_hash_or_array.dup
        when Hash
          unless record_or_hash_or_array[:id]
            raise ArgumentError, "Nil location provided. Can't build URI."
          end

          opts        = record_or_hash_or_array.dup.merge!(opts)
          args        = [opts.delete(:id)]
          record_list = args.dup
        when nil
          raise ArgumentError, "Nil location provided. Can't build URI."
        else

          args        = [record_or_hash_or_array]
          record_list = [record_or_hash_or_array]
        end


        record = record_list.pop

        inflection = nil

        should_pop = true
        if record.try(:persisted?)
          should_pop = false
          inflection = :singular
        elsif options[:action] == 'new'
          should_pop = true
          inflection = :singular
        else
          should_pop = true
          inflection = :plural
        end

        record = record.respond_to?(:to_model) ? record.to_model : record

        #if options[:action] && options[:action].to_s == "new"
        #  inflection = :singular
        #elsif (record.respond_to?(:persisted?) && !record.persisted?)
        #  inflection = :plural
        #elsif record.is_a?(Class)
        #  inflection = :plural
        #else
        #  args << record
        #  inflection = :singular
        #end

        route  = record_list.map { |parent|
          if parent.is_a?(Symbol) || parent.is_a?(String)
            parent.to_s
          else
            model_name_from_record_or_class(parent).singular_route_key
          end
        }

        route <<
          if record.is_a?(Symbol) || record.is_a?(String)
            record.to_s
          else
            if inflection == :singular
              model_name_from_record_or_class(record).singular_route_key
            else
              model_name_from_record_or_class(record).route_key
            end
          end

        route << routing_type(options)

        named_route = action_prefix(options) + route.join("_")

        args.pop if should_pop
        args.delete_if {|arg| arg.is_a?(Symbol) || arg.is_a?(String)}

        args.collect! { |a| convert_to_model(a) }

        recipient.send(named_route, *args, opts)
      end

      # Returns the path component of a URL for the given record. It uses
      # <tt>polymorphic_url</tt> with <tt>routing_type: :path</tt>.
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

        def build_route_part(record, inflection)
          if record.is_a?(Symbol) || record.is_a?(String)
            record.to_s
          else
            if inflection == :singular
              model_name_from_record_or_class(record).singular_route_key
            else
              model_name_from_record_or_class(record).route_key
            end
          end
        end
    end
  end
end

