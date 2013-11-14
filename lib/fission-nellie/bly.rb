module Fission
  module Nellie
    class Bly < Callback

      def valid?(message)
        m = unpack(message)
        m[:repository]
      end

      def execute(message)
        m = unpack(message)
      end

    end
  end
end
