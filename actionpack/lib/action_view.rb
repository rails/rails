#--
# Copyright (c) 2004-2010 David Heinemeier Hansson
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

module ActionView
  def self.load_all!
    [Base, InlineTemplate, TemplateError]
  end

  autoload :Base, 'action_view/base'
  autoload :Helpers, 'action_view/helpers'
  autoload :InlineTemplate, 'action_view/inline_template'
  autoload :Partials, 'action_view/partials'
  autoload :PathSet, 'action_view/paths'
  autoload :Renderable, 'action_view/renderable'
  autoload :RenderablePartial, 'action_view/renderable_partial'
  autoload :Template, 'action_view/template'
  autoload :ReloadableTemplate, 'action_view/reloadable_template'
  autoload :TemplateError, 'action_view/template_error'
  autoload :TemplateHandler, 'action_view/template_handler'
  autoload :TemplateHandlers, 'action_view/template_handlers'
  autoload :Helpers, 'action_view/helpers'
end

require 'active_support/core_ext/string/output_safety'


I18n.load_path << "#{File.dirname(__FILE__)}/action_view/locale/en.yml"
