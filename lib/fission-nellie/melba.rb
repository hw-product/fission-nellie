require 'jackal-nellie'
require 'fission-nellie'

module Fission
  module Nellie
    # Container based nellie
    class Melba < Jackal::Nellie::Processor

      # Run collection of commands
      #
      # @param commands [Array<String>] commands to execute
      # @param env [Hash] environment variables for process
      # @param payload [Smash]
      # @param process_cwd [String] working directory for process
      # @return [Array<Smash>] command results ({:start_time, :stop_time, :exit_code, :logs, :timed_out})
      def run_commands(commands, env, payload, process_cwd)

        event!(:info, :info => 'Starting nellie command execution!', :message_id => payload[:message_id])

        log_file = Tempfile.new('nellie')
        container = remote_process
        w_space = Fission::Assets::Packer.pack(process_cwd)
        container.push_file(w_space, '/tmp/workspace.zip')
        container.exec!("mkdir -p #{process_cwd}")
        container.exec!("unzip /tmp/workspace.zip -d #{process_cwd}")

        results = []
        e_vars = Smash.new(
          'NELLIE_GIT_COMMIT_SHA' => payload.get(:data, :code_fetcher, :info, :commit_sha),
          'NELLIE_GIT_REF' => payload.get(:data, :code_fetcher, :info, :reference)
        ).merge(payload.fetch(:data, :nellie, :environment, Smash.new)).merge(config.fetch(:environment, Smash.new))

        commands.each do |command|
          event!(:info, :info => "Start execution: `#{command}`", :message_id => payload[:message_id])
          result = Smash.new
          result[:start_time] = Time.now.to_i
          stream = Fission::Utils::RemoteProcess::QueueStream.new
          future = Zoidberg::Future.new do
            begin
              cmd_info = container.exec(command,
                :stream => stream,
                :timeout => 3600,
                :cwd => process_cwd,
                :environment => e_vars
              )
              event!(:info, :info => "Complete execution: `#{command}`", :message_id => payload[:message_id])
              cmd_info
            rescue => e
              payload.set(:data, :nellie, :result, :failed, true)
              error "Nellie command failed (ID: #{payload[:message_id]}): #{e.class} - #{e}"
              debug "#{e.class}: #{e}\n#{e.backtrace.join("\n")}"
              Fission::Utils::RemoteProcess::Result(-1, "Command failed (ID: #{payload[:message_id]}): #{e.class} - #{e}")
            ensure
              stream.write :complete
            end
          end

          until((lines = stream.pop) == :complete)
            lines.split("\n").each do |line|
              next if line.empty?
              debug "Log line: #{line}"
              log_file.puts line
              event!(:info, :info => line, :message_id => payload[:message_id])
            end
          end

          cmd_result = future.value
          result[:stop_time] = Time.now.to_i
          result[:exit_code] = cmd_result.exit_code

          unless(cmd_result.success?)
            payload.set(:data, :nellie, :result, :failed, true)
            break
          end

          results << result
        end

        container.terminate

        log_file.flush
        log_file.rewind
        log_key = "nellie/#{payload[:message_id]}.log"
        asset_store.put(log_key, log_file)
        log_file.delete
        payload.set(:data, :nellie, :logs, :output, log_key)
        results
      end

    end
  end
end

Fission.register(:nellie, :melba, Fission::Nellie::Melba)
