# frozen_string_literal: true

# DATS = Deprecated Associations Test Suite.
#
# Minimal models defined ad-hoc for the test suite of deprecated associations.
# They are persisted in exisiting tables for simplicity.
module DATS
  def self.table_name_prefix = ""

  require_relative "dats/author"
  require_relative "dats/author_favorite"
  require_relative "dats/post"
  require_relative "dats/category"
  require_relative "dats/comment"
  require_relative "dats/car"
  require_relative "dats/tire"
  require_relative "dats/bulb"
end
