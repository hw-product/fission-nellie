require 'fission/callback'

module Fission
  module Nellie
    class Trent < Callback

      def valid?(message)
        m = unpack(message)
        m[:process_notification]
      end

      def execute(message)
        payload = unpack(message)
        debug "Cleanup of nellie generated process - #{payload[:process_notification]}"
        p_lock = process_manager.lock(payload[:process_notification])
        %w(stdout stderr).each do |k|
          p_lock[:process].io.send(k).rewind
          debug "#{k}<#{payload[:process_notification]}>: #{p_lock[:process].io.send(k).read}"
        end
        successful = p_lock[:process].crashed?
        process_manager.unlock(p_lock)
        process_manager.delete(payload[:process_notification])
        if(successful)
          if(payload[:nellie_commands] && !payload[:nellie_commands].empty?)
            debug "Process cleanup is not final process for payload. No notifications."
          else
            [:nellie_commands, :process_notification].each{|key| payload.delete(key) }
            completed(payload, message)
          end
        else
          error "Process failed! Send notification at what?"
        end
      end
    end
  end
end

Fission.register(:nellie, :trent, Fission::Nellie::Trent)
