module Fission
  module Nellie
    class Banks < Callback

      SCRIPT_NAME = '.nellie'

      def valid?(message)
        m = unpack(message)
        m[:repository]
      end

      def log_file(*args)
        File.join('/tmp', *args)
      end

      def execute(message)
        m = unpack(message)
        debug "Processing message for testing"
        if(File.exists?(test_path = File.join(m[:repository][:path], SCRIPT_NAME)))
          debug "Running test at path: #{test_path}"
          process_pid = Celluloid.uuid
          process_manager.process(process_pid, message[:source], ['/bin/bash', test_path]) do |proc|
            proc.cwd = File.dirname(test_path)
#            proc.io.stdout = Tempfile.new(log_file(process_pid, 'stdout'))
#            proc.io.stderr = Tempfile.new(log_file(process_pid, 'stderr'))
#            proc.detach = true
            proc.start
          end
          debug "Process left running with process id of: #{process_pid}"
        else
          debug "No test file found for processing (#{test_path})"
        end
      end

    end
  end
end

Fission.register(:fission_nellie, Fission::Validators::Validate)
Fission.register(:fission_nellie, Fission::PackageBuilder::Repository)
Fission.register(:fission_nellie, Fission::Nellie::Banks)
