# frozen_string_literal: true

# Because we implement our own query string parsing, and it is extremely
# similar to Rack's in most simple cases, it would be very easy to have
# locations sneak in where we unknowingly depend on Rack's
# interpretation rather than our own, potentially creating edge-case
# incompatibilities.
#
# To counter that, we monkey-patch Rack in our tests to allow-list the
# call sites that are known to be safe & appropriate.
#
# This file may need to change in response to future Rack changes. If
# you're here because you're adding new code/tests to Rails, though, you
# probably need to work out how to ensure you're using the Rails query
# parser instead.
module RackParsingOverride
  UnexpectedCall = Class.new(Exception)

  # The only expected calls to Rack::QueryParser#parse_nested_query are
  # from Rack::Request#GET/POST, which are separately protected below.
  module ParserPatch
    def parse_nested_query(*)
      unless caller_locations.any? { |loc| loc.path == __FILE__ && (loc.lineno == RackParsingOverride::GET_LINE || loc.lineno == RackParsingOverride::POST_LINE) }
        raise UnexpectedCall, "Unexpected call to Rack::QueryParser#parse_nested_query"
      end
      super
    end
  end

  # This is where we do the real checking, because we need to catch
  # every caller that might _use_ the cached result of Rack's parsing,
  # not just the first call site where parsing gets triggered.
  module RequestPatch
    # Single list of permitted callers -- we don't care about GET vs POST
    def self.permitted_caller?
      caller_locations.any? do |loc|
        # Our parser calls Rack's to prepopulate caches
        loc.path.end_with?("lib/action_dispatch/http/request.rb") && loc.base_label == "request_parameters_list" ||
          # and as a fallback for older Rack versions
          loc.path.end_with?("lib/action_dispatch/http/request.rb") && loc.base_label == "fallback_request_parameters" ||
          # This specifically tests that a "pure" Rack middleware
          # doesn't interfere with our parsing
          (loc.path.end_with?("test/dispatch/request/query_string_parsing_test.rb") && loc.base_label == "populate_rack_cache") ||
          # Rack::MethodOverride obviously uses Rack's parsing, and
          # that's fine: it's looking for a simple top-level key.
          # Checking for a specific internal method is fragile, but we
          # don't want to ignore any app that happens to have
          # MethodOverride on its call stack!
          (loc.path.end_with?("lib/rack/method_override.rb") && loc.base_label == "method_override_param")
      end
    end

    def params
      unless RequestPatch.permitted_caller?
        raise UnexpectedCall, "Unexpected call to Rack::Request#params"
      end
      super
    end
    ::RackParsingOverride::PARAMS_LINE = __LINE__ - 2

    def GET
      unless RequestPatch.permitted_caller?
        raise UnexpectedCall, "Unexpected call to Rack::Request#GET"
      end
      super
    end
    ::RackParsingOverride::GET_LINE = __LINE__ - 2

    def POST
      unless RequestPatch.permitted_caller?
        raise UnexpectedCall, "Unexpected call to Rack::Request#POST"
      end
      super
    end
    ::RackParsingOverride::POST_LINE = __LINE__ - 2
  end

  Rack::QueryParser.class_eval do
    # Being careful here, as this is more internal
    unless method_defined?(:parse_nested_query)
      raise "Rack changed? Can't patch absent Rack::QueryParser#parse_nested_query"
    end
    prepend ParserPatch
  end

  Rack::Request.prepend RequestPatch
end
