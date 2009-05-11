module ActionController
  module ConditionalGet
    
    # Sets the etag, last_modified, or both on the response and renders a
    # "304 Not Modified" response if the request is already fresh.
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
    #     fresh_when(:etag => @article, :last_modified => @article.created_at.utc, :public => true)
    #   end
    #
    # This will render the show template if the request isn't sending a matching etag or
    # If-Modified-Since header and just a "304 Not Modified" response if there's a match.
    #    
    def fresh_when(options)
      options.assert_valid_keys(:etag, :last_modified, :public)

      response.etag          = options[:etag]          if options[:etag]
      response.last_modified = options[:last_modified] if options[:last_modified]
      
      if options[:public] 
        cache_control = response.headers["Cache-Control"].split(",").map {|k| k.strip }
        cache_control.delete("private")
        cache_control.delete("no-cache")
        cache_control << "public"
        response.headers["Cache-Control"] = cache_control.join(', ')
      end

      if request.fresh?(response)
        head :not_modified
      end
    end    
    
  end
end