module ActionView 
  module Helpers
    # == THIS IS AN EXPERIMENTAL FEATURE
    #
    # Which means that it doesn't yet work on all systems. We're still working on full
    # compatibility. It's thus not advised to use this unless you've verified it to work
    # fully on all the systems that is a part of your environment. Consider this an extended
    # preview.
    #
    # Provides a set of methods to be used in your views to help with the
    # rendering of Ajax enabled status updating during a multipart upload.
    #
    # The basic mechanism for upload progress is that the form will post to a
    # hidden <iframe> element, then poll a status action that will replace the
    # contents of a status container.  Client Javascript hooks are provided for
    # +begin+ and +finish+ of the update.
    #
    # If you wish to have a DTD that will validate this page, use XHTML
    # Transitional because this DTD supports the <iframe> element.
    #
    # == Typical usage
    #
    # In your upload view:
    #
    #   <%= form_tag_with_upload_progress({ :action => 'create' }) %>
    #     <%= file_field "document", "file" %>
    #     <%= submit_tag "Upload" %>
    #     <%= upload_status_tag %>
    #   <%= end_form_tag %>
    #
    # In your controller:
    #
    #   class DocumentController < ApplicationController   
    #     upload_status_for  :create
    #     
    #     def create
    #       # ... Your document creation action
    #     end
    #   end
    #   
    # == Javascript callback on begin and finished
    #
    # In your upload view:
    #
    #   <%= form_tag_with_upload_progress({ :action => 'create' }, {
    #       :begin => "alert('upload beginning'), 
    #       :finish => "alert('upload finished')}) %>
    #     <%= file_field "document", "file" %>
    #     <%= submit_tag "Upload" %>
    #     <%= upload_status_tag %>
    #   <%= end_form_tag %>
    #
    #
    # == CSS Styling of the status text and progress bar
    #
    # See +upload_status_text_tag+ and +upload_status_progress_bar_tag+ for references
    # of the IDs and CSS classes used.
    #
    # Default styling is included with the scaffolding CSS.
    module UploadProgressHelper
      unless const_defined? :FREQUENCY
        # Default number of seconds between client updates
        FREQUENCY = 2.0 

        # Factor to decrease the frequency when the +upload_status+ action returns the same results
        # To disable update decay, set this constant to +false+
        FREQUENCY_DECAY = 1.8
      end
      
      # Contains a hash of status messages used for localization of
      # +upload_progress_status+ and +upload_progress_text+.  Each string is
      # evaluated in the helper method context so you can include your own 
      # calculations and string iterpolations.
      #
      # The following keys are defined:
      #
      # <tt>:begin</tt>::      Displayed before the first byte is received on the server
      # <tt>:update</tt>::     Contains a human representation of the upload progress
      # <tt>:finish</tt>::     Displayed when the file upload is complete, before the action has completed.  If you are performing extra activity in your action such as processing of the upload, then inform the user of what you are doing by setting +upload_progress.message+
      #
      @@default_messages = {
        :begin => '"Upload starting..."',
        :update => '"#{human_size(upload_progress.received_bytes)} of #{human_size(upload_progress.total_bytes)} at #{human_size(upload_progress.bitrate)}/s; #{distance_of_time_in_words(0,upload_progress.remaining_seconds,true)} remaining"',
        :finish => 'upload_progress.message.blank? ? "Upload finished." : upload_progress.message',
      }


      # Creates a form tag and hidden <iframe> necessary for the upload progress
      # status messages to be displayed in a designated +div+ on your page.
      #
      # == Initializations
      #
      # When the upload starts, the content created by +upload_status_tag+ will be filled out with
      # "Upload starting...".  When the upload is finished, "Upload finished." will be used.  Every
      # update inbetween the begin and finish events will be determined by the server +upload_status+
      # action.  Doing this automatically means that the user can use the same form to upload multiple
      # files without refreshing page while still displaying a reasonable progress.
      #
      # == Upload IDs
      #
      # For the view and the controller to know about the same upload they must share
      # a common +upload_id+.  +form_tag_with_upload_progress+ prepares the next available 
      # +upload_id+ when called.  There are other methods which use the +upload_id+ so the 
      # order in which you include your content is important.  Any content that depends on the 
      # +upload_id+ will use the one defined +form_tag_with_upload_progress+
      # otherwise you will need to explicitly declare the +upload_id+ shared among
      # your progress elements.
      #
      # Status container after the form:
      #
      #   <%= form_tag_with_upload_progress %>
      #   <%= end_form_tag %>
      #
      #   <%= upload_status_tag %>
      #
      # Status container before form:
      #
      #   <% my_upload_id = next_upload_id %>
      #
      #   <%= upload_status_tag %>
      #
      #   <%= form_tag_with_upload_progress :upload_id => my_upload_id %>
      #   <%= end_form_tag %>
      #
      # It is recommended that the helpers manage the +upload_id+ parameter.
      #
      # == Options
      #
      # +form_tag_with_upload_progress+ uses similar options as +form_tag+
      # yet accepts another hash for the options used for the +upload_status+ action.
      #
      # <tt>url_for_options</tt>:: The same options used by +form_tag+ including:
      # <tt>:upload_id</tt>:: the upload id used to uniquely identify this upload
      #
      # <tt>options</tt>:: similar options to +form_tag+ including:
      # <tt>:begin</tt>::   Javascript code that executes before the first status update occurs.
      # <tt>:finish</tt>::  Javascript code that executes after the action that receives the post returns.
      # <tt>:frequency</tt>:: number of seconds between polls to the upload status action.
      #
      # <tt>status_url_for_options</tt>:: options passed to +url_for+ to build the url
      # for the upload status action.
      # <tt>:controller</tt>::  defines the controller to be used for a custom update status action
      # <tt>:action</tt>::      defines the action to be used for a custom update status action
      #
      # Parameters passed to the action defined by status_url_for_options
      #
      # <tt>:upload_id</tt>::   the upload_id automatically generated by +form_tag_with_upload_progress+ or the user defined id passed to this method.
      #   
      def form_tag_with_upload_progress(url_for_options = {}, options = {}, status_url_for_options = {}, *parameters_for_url_method)
        
        ## Setup the action URL and the server-side upload_status action for
        ## polling of status during the upload

        options = options.dup

        upload_id = url_for_options.delete(:upload_id) || next_upload_id
        upload_action_url = url_for(url_for_options)

        if status_url_for_options.is_a? Hash
          status_url_for_options = status_url_for_options.merge({
            :action => 'upload_status', 
            :upload_id => upload_id})
        end

        status_url = url_for(status_url_for_options)
        
        ## Prepare the form options.  Dynamically change the target and URL to enable the status
        ## updating only if javascript is enabled, otherwise perform the form submission in the same 
        ## frame.
        
        upload_target = options[:target] || upload_target_id
        upload_id_param = "#{upload_action_url.include?('?') ? '&' : '?'}upload_id=#{upload_id}"
        
        ## Externally :begin and :finish are the entry and exit points
        ## Internally, :finish is called :complete

        js_options = {
          :decay => options[:decay] || FREQUENCY_DECAY,
          :frequency => options[:frequency] || FREQUENCY,
        }

        updater_options = '{' + js_options.map {|k, v| "#{k}:#{v}"}.sort.join(',') + '}'

        ## Finish off the updating by forcing the progress bar to 100% and status text because the
        ## results of the post may load and finish in the IFRAME before the last status update
        ## is loaded. 

        options[:complete] = "$('#{status_tag_id}').innerHTML='#{escape_javascript upload_progress_text(:finish)}';"
        options[:complete] << "#{upload_progress_update_bar_js(100)};"
        options[:complete] << "#{upload_update_object} = null"
        options[:complete] = "#{options[:complete]}; #{options[:finish]}" if options[:finish]

        options[:script] = true

        ## Prepare the periodic updater, clearing any previous updater

        updater = "if (#{upload_update_object}) { #{upload_update_object}.stop(); }"
        updater << "#{upload_update_object} = new Ajax.PeriodicalUpdater('#{status_tag_id}',"
        updater << "'#{status_url}', Object.extend(#{options_for_ajax(options)},#{updater_options}))"

        updater = "#{options[:begin]}; #{updater}" if options[:begin]
        updater = "#{upload_progress_update_bar_js(0)}; #{updater}"
        updater = "$('#{status_tag_id}').innerHTML='#{escape_javascript upload_progress_text(:begin)}'; #{updater}"
        
        ## Touch up the form action and target to use the given target instead of the
        ## default one. Then start the updater

        options[:onsubmit] = "if (this.action.indexOf('upload_id') < 0){ this.action += '#{escape_javascript upload_id_param}'; }"
        options[:onsubmit] << "this.target = '#{escape_javascript upload_target}';"
        options[:onsubmit] << "#{updater}; return true" 
        options[:multipart] = true

        [:begin, :finish, :complete, :frequency, :decay, :script].each { |sym| options.delete(sym) }

        ## Create the tags
        ## If a target for the form is given then avoid creating the hidden IFRAME

        tag = form_tag(upload_action_url, options, *parameters_for_url_method)

        unless options[:target]
          tag << content_tag('iframe', '', { 
            :id => upload_target, 
            :name => upload_target,
            :src => '',
            :style => 'width:0px;height:0px;border:0' 
          })
        end

        tag
      end

      # This method must be called by the action that receives the form post
      # with the +upload_progress+.  By default this method is rendered when
      # the controller declares that the action is the receiver of a 
      # +form_tag_with_upload_progress+ posting.
      #
      # This template will do a javascript redirect to the URL specified in +redirect_to+
      # if this method is called anywhere in the controller action.  When the action
      # performs a redirect, the +finish+ handler will not be called.
      #
      # If there are errors in the action then you should set the controller 
      # instance variable +@errors+.  The +@errors+ object will be
      # converted to a javascript array from +@errors.full_messages+ and
      # passed to the +finish+ handler of +form_tag_with_upload_progress+
      #
      # If no errors have occured, the parameter to the +finish+ handler will
      # be +undefined+.
      #
      # == Example (in view)
      #
      #  <script>
      #   function do_finish(errors) {
      #     if (errors) {
      #       alert(errors);
      #     }
      #   }
      #  </script>
      #
      #  <%= form_tag_with_upload_progress {:action => 'create'}, {finish => 'do_finish(arguments[0])'} %>
      #
      def finish_upload_status(options = {})
        # Always trigger the stop/finish callback
        js = "parent.#{upload_update_object}.stop(#{options[:client_js_argument]});\n"

        # Redirect if redirect_to was called in controller
        js << "parent.location.replace('#{escape_javascript options[:redirect_to]}');\n" unless options[:redirect_to].blank?

        # Guard against multiple triggers/redirects on back
        js = "if (parent.#{upload_update_object}) { #{js} }\n"
        
        content_tag("html", 
          content_tag("head", 
            content_tag("script", "function finish() { #{js} }", 
              {:type => "text/javascript", :language => "javascript"})) + 
          content_tag("body", '', :onload => 'finish()'))
      end

      # Renders the HTML to contain the upload progress bar above the 
      # default messages
      #
      # Use this method to display the upload status after your +form_tag_with_upload_progress+
      def upload_status_tag(content='', options={})
        upload_status_progress_bar_tag + upload_status_text_tag(content, options)
      end

      # Content helper that will create a +div+ with the proper ID and class that
      # will contain the contents returned by the +upload_status+ action.  The container
      # is defined as
      #
      #   <div id="#{status_tag_id}" class="uploadStatus"> </div>
      #
      # Style this container by selecting the +.uploadStatus+ +CSS+ class.
      #
      # The +content+ parameter will be included in the inner most +div+ when 
      # rendered.
      #
      # The +options+ will create attributes on the outer most div.  To use a different
      # +CSS+ class, pass a different class option.
      #
      # Example +CSS+:
      #   .uploadStatus { font-size: 10px; color: grey; }
      #
      def upload_status_text_tag(content=nil, options={})
        content_tag("div", content, {:id => status_tag_id, :class => 'uploadStatus'}.merge(options))
      end

      # Content helper that will create the element tree that can be easily styled
      # with +CSS+ to create a progress bar effect.  The containers are defined as:
      #
      #   <div class="progressBar" id="#{progress_bar_id}">
      #     <div class="border">
      #       <div class="background">
      #         <div class="content"> </div>
      #       </div>
      #     </div>
      #   </div>
      # 
      # The +content+ parameter will be included in the inner most +div+ when 
      # rendered.
      #
      # The +options+ will create attributes on the outer most div.  To use a different
      # +CSS+ class, pass a different class option.
      #
      # Example:
      #   <%= upload_status_progress_bar_tag('', {:class => 'progress'}) %>
      #
      # Example +CSS+:
      #
      #   div.progressBar {
      #     margin: 5px;
      #   }
      #
      #   div.progressBar div.border {
      #     background-color: #fff;
      #     border: 1px solid grey;
      #     width: 100%;
      #   }
      #
      #   div.progressBar div.background {
      #     background-color: #333;
      #     height: 18px;
      #     width: 0%;
      #   }
      #
      def upload_status_progress_bar_tag(content='', options={})
        css = [options[:class], 'progressBar'].compact.join(' ')

        content_tag("div", 
          content_tag("div", 
            content_tag("div", 
              content_tag("div", content, :class => 'foreground'),
            :class => 'background'), 
          :class => 'border'), 
        {:id => progress_bar_id}.merge(options).merge({:class => css}))
      end

      # The text and Javascript returned by the default +upload_status+ controller
      # action which will replace the contents of the div created by +upload_status_text_tag+
      # and grow the progress bar background to the appropriate width.
      #
      # See +upload_progress_text+ and +upload_progress_update_bar_js+
      def upload_progress_status
        "#{upload_progress_text}<script>#{upload_progress_update_bar_js}</script>"
      end
      
      # Javascript helper that will create a script that will change the width
      # of the background progress bar container.  Include this in the script
      # portion of your view rendered by your +upload_status+ action to
      # automatically find and update the progress bar.
      #
      # Example (in controller):
      #
      #   def upload_status
      #     render :inline => "<script><%= update_upload_progress_bar_js %></script>", :layout => false
      #   end
      #
      #
      def upload_progress_update_bar_js(percent=nil)
        progress = upload_progress
        percent ||= case 
          when progress.nil? || !progress.started? then 0
          when progress.finished? then 100
          else progress.completed_percent
        end.to_i

        # TODO do animation instead of jumping
        "if($('#{progress_bar_id}')){$('#{progress_bar_id}').firstChild.firstChild.style.width='#{percent}%'}"
      end
      
      # Generates a nicely formatted string of current upload progress for
      # +UploadProgress::Progress+ object +progress+.  Addtionally, it
      # will return "Upload starting..." if progress has not been initialized,
      # "Receiving data..." if there is no received data yet, and "Upload
      # finished" when all data has been sent.
      #
      # You can overload this method to add you own output to the
      #
      # Example return: 223.5 KB of 1.5 MB at 321.2 KB/s; less than 10 seconds
      # remaining
      def upload_progress_text(state=nil)
        eval case 
          when state then @@default_messages[state.to_sym]
          when upload_progress.nil? || !upload_progress.started? then @@default_messages[:begin]
          when upload_progress.finished? then @@default_messages[:finish]
          else @@default_messages[:update]
        end 
      end

      protected
      # Javascript object used to contain the polling methods and keep track of
      # the finished state
      def upload_update_object
        "document.uploadStatus#{current_upload_id}"
      end

      # Element ID of the progress bar
      def progress_bar_id
        "UploadProgressBar#{current_upload_id}"
      end

      # Element ID of the progress status container
      def status_tag_id
        "UploadStatus#{current_upload_id}"
      end

      # Element ID of the target <iframe> used as the target of the form
      def upload_target_id
        "UploadTarget#{current_upload_id}"
      end

    end
  end
end
