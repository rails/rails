#--
# Copyright (c) 2004 Jeremy Kemper
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

railties = File.expand_path("..", __FILE__)
$:.unshift(railties) unless $:.include?(railties)

activesupport = File.expand_path("../../../activesupport/lib", __FILE__)
$:.unshift(activesupport) unless $:.include?(activesupport)

begin
  require 'active_support'  
rescue LoadError
  require 'rubygems'
  gem 'activesupport'
end

require 'rails_generator/base'
require 'rails_generator/lookup'
require 'rails_generator/commands'

Rails::Generator::Base.send(:include, Rails::Generator::Lookup)
Rails::Generator::Base.send(:include, Rails::Generator::Commands)

# Set up a default logger for convenience.
require 'rails_generator/simple_logger'
Rails::Generator::Base.logger = Rails::Generator::SimpleLogger.new(STDOUT)
