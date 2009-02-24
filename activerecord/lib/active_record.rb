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

begin
  require 'active_support'
rescue LoadError
  activesupport_path = "#{File.dirname(__FILE__)}/../../activesupport/lib"
  if File.directory?(activesupport_path)
    $:.unshift activesupport_path
    require 'active_support'
  end
end

module ActiveRecord
  # TODO: Review explicit loads to see if they will automatically be handled by the initilizer.
  def self.load_all!
    [Base, DynamicFinderMatch, ConnectionAdapters::AbstractAdapter]
  end

  autoload :VERSION, 'active_record/version'

  autoload :ActiveRecordError, 'active_record/base'
  autoload :ConnectionNotEstablished, 'active_record/base'

  autoload :Aggregations, 'active_record/aggregations'
  autoload :AssociationPreload, 'active_record/association_preload'
  autoload :Associations, 'active_record/associations'
  autoload :AttributeMethods, 'active_record/attribute_methods'
  autoload :AutosaveAssociation, 'active_record/autosave_association'
  autoload :Base, 'active_record/base'
  autoload :Batches, 'active_record/batches'
  autoload :Calculations, 'active_record/calculations'
  autoload :Callbacks, 'active_record/callbacks'
  autoload :Dirty, 'active_record/dirty'
  autoload :DynamicFinderMatch, 'active_record/dynamic_finder_match'
  autoload :DynamicScopeMatch, 'active_record/dynamic_scope_match'
  autoload :Migration, 'active_record/migration'
  autoload :Migrator, 'active_record/migration'
  autoload :NamedScope, 'active_record/named_scope'
  autoload :NestedAttributes, 'active_record/nested_attributes'
  autoload :Observing, 'active_record/observer'
  autoload :QueryCache, 'active_record/query_cache'
  autoload :Reflection, 'active_record/reflection'
  autoload :Schema, 'active_record/schema'
  autoload :SchemaDumper, 'active_record/schema_dumper'
  autoload :Serialization, 'active_record/serialization'
  autoload :SessionStore, 'active_record/session_store'
  autoload :TestCase, 'active_record/test_case'
  autoload :Timestamp, 'active_record/timestamp'
  autoload :Transactions, 'active_record/transactions'
  autoload :Validations, 'active_record/validations'

  module Locking
    autoload :Optimistic, 'active_record/locking/optimistic'
    autoload :Pessimistic, 'active_record/locking/pessimistic'
  end

  module ConnectionAdapters
    autoload :AbstractAdapter, 'active_record/connection_adapters/abstract_adapter'
  end
end

require 'active_record/i18n_interpolation_deprecation'
I18n.load_path << File.dirname(__FILE__) + '/active_record/locale/en.yml'
