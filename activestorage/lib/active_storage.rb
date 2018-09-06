# frozen_string_literal: true

#--
# Copyright (c) 2017-2018 David Heinemeier Hansson, Basecamp
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

require "active_record"
require "active_support"
require "active_support/rails"

require "active_storage/version"
require "active_storage/errors"

require "marcel"

module ActiveStorage
  extend ActiveSupport::Autoload

  autoload :Attached
  autoload :Service
  autoload :Previewer
  autoload :Analyzer

  mattr_accessor :logger
  mattr_accessor :verifier
  mattr_accessor :queue
  mattr_accessor :previewers, default: []
  mattr_accessor :analyzers, default: []
  mattr_accessor :paths, default: {}
  mattr_accessor :variable_content_types, default: []
  mattr_accessor :content_types_to_serve_as_binary, default: []
  mattr_accessor :content_types_allowed_inline, default: []
  mattr_accessor :binary_content_type, default: "application/octet-stream"
end
