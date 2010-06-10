min_release  = "1.8.7"
ruby_release = "#{RUBY_VERSION} (#{RUBY_RELEASE_DATE})"
if ruby_release < min_release
  abort <<-end_message

    Rails requires Ruby version #{min_release} or later.
    You're running #{ruby_release}; please upgrade to continue.

  end_message
elsif RUBY_VERSION == '1.9.1'
  abort <<-EOS
  
    Rails 3 does not work with Ruby 1.9.1. Please upgrade to 1.9.2.

  EOS
end
