require 'active_support/core_ext/file'

module ActionView
  module Helpers
    module AssetTagHelper

      class AssetPaths
        # You can enable or disable the asset tag ids cache.
        # With the cache enabled, the asset tag helper methods will make fewer
        # expensive file system calls (the default implementation checks the file
        # system timestamp). However this prevents you from modifying any asset
        # files while the server is running.
        #
        #   ActionView::Helpers::AssetTagHelper::AssetPaths.cache_asset_ids = false
        mattr_accessor :cache_asset_ids

        attr_reader :config, :controller

        def initialize(config, controller)
          @config = config
          @controller = controller
        end

        # Add the extension +ext+ if not present. Return full URLs otherwise untouched.
        # Prefix with <tt>/dir/</tt> if lacking a leading +/+. Account for relative URL
        # roots. Rewrite the asset path for cache-busting asset ids. Include
        # asset host, if configured, with the correct request protocol.
        def compute_public_path(source, dir, ext = nil, include_host = true)
          return source if is_uri?(source)

          source = rewrite_extension(source, dir, ext) if ext
          source = "/#{dir}/#{source}" unless source[0] == ?/
          if controller.respond_to?(:env) && controller.env["action_dispatch.asset_path"]
            source = rewrite_asset_path(source, controller.env["action_dispatch.asset_path"])
          end
          source = rewrite_asset_path(source, config.asset_path)

          has_request = controller.respond_to?(:request)
          source = rewrite_relative_url_root(source, controller.config.relative_url_root) if has_request && include_host
          source = rewrite_host_and_protocol(source, has_request) if include_host

          source
        end

        # Add or change an asset id in the asset id cache. This can be used
        # for SASS on Heroku.
        # :api: public
        def add_to_asset_ids_cache(source, asset_id)
          self.asset_ids_cache_guard.synchronize do
            self.asset_ids_cache[source] = asset_id
          end
        end

        def is_uri?(path)
          path =~ %r{^[-a-z]+://|^cid:}
        end

        private

          def rewrite_extension(source, dir, ext)
            source_ext = File.extname(source)

            source_with_ext = if source_ext.empty?
              "#{source}.#{ext}"
            elsif ext != source_ext[1..-1]
              with_ext = "#{source}.#{ext}"
              with_ext if File.exist?(File.join(config.assets_dir, dir, with_ext))
            end

            source_with_ext || source
          end

          # Break out the asset path rewrite in case plugins wish to put the asset id
          # someplace other than the query string.
          def rewrite_asset_path(source, path = nil)
            if path && path.respond_to?(:call)
              return path.call(source)
            elsif path && path.is_a?(String)
              return path % [source]
            end

            asset_id = rails_asset_id(source)
            if asset_id.empty?
              source
            else
              "#{source}?#{asset_id}"
            end
          end

          mattr_accessor :asset_ids_cache
          self.asset_ids_cache = {}

          mattr_accessor :asset_ids_cache_guard
          self.asset_ids_cache_guard = Mutex.new

          # Use the RAILS_ASSET_ID environment variable or the source's
          # modification time as its cache-busting asset id.
          def rails_asset_id(source)
            if asset_id = ENV["RAILS_ASSET_ID"]
              asset_id
            else
              if self.cache_asset_ids && (asset_id = self.asset_ids_cache[source])
                asset_id
              else
                path = File.join(config.assets_dir, source)
                asset_id = File.exist?(path) ? File.mtime(path).to_i.to_s : ''

                if self.cache_asset_ids
                  add_to_asset_ids_cache(source, asset_id)
                end

                asset_id
              end
            end
          end

          def rewrite_relative_url_root(source, relative_url_root)
            relative_url_root && !source.starts_with?("#{relative_url_root}/") ? "#{relative_url_root}#{source}" : source
          end

          def rewrite_host_and_protocol(source, has_request)
            host = compute_asset_host(source)
            if has_request && host && !is_uri?(host)
              host = "#{controller.request.protocol}#{host}"
            end
            "#{host}#{source}"
          end

          # Pick an asset host for this source. Returns +nil+ if no host is set,
          # the host if no wildcard is set, the host interpolated with the
          # numbers 0-3 if it contains <tt>%d</tt> (the number is the source hash mod 4),
          # or the value returned from invoking the proc if it's a proc or the value from
          # invoking call if it's an object responding to call.
          def compute_asset_host(source)
            if host = config.asset_host
              if host.is_a?(Proc) || host.respond_to?(:call)
                case host.is_a?(Proc) ? host.arity : host.method(:call).arity
                when 2
                  request = controller.respond_to?(:request) && controller.request
                  host.call(source, request)
                else
                  host.call(source)
                end
              else
                (host =~ /%d/) ? host % (source.hash % 4) : host
              end
            end
          end
      end

    end
  end
end