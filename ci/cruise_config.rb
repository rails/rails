Project.configure do |project|
  project.build_command = 'sudo gem update --system && ruby ci/ci_build.rb'
  project.email_notifier.from = 'rails-ci@wyeworks.com'

  # project.campfire_notifier.account  = 'rails'
  # project.campfire_notifier.token    = ''
  # project.campfire_notifier.room     = 'Rails 3'
  # project.campfire_notifier.ssl      = true
end
