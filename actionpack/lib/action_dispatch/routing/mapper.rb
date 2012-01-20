require 'action_dispatch/routing/constraints'
require 'action_dispatch/routing/mapping'
require 'action_dispatch/routing/base'
require 'action_dispatch/routing/http_helpers'
require 'action_dispatch/routing/scoping'
require 'action_dispatch/routing/resources'
require 'action_dispatch/routing/redirection'
require 'active_support/deprecation/proxy_wrappers'

module ActionDispatch
  module Routing
    class Mapper
      # Invokes Rack::Mount::Utils.normalize path and ensure that
      # (:locale) becomes (/:locale) instead of /(:locale). Except
      # for root cases, where the latter is the correct one.
      def self.normalize_path(path)
        path = Journey::Router::Utils.normalize_path(path)
        path.gsub!(%r{/(\(+)/?}, '\1/') unless path =~ %r{^/\(+[^/]+\)$}
        path
      end

      def self.normalize_name(name)
        normalize_path(name)[1..-1].gsub("/", "_")
      end

      def initialize(set) #:nodoc:
        @set = set
        @scope = { :path_names => @set.resources_path_names }
      end

      include Base
      include HttpHelpers
      include Redirection
      include Scoping
      include Resources

      %w(Constraints Mapping Base HttpHelpers Scoping Resources).each do |name|
        const = ActiveSupport::Deprecation::DeprecatedConstantProxy.new(
          "ActionDispatch::Routing::Mapper::#{name}", "ActionDispatch::Routing::#{name}")
        const_set(name, const)
      end
    end
  end
end
