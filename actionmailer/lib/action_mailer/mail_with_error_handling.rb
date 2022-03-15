# frozen_string_literal: true

begin
  require "mail"
rescue LoadError => error
  if error.message.match?(/net\/smtp/)
    $stderr.puts "You don't have net-smtp installed in your application. Please add it to your Gemfile and run bundle install"
    raise
  end
end
