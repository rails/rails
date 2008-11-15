module ActionController
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
  # Polymorphic URL helpers are used in a number of places throughout the Rails framework:
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
  # * <tt>formatted_polymorphic_url</tt>, <tt>formatted_polymorphic_path</tt>
  #
  # Example usage:
  #
  #   edit_polymorphic_path(@post)              # => "/posts/1/edit"
  #   formatted_polymorphic_path([@post, :pdf]) # => "/posts/1.pdf"
  module PolymorphicRoutes
    # Constructs a call to a named RESTful route for the given record and returns the
    # resulting URL string. For example:
    #
    #   # calls post_url(post)
    #   polymorphic_url(post) # => "http://example.com/posts/1"
    #   polymorphic_url([blog, post]) # => "http://example.com/blogs/1/posts/1"
    #   polymorphic_url([:admin, blog, post]) # => "http://example.com/admin/blogs/1/posts/1"
    #   polymorphic_url([user, :blog, post]) # => "http://example.com/users/1/blog/posts/1"
    #
    # ==== Options
    #
    # * <tt>:action</tt> - Specifies the action prefix for the named route:
    #   <tt>:new</tt>, <tt>:edit</tt>, or <tt>:formatted</tt>. Default is no prefix.
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
    def polymorphic_url(record_or_hash_or_array, options = {})
      if record_or_hash_or_array.kind_of?(Array)
        record_or_hash_or_array = record_or_hash_or_array.compact
      end

      record    = extract_record(record_or_hash_or_array)
      format    = extract_format(record_or_hash_or_array, options)
      namespace = extract_namespace(record_or_hash_or_array)
      
      args = case record_or_hash_or_array
        when Hash;  [ record_or_hash_or_array ]
        when Array; record_or_hash_or_array.dup
        else        [ record_or_hash_or_array ]
      end

      inflection =
        case
        when options[:action].to_s == "new"
          args.pop
          :singular
        when record.respond_to?(:new_record?) && record.new_record?
          args.pop
          :plural
        else
          :singular
        end

      args.delete_if {|arg| arg.is_a?(Symbol) || arg.is_a?(String)}
      args << format if format
      
      named_route = build_named_route_call(record_or_hash_or_array, namespace, inflection, options)

      url_options = options.except(:action, :routing_type, :format)
      unless url_options.empty?
        args.last.kind_of?(Hash) ? args.last.merge!(url_options) : args << url_options
      end

      __send__(named_route, *args)
    end

    # Returns the path component of a URL for the given record. It uses
    # <tt>polymorphic_url</tt> with <tt>:routing_type => :path</tt>.
    def polymorphic_path(record_or_hash_or_array, options = {})
      options[:routing_type] = :path
      polymorphic_url(record_or_hash_or_array, options)
    end

    %w(edit new formatted).each do |action|
      module_eval <<-EOT, __FILE__, __LINE__
        def #{action}_polymorphic_url(record_or_hash, options = {})
          polymorphic_url(record_or_hash, options.merge(:action => "#{action}"))
        end

        def #{action}_polymorphic_path(record_or_hash, options = {})
          polymorphic_url(record_or_hash, options.merge(:action => "#{action}", :routing_type => :path))
        end
      EOT
    end

    private
      def action_prefix(options)
        options[:action] ? "#{options[:action]}_" : options[:format] ? "formatted_" : ""
      end

      def routing_type(options)
        options[:routing_type] || :url
      end

      def build_named_route_call(records, namespace, inflection, options = {})
        unless records.is_a?(Array)
          record = extract_record(records)
          route  = ''
        else
          record = records.pop
          route = records.inject("") do |string, parent|
            if parent.is_a?(Symbol) || parent.is_a?(String)
              string << "#{parent}_"
            else
              string << "#{RecordIdentifier.__send__("singular_class_name", parent)}_"
            end
          end
        end

        if record.is_a?(Symbol) || record.is_a?(String)
          route << "#{record}_"
        else
          route << "#{RecordIdentifier.__send__("#{inflection}_class_name", record)}_"
        end

        action_prefix(options) + namespace + route + routing_type(options).to_s
      end

      def extract_record(record_or_hash_or_array)
        case record_or_hash_or_array
          when Array; record_or_hash_or_array.last
          when Hash;  record_or_hash_or_array[:id]
          else        record_or_hash_or_array
        end
      end
      
      def extract_format(record_or_hash_or_array, options)
        if options[:action].to_s == "formatted" && record_or_hash_or_array.is_a?(Array)
          record_or_hash_or_array.pop
        elsif options[:format]
          options[:format]
        else
          nil
        end
      end
      
      # Remove the first symbols from the array and return the url prefix
      # implied by those symbols.
      def extract_namespace(record_or_hash_or_array)
        return "" unless record_or_hash_or_array.is_a?(Array)

        namespace_keys = []
        while (key = record_or_hash_or_array.first) && key.is_a?(String) || key.is_a?(Symbol)
          namespace_keys << record_or_hash_or_array.shift
        end

        namespace_keys.map {|k| "#{k}_"}.join
      end
  end
end
