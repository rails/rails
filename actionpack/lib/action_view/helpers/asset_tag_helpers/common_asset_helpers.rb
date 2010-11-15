require 'active_support/core_ext/file'

module ActionView
  module Helpers
    module AssetTagHelper

      module HelperMacros
        private
        def asset_path(asset_type, extension = nil)
          define_method("#{asset_type}_path") do |source|
            compute_public_path(source, asset_type.to_s.pluralize, extension)
          end
          alias_method :"path_to_#{asset_type}", :"#{asset_type}_path" # aliased to avoid conflicts with a *_path named route
        end
      end

      module CommonAssetHelpers
        private
        # Add the the extension +ext+ if not present. Return full URLs otherwise untouched.
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

        def is_uri?(path)
          path =~ %r{^[-a-z]+://|^cid:}
        end

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
          else
            handle_asset_id(source)
          end
        end

        # This is the default implementation
        def handle_asset_id(source)
          source
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