#--
# Copyright (c) 2005 David Heinemeier Hansson
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

module ActiveSupport
  class << self
    attr_accessor :load_all_hooks
    def on_load_all(&hook) load_all_hooks << hook end
    def load_all!; load_all_hooks.each { |hook| hook.call } end
  end
  self.load_all_hooks = []

  on_load_all do
    [Dependencies, Deprecation, Gzip, MessageVerifier, Multibyte, SecureRandom]
  end
end

require "active_support/dependencies/autoload"

module ActiveSupport
  extend ActiveSupport::Autoload

  autoload :DescendantsTracker
  autoload :FileUpdateChecker
  autoload :LogSubscriber
  autoload :Notifications

  # TODO: Narrow this list down
  eager_autoload do
    autoload :BacktraceCleaner
    autoload :Base64
    autoload :BasicObject
    autoload :Benchmarkable
    autoload :BufferedLogger
    autoload :Cache
    autoload :Callbacks
    autoload :Concern
    autoload :Configurable
    autoload :Deprecation
    autoload :Gzip
    autoload :Inflector
    autoload :JSON
    autoload :Memoizable
    autoload :MessageEncryptor
    autoload :MessageVerifier
    autoload :Multibyte
    autoload :OptionMerger
    autoload :OrderedHash
    autoload :OrderedOptions
    autoload :Rescuable
    autoload :SecureRandom
    autoload :StringInquirer
    autoload :XmlMini
  end

  autoload :SafeBuffer, "active_support/core_ext/string/output_safety"
  autoload :TestCase
end

autoload :I18n, "active_support/i18n"
