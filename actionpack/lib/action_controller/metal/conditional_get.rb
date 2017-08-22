# frozen_string_literal: true

require "active_support/core_ext/hash/keys"

module ActionController
  module ConditionalGet
    extend ActiveSupport::Concern

    include Head

    included do
      class_attribute :etaggers, default: []
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
    # * <tt>:etag</tt> Sets a "weak" ETag validator on the response. See the
    #   +:weak_etag+ option.
    # * <tt>:weak_etag</tt> Sets a "weak" ETag validator on the response.
    #   Requests that set If-None-Match header may return a 304 Not Modified
    #   response if it matches the ETag exactly. A weak ETag indicates semantic
    #   equivalence, not byte-for-byte equality, so they're good for caching
    #   HTML pages in browser caches. They can't be used for responses that
    #   must be byte-identical, like serving Range requests within a PDF file.
    # * <tt>:strong_etag</tt> Sets a "strong" ETag validator on the response.
    #   Requests that set If-None-Match header may return a 304 Not Modified
    #   response if it matches the ETag exactly. A strong ETag implies exact
    #   equality: the response must match byte for byte. This is necessary for
    #   doing Range requests within a large video or PDF file, for example, or
    #   for compatibility with some CDNs that don't support weak ETags.
    # * <tt>:last_modified</tt> Sets a "weak" last-update validator on the
    #   response. Subsequent requests that set If-Modified-Since may return a
    #   304 Not Modified response if last_modified <= If-Modified-Since.
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
    def fresh_when(object = nil, etag: nil, weak_etag: nil, strong_etag: nil, last_modified: nil, public: false, template: nil)
      weak_etag ||= etag || object unless strong_etag
      last_modified ||= object.try(:updated_at) || object.try(:maximum, :updated_at)

      if strong_etag
        response.strong_etag = combine_etags strong_etag,
          last_modified: last_modified, public: public, template: template
      elsif weak_etag || template
        response.weak_etag = combine_etags weak_etag,
          last_modified: last_modified, public: public, template: template
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
    # * <tt>:etag</tt> Sets a "weak" ETag validator on the response. See the
    #   +:weak_etag+ option.
    # * <tt>:weak_etag</tt> Sets a "weak" ETag validator on the response.
    #   Requests that set If-None-Match header may return a 304 Not Modified
    #   response if it matches the ETag exactly. A weak ETag indicates semantic
    #   equivalence, not byte-for-byte equality, so they're good for caching
    #   HTML pages in browser caches. They can't be used for responses that
    #   must be byte-identical, like serving Range requests within a PDF file.
    # * <tt>:strong_etag</tt> Sets a "strong" ETag validator on the response.
    #   Requests that set If-None-Match header may return a 304 Not Modified
    #   response if it matches the ETag exactly. A strong ETag implies exact
    #   equality: the response must match byte for byte. This is necessary for
    #   doing Range requests within a large video or PDF file, for example, or
    #   for compatibility with some CDNs that don't support weak ETags.
    # * <tt>:last_modified</tt> Sets a "weak" last-update validator on the
    #   response. Subsequent requests that set If-Modified-Since may return a
    #   304 Not Modified response if last_modified <= If-Modified-Since.
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
    def stale?(object = nil, **freshness_kwargs)
      fresh_when(object, **freshness_kwargs)
      !request.fresh?(response)
    end

    # Sets an HTTP 1.1 Cache-Control header. Defaults to issuing a +private+
    # instruction, so that intermediate caches must not cache the response.
    #
    #   expires_in 20.minutes
    #   expires_in 3.hours, public: true
    #   expires_in 3.hours, public: true, must_revalidate: true
    #
    # This method will overwrite an existing Cache-Control header.
    # See https://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html for more possibilities.
    #
    # The method will also ensure an HTTP Date header for client compatibility.
    def expires_in(seconds, options = {})
      response.cache_control.merge!(
        max_age: seconds,
        public: options.delete(:public),
        must_revalidate: options.delete(:must_revalidate)
      )
      options.delete(:private)

      response.cache_control[:extras] = options.map { |k, v| "#{k}=#{v}" }
      response.date = Time.now unless response.date?
    end

    # Sets an HTTP 1.1 Cache-Control header of <tt>no-cache</tt>. This means the
    # resource will be marked as stale, so clients must always revalidate.
    # Intermediate/browser caches may still store the asset.
    def expires_now
      response.cache_control.replace(no_cache: true)
    end

    # Cache or yield the block. The cache is supposed to never expire.
    #
    # You can use this method when you have an HTTP response that never changes,
    # and the browser and proxies should cache it indefinitely.
    #
    # * +public+: By default, HTTP responses are private, cached only on the
    #   user's web browser. To allow proxies to cache the response, set +true+ to
    #   indicate that they can serve the cached response to all users.
    def http_cache_forever(public: false)
      expires_in 100.years, public: public

      yield if stale?(etag: request.fullpath,
                      last_modified: Time.new(2011, 1, 1).utc,
                      public: public)
    end

    private
      def combine_etags(validator, options)
        [validator, *etaggers.map { |etagger| instance_exec(options, &etagger) }].compact
      end
  end
end
