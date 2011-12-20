#--
# Copyright (c) 2004-2011 David Heinemeier Hansson
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
require 'active_support/i18n'
require 'active_model'
require 'arel'

require 'active_record/version'

module ActiveRecord
  extend ActiveSupport::Autoload

  eager_autoload do
    autoload :ActiveRecordError, 'active_record/errors'
    autoload :ConnectionNotEstablished, 'active_record/errors'
    autoload :ConnectionAdapters, 'active_record/connection_adapters/abstract_adapter'

    autoload :Aggregations
    autoload :Associations
    autoload :AttributeMethods
    autoload :AttributeAssignment
    autoload :AutosaveAssociation

    autoload :Relation

    autoload_under 'relation' do
      autoload :QueryMethods
      autoload :FinderMethods
      autoload :Calculations
      autoload :PredicateBuilder
      autoload :SpawnMethods
      autoload :Batches
      autoload :Explain
      autoload :Delegation
    end

    autoload :Base
    autoload :Callbacks
    autoload :CounterCache
    autoload :DynamicMatchers
    autoload :DynamicFinderMatch
    autoload :DynamicScopeMatch
    autoload :Explain
    autoload :IdentityMap
    autoload :Inheritance
    autoload :Integration
    autoload :Migration
    autoload :Migrator, 'active_record/migration'
    autoload :ModelSchema
    autoload :NestedAttributes
    autoload :Observer
    autoload :Persistence
    autoload :QueryCache
    autoload :Querying
    autoload :ReadonlyAttributes
    autoload :Reflection
    autoload :Result
    autoload :Sanitization
    autoload :Schema
    autoload :SchemaDumper
    autoload :Scoping
    autoload :Serialization
    autoload :SessionStore
    autoload :Store
    autoload :Timestamp
    autoload :Transactions
    autoload :Translation
    autoload :Validations
  end

  module Coders
    autoload :YAMLColumn, 'active_record/coders/yaml_column'
  end

  module AttributeMethods
    extend ActiveSupport::Autoload

    eager_autoload do
      autoload :BeforeTypeCast
      autoload :Dirty
      autoload :PrimaryKey
      autoload :Query
      autoload :Read
      autoload :TimeZoneConversion
      autoload :Write
      autoload :Serialization
      autoload :DeprecatedUnderscoreRead
    end
  end

  module Locking
    extend ActiveSupport::Autoload

    eager_autoload do
      autoload :Optimistic
      autoload :Pessimistic
    end
  end

  module ConnectionAdapters
    extend ActiveSupport::Autoload

    eager_autoload do
      autoload :AbstractAdapter
      autoload :ConnectionManagement, "active_record/connection_adapters/abstract/connection_pool"
    end
  end

  module Scoping
    extend ActiveSupport::Autoload

    eager_autoload do
      autoload :Named
      autoload :Default
    end
  end

  autoload :TestCase
  autoload :TestFixtures, 'active_record/fixtures'
end

ActiveSupport.on_load(:active_record) do
  Arel::Table.engine = self
end

I18n.load_path << File.dirname(__FILE__) + '/active_record/locale/en.yml'
