require 'active_support/core_ext/hash/keys'

module ActionController
  module ConditionalGet
    extend ActiveSupport::Concern

    include Head

    included do
      class_attribute :etaggers
      self.etaggers = []
    end

    module ClassMethods
      # Allows you to consider additional controller-wide information when generating an ETag.
      # For example, if you serve pages tailored depending on who's logged in at the moment, you
      # may want to add the current user id to be part of the ETag to prevent unauthorized displaying
      # of cached pages.
      #
      #   class InvoicesController < ApplicationController
      #     etag { current_user.try :id }
      #
      #     def show
      #       # Etag will differ even for the same invoice when it's viewed by a different current_user
      #       @invoice = Invoice.find(params[:id])
      #       fresh_when(@invoice)
      #     end
      #   end
      def etag(&etagger)
        self.etaggers += [etagger]
      end
    end

    # Sets the +etag+, +last_modified+, or both on the response and renders a
    # <tt>304 Not Modified</tt> response if the request is already fresh.
    #
    # === Parameters:
    #
    # * <tt>:etag</tt>.
    # * <tt>:last_modified</tt>.
    # * <tt>:public</tt> By default the Cache-Control header is private, set this to
    #   +true+ if you want your application to be cacheable by other devices (proxy caches).
    # * <tt>:template</tt> By default, the template digest for the current
    #   controller/action is included in ETags. If the action renders a
    #   different template, you can include its digest instead. If the action
    #   doesn't render a template at all, you can pass <tt>template: false</tt>
    #   to skip any attempt to check for a template digest.
    #
    # === Example:
    #
    #   def show
    #     @article = Article.find(params[:id])
    #     fresh_when(etag: @article, last_modified: @article.updated_at, public: true)
    #   end
    #
    # This will render the show template if the request isn't sending a matching ETag or
    # If-Modified-Since header and just a <tt>304 Not Modified</tt> response if there's a match.
    #
    # You can also just pass a record. In this case +last_modified+ will be set
    # by calling +updated_at+ and +etag+ by passing the object itself.
    #
    #   def show
    #     @article = Article.find(params[:id])
    #     fresh_when(@article)
    #   end
    #
    # You can also pass an object that responds to +maximum+, such as a
    # collection of active records. In this case +last_modified+ will be set by
    # calling <tt>maximum(:updated_at)</tt> on the collection (the timestamp of the
    # most recently updated record) and the +etag+ by passing the object itself.
    #
    #   def index
    #     @articles = Article.all
    #     fresh_when(@articles)
    #   end
    #
    # When passing a record or a collection, you can still set the public header:
    #
    #   def show
    #     @article = Article.find(params[:id])
    #     fresh_when(@article, public: true)
    #   end
    #
    # When rendering a different template than the default controller/action
    # style, you can indicate which digest to include in the ETag:
    #
    #   before_action { fresh_when @article, template: 'widgets/show' }
    #
    def fresh_when(object = nil, etag: object, last_modified: nil, public: false, template: nil)
      last_modified ||= object.try(:updated_at) || object.try(:maximum, :updated_at)

      if etag || template
        response.etag = combine_etags(etag: etag, last_modified: last_modified,
          public: public, template: template)
      end

      response.last_modified = last_modified if last_modified
      response.cache_control[:public] = true if public

      head :not_modified if request.fresh?(response)
    end

    # Sets the +etag+ and/or +last_modified+ on the response and checks it against
    # the client request. If the request doesn't match the options provided, the
    # request is considered stale and should be generated from scratch. Otherwise,
    # it's fresh and we don't need to generate anything and a reply of <tt>304 Not Modified</tt> is sent.
    #
    # === Parameters:
    #
    # * <tt>:etag</tt>.
    # * <tt>:last_modified</tt>.
    # * <tt>:public</tt> By default the Cache-Control header is private, set this to
    #   +true+ if you want your application to be cacheable by other devices (proxy caches).
    # * <tt>:template</tt> By default, the template digest for the current
    #   controller/action is included in ETags. If the action renders a
    #   different template, you can include its digest instead. If the action
    #   doesn't render a template at all, you can pass <tt>template: false</tt>
    #   to skip any attempt to check for a template digest.
    #
    # === Example:
    #
    #   def show
    #     @article = Article.find(params[:id])
    #
    #     if stale?(etag: @article, last_modified: @article.updated_at)
    #       @statistics = @article.really_expensive_call
    #       respond_to do |format|
    #         # all the supported formats
    #       end
    #     end
    #   end
    #
    # You can also just pass a record. In this case +last_modified+ will be set
    # by calling +updated_at+ and +etag+ by passing the object itself.
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
    # You can also pass an object that responds to +maximum+, such as a
    # collection of active records. In this case +last_modified+ will be set by
    # calling +maximum(:updated_at)+ on the collection (the timestamp of the
    # most recently updated record) and the +etag+ by passing the object itself.
    #
    #   def index
    #     @articles = Article.all
    #
    #     if stale?(@articles)
    #       @statistics = @articles.really_expensive_call
    #       respond_to do |format|
    #         # all the supported formats
    #       end
    #     end
    #   end
    #
    # When passing a record or a collection, you can still set the public header:
    #
    #   def show
    #     @article = Article.find(params[:id])
    #
    #     if stale?(@article, public: true)
    #       @statistics = @article.really_expensive_call
    #       respond_to do |format|
    #         # all the supported formats
    #       end
    #     end
    #   end
    #
    # When rendering a different template than the default controller/action
    # style, you can indicate which digest to include in the ETag:
    #
    #   def show
    #     super if stale? @article, template: 'widgets/show'
    #   end
    #
    def stale?(object = nil, etag: object, last_modified: nil, public: nil, template: nil)
      fresh_when(object, etag: etag, last_modified: last_modified, public: public, template: template)
      !request.fresh?(response)
    end

    # Sets a HTTP 1.1 Cache-Control header. Defaults to issuing a +private+
    # instruction, so that intermediate caches must not cache the response.
    #
    #   expires_in 20.minutes
    #   expires_in 3.hours, public: true
    #   expires_in 3.hours, public: true, must_revalidate: true
    #
    # This method will overwrite an existing Cache-Control header.
    # See http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html for more possibilities.
    #
    # The method will also ensure a HTTP Date header for client compatibility.
    def expires_in(seconds, options = {})
      response.cache_control.merge!(
        :max_age         => seconds,
        :public          => options.delete(:public),
        :must_revalidate => options.delete(:must_revalidate)
      )
      options.delete(:private)

      response.cache_control[:extras] = options.map {|k,v| "#{k}=#{v}"}
      response.date = Time.now unless response.date?
    end

    # Sets a HTTP 1.1 Cache-Control header of <tt>no-cache</tt> so no caching should
    # occur by the browser or intermediate caches (like caching proxy servers).
    def expires_now
      response.cache_control.replace(:no_cache => true)
    end

    # Cache or yield the block. The cache is supposed to never expire.
    #
    # You can use this method when you have a HTTP response that never changes,
    # and the browser and proxies should cache it indefinitely.
    #
    # * +public+: By default, HTTP responses are private, cached only on the
    #   user's web browser. To allow proxies to cache the response, set +true+ to
    #   indicate that they can serve the cached response to all users.
    #
    # * +version+: the version passed as a key for the cache.
    def http_cache_forever(public: false, version: 'v1')
      expires_in 100.years, public: public

      yield if stale?(etag: "#{version}-#{request.fullpath}",
                      last_modified: Time.new(2011, 1, 1).utc,
                      public: public)
    end

    private
      def combine_etags(options)
        etags = etaggers.map { |etagger| instance_exec(options, &etagger) }.compact
        etags.unshift options[:etag]
      end
  end
end
