#--
# Copyright (c) 2004-2008 David Heinemeier Hansson
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

require 'action_view/template_handlers'
require 'action_view/renderable'
require 'action_view/renderable_partial'

require 'action_view/template'
require 'action_view/inline_template'
require 'action_view/paths'

require 'action_view/base'
require 'action_view/partials'
require 'action_view/template_error'

I18n.load_path << "#{File.dirname(__FILE__)}/action_view/locale/en-US.yml"

require 'action_view/helpers'

ActionView::Base.class_eval do
  include ActionView::Partials
  include ActionView::Helpers
end
