Project.configure do |project|
  # Send email notifications about broken and fixed builds to core mailing list
  if Socket.gethostname =~ /ci.rubyonrails.org/ && ENV['ENABLE_RAILS_CI_EMAILS'] == 'true'
    project.email_notifier.emails = ['rubyonrails-core@googlegroups.com']
  end

  project.build_command = 'sudo gem update --system && ruby ci/ci_build.rb'
  project.email_notifier.from = 'thewoolleyman@gmail.com'
end
