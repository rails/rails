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

# :include: ../README.rdoc
module ActiveSupport
  extend ActiveSupport::Autoload

  autoload :Concern
  autoload :CodeGenerator
  autoload :ActionableError
  autoload :Configurable
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
  autoload :StructuredEventSubscriber
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
    autoload :ColorizeLogging
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

  def self.eager_load!
    super

    NumberHelper.eager_load!
  end

  singleton_class.attr_accessor :test_order # :nodoc:

  @test_parallelization_threshold = 50
  singleton_class.attr_accessor :test_parallelization_threshold # :nodoc:

  @parallelize_test_databases = true
  singleton_class.attr_accessor :parallelize_test_databases # :nodoc:

  @error_reporter = ActiveSupport::ErrorReporter.new
  singleton_class.attr_accessor :error_reporter # :nodoc:

  @event_reporter = ActiveSupport::EventReporter.new
  singleton_class.attr_accessor :event_reporter # :nodoc:

  cattr_accessor :filter_parameters, default: [] # :nodoc:

  @colorize_logging = true
  singleton_class.attr_accessor :colorize_logging

  def self.cache_format_version
    Cache.format_version
  end

  def self.cache_format_version=(value)
    Cache.format_version = value
  end

  def self.to_time_preserves_timezone
    ActiveSupport.deprecator.warn(
      "`config.active_support.to_time_preserves_timezone` is deprecated and will be removed in Rails 8.2"
    )
    @to_time_preserves_timezone
  end

  def self.to_time_preserves_timezone=(value)
    ActiveSupport.deprecator.warn(
      "`config.active_support.to_time_preserves_timezone` is deprecated and will be removed in Rails 8.2"
    )

    @to_time_preserves_timezone = value
  end

  # Change the output of <tt>ActiveSupport::TimeZone.utc_to_local</tt>.
  #
  # When +true+, it returns local times with a UTC offset, with +false+ local
  # times are returned as UTC.
  #
  #   # Given this zone:
  #   zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
  #
  #   # With `utc_to_local_returns_utc_offset_times = false`, local time is converted to UTC:
  #   zone.utc_to_local(Time.utc(2000, 1)) # => 1999-12-31 19:00:00 UTC
  #
  #   # With `utc_to_local_returns_utc_offset_times = true`, local time is returned with UTC offset:
  #   zone.utc_to_local(Time.utc(2000, 1)) # => 1999-12-31 19:00:00 -0500
  singleton_class.attr_accessor :utc_to_local_returns_utc_offset_times
  @utc_to_local_returns_utc_offset_times = false
end

autoload :I18n, "active_support/i18n"
