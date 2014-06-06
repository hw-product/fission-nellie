require 'fission/callback'

module Fission
  module Nellie
    # Process cleanup
    class Trent < Callback

      # Validity of message
      #
      # @return [Truthy, Falsey]
      def valid?(message)
        super do |m|
          m.get(:data, :process_notification)
        end
      end

      # Clean up process and forward payload
      #
      # @param message [Carnivore::Message]
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
          payload[:data].delete(:process_notification)
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

    end
  end
end

Fission.register(:nellie, :trent, Fission::Nellie::Trent)
