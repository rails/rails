# frozen_string_literal: true

require_relative "../../tools/strict_warnings"

$LOAD_PATH.unshift File.expand_path("..", __dir__)

require "rails_guides"

require "minitest/autorun"
Minitest.load :rails if Minitest.respond_to? :load
