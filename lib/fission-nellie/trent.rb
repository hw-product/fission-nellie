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
        process_manager.unlock(p_lock)
        process_manager.delete(payload[:process_notification])
        if(payload[:nellie_commands] && !payload[:nellie_commands].empty?)
          debug "Process cleanup is not final process for payload. No notifications."
        else
          debug "This payload is complete! Who the hell do I tell!?"
        end
      end
    end
  end
end

Fission.register(:fission_nellie, Fission::Nellie::Trent)
