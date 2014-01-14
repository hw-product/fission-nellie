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
          %w(stdout stderr).each do |k|
            p_lock[:process].io.send(k).rewind
            debug "#{k}<#{payload[:data][:process_notification]}>: #{p_lock[:process].io.send(k).read}"
          end
          successful = p_lock[:process].exit_code == 0
          process_manager.unlock(p_lock)
          process_manager.delete(payload[:data][:process_notification])
          if(successful)
            payload[:data].delete(:process_notification)
            forward(payload)
          else
            error "Nellie process failed! Process ID: #{payload[:data][:process_notification]}"
            debug "Payload needs to be transmitted to `:finalizer`"
          end
        end
      end
    end
  end
end

Fission.register(:nellie, :trent, Fission::Nellie::Trent)
