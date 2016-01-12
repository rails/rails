module ActiveJob
  class ArgumentsFilter
    def initialize(job)
      @job = job
      @arguments = job.arguments
    end

    def filtered_arguments
      return formatted_arguments.join(', ') if ActiveJob::Base.log_all_arguments

      if action_mailer_job?
        return (formatted_arguments[0..2] + global_id_args).join(', ')
      end

      global_id_args.join(', ')
    end

    private

    def formatted_arguments
      @arguments.flat_map { |arg| format(arg) }
    end

    def format(arg)
      case arg
      when Hash
        arg.transform_values { |value| format(value) }
      when Array
        arg.map { |value| format(value) }
      when GlobalID::Identification
        arg.to_global_id.to_s rescue arg.inspect
      else
        arg.inspect
      end
    end

    def action_mailer_job?
      @job.class.name == 'ActionMailer::DeliveryJob'
    end

    def global_id_args
      formatted_arguments.select { |arg| arg.include?('gid://') }
    end
  end
end
