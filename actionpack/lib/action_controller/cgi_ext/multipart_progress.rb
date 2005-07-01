# == Overview
#
# This module will extend the CGI module with methods to track the upload
# progress for multipart forms for use with progress meters.  The progress is
# saved in the session to be used from any request from any server with the
# same session.  In other words, this module will work across application
# instances.
#
# === Usage
#
# Just do your file-uploads as you normally would, but include an upload_id in
# the query string of your form action.  Your form post action should look
# like:
#
#   <form method="post" enctype="multipart/form-data" action="postaction?upload_id=SOMEIDYOUSET">
#     <input type="file" name="client_file"/>
#   </form>
#
# Query the upload state in a progress by reading the progress from the session
#
#   class UploadController < ApplicationController
#     def upload_status
#       render :text => "Percent complete: " + @session[:uploads]['SOMEIDYOUSET'].completed_percent"
#     end
#   end
#
# === Session options
#
# Upload progress uses the session options defined in 
# ActionController::CgiRequest::DEFAULT_SESSION_OPTIONS.  If you are passing
# custom session options to your dispatcher then please follow the
# "recommended way to change session options":http://wiki.rubyonrails.com/rails/show/HowtoChangeSessionOptions
#
# === Update frequency
#
# During an upload, the progress will be written to the session every 2
# seconds.  This prevents excessive writes yet maintains a decent picture of
# the upload progress for larger files.  
#
# User interfaces that update more often that every 2 seconds will display the same results.
# Consider this update frequency when designing your progress polling.
#

require 'cgi'

# For integration with ActionPack
require 'action_controller/base'
require 'action_controller/cgi_process'
require 'action_controller/upload_progress'

class CGI #:nodoc:
  class ProgressIO < SimpleDelegator #:nodoc:
    MIN_SAVE_INTERVAL = 1.0         # Number of seconds between session saves

    attr_reader :progress, :session

    def initialize(orig_io, progress, session)
      @session = session
      @progress = progress
      
      @start_time = Time.now
      @last_save_time = @start_time
      save_progress
      
      super(orig_io)
    end

    def read(*args)
      data = __getobj__.read(*args)

      if data and data.size > 0
        now = Time.now
        elapsed =  now - @start_time
        progress.update!(data.size, elapsed)

        if now - @last_save_time > MIN_SAVE_INTERVAL
          save_progress 
          @last_save_time = now 
        end
      else
        ActionController::Base.logger.debug("CGI::ProgressIO#read returns nothing when it should return nil if IO is finished: [#{args.inspect}], a cancelled upload or old FCGI bindings.  Resetting the upload progress")

        progress.reset!
        save_progress
      end

      data
    end

    def save_progress
      @session.update 
    end

    def finish
      @session.update
      ActionController::Base.logger.debug("Finished processing multipart upload in #{@progress.elapsed_seconds.to_s}s")
    end
  end

  module QueryExtension #:nodoc:
    # Need to do lazy aliasing on the instance that we are extending because of the way QueryExtension
    # gets included for each instance of the CGI object rather than on a module level.  This method is a 
    # bit obtrusive because we are overriding CGI::QueryExtension::extended which could be used in the 
    # future.  Need to research a better method
    def self.extended(obj)
      obj.instance_eval do
        # unless defined? will prevent clobbering the progress IO on multiple extensions
        alias :stdinput_without_progress :stdinput unless defined? stdinput_without_progress
        alias :stdinput :stdinput_with_progress 
      end
    end

    def stdinput_with_progress
      @stdin_with_progress or stdinput_without_progress
    end

    private
    # Bootstrapped on ActionController::UploadProgress::upload_status_for
    def read_multipart_with_progress(boundary, content_length)
      begin
        begin
          # Session disabled if the default session options have been set to 'false'
          options = ActionController::CgiRequest::DEFAULT_SESSION_OPTIONS
          raise RuntimeError.new("Multipart upload progress disabled, no session options") unless options

          options = options.stringify_keys
       
          # Pull in the application controller to satisfy any dependencies on class definitions
          # of instances stored in the session.
          Controllers.const_load!(:ApplicationController, "application") unless Controllers.const_defined?(:ApplicationController)

          # Assumes that @cookies has already been setup
          # Raises nomethod if upload_id is not defined
          @params = CGI::parse(read_params_from_query)
          upload_id = @params[(options['upload_key'] || 'upload_id')].first
          raise RuntimeError.new("Multipart upload progress disabled, no upload id in query string") unless upload_id

          upload_progress = ActionController::UploadProgress::Progress.new(content_length)

          session = Session.new(self, options)
          session[:uploads] = {} unless session[:uploads]
          session[:uploads].delete(upload_id) # in case the same upload id is used twice
          session[:uploads][upload_id] = upload_progress

          @stdin_with_progress = CGI::ProgressIO.new(stdinput_without_progress, upload_progress, session)
          ActionController::Base.logger.debug("Multipart upload with progress (id: #{upload_id}, size: #{content_length})")
        rescue
          ActionController::Base.logger.debug("Exception during setup of read_multipart_with_progress: #{$!}")
        end
      ensure
        begin
          params = read_multipart_without_progress(boundary, content_length)
          @stdin_with_progress.finish if @stdin_with_progress.respond_to? :finish
        ensure
          @stdin_with_progress = nil
          session.close if session
        end
      end
      params 
    end

    # Prevent redefinition of aliases on multiple includes
    unless private_instance_methods.include?("read_multipart_without_progress")
      alias_method :read_multipart_without_progress, :read_multipart 
      alias_method :read_multipart, :read_multipart_with_progress
    end

  end
end
