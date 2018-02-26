# frozen_string_literal: true

#--
# Copyright (c) 2004-2018 David Heinemeier Hansson
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

require "active_support"
require "active_support/rails"
require "active_model"
require "arel"
require "yaml"

require "active_record/version"
require "active_model/attribute_set"

module ActiveRecord
  extend ActiveSupport::Autoload

  autoload :Base
  autoload :Callbacks
  autoload :Core
  autoload :ConnectionHandling
  autoload :CounterCache
  autoload :DynamicMatchers
  autoload :Enum
  autoload :InternalMetadata
  autoload :Explain
  autoload :Inheritance
  autoload :Integration
  autoload :Migration
  autoload :Migrator, "active_record/migration"
  autoload :ModelSchema
  autoload :NestedAttributes
  autoload :NoTouching
  autoload :TouchLater
  autoload :Persistence
  autoload :QueryCache
  autoload :Querying
  autoload :CollectionCacheKey
  autoload :ReadonlyAttributes
  autoload :RecordInvalid, "active_record/validations"
  autoload :Reflection
  autoload :RuntimeRegistry
  autoload :Sanitization
  autoload :Schema
  autoload :SchemaDumper
  autoload :SchemaMigration
  autoload :Scoping
  autoload :Serialization
  autoload :StatementCache
  autoload :Store
  autoload :Suppressor
  autoload :Timestamp
  autoload :Transactions
  autoload :Translation
  autoload :Validations
  autoload :SecureToken

  eager_autoload do
    autoload :ActiveRecordError, "active_record/errors"
    autoload :ConnectionNotEstablished, "active_record/errors"
    autoload :ConnectionAdapters, "active_record/connection_adapters/abstract_adapter"

    autoload :Aggregations
    autoload :Associations
    autoload :AttributeAssignment
    autoload :AttributeMethods
    autoload :AttributeMethodsBuilder
    autoload :AutosaveAssociation

    autoload :LegacyYamlAdapter

    autoload :Relation
    autoload :AssociationRelation
    autoload :NullRelation

    autoload_under "relation" do
      autoload :QueryMethods
      autoload :FinderMethods
      autoload :Calculations
      autoload :PredicateBuilder
      autoload :SpawnMethods
      autoload :Batches
      autoload :Delegation
    end

    autoload :Result
    autoload :TableMetadata
    autoload :Type
  end

  module Coders
    autoload :YAMLColumn, "active_record/coders/yaml_column"
    autoload :JSON, "active_record/coders/json"
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
    end
  end

  module Scoping
    extend ActiveSupport::Autoload

    eager_autoload do
      autoload :Named
      autoload :Default
    end
  end

  module Tasks
    extend ActiveSupport::Autoload

    autoload :DatabaseTasks
    autoload :SQLiteDatabaseTasks, "active_record/tasks/sqlite_database_tasks"
    autoload :MySQLDatabaseTasks,  "active_record/tasks/mysql_database_tasks"
    autoload :PostgreSQLDatabaseTasks,
      "active_record/tasks/postgresql_database_tasks"
  end

  autoload :TestDatabases, "active_record/test_databases"
  autoload :TestFixtures, "active_record/fixtures"

  def self.eager_load!
    super
    ActiveRecord::Locking.eager_load!
    ActiveRecord::Scoping.eager_load!
    ActiveRecord::Associations.eager_load!
    ActiveRecord::AttributeMethods.eager_load!
    ActiveRecord::ConnectionAdapters.eager_load!
  end
end

ActiveSupport.on_load(:active_record) do
  Arel::Table.engine = self
end

ActiveSupport.on_load(:i18n) do
  I18n.load_path << File.expand_path("active_record/locale/en.yml", __dir__)
end

YAML.load_tags["!ruby/object:ActiveRecord::AttributeSet"] = "ActiveModel::AttributeSet"
YAML.load_tags["!ruby/object:ActiveRecord::Attribute::FromDatabase"] = "ActiveModel::Attribute::FromDatabase"
YAML.load_tags["!ruby/object:ActiveRecord::LazyAttributeHash"] = "ActiveModel::LazyAttributeHash"
