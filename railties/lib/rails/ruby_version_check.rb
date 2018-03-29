if Gem::Version.new(RUBY_VERSION) < Gem::Version.new('2.2.2') && RUBY_ENGINE == 'ruby'
  desc = defined?(RUBY_DESCRIPTION) ? RUBY_DESCRIPTION : "ruby #{RUBY_VERSION} (#{RUBY_RELEASE_DATE})"
  abort <<-end_message

    Rails 5 requires Ruby 2.2.2 or newer.

    You're running
      #{desc}

    Please upgrade to Ruby 2.2.2 or newer to continue.

  end_message
end
