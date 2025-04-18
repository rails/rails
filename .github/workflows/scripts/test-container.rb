#!/usr/bin/env ruby
# frozen_string_literal: true

# Based on Sam Ruby's system test from dockerfile-rails:
# https://github.com/rubys/dockerfile-rails/pull/21

require "net/http"
require "socket"

LOCALHOST = Socket.gethostname
PORT = 3000

60.times do |i|
  sleep 0.5
  begin
    response = Net::HTTP.get_response(LOCALHOST, "/up", PORT)

    if %w(404 500).include? response.code
      status = response.code.to_i
    end

    puts response.body
    exit status || 0
  rescue SystemCallError, IOError
    puts "#{i}/60 Connection to #{LOCALHOST}:#{PORT} refused or timed out, retrying..."
  end
end

exit 999
