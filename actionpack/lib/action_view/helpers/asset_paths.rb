require 'active_support/core_ext/file'

module ActionView
  module Helpers

    class AssetPaths #:nodoc:
      attr_reader :config, :controller

      def initialize(config, controller)
        @config = config
        @controller = controller
      end

      # Add the extension +ext+ if not present. Return full or scheme-relative URLs otherwise untouched.
      # Prefix with <tt>/dir/</tt> if lacking a leading +/+. Account for relative URL
      # roots. Rewrite the asset path for cache-busting asset ids. Include
      # asset host, if configured, with the correct request protocol.
      def compute_public_path(source, dir, ext = nil, include_host = true)
        source = source.to_s
        return source if is_uri?(source)

        source = rewrite_extension(source, dir, ext) if ext
        source = rewrite_asset_path(source, dir)

        if controller && include_host
          has_request = controller.respond_to?(:request)
          source = rewrite_host_and_protocol(source, has_request)
        end

        source
      end

      def is_uri?(path)
        path =~ %r{^[-a-z]+://|^cid:|^//}
      end

    private

      def rewrite_extension(source, dir, ext)
        raise NotImplementedError
      end

      def rewrite_asset_path(source, path = nil)
        raise NotImplementedError
      end

      def rewrite_relative_url_root(source, relative_url_root)
        relative_url_root && !source.starts_with?("#{relative_url_root}/") ? "#{relative_url_root}#{source}" : source
      end

      def rewrite_host_and_protocol(source, has_request)
        source = rewrite_relative_url_root(source, controller.config.relative_url_root) if has_request
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
