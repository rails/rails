
module ActionDispatch
  module Http
    module Cache
      module Request

        HTTP_IF_MODIFIED_SINCE = 'HTTP_IF_MODIFIED_SINCE'.freeze
        HTTP_IF_NONE_MATCH     = 'HTTP_IF_NONE_MATCH'.freeze

        def if_modified_since
          if since = env[HTTP_IF_MODIFIED_SINCE]
            Time.rfc2822(since) rescue nil
          end
        end

        def if_none_match
          env[HTTP_IF_NONE_MATCH]
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
        attr_reader :cache_control, :etag
        alias :etag? :etag

        def last_modified
          if last = headers[LAST_MODIFIED]
            Time.httpdate(last)
          end
        end

        def last_modified?
          headers.include?(LAST_MODIFIED)
        end

        def last_modified=(utc_time)
          headers[LAST_MODIFIED] = utc_time.httpdate
        end

        def date
          if date_header = headers[DATE]
            Time.httpdate(date_header)
          end
        end

        def date?
          headers.include?(DATE)
        end

        def date=(utc_time)
          headers[DATE] = utc_time.httpdate
        end

        def etag=(etag)
          key = ActiveSupport::Cache.expand_cache_key(etag)
          @etag = self[ETAG] = %("#{Digest::MD5.hexdigest(key)}")
        end

      private

        DATE          = 'Date'.freeze
        LAST_MODIFIED = "Last-Modified".freeze
        ETAG          = "ETag".freeze
        CACHE_CONTROL = "Cache-Control".freeze
        SPECIAL_KEYS  = Set.new(%w[extras no-cache max-age public must-revalidate])

        def cache_control_segments
          if cache_control = self[CACHE_CONTROL]
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
          @etag = self[ETAG]
        end

        def handle_conditional_get!
          if etag? || last_modified? || !@cache_control.empty?
            set_conditional_cache_control!
          end
        end

        DEFAULT_CACHE_CONTROL = "max-age=0, private, must-revalidate".freeze
        NO_CACHE              = "no-cache".freeze
        PUBLIC                = "public".freeze
        PRIVATE               = "private".freeze
        MUST_REVALIDATE       = "must-revalidate".freeze

        def set_conditional_cache_control!
          control = {}
          cc_headers = cache_control_headers
          if extras = cc_headers.delete(:extras)
            @cache_control[:extras] ||= []
            @cache_control[:extras] += extras
            @cache_control[:extras].uniq!
          end

          control.merge! cc_headers
          control.merge! @cache_control

          if control.empty?
            headers[CACHE_CONTROL] = DEFAULT_CACHE_CONTROL
          elsif control[:no_cache]
            headers[CACHE_CONTROL] = NO_CACHE
            if control[:extras]
              headers[CACHE_CONTROL] += ", #{control[:extras].join(', ')}"
            end
          else
            extras  = control[:extras]
            max_age = control[:max_age]

            options = []
            options << "max-age=#{max_age.to_i}" if max_age
            options << (control[:public] ? PUBLIC : PRIVATE)
            options << MUST_REVALIDATE if control[:must_revalidate]
            options.concat(extras) if extras

            headers[CACHE_CONTROL] = options.join(", ")
          end
        end
      end
    end
  end
end
