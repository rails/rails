# frozen_string_literal: true

#--
# Copyright (c) David Heinemeier Hansson
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

require "securerandom"
require "active_support/dependencies/autoload"
require "active_support/version"
require "active_support/deprecator"
require "active_support/logger"
require "active_support/broadcast_logger"
require "active_support/lazy_load_hooks"
require "active_support/core_ext/date_and_time/compatibility"

# :include: ../README.rdoc
module ActiveSupport
  extend ActiveSupport::Autoload

  autoload :Concern
  autoload :CodeGenerator
  autoload :ActionableError
  autoload :ConfigurationFile
  autoload :ContinuousIntegration
  autoload :CurrentAttributes
  autoload :Dependencies
  autoload :DescendantsTracker
  autoload :Editor
  autoload :ExecutionWrapper
  autoload :Executor
  autoload :ErrorReporter
  autoload :EventReporter
  autoload :FileUpdateChecker
  autoload :EventedFileUpdateChecker
  autoload :ForkTracker
  autoload :LogSubscriber
  autoload :IsolatedExecutionState
  autoload :Notifications
  autoload :Reloader
  autoload :SecureCompareRotator

  eager_autoload do
    autoload :BacktraceCleaner
    autoload :Benchmark
    autoload :Benchmarkable
    autoload :Cache
    autoload :Callbacks
    autoload :Configurable
    autoload :ClassAttribute
    autoload :Deprecation
    autoload :Delegation
    autoload :Digest
    autoload :ExecutionContext
    autoload :Gzip
    autoload :Inflector
    autoload :JSON
    autoload :KeyGenerator
    autoload :MessageEncryptor
    autoload :MessageEncryptors
    autoload :MessageVerifier
    autoload :MessageVerifiers
    autoload :Multibyte
    autoload :NumberHelper
    autoload :OptionMerger
    autoload :OrderedHash
    autoload :OrderedOptions
    autoload :StringInquirer
    autoload :EnvironmentInquirer
    autoload :TaggedLogging
    autoload :XmlMini
    autoload :ArrayInquirer
  end

  autoload :Rescuable
  autoload :SafeBuffer, "active_support/core_ext/string/output_safety"
  autoload :TestCase

  include Deprecation::DeprecatedConstantAccessor

  deprecate_constant :Configurable, "class_attribute :config, default: {}", deprecator: ActiveSupport.deprecator

  def self.eager_load!
    super

    NumberHelper.eager_load!
  end

  cattr_accessor :test_order # :nodoc:
  cattr_accessor :test_parallelization_threshold, default: 50 # :nodoc:
  cattr_accessor :parallelize_test_databases, default: true # :nodoc:

  @error_reporter = ActiveSupport::ErrorReporter.new
  singleton_class.attr_accessor :error_reporter # :nodoc:

  @event_reporter = ActiveSupport::EventReporter.new
  singleton_class.attr_accessor :event_reporter # :nodoc:

  cattr_accessor :filter_parameters, default: [] # :nodoc:

  def self.cache_format_version
    Cache.format_version
  end

  def self.cache_format_version=(value)
    Cache.format_version = value
  end

  def self.to_time_preserves_timezone
    DateAndTime::Compatibility.preserve_timezone
  end

  def self.to_time_preserves_timezone=(value)
    if !value
      ActiveSupport.deprecator.warn(
        "`to_time` will always preserve the receiver timezone rather than system local time in Rails 8.1. " \
        "To opt in to the new behavior, set `config.active_support.to_time_preserves_timezone = :zone`."
      )
    elsif value != :zone
      ActiveSupport.deprecator.warn(
        "`to_time` will always preserve the full timezone rather than offset of the receiver in Rails 8.1. " \
        "To opt in to the new behavior, set `config.active_support.to_time_preserves_timezone = :zone`."
      )
    end

    DateAndTime::Compatibility.preserve_timezone = value
  end

  def self.utc_to_local_returns_utc_offset_times
    DateAndTime::Compatibility.utc_to_local_returns_utc_offset_times
  end

  def self.utc_to_local_returns_utc_offset_times=(value)
    DateAndTime::Compatibility.utc_to_local_returns_utc_offset_times = value
  end
end

autoload :I18n, "active_support/i18n"
