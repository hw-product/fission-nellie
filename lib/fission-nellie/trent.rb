require 'fission/callback'

module Fission
  module Nellie
    class Trent < Callback

      def valid?(message)
        super do |m|
          m[:data][:process_notification]
        end
      end

      def execute(message)
        failure_wrap(message) do |payload|
          debug "Cleanup of nellie generated process - #{payload[:data][:process_notification]}"
          p_lock = process_manager.lock(payload[:data][:process_notification])
          logs = {}
          %w(stdout stderr).each do |k|
            p_lock[:process].io.send(k).rewind
            logs[k] = p_lock[:process].io.send(k).read
            debug "#{k}<#{payload[:data][:process_notification]}>: #{logs[k]}"
          end
          successful = p_lock[:process].exit_code == 0
          process_manager.unlock(p_lock)
          process_manager.delete(payload[:data][:process_notification])
          if(successful)
            payload.set(:data, :nellie, :status, 'ok')
            forward(payload)
          else
            error "Nellie process failed! Process ID: #{payload[:data][:process_notification]}"
            payload.set(:data, :nellie, :status, 'fail')
            payload.set(:data, :nellie, :logs, logs)
            job_completed('nellie', payload, message)
          end
        end
      end

      # Set payload data for mail type notifications
      # TODO: custom mail address provided via .nellie file?
      def set_failure_email(payload, files={})
        project_name = retrieve(payload, :data, :github, :repository, :name)
        failed_sha = retrieve(payload, :data, :github, :after)
        dest_email = [
          retrieve(payload, :data, :github, :repository, :owner, :email),
          retrieve(payload, :data, :github, :pusher, :email)
        ].compact
        details = retrieve(payload, :data, :github, :compare)
        files = {}.tap do |new_files|
          files.each do |k,v|
            new_files["#{k}.txt"] = v
          end
        end
        notify = {
          :destination => dest_email.map{ |target|
            {:email => target}
          },
          :origin => {
            :email => origin[:email],
            :name => origin[:name]
          },
          :attachments => files
        }
        notify.merge!(
          :subject => "[#{origin[:name]}] FAILED #{project_name} build failure",
          :message => "Build failure encountered on #{project_name} at SHA: #{failed_sha}\nComparision at: #{details}",
          :html => false
        )
        payload[:data][:notification_email] = notify
      end

    end
  end
end

Fission.register(:nellie, :trent, Fission::Nellie::Trent)
