#--
# Copyright (C) 2005 Leon Breedt
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
  require 'action_controller'
  require 'active_record'
rescue LoadError
  require 'rubygems'
  require_gem 'activesupport', '>= 0.9.0'
  require_gem 'actionpack', '>= 1.4.0'
  require_gem 'activerecord', '>= 1.6.0'
end

$:.unshift(File.dirname(__FILE__))

require 'action_service/base'
require 'action_service/client'
require 'action_service/invocation'
require 'action_service/api'
require 'action_service/struct'
require 'action_service/container'
require 'action_service/protocol'
require 'action_service/router'

ActionService::Base.class_eval do
  include ActionService::API
  include ActionService::Invocation
end

ActionController::Base.class_eval do
  include ActionService::Container
  include ActionService::Protocol::Registry
  include ActionService::Protocol::Soap
  include ActionService::Protocol::XmlRpc
  include ActionService::API
  include ActionService::API::ActionController
  include ActionService::Router::ActionController
  include ActionService::Router::Wsdl
end
