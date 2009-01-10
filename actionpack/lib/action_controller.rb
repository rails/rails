#--
# Copyright (c) 2004-2008 David Heinemeier Hansson
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++

begin
  require 'active_support'
rescue LoadError
  activesupport_path = "#{File.dirname(__FILE__)}/../../activesupport/lib"
  if File.directory?(activesupport_path)
    $:.unshift activesupport_path
    require 'active_support'
  end
end

gem 'rack', '>= 0.9.0'
require 'rack'

module ActionController
  # TODO: Review explicit to see if they will automatically be handled by
  # the initilizer if they are really needed.
  def self.load_all!
    [Base, CGIHandler, CgiRequest, Request, Response, Http::Headers, UrlRewriter, UrlWriter]
  end

  autoload :AbstractRequest, 'action_controller/request'
  autoload :Base, 'action_controller/base'
  autoload :Benchmarking, 'action_controller/benchmarking'
  autoload :Caching, 'action_controller/caching'
  autoload :Cookies, 'action_controller/cookies'
  autoload :Dispatcher, 'action_controller/dispatcher'
  autoload :Failsafe, 'action_controller/failsafe'
  autoload :Filters, 'action_controller/filters'
  autoload :Flash, 'action_controller/flash'
  autoload :Helpers, 'action_controller/helpers'
  autoload :HttpAuthentication, 'action_controller/http_authentication'
  autoload :Integration, 'action_controller/integration'
  autoload :IntegrationTest, 'action_controller/integration'
  autoload :Layout, 'action_controller/layout'
  autoload :Lock, 'action_controller/lock'
  autoload :MiddlewareStack, 'action_controller/middleware_stack'
  autoload :MimeResponds, 'action_controller/mime_responds'
  autoload :PolymorphicRoutes, 'action_controller/polymorphic_routes'
  autoload :Request, 'action_controller/request'
  autoload :RequestParser, 'action_controller/request_parser'
  autoload :UrlEncodedPairParser, 'action_controller/url_encoded_pair_parser'
  autoload :UploadedStringIO, 'action_controller/uploaded_file'
  autoload :UploadedTempfile, 'action_controller/uploaded_file'
  autoload :RecordIdentifier, 'action_controller/record_identifier'
  autoload :Response, 'action_controller/response'
  autoload :RequestForgeryProtection, 'action_controller/request_forgery_protection'
  autoload :Rescue, 'action_controller/rescue'
  autoload :Resources, 'action_controller/resources'
  autoload :Routing, 'action_controller/routing'
  autoload :SessionManagement, 'action_controller/session_management'
  autoload :StatusCodes, 'action_controller/status_codes'
  autoload :Streaming, 'action_controller/streaming'
  autoload :TestCase, 'action_controller/test_case'
  autoload :TestProcess, 'action_controller/test_process'
  autoload :Translation, 'action_controller/translation'
  autoload :UrlRewriter, 'action_controller/url_rewriter'
  autoload :UrlWriter, 'action_controller/url_rewriter'
  autoload :VerbPiggybacking, 'action_controller/verb_piggybacking'
  autoload :Verification, 'action_controller/verification'

  module Assertions
    autoload :DomAssertions, 'action_controller/assertions/dom_assertions'
    autoload :ModelAssertions, 'action_controller/assertions/model_assertions'
    autoload :ResponseAssertions, 'action_controller/assertions/response_assertions'
    autoload :RoutingAssertions, 'action_controller/assertions/routing_assertions'
    autoload :SelectorAssertions, 'action_controller/assertions/selector_assertions'
    autoload :TagAssertions, 'action_controller/assertions/tag_assertions'
  end

  module Http
    autoload :Headers, 'action_controller/headers'
  end

  module Session
    autoload :AbstractStore, 'action_controller/session/abstract_store'
    autoload :CookieStore, 'action_controller/session/cookie_store'
    autoload :MemCacheStore, 'action_controller/session/mem_cache_store'
  end

  # DEPRECATE: Remove CGI support
  autoload :CgiRequest, 'action_controller/cgi_process'
  autoload :CGIHandler, 'action_controller/cgi_process'
end

autoload :Mime, 'action_controller/mime_type'

autoload :HTML, 'action_controller/vendor/html-scanner'

require 'action_view'
