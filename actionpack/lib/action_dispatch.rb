#--
# Copyright (c) 2004-2010 David Heinemeier Hansson
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

activesupport_path = File.expand_path('../../../activesupport/lib', __FILE__)
$:.unshift(activesupport_path) if File.directory?(activesupport_path) && !$:.include?(activesupport_path)

activemodel_path = File.expand_path('../../../activemodel/lib', __FILE__)
$:.unshift(activemodel_path) if File.directory?(activemodel_path) && !$:.include?(activemodel_path)

require 'active_support'
require 'active_support/dependencies/autoload'

require 'action_pack'
require 'active_model'
require 'rack'

module Rack
  autoload :Test, 'rack/test'
end

module ActionDispatch
  extend ActiveSupport::Autoload

  autoload_under 'http' do
    autoload :Request
    autoload :Response
  end

  autoload_under 'middleware' do
    autoload :BestStandardsSupport
    autoload :Callbacks
    autoload :Cookies
    autoload :Flash
    autoload :Head
    autoload :ParamsParser
    autoload :RemoteIp
    autoload :Rescue
    autoload :ShowExceptions
    autoload :Static
  end

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
    autoload :Upload
    autoload :UploadedFile, 'action_dispatch/http/upload'
    autoload :URL
  end

  module Session
    autoload :AbstractStore, 'action_dispatch/middleware/session/abstract_store'
    autoload :CookieStore,   'action_dispatch/middleware/session/cookie_store'
    autoload :MemCacheStore, 'action_dispatch/middleware/session/mem_cache_store'
  end

  autoload_under 'testing' do
    autoload :Assertions
    autoload :Integration
    autoload :PerformanceTest
    autoload :TestProcess
    autoload :TestRequest
    autoload :TestResponse
  end
end

autoload :Mime, 'action_dispatch/http/mime_type'
