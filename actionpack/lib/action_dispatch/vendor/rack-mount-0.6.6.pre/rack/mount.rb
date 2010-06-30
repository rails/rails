require 'rack'

module Rack #:nodoc:
  # A stackable dynamic tree based Rack router.
  #
  # Rack::Mount supports Rack's Cascade style of trying several routes until
  # it finds one that is not a 404. This allows multiple routes to be nested
  # or stacked on top of each other. Since the application endpoint can
  # trigger the router to continue matching, middleware can be used to add
  # arbitrary conditions to any route. This allows you to route based on
  # other request attributes, session information, or even data dynamically
  # pulled from a database.
  module Mount
    autoload :CodeGeneration, 'rack/mount/code_generation'
    autoload :GeneratableRegexp, 'rack/mount/generatable_regexp'
    autoload :Multimap, 'rack/mount/multimap'
    autoload :Prefix, 'rack/mount/prefix'
    autoload :RegexpWithNamedGroups, 'rack/mount/regexp_with_named_groups'
    autoload :Route, 'rack/mount/route'
    autoload :RouteSet, 'rack/mount/route_set'
    autoload :RoutingError, 'rack/mount/route_set'
    autoload :Strexp, 'rack/mount/strexp'
    autoload :Utils, 'rack/mount/utils'
    autoload :Version, 'rack/mount/version'

    module Analysis #:nodoc:
      autoload :Frequency, 'rack/mount/analysis/frequency'
      autoload :Histogram, 'rack/mount/analysis/histogram'
      autoload :Splitting, 'rack/mount/analysis/splitting'
    end
  end
end
