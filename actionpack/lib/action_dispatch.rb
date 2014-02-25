#--
# Copyright (c) 2004-2013 David Heinemeier Hansson
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

require 'active_support'
require 'active_support/rails'
require 'active_support/core_ext/module/attribute_accessors'

require 'action_pack'
require 'rack'

module Rack
  autoload :Test, 'rack/test'
end

module ActionDispatch
  extend ActiveSupport::Autoload

  class IllegalStateError < StandardError
  end

  eager_autoload do
    autoload_under 'http' do
      autoload :Request
      autoload :Response
    end
  end

  autoload_under 'middleware' do
    autoload :RequestId
    autoload :Callbacks
    autoload :Cookies
    autoload :DebugExceptions
    autoload :ExceptionWrapper
    autoload :Flash
    autoload :ParamsParser
    autoload :PublicExceptions
    autoload :Reloader
    autoload :RemoteIp
    autoload :ShowExceptions
    autoload :SSL
    autoload :Static
  end

  autoload :Journey
  autoload :MiddlewareStack, 'action_dispatch/middleware/stack'
  autoload :Routing

  module Http
    extend ActiveSupport::Autoload

    autoload :Cache
    autoload :Headers
    autoload :MimeNegotiation
    autoload :Parameters
    autoload :ParameterFilter
    autoload :FilterParameters
    autoload :FilterRedirect
    autoload :Upload
    autoload :UploadedFile, 'action_dispatch/http/upload'
    autoload :URL
  end

  module Session
    autoload :AbstractStore, 'action_dispatch/middleware/session/abstract_store'
    autoload :CookieStore,   'action_dispatch/middleware/session/cookie_store'
    autoload :MemCacheStore, 'action_dispatch/middleware/session/mem_cache_store'
    autoload :CacheStore,    'action_dispatch/middleware/session/cache_store'
  end

  mattr_accessor :test_app

  autoload_under 'testing' do
    autoload :Assertions
    autoload :Integration
    autoload :IntegrationTest, 'action_dispatch/testing/integration'
    autoload :TestProcess
    autoload :TestRequest
    autoload :TestResponse
  end
end

autoload :Mime, 'action_dispatch/http/mime_type'

ActiveSupport.on_load(:action_view) do
  ActionView::Base.default_formats ||= Mime::SET.symbols
  ActionView::Template::Types.delegate_to Mime
end
