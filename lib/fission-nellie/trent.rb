module Fission
  module Nellie
    class Trent < Callback

      def valid?(message)
        m = unpack(message)
        m[:process_notification]
      end

      def execute(message)
        File.open('/tmp/fubar', 'w') do |file|
          file.puts "DONE!"
        end
        debug "Wrote final message for completion"
      end
    end
  end
end

Fission.register(:fission_nellie, Fission::Nellie::Trent)
