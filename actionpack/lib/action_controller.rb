#--
# Copyright (c) 2004 David Heinemeier Hansson
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

$:.unshift(File.dirname(__FILE__))

require 'action_controller/support/core_ext'
require 'action_controller/support/clean_logger'
require 'action_controller/support/misc'
require 'action_controller/support/dependencies'

require 'action_controller/base'
require 'action_controller/rescue'
require 'action_controller/benchmarking'
require 'action_controller/filters'
require 'action_controller/layout'
require 'action_controller/flash'
require 'action_controller/session'
require 'action_controller/dependencies'
require 'action_controller/scaffolding'
require 'action_controller/helpers'
require 'action_controller/cookies'
require 'action_controller/cgi_process'
require 'action_controller/caching'

ActionController::Base.class_eval do
  include ActionController::Filters
  include ActionController::Layout
  include ActionController::Flash
  include ActionController::Benchmarking
  include ActionController::Rescue
  include ActionController::Dependencies
  include ActionController::Scaffolding
  include ActionController::Helpers
  include ActionController::Cookies
  include ActionController::Session
  include ActionController::Caching
end

require 'action_view'
ActionController::Base.template_class = ActionView::Base