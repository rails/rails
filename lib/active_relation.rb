$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'rubygems'
require 'activesupport'
require 'activerecord'

require 'active_relation/sql_builder'

require 'active_relation/relations/relation'
require 'active_relation/relations/compound_relation'
require 'active_relation/relations/table_relation'
require 'active_relation/relations/join_relation'
require 'active_relation/relations/attribute'
require 'active_relation/relations/projection_relation'
require 'active_relation/relations/selection_relation'
require 'active_relation/relations/order_relation'
require 'active_relation/relations/range_relation'
require 'active_relation/relations/rename_relation'
require 'active_relation/relations/deletion_relation'
require 'active_relation/relations/insertion_relation'

require 'active_relation/predicates'

require 'active_relation/extensions/object'
require 'active_relation/extensions/array'
require 'active_relation/extensions/base'
require 'active_relation/extensions/hash'