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

require "active_support"
require "active_support/rails"
require "active_job/version"
require "active_job/deprecator"
require "global_id"

# :markup: markdown
# :include: ../README.md
module ActiveJob
  extend ActiveSupport::Autoload

  autoload :Base
  autoload :QueueAdapters
  autoload :Arguments
  autoload :DeserializationError, "active_job/arguments"
  autoload :SerializationError, "active_job/arguments"
  autoload :EnqueueAfterTransactionCommit

  eager_autoload do
    autoload :Serializers
    autoload :ConfiguredJob
  end

  autoload :TestCase
  autoload :TestHelper

  def self.use_big_decimal_serializer
    ActiveJob.deprecator.warn <<-WARNING.squish
      Rails.application.config.active_job.use_big_decimal_serializer is deprecated and will be removed in Rails 8.0.
    WARNING
  end

  def self.use_big_decimal_serializer=(value)
    ActiveJob.deprecator.warn <<-WARNING.squish
      Rails.application.config.active_job.use_big_decimal_serializer is deprecated and will be removed in Rails 8.0.
    WARNING
  end

  ##
  # :singleton-method: verbose_enqueue_logs
  #
  # Specifies if the methods calling background job enqueue should be logged below
  # their relevant enqueue log lines. Defaults to false.
  singleton_class.attr_accessor :verbose_enqueue_logs
  self.verbose_enqueue_logs = false
end
