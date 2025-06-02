# frozen_string_literal: true

# DATS = Deprecated Associations Test Suite.
#
# Minimal models defined ad-hoc for the test suite of deprecated associations.
# They are persisted in exisiting tables for simplicity.
module DATS
  def self.table_name_prefix = ''

  require_relative "dats/car"
  require_relative "dats/tyre"
  require_relative "dats/bulb"
end
