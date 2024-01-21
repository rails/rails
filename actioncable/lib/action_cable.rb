# frozen_string_literal: true

#--
# Copyright (c) 37signals LLC
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
require "zeitwerk"

Zeitwerk::Loader.for_gem.tap do |loader|
  loader.ignore(
    "#{__dir__}/rails", # Contains generators, templates, docs, etc.
    "#{__dir__}/action_cable/gem_version.rb",
    "#{__dir__}/action_cable/deprecator.rb",
  )

  loader.do_not_eager_load(
    "#{__dir__}/action_cable/subscription_adapter", # Adapters are required and loaded on demand.
    "#{__dir__}/action_cable/test_helper.rb",
    Dir["#{__dir__}/action_cable/**/test_case.rb"]
  )

  loader.inflector.inflect("postgresql" => "PostgreSQL")
end.setup

# :markup: markdown
# :include: ../README.md
module ActionCable
  require_relative "action_cable/version"
  require_relative "action_cable/deprecator"

  INTERNAL = {
    message_types: {
      welcome: "welcome",
      disconnect: "disconnect",
      ping: "ping",
      confirmation: "confirm_subscription",
      rejection: "reject_subscription"
    },
    disconnect_reasons: {
      unauthorized: "unauthorized",
      invalid_request: "invalid_request",
      server_restart: "server_restart",
      remote: "remote"
    },
    default_mount_path: "/cable",
    protocols: ["actioncable-v1-json", "actioncable-unsupported"].freeze
  }

  # Singleton instance of the server
  module_function def server
    @server ||= ActionCable::Server::Base.new
  end
end
