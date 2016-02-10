module ActionDispatch
  module Http
    module Cache
      module Request

        HTTP_IF_MODIFIED_SINCE = 'HTTP_IF_MODIFIED_SINCE'.freeze
        HTTP_IF_NONE_MATCH     = 'HTTP_IF_NONE_MATCH'.freeze

        def if_modified_since
          if since = get_header(HTTP_IF_MODIFIED_SINCE)
            Time.rfc2822(since) rescue nil
          end
        end

        def if_none_match
          get_header HTTP_IF_NONE_MATCH
        end

        def if_none_match_etags
          (if_none_match ? if_none_match.split(/\s*,\s*/) : []).collect do |etag|
            etag.gsub(/^\"|\"$/, "")
          end
        end

        def not_modified?(modified_at)
          if_modified_since && modified_at && if_modified_since >= modified_at
        end

        def etag_matches?(etag)
          if etag
            etag = etag.gsub(/^\"|\"$/, "")
            if_none_match_etags.include?(etag)
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

        # This method allows you to set the ETag for cached content, which
        # will be returned to the end user.
        #
        # By default, Action Dispatch sets all ETags to be weak.
        # This ensures that if the content changes only semantically,
        # the whole page doesn't have to be regenerated from scratch
        # by the web server. With strong ETags, pages are compared
        # byte by byte, and are regenerated only if they are not exactly equal.
        def etag=(etag)
          key = ActiveSupport::Cache.expand_cache_key(etag)
          super %(W/"#{Digest::MD5.hexdigest(key)}")
        end

        def etag?; etag; end

      private

        DATE          = 'Date'.freeze
        LAST_MODIFIED = "Last-Modified".freeze
        SPECIAL_KEYS  = Set.new(%w[extras no-cache max-age public private must-revalidate])

        def cache_control_segments
          if cache_control = _cache_control
            cache_control.delete(' ').split(',')
          else
            []
          end
        end

        def cache_control_headers
          cache_control = {}

          cache_control_segments.each do |segment|
            directive, argument = segment.split('=', 2)

            if SPECIAL_KEYS.include? directive
              key = directive.tr('-', '_')
              cache_control[key.to_sym] = argument || true
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

        def handle_conditional_get!
          if etag? || last_modified? || !@cache_control.empty?
            set_conditional_cache_control!(@cache_control)
          end
        end

        DEFAULT_CACHE_CONTROL = "max-age=0, private, must-revalidate".freeze
        NO_CACHE              = "no-cache".freeze
        PUBLIC                = "public".freeze
        PRIVATE               = "private".freeze
        MUST_REVALIDATE       = "must-revalidate".freeze

        def set_conditional_cache_control!(cache_control)
          control = {}
          cc_headers = cache_control_headers
          if extras = cc_headers.delete(:extras)
            cache_control[:extras] ||= []
            cache_control[:extras] += extras
            cache_control[:extras].uniq!
          end

          control.merge! cc_headers
          control.merge! cache_control

          if control.empty?
            self._cache_control = DEFAULT_CACHE_CONTROL
          elsif control[:no_cache]
            self._cache_control = NO_CACHE
            if control[:extras]
              self._cache_control = _cache_control + ", #{control[:extras].join(', ')}"
            end
          else
            extras  = control[:extras]
            max_age = control[:max_age]

            options = []
            options << "max-age=#{max_age.to_i}" if max_age
            options << (control[:public] ? PUBLIC : PRIVATE)
            options << MUST_REVALIDATE if control[:must_revalidate]
            options.concat(extras) if extras

            self._cache_control = options.join(", ")
          end
        end
      end
    end
  end
end
