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
$:.unshift(activesupport_path) if File.directory?(activesupport_path)
require 'active_support'

module ActiveModel
  autoload :AttributeMethods, 'active_model/attribute_methods'
  autoload :Conversion, 'active_model/conversion'
  autoload :DeprecatedErrorMethods, 'active_model/deprecated_error_methods'
  autoload :Dirty, 'active_model/dirty'
  autoload :Errors, 'active_model/errors'
  autoload :Name, 'active_model/naming'
  autoload :Naming, 'active_model/naming'
  autoload :Observer, 'active_model/observing'
  autoload :Observing, 'active_model/observing'
  autoload :Serializer, 'active_model/serializer'
  autoload :StateMachine, 'active_model/state_machine'
  autoload :TestCase, 'active_model/test_case'
  autoload :Validations, 'active_model/validations'
  autoload :ValidationsRepairHelper, 'active_model/validations_repair_helper'

  module Serializers
    autoload :JSON, 'active_model/serializers/json'
    autoload :Xml, 'active_model/serializers/xml'
  end
end

I18n.load_path << File.dirname(__FILE__) + '/active_model/locale/en.yml'
