module ActionController
  module ConditionalGet
    extend ActiveSupport::Concern

    include RackDelegation
    include Head

    # Sets the etag, last_modified, or both on the response and renders a
    # <tt>304 Not Modified</tt> response if the request is already fresh.
    #
    # Parameters:
    # * <tt>:etag</tt>
    # * <tt>:last_modified</tt>
    # * <tt>:public</tt> By default the Cache-Control header is private, set this to true if you want your application to be cachable by other devices (proxy caches).
    #
    # Example:
    #
    #   def show
    #     @article = Article.find(params[:id])
    #     fresh_when(:etag => @article, :last_modified => @article.created_at, :public => true)
    #   end
    #
    # This will render the show template if the request isn't sending a matching etag or
    # If-Modified-Since header and just a <tt>304 Not Modified</tt> response if there's a match.
    #
    # You can also just pass a record where last_modified will be set by calling updated_at and the etag by passing the object itself. Example:
    #
    #   def show
    #     @article = Article.find(params[:id])
    #     fresh_when(@article)
    #   end
    #
    # When passing a record, you can still set whether the public header:
    #
    #   def show
    #     @article = Article.find(params[:id])
    #     fresh_when(@article, :public => true)
    #   end
    def fresh_when(record_or_options, additional_options = {})
      if record_or_options.is_a? Hash
        options = record_or_options
        options.assert_valid_keys(:etag, :last_modified, :public)
      else
        record  = record_or_options
        options = { :etag => record, :last_modified => record.try(:updated_at) }.merge(additional_options)
      end

      response.etag          = options[:etag]          if options[:etag]
      response.last_modified = options[:last_modified] if options[:last_modified]
      response.cache_control[:public] = true if options[:public]

      head :not_modified if request.fresh?(response)
    end

    # Sets the etag and/or last_modified on the response and checks it against
    # the client request. If the request doesn't match the options provided, the
    # request is considered stale and should be generated from scratch. Otherwise,
    # it's fresh and we don't need to generate anything and a reply of <tt>304 Not Modified</tt> is sent.
    #
    # Parameters:
    # * <tt>:etag</tt>
    # * <tt>:last_modified</tt>
    # * <tt>:public</tt> By default the Cache-Control header is private, set this to true if you want your application to be cachable by other devices (proxy caches).
    #
    # Example:
    #
    #   def show
    #     @article = Article.find(params[:id])
    #
    #     if stale?(:etag => @article, :last_modified => @article.created_at)
    #       @statistics = @article.really_expensive_call
    #       respond_to do |format|
    #         # all the supported formats
    #       end
    #     end
    #   end
    #
    # You can also just pass a record where last_modified will be set by calling updated_at and the etag by passing the object itself. Example:
    #
    #   def show
    #     @article = Article.find(params[:id])
    #
    #     if stale?(@article)
    #       @statistics = @article.really_expensive_call
    #       respond_to do |format|
    #         # all the supported formats
    #       end
    #     end
    #   end
    #
    # When passing a record, you can still set whether the public header:
    #
    #   def show
    #     @article = Article.find(params[:id])
    #
    #     if stale?(@article, :public => true)
    #       @statistics = @article.really_expensive_call
    #       respond_to do |format|
    #         # all the supported formats
    #       end
    #     end
    #   end
    def stale?(record_or_options, additional_options = {})
      fresh_when(record_or_options, additional_options)
      !request.fresh?(response)
    end

    # Sets a HTTP 1.1 Cache-Control header. Defaults to issuing a <tt>private</tt> instruction, so that
    # intermediate caches must not cache the response.
    #
    # Examples:
    #   expires_in 20.minutes
    #   expires_in 3.hours, :public => true
    #   expires_in 3.hours, 'max-stale' => 5.hours, :public => true
    #
    # This method will overwrite an existing Cache-Control header.
    # See http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html for more possibilities.
    def expires_in(seconds, options = {}) #:doc:
      response.cache_control.merge!(:max_age => seconds, :public => options.delete(:public))
      options.delete(:private)

      response.cache_control[:extras] = options.map {|k,v| "#{k}=#{v}"}
    end

    # Sets a HTTP 1.1 Cache-Control header of <tt>no-cache</tt> so no caching should occur by the browser or
    # intermediate caches (like caching proxy servers).
    def expires_now #:doc:
      response.cache_control.replace(:no_cache => true)
    end
  end
end
