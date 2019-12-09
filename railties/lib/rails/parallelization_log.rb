# frozen_string_literal: true

require "active_support/testing/parallelization"
require "fileutils"

module ParallelizationLog
  ActiveSupport::Testing::Parallelization.after_fork_hook do |i|
    logfile = Rails.application.config.paths['log'].first
    logfile += "-#{i}"
    f = File.open(logfile, "a")
    f.binmode
    f.sync = true

    Rails.logger.reopen(f)
  end

  ActiveSupport::Testing::Parallelization.run_cleanup_hook do |i|
    main_logfile = Rails.application.config.paths['log'].first
    process_logfile = main_logfile + "-#{i}"

    File.open(main_logfile, 'ab') do |f|
      f.flock(File::LOCK_EX)
      f.write(File.read(process_logfile))
    end
    FileUtils.rm(process_logfile)
  end
end
