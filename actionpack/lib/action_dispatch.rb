# frozen_string_literal: true

#--
# Copyright (c) David Heinemeier Hansson
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#++

# :markup: markdown

require "active_support"
require "active_support/rails"
require "active_support/core_ext/module/attribute_accessors"

require "action_pack"
require "rack"
require "action_dispatch/deprecator"

module Rack # :nodoc:
  autoload :Test, "rack/test"
end

# # Action Dispatch
#
# Action Dispatch is a module of Action Pack.
#
# Action Dispatch parses information about the web request, handles routing as
# defined by the user, and does advanced processing related to HTTP such as
# MIME-type negotiation, decoding parameters in POST, PATCH, or PUT bodies,
# handling HTTP caching logic, cookies and sessions.
module ActionDispatch
  extend ActiveSupport::Autoload

  class MissingController < NameError
  end

  eager_autoload do
    autoload_under "http" do
      autoload :ContentSecurityPolicy
      autoload :InvalidParameterError, "action_dispatch/http/param_error"
      autoload :ParamBuilder
      autoload :ParamError
      autoload :ParameterTypeError, "action_dispatch/http/param_error"
      autoload :ParamsTooDeepError, "action_dispatch/http/param_error"
      autoload :PermissionsPolicy
      autoload :QueryParser
      autoload :Request
      autoload :Response
    end
  end

  autoload_under "middleware" do
    autoload :AssumeSSL
    autoload :HostAuthorization
    autoload :RequestId
    autoload :Callbacks
    autoload :Cookies
    autoload :ActionableExceptions
    autoload :DebugExceptions
    autoload :DebugLocks
    autoload :DebugView
    autoload :ExceptionWrapper
    autoload :Executor
    autoload :Flash
    autoload :PublicExceptions
    autoload :Reloader
    autoload :RemoteIp
    autoload :ServerTiming
    autoload :ShowExceptions
    autoload :SSL
    autoload :Static
  end

  autoload :Constants
  autoload :Journey
  autoload :MiddlewareStack, "action_dispatch/middleware/stack"
  autoload :Routing

  module Http
    extend ActiveSupport::Autoload

    autoload :Cache
    autoload :Headers
    autoload :MimeNegotiation
    autoload :Parameters
    autoload :UploadedFile, "action_dispatch/http/upload"
    autoload :URL
  end

  module Session
    autoload :AbstractStore,       "action_dispatch/middleware/session/abstract_store"
    autoload :AbstractSecureStore, "action_dispatch/middleware/session/abstract_store"
    autoload :CookieStore,         "action_dispatch/middleware/session/cookie_store"
    autoload :MemCacheStore,       "action_dispatch/middleware/session/mem_cache_store"
    autoload :CacheStore,          "action_dispatch/middleware/session/cache_store"

    def self.resolve_store(session_store) # :nodoc:
      self.const_get(session_store.to_s.camelize)
    rescue NameError
      raise <<~ERROR
        Unable to resolve session store #{session_store.inspect}.

        #{session_store.inspect} resolves to ActionDispatch::Session::#{session_store.to_s.camelize},
        but that class is undefined.

        Is #{session_store.inspect} spelled correctly, and are any necessary gems installed?
      ERROR
    end
  end

  mattr_accessor :test_app

  autoload_under "testing" do
    autoload :Assertions
    autoload :Integration
    autoload :IntegrationTest, "action_dispatch/testing/integration"
    autoload :TestProcess
    autoload :TestRequest
    autoload :TestResponse
    autoload :AssertionResponse
  end

  autoload :SystemTestCase, "action_dispatch/system_test_case"

  def eager_load!
    super
    Routing.eager_load!
  end
end

autoload :Mime, "action_dispatch/http/mime_type"

ActiveSupport.on_load(:action_view) do
  ActionView::Base.default_formats ||= Mime::SET.symbols
  ActionView::Template.mime_types_implementation = Mime
  ActionView::LookupContext::DetailsKey.clear
end
