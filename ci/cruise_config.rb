Project.configure do |project|
  # Send email notifications about broken and fixed builds to core mailing list
  if Socket.gethostname =~ /ci.rubyonrails.org/
    project.email_notifier.emails = ['rubyonrails-core@googlegroups.com']
  end

  project.build_command = 'sudo update_rubygems && ruby ci/ci_build.rb'
  project.email_notifier.from = 'thewoolleyman+railsci@gmail.com'
end
