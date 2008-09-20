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

$:.unshift "#{File.dirname(__FILE__)}/action_controller/vendor/html-scanner"

require 'action_controller/base'
require 'action_controller/request'
require 'action_controller/rescue'
require 'action_controller/benchmarking'
require 'action_controller/flash'
require 'action_controller/filters'
require 'action_controller/layout'
require 'action_controller/mime_responds'
require 'action_controller/helpers'
require 'action_controller/cookies'
require 'action_controller/cgi_process'
require 'action_controller/caching'
require 'action_controller/verification'
require 'action_controller/streaming'
require 'action_controller/session_management'
require 'action_controller/http_authentication'
require 'action_controller/components'
require 'action_controller/rack_process'
require 'action_controller/record_identifier'
require 'action_controller/request_forgery_protection'
require 'action_controller/headers'
require 'action_controller/translation'

require 'action_view'

ActionController::Base.class_eval do
  include ActionController::Flash
  include ActionController::Filters
  include ActionController::Layout
  include ActionController::Benchmarking
  include ActionController::Rescue
  include ActionController::MimeResponds
  include ActionController::Helpers
  include ActionController::Cookies
  include ActionController::Caching
  include ActionController::Verification
  include ActionController::Streaming
  include ActionController::SessionManagement
  include ActionController::HttpAuthentication::Basic::ControllerMethods
  include ActionController::Components
  include ActionController::RecordIdentifier
  include ActionController::RequestForgeryProtection
  include ActionController::Translation
end
