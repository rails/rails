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

begin
  gem 'rack', '~> 1.1.pre'
rescue Gem::LoadError, ArgumentError
  $:.unshift "#{File.dirname(__FILE__)}/action_dispatch/vendor/rack-1.1.pre"
end

require 'rack'

$:.unshift "#{File.dirname(__FILE__)}/action_dispatch/vendor/rack-test"

module ActionDispatch
  autoload :Request, 'action_dispatch/http/request'
  autoload :Response, 'action_dispatch/http/response'
  autoload :StatusCodes, 'action_dispatch/http/status_codes'

  autoload :Callbacks, 'action_dispatch/middleware/callbacks'
  autoload :ParamsParser, 'action_dispatch/middleware/params_parser'
  autoload :Rescue, 'action_dispatch/middleware/rescue'
  autoload :ShowExceptions, 'action_dispatch/middleware/show_exceptions'
  autoload :MiddlewareStack, 'action_dispatch/middleware/stack'

  autoload :HTML, 'action_controller/vendor/html-scanner'
  autoload :Assertions, 'action_dispatch/testing/assertions'
  autoload :TestRequest, 'action_dispatch/testing/test_request'
  autoload :TestResponse, 'action_dispatch/testing/test_response'

  module Http
    autoload :Headers, 'action_dispatch/http/headers'
  end

  module Session
    autoload :AbstractStore, 'action_dispatch/middleware/session/abstract_store'
    autoload :CookieStore, 'action_dispatch/middleware/session/cookie_store'
    autoload :MemCacheStore, 'action_dispatch/middleware/session/mem_cache_store'
  end
end

autoload :Mime, 'action_dispatch/http/mime_type'
