$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'rubygems'
require 'active_support'

require 'sql_algebra/relations/relation'
require 'sql_algebra/relations/table_relation'
require 'sql_algebra/relations/join_operation'
require 'sql_algebra/relations/join_relation'
require 'sql_algebra/relations/attribute'

require 'sql_algebra/relations/predicates/predicate'
require 'sql_algebra/relations/predicates/binary_predicate'
require 'sql_algebra/relations/predicates/equality_predicate'
require 'sql_algebra/relations/predicates/less_than_predicate'
require 'sql_algebra/relations/predicates/less_than_or_equal_to_predicate'
require 'sql_algebra/relations/predicates/greater_than_predicate'
require 'sql_algebra/relations/predicates/greater_than_or_equal_to_predicate'
require 'sql_algebra/relations/predicates/range_inclusion_predicate'
require 'sql_algebra/relations/predicates/relation_inclusion_predicate'
require 'sql_algebra/relations/predicates/match_predicate'

require 'sql_algebra/extensions/range'

require 'sql_algebra/sql/select'