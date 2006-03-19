min_release  = "1.8.2 (2004-12-25)"
ruby_release = "#{RUBY_VERSION} (#{RUBY_RELEASE_DATE})"
if ruby_release =~ /1\.8\.3/
  abort <<-end_message

    Rails does not work with Ruby version 1.8.3.
    Please upgrade to version 1.8.4 or downgrade to 1.8.2.

  end_message
elsif ruby_release < min_release
  abort <<-end_message

    Rails requires Ruby version #{min_release} or later.
    You're running #{ruby_release}; please upgrade to continue.

  end_message
end
