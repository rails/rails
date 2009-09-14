require 'active_record'
require 'active_record/connection_adapters/abstract/quoting'

$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'arel/algebra'
require 'arel/engines'
require 'arel/session'
