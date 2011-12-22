#--
# Copyright (c) 2004-2011 David Heinemeier Hansson
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

require 'active_support/ruby/shim'
require 'active_support/core_ext/class/attribute_accessors'

require 'action_pack'

module ActionView
  extend ActiveSupport::Autoload

  eager_autoload do
    autoload :AssetPaths
    autoload :Base
    autoload :Context
    autoload :CompiledTemplates, "action_view/context"
    autoload :Helpers
    autoload :LookupContext
    autoload :PathSet
    autoload :Template
    autoload :TestCase

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
      autoload :FileSystemResolver
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
      autoload :TemplateError
      autoload :WrongEncodingError
    end
  end

  ENCODING_FLAG = '#.*coding[:=]\s*(\S+)[ \t]*'
end

require 'active_support/i18n'
require 'active_support/core_ext/string/output_safety'

I18n.load_path << "#{File.dirname(__FILE__)}/action_view/locale/en.yml"
