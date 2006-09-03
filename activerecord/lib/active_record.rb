#--
# Copyright (c) 2004-2006 David Heinemeier Hansson
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

$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

unless defined?(ActiveSupport)
  begin
    $:.unshift(File.dirname(__FILE__) + "/../../activesupport/lib")  
    require 'active_support'  
  rescue LoadError
    require 'rubygems'
    require_gem 'activesupport'
  end
end

require 'active_record/base'
require 'active_record/observer'
require 'active_record/validations'
require 'active_record/callbacks'
require 'active_record/reflection'
require 'active_record/associations'
require 'active_record/aggregations'
require 'active_record/transactions'
require 'active_record/timestamp'
require 'active_record/acts/list'
require 'active_record/acts/tree'
require 'active_record/acts/nested_set'
require 'active_record/locking/optimistic'
require 'active_record/locking/pessimistic'
require 'active_record/migration'
require 'active_record/schema'
require 'active_record/calculations'
require 'active_record/xml_serialization'
require 'active_record/attribute_methods'

ActiveRecord::Base.class_eval do
  include ActiveRecord::Validations
  include ActiveRecord::Locking::Optimistic
  include ActiveRecord::Locking::Pessimistic
  include ActiveRecord::Callbacks
  include ActiveRecord::Observing
  include ActiveRecord::Timestamp
  include ActiveRecord::Associations
  include ActiveRecord::Aggregations
  include ActiveRecord::Transactions
  include ActiveRecord::Reflection
  include ActiveRecord::Acts::Tree
  include ActiveRecord::Acts::List
  include ActiveRecord::Acts::NestedSet
  include ActiveRecord::Calculations
  include ActiveRecord::XmlSerialization
  include ActiveRecord::AttributeMethods
end

unless defined?(RAILS_CONNECTION_ADAPTERS)
  RAILS_CONNECTION_ADAPTERS = %w( mysql postgresql sqlite firebird sqlserver db2 oracle sybase openbase frontbase )
end

RAILS_CONNECTION_ADAPTERS.each do |adapter|
  require "active_record/connection_adapters/" + adapter + "_adapter"
end

require 'active_record/query_cache'
require 'active_record/schema_dumper'
