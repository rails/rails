require 'active_support/inflector'
require 'active_support/core_ext/module/delegation'
require 'active_support/core_ext/object/blank'

require 'arel/recursion/base_case'

module Arel
  require 'arel/algebra'
  require 'arel/sql_literal'
  require 'arel/engines'
  require 'arel/version'

  autoload :Session, 'arel/session'
end
