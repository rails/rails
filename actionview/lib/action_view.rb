#--
# Copyright (c) 2004-2014 David Heinemeier Hansson
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

require 'active_support'
require 'active_support/rails'
require 'action_view/version'

module ActionView
  extend ActiveSupport::Autoload

  ENCODING_FLAG = '#.*coding[:=]\s*(\S+)[ \t]*'

  eager_autoload do
    autoload :Base
    autoload :Context
    autoload :CompiledTemplates, "action_view/context"
    autoload :Digestor
    autoload :Helpers
    autoload :LookupContext
    autoload :Layouts
    autoload :PathSet
    autoload :RecordIdentifier
    autoload :Rendering
    autoload :RoutingUrlFor
    autoload :Template
    autoload :ViewPaths

    autoload_under "renderer" do
      autoload :Renderer
      autoload :AbstractRenderer
      autoload :PartialRenderer
      autoload :TemplateRenderer
      autoload :StreamingTemplateRenderer
    end

    autoload_at "action_view/template/resolver" do
      autoload :Resolver
      autoload :PathResolver
      autoload :OptimizedFileSystemResolver
      autoload :FallbackFileSystemResolver
    end

    autoload_at "action_view/buffers" do
      autoload :OutputBuffer
      autoload :StreamingBuffer
    end

    autoload_at "action_view/flows" do
      autoload :OutputFlow
      autoload :StreamingFlow
    end

    autoload_at "action_view/template/error" do
      autoload :MissingTemplate
      autoload :ActionViewError
      autoload :EncodingError
      autoload :MissingRequestError
      autoload :TemplateError
      autoload :WrongEncodingError
    end
  end

  autoload :TestCase

  def self.eager_load!
    super
    ActionView::Helpers.eager_load!
    ActionView::Template.eager_load!
  end
end

require 'active_support/core_ext/string/output_safety'

ActiveSupport.on_load(:i18n) do
  I18n.load_path << "#{File.dirname(__FILE__)}/action_view/locale/en.yml"
end
