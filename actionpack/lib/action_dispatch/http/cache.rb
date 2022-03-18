# frozen_string_literal: true

module ActionDispatch
  module Http
    module Cache
      module Request
        HTTP_IF_MODIFIED_SINCE = "HTTP_IF_MODIFIED_SINCE"
        HTTP_IF_NONE_MATCH     = "HTTP_IF_NONE_MATCH"

        def if_modified_since
          if since = get_header(HTTP_IF_MODIFIED_SINCE)
            Time.rfc2822(since) rescue nil
          end
        end

        def if_none_match
          get_header HTTP_IF_NONE_MATCH
        end

        def if_none_match_etags
          if_none_match ? if_none_match.split(/\s*,\s*/) : []
        end

        def not_modified?(modified_at)
          if_modified_since && modified_at && if_modified_since >= modified_at
        end

        def etag_matches?(etag)
          if etag
            validators = if_none_match_etags
            validators.include?(etag) || validators.include?("*")
          end
        end

        # Check response freshness (Last-Modified and ETag) against request
        # If-Modified-Since and If-None-Match conditions. If both headers are
        # supplied, both must match, or the request is not considered fresh.
        def fresh?(response)
          last_modified = if_modified_since
          etag          = if_none_match

          return false unless last_modified || etag

          success = true
          success &&= not_modified?(response.last_modified) if last_modified
          success &&= etag_matches?(response.etag) if etag
          success
        end
      end

      module Response
        attr_reader :cache_control

        def last_modified
          if last = get_header(LAST_MODIFIED)
            Time.httpdate(last)
          end
        end

        def last_modified?
          has_header? LAST_MODIFIED
        end

        def last_modified=(utc_time)
          set_header LAST_MODIFIED, utc_time.httpdate
        end

        def date
          if date_header = get_header(DATE)
            Time.httpdate(date_header)
          end
        end

        def date?
          has_header? DATE
        end

        def date=(utc_time)
          set_header DATE, utc_time.httpdate
        end

        # This method sets a weak ETag validator on the response so browsers
        # and proxies may cache the response, keyed on the ETag. On subsequent
        # requests, the If-None-Match header is set to the cached ETag. If it
        # matches the current ETag, we can return a 304 Not Modified response
        # with no body, letting the browser or proxy know that their cache is
        # current. Big savings in request time and network bandwidth.
        #
        # Weak ETags are considered to be semantically equivalent but not
        # byte-for-byte identical. This is perfect for browser caching of HTML
        # pages where we don't care about exact equality, just what the user
        # is viewing.
        #
        # Strong ETags are considered byte-for-byte identical. They allow a
        # browser or proxy cache to support Range requests, useful for paging
        # through a PDF file or scrubbing through a video. Some CDNs only
        # support strong ETags and will ignore weak ETags entirely.
        #
        # Weak ETags are what we almost always need, so they're the default.
        # Check out #strong_etag= to provide a strong ETag validator.
        def etag=(weak_validators)
          self.weak_etag = weak_validators
        end

        def weak_etag=(weak_validators)
          set_header "ETag", generate_weak_etag(weak_validators)
        end

        def strong_etag=(strong_validators)
          set_header "ETag", generate_strong_etag(strong_validators)
        end

        def etag?; etag; end

        # True if an ETag is set and it's a weak validator (preceded with W/)
        def weak_etag?
          etag? && etag.start_with?('W/"')
        end

        # True if an ETag is set and it isn't a weak validator (not preceded with W/)
        def strong_etag?
          etag? && !weak_etag?
        end

      private
        DATE          = "Date"
        LAST_MODIFIED = "Last-Modified"
        SPECIAL_KEYS  = Set.new(%w[extras no-store no-cache max-age public private must-revalidate])

        def generate_weak_etag(validators)
          "W/#{generate_strong_etag(validators)}"
        end

        def generate_strong_etag(validators)
          %("#{ActiveSupport::Digest.hexdigest(ActiveSupport::Cache.expand_cache_key(validators))}")
        end

        def cache_control_segments
          if cache_control = _cache_control
            cache_control.delete(" ").split(",")
          else
            []
          end
        end

        def cache_control_headers
          cache_control = {}

          cache_control_segments.each do |segment|
            directive, argument = segment.split("=", 2)

            if SPECIAL_KEYS.include? directive
              directive.tr!("-", "_")
              cache_control[directive.to_sym] = argument || true
            else
              cache_control[:extras] ||= []
              cache_control[:extras] << segment
            end
          end

          cache_control
        end

        def prepare_cache_control!
          @cache_control = cache_control_headers
        end

        DEFAULT_CACHE_CONTROL = "max-age=0, private, must-revalidate"
        NO_STORE              = "no-store"
        NO_CACHE              = "no-cache"
        PUBLIC                = "public"
        PRIVATE               = "private"
        MUST_REVALIDATE       = "must-revalidate"

        def handle_conditional_get!
          # Normally default cache control setting is handled by ETag
          # middleware. But, if an etag is already set, the middleware
          # defaults to `no-cache` unless a default `Cache-Control` value is
          # previously set. So, set a default one here.
          if (etag? || last_modified?) && !self._cache_control
            self._cache_control = DEFAULT_CACHE_CONTROL
          end
        end

        def merge_and_normalize_cache_control!(cache_control)
          control = cache_control_headers

          return if control.empty? && cache_control.empty?  # Let middleware handle default behavior

          if cache_control.any?
            # Any caching directive coming from a controller overrides
            # no-cache/no-store in the default Cache-Control header.
            control.delete(:no_cache)
            control.delete(:no_store)

            if extras = control.delete(:extras)
              cache_control[:extras] ||= []
              cache_control[:extras] += extras
              cache_control[:extras].uniq!
            end

            control.merge! cache_control
          end

          options = []

          if control[:no_store]
            options << PRIVATE if control[:private]
            options << NO_STORE
          elsif control[:no_cache]
            options << PUBLIC if control[:public]
            options << NO_CACHE
            options.concat(control[:extras]) if control[:extras]
          else
            extras = control[:extras]
            max_age = control[:max_age]
            stale_while_revalidate = control[:stale_while_revalidate]
            stale_if_error = control[:stale_if_error]

            options << "max-age=#{max_age.to_i}" if max_age
            options << (control[:public] ? PUBLIC : PRIVATE)
            options << MUST_REVALIDATE if control[:must_revalidate]
            options << "stale-while-revalidate=#{stale_while_revalidate.to_i}" if stale_while_revalidate
            options << "stale-if-error=#{stale_if_error.to_i}" if stale_if_error
            options.concat(extras) if extras
          end

          self._cache_control = options.join(", ")
        end
      end
    end
  end
end
