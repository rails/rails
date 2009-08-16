Project.configure do |project|
 project.build_command = 'ruby ci/ci_build.rb'
 project.email_notifier.emails = ['rubyonrails-core@googlegroups.com', 'thewoolleyman@gmail.com','michael@koziarski.com', 'david@loudthinking.com', 'jeremy@bitsweat.net', 'josh@joshpeek.com', 'pratiknaik@gmail.com', 'wycats@gmail.com']
 project.email_notifier.from = 'thewoolleyman+railsci@gmail.com'
end
