Project.configure do |project|
 project.build_command = 'ruby ci/ci_build.rb'
 project.email_notifier.emails = ['thewoolleyman@gmail.com','michael@koziarski.com']
 project.email_notifier.from = 'thewoolleyman+railsci@gmail.com'
end
