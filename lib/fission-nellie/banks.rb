require 'fission/callback'
require 'fission/validators/validate'

module Fission
  module Nellie
    class Banks < Callback

      SCRIPT_NAME = '.nellie'

      def valid?(message)
        m = unpack(message)
        if(m[:repository])
          if(m[:process_notification])
            m[:nellie_commands] && !m[:nellie_commands].empty?
          else
            true
          end
        end
      end

      def execute(message)
        payload = unpack(message)
        process_pid = nil
        command = nil
        debug "Processing message for testing"
        test_path = File.join(payload[:repository][:path], SCRIPT_NAME)

        unless(payload[:nellie_commands])
          if(File.exists?(test_path))
            debug "Running test at path: #{test_path}"
            begin
              json = JSON.load(File.read(test_path))
              debug 'Nellie file is JSON. Populating commands into payload and tossing back to the queue.'
              payload[:nellie_commands] = json['commands']
            rescue
              debug 'Looks like that wasn\'t JSON. Lets just execute it!'
              command = File.executable?(test_path) ? test_path : "/bin/bash #{test_path}"
            end
          else
            abort "No nellie file found! (checked: #{test_path})"
          end
        end
        if(payload[:nellie_commands])
          command = payload[:nellie_commands].shift
        end
        process_pid = run_process(command,
          :source => message[:source],
          :payload => payload,
          :cwd => payload[:repository][:path]
        )
        debug "Process left running with process id of: #{process_pid}"
      end

      def run_script(test_path, source, payload)
        run_process("/bin/bash #{test_path}",
          :source => source,
          :payload => payload,
          :cwd => File.dirname(test_path)
        )
        process_pid = run_process(message, '/bin/bash', test_path)
      end

      def run_process(command, pack={})
        process_pid = Celluloid.uuid
        cwd = pack.delete(:cwd) || '/tmp'
        stdout_log = process_manager.create_io_tmp(process_pid, 'stdout')
        stderr_log = process_manager.create_io_tmp(process_pid, 'stderr')
        process_manager.process(process_pid, command, pack) do |proc|
          proc.cwd = cwd
          proc.io.stdout = stdout_log
          proc.io.stderr = stderr_log
          proc.start
        end
        process_pid
      end

      def run_json(message, json)
        json['commands'].each do |command|
          run_process(message, *command.split(' '))
        end
      end

    end
  end
end

Fission.register(:nellie, :validators, Fission::Validators::Validate)
Fission.register(:nellie, :validators, Fission::PackageBuilder::Repository)
Fission.register(:nellie, :banks, Fission::Nellie::Banks)
