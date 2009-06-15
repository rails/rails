#--
# Copyright (c) 2004-2009 David Heinemeier Hansson
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

activesupport_path = "#{File.dirname(__FILE__)}/../../activesupport/lib"
$:.unshift activesupport_path if File.directory?(activesupport_path)
require 'active_support'

require File.join(File.dirname(__FILE__), "action_pack")

module ActionController
  # TODO: Review explicit to see if they will automatically be handled by
  # the initilizer if they are really needed.
  def self.load_all!
    [Base, Request, Response, UrlRewriter, UrlWriter]
    [ActionDispatch::Http::Headers]
  end

  autoload :Base, 'action_controller/base/base'
  autoload :Benchmarking, 'action_controller/base/chained/benchmarking'
  autoload :Caching, 'action_controller/caching'
  autoload :Cookies, 'action_controller/base/cookies'
  autoload :Dispatcher, 'action_controller/dispatch/dispatcher'
  autoload :Filters, 'action_controller/base/chained/filters'
  autoload :Flash, 'action_controller/base/chained/flash'
  autoload :Helpers, 'action_controller/base/helpers'
  autoload :HttpAuthentication, 'action_controller/base/http_authentication'
  autoload :Integration, 'action_controller/testing/integration'
  autoload :IntegrationTest, 'action_controller/testing/integration'
  autoload :Layout, 'action_controller/base/layout'
  autoload :MimeResponds, 'action_controller/base/mime_responds'
  autoload :PolymorphicRoutes, 'action_controller/routing/generation/polymorphic_routes'
  autoload :RecordIdentifier, 'action_controller/record_identifier'
  autoload :Redirector, 'action_controller/base/redirect'
  autoload :Renderer, 'action_controller/base/render'
  autoload :RequestForgeryProtection, 'action_controller/base/request_forgery_protection'
  autoload :Rescue, 'action_controller/base/rescue'
  autoload :Resources, 'action_controller/routing/resources'
  autoload :Responder, 'action_controller/base/responder'
  autoload :Routing, 'action_controller/routing'
  autoload :SessionManagement, 'action_controller/base/session_management'
  autoload :Streaming, 'action_controller/base/streaming'
  autoload :TestCase, 'action_controller/testing/test_case'
  autoload :TestProcess, 'action_controller/testing/process'
  autoload :Translation, 'action_controller/translation'
  autoload :UrlEncodedPairParser, 'action_controller/dispatch/url_encoded_pair_parser'
  autoload :UrlRewriter, 'action_controller/routing/generation/url_rewriter'
  autoload :UrlWriter, 'action_controller/routing/generation/url_rewriter'
  autoload :Verification, 'action_controller/base/verification'
  autoload :FilterParameterLogging, 'action_controller/base/filter_parameter_logging'

  module Assertions
    autoload :DomAssertions, 'action_controller/testing/assertions/dom'
    autoload :ModelAssertions, 'action_controller/testing/assertions/model'
    autoload :ResponseAssertions, 'action_controller/testing/assertions/response'
    autoload :RoutingAssertions, 'action_controller/testing/assertions/routing'
    autoload :SelectorAssertions, 'action_controller/testing/assertions/selector'
    autoload :TagAssertions, 'action_controller/testing/assertions/tag'
  end
end

autoload :HTML, 'action_controller/vendor/html-scanner'

require 'action_dispatch'
require 'action_view'
