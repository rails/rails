# frozen_string_literal: true

# :markup: markdown

require "active_support/core_ext/object/try"
require "active_support/core_ext/integer/time"

module ActionController
  module ConditionalGet
    extend ActiveSupport::Concern

    include Head

    included do
      class_attribute :etaggers, default: []
    end

    module ClassMethods
      # Allows you to consider additional controller-wide information when generating
      # an ETag. For example, if you serve pages tailored depending on who's logged in
      # at the moment, you may want to add the current user id to be part of the ETag
      # to prevent unauthorized displaying of cached pages.
      #
      #     class InvoicesController < ApplicationController
      #       etag { current_user&.id }
      #
      #       def show
      #         # Etag will differ even for the same invoice when it's viewed by a different current_user
      #         @invoice = Invoice.find(params[:id])
      #         fresh_when etag: @invoice
      #       end
      #     end
      def etag(&etagger)
        self.etaggers += [etagger]
      end
    end

    # Sets the `etag`, `last_modified`, or both on the response, and renders a `304
    # Not Modified` response if the request is already fresh.
    #
    # #### Options
    #
    # `:etag`
    # :   Sets a "weak" ETag validator on the response. See the `:weak_etag` option.
    #
    # `:weak_etag`
    # :   Sets a "weak" ETag validator on the response. Requests that specify an
    #     `If-None-Match` header may receive a `304 Not Modified` response if the
    #     ETag matches exactly.
    #
    # :   A weak ETag indicates semantic equivalence, not byte-for-byte equality, so
    #     they're good for caching HTML pages in browser caches. They can't be used
    #     for responses that must be byte-identical, like serving `Range` requests
    #     within a PDF file.
    #
    # `:strong_etag`
    # :   Sets a "strong" ETag validator on the response. Requests that specify an
    #     `If-None-Match` header may receive a `304 Not Modified` response if the
    #     ETag matches exactly.
    #
    # :   A strong ETag implies exact equality -- the response must match byte for
    #     byte. This is necessary for serving `Range` requests within a large video
    #     or PDF file, for example, or for compatibility with some CDNs that don't
    #     support weak ETags.
    #
    # `:last_modified`
    # :   Sets a "weak" last-update validator on the response. Subsequent requests
    #     that specify an `If-Modified-Since` header may receive a `304 Not
    #     Modified` response if `last_modified` <= `If-Modified-Since`.
    #
    # `:public`
    # :   By default the `Cache-Control` header is private. Set this option to
    #     `true` if you want your application to be cacheable by other devices, such
    #     as proxy caches.
    #
    # `:cache_control`
    # :   When given, will overwrite an existing `Cache-Control` header. For a list
    #     of `Cache-Control` directives, see the [article on
    #     MDN](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Cache-Control).
    #
    # `:template`
    # :   By default, the template digest for the current controller/action is
    #     included in ETags. If the action renders a different template, you can
    #     include its digest instead. If the action doesn't render a template at
    #     all, you can pass `template: false` to skip any attempt to check for a
    #     template digest.
    #
    #
    # #### Examples
    #
    #     def show
    #       @article = Article.find(params[:id])
    #       fresh_when(etag: @article, last_modified: @article.updated_at, public: true)
    #     end
    #
    # This will send a `304 Not Modified` response if the request specifies a
    # matching ETag and `If-Modified-Since` header. Otherwise, it will render the
    # `show` template.
    #
    # You can also just pass a record:
    #
    #     def show
    #       @article = Article.find(params[:id])
    #       fresh_when(@article)
    #     end
    #
    # `etag` will be set to the record, and `last_modified` will be set to the
    # record's `updated_at`.
    #
    # You can also pass an object that responds to `maximum`, such as a collection
    # of records:
    #
    #     def index
    #       @articles = Article.all
    #       fresh_when(@articles)
    #     end
    #
    # In this case, `etag` will be set to the collection, and `last_modified` will
    # be set to `maximum(:updated_at)` (the timestamp of the most recently updated
    # record).
    #
    # When passing a record or a collection, you can still specify other options,
    # such as `:public` and `:cache_control`:
    #
    #     def show
    #       @article = Article.find(params[:id])
    #       fresh_when(@article, public: true, cache_control: { no_cache: true })
    #     end
    #
    # The above will set `Cache-Control: public, no-cache` in the response.
    #
    # When rendering a different template than the controller/action's default
    # template, you can indicate which digest to include in the ETag:
    #
    #     before_action { fresh_when @article, template: "widgets/show" }
    #
    def fresh_when(object = nil, etag: nil, weak_etag: nil, strong_etag: nil, last_modified: nil, public: false, cache_control: {}, template: nil)
      response.cache_control.delete(:no_store)
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
      response.cache_control.merge!(cache_control)

      head :not_modified if request.fresh?(response)
    end

    # Sets the `etag` and/or `last_modified` on the response and checks them against
    # the request. If the request doesn't match the provided options, it is
    # considered stale, and the response should be rendered from scratch. Otherwise,
    # it is fresh, and a `304 Not Modified` is sent.
    #
    # #### Options
    #
    # See #fresh_when for supported options.
    #
    # #### Examples
    #
    #     def show
    #       @article = Article.find(params[:id])
    #
    #       if stale?(etag: @article, last_modified: @article.updated_at)
    #         @statistics = @article.really_expensive_call
    #         respond_to do |format|
    #           # all the supported formats
    #         end
    #       end
    #     end
    #
    # You can also just pass a record:
    #
    #     def show
    #       @article = Article.find(params[:id])
    #
    #       if stale?(@article)
    #         @statistics = @article.really_expensive_call
    #         respond_to do |format|
    #           # all the supported formats
    #         end
    #       end
    #     end
    #
    # `etag` will be set to the record, and `last_modified` will be set to the
    # record's `updated_at`.
    #
    # You can also pass an object that responds to `maximum`, such as a collection
    # of records:
    #
    #     def index
    #       @articles = Article.all
    #
    #       if stale?(@articles)
    #         @statistics = @articles.really_expensive_call
    #         respond_to do |format|
    #           # all the supported formats
    #         end
    #       end
    #     end
    #
    # In this case, `etag` will be set to the collection, and `last_modified` will
    # be set to `maximum(:updated_at)` (the timestamp of the most recently updated
    # record).
    #
    # When passing a record or a collection, you can still specify other options,
    # such as `:public` and `:cache_control`:
    #
    #     def show
    #       @article = Article.find(params[:id])
    #
    #       if stale?(@article, public: true, cache_control: { no_cache: true })
    #         @statistics = @articles.really_expensive_call
    #         respond_to do |format|
    #           # all the supported formats
    #         end
    #       end
    #     end
    #
    # The above will set `Cache-Control: public, no-cache` in the response.
    #
    # When rendering a different template than the controller/action's default
    # template, you can indicate which digest to include in the ETag:
    #
    #     def show
    #       super if stale?(@article, template: "widgets/show")
    #     end
    #
    def stale?(object = nil, **freshness_kwargs)
      fresh_when(object, **freshness_kwargs)
      !request.fresh?(response)
    end

    # Sets the `Cache-Control` header, overwriting existing directives. This method
    # will also ensure an HTTP `Date` header for client compatibility.
    #
    # Defaults to issuing the `private` directive, so that intermediate caches must
    # not cache the response.
    #
    # #### Options
    #
    # `:public`
    # :   If true, replaces the default `private` directive with the `public`
    #     directive.
    #
    # `:must_revalidate`
    # :   If true, adds the `must-revalidate` directive.
    #
    # `:stale_while_revalidate`
    # :   Sets the value of the `stale-while-revalidate` directive.
    #
    # `:stale_if_error`
    # :   Sets the value of the `stale-if-error` directive.
    #
    # `:immutable`
    # :   If true, adds the `immutable` directive.
    #
    #
    # Any additional key-value pairs are concatenated as directives. For a list of
    # supported `Cache-Control` directives, see the [article on
    # MDN](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Cache-Control).
    #
    # #### Examples
    #
    #     expires_in 10.minutes
    #     # => Cache-Control: max-age=600, private
    #
    #     expires_in 10.minutes, public: true
    #     # => Cache-Control: max-age=600, public
    #
    #     expires_in 10.minutes, public: true, must_revalidate: true
    #     # => Cache-Control: max-age=600, public, must-revalidate
    #
    #     expires_in 1.hour, stale_while_revalidate: 60.seconds
    #     # => Cache-Control: max-age=3600, private, stale-while-revalidate=60
    #
    #     expires_in 1.hour, stale_if_error: 5.minutes
    #     # => Cache-Control: max-age=3600, private, stale-if-error=300
    #
    #     expires_in 1.hour, public: true, "s-maxage": 3.hours, "no-transform": true
    #     # => Cache-Control: max-age=3600, public, s-maxage=10800, no-transform=true
    #
    def expires_in(seconds, options = {})
      response.cache_control.delete(:no_store)
      response.cache_control.merge!(
        max_age: seconds,
        public: options.delete(:public),
        must_revalidate: options.delete(:must_revalidate),
        stale_while_revalidate: options.delete(:stale_while_revalidate),
        stale_if_error: options.delete(:stale_if_error),
        immutable: options.delete(:immutable),
      )
      options.delete(:private)

      response.cache_control[:extras] = options.map { |k, v| "#{k}=#{v}" }
      response.date = Time.now unless response.date?
    end

    # Sets an HTTP 1.1 `Cache-Control` header of `no-cache`. This means the resource
    # will be marked as stale, so clients must always revalidate.
    # Intermediate/browser caches may still store the asset.
    def expires_now
      response.cache_control.replace(no_cache: true)
    end

    # Cache or yield the block. The cache is supposed to never expire.
    #
    # You can use this method when you have an HTTP response that never changes, and
    # the browser and proxies should cache it indefinitely.
    #
    # *   `public`: By default, HTTP responses are private, cached only on the
    #     user's web browser. To allow proxies to cache the response, set `true` to
    #     indicate that they can serve the cached response to all users.
    def http_cache_forever(public: false)
      expires_in 100.years, public: public, immutable: true

      yield if stale?(etag: request.fullpath,
                      last_modified: Time.new(2011, 1, 1).utc,
                      public: public)
    end

    # Sets an HTTP 1.1 `Cache-Control` header of `no-store`. This means the resource
    # may not be stored in any cache.
    def no_store
      response.cache_control.replace(no_store: true)
    end

    # Adds the `must-understand` directive to the `Cache-Control` header, which indicates
    # that a cache MUST understand the semantics of the response status code that has been
    # received, or discard the response.
    #
    # This is particularly useful when returning responses with new or uncommon
    # status codes that might not be properly interpreted by older caches.
    #
    # #### Example
    #
    #     def show
    #       @article = Article.find(params[:id])
    #
    #       if @article.early_access?
    #         must_understand
    #         render status: 203 # Non-Authoritative Information
    #       else
    #         fresh_when @article
    #       end
    #     end
    #
    def must_understand
      response.cache_control[:must_understand] = true
      response.cache_control[:no_store] = true
    end

    private
      def combine_etags(validator, options)
        [validator, *etaggers.map { |etagger| instance_exec(options, &etagger) }].compact
      end
  end
end
