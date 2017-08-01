# frozen_string_literal: true

require_relative "utils/query_param"

URI::HTTP.class_eval do
  include URI::Utils::QueryParam
end
