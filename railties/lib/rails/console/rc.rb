if File.exists?(console_rc = File.join(Rails.root, "config/console_rc.rb"))
  puts "Loading config/console_rb.rc"
  require console_rc
end