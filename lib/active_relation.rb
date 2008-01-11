$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'rubygems'
require 'activesupport'
require 'activerecord'

require 'active_relation/sql_builder'

require 'active_relation/relations/base'
require 'active_relation/relations/compound'
require 'active_relation/relations/table'
require 'active_relation/relations/join'
require 'active_relation/relations/attribute'
require 'active_relation/relations/projection'
require 'active_relation/relations/selection'
require 'active_relation/relations/order'
require 'active_relation/relations/range'
require 'active_relation/relations/rename'
require 'active_relation/relations/deletion'
require 'active_relation/relations/insertion'

require 'active_relation/predicates'

require 'active_relation/extensions/object'
require 'active_relation/extensions/array'
require 'active_relation/extensions/base'
require 'active_relation/extensions/hash'