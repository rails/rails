#--
# Copyright (c) 2004 David Heinemeier Hansson
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


$:.unshift(File.dirname(__FILE__))

require 'active_record/support/clean_logger'
require 'active_record/support/misc'

require 'active_record/base'
require 'active_record/observer'
require 'active_record/validations'
require 'active_record/callbacks'
require 'active_record/associations'
require 'active_record/aggregations'
require 'active_record/transactions'
require 'active_record/reflection'

ActiveRecord::Base.class_eval do
  include ActiveRecord::Validations
  include ActiveRecord::Callbacks
  include ActiveRecord::Associations
  include ActiveRecord::Aggregations
  include ActiveRecord::Transactions
  include ActiveRecord::Reflection
end

require 'active_record/mixins/list'
require 'active_record/mixins/touch'

require 'active_record/connection_adapters/mysql_adapter'
require 'active_record/connection_adapters/postgresql_adapter'
require 'active_record/connection_adapters/sqlite_adapter'
require 'active_record/connection_adapters/sqlserver_adapter'