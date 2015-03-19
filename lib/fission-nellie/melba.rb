require 'elecksee'
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
        container = Lxc::Ephemeral.new(
          :original => 'ubuntu_1204',
          :daemon => true,
          :bind => process_cwd
        )
        results = []
        begin
          container.start!(:detach)
          connection = container.lxc.connection
          log_path = File.join(process_cwd, "#{payload[:message_id]}.log")
          commands.each do |command|
            result = Smash.new
            File.open(log_path, 'a+'){|file| file.puts "$ #{command}" }
            debug "Running command from payload #{payload[:message_id]}: #{command}"
            command = "#{command} >> #{log_path} 2>&1"
            result[:start_time] = Time.now.to_i
            result[:exit_code] = run_process(command,
              :connection => connection,
              :payload => payload,
              :cwd => process_cwd,
              :environment => Smash.new(
                'NELLIE_GIT_COMMIT_SHA' => payload.get(:data, :code_fetcher, :info, :commit_sha),
                'NELLIE_GIT_REF' => payload.get(:data, :code_fetcher, :info, :reference)
              ).merge(payload.fetch(:data, :nellie, :environment, Smash.new))
            )
            result[:stop_time] = Time.now.to_i
            debug "Command completed from payload #{payload[:message_id]}: #{command}"
            results << result
            unless(result[:exit_code] == 0)
              payload.set(:data, :nellie, :result, :failed, true)
              break
            end
          end
          log_key = "nellie/#{payload[:message_id]}.log"
          asset_store.put(log_key, File.open(log_path, 'r'))
          payload.set(:data, :nellie, :result, :log, log_key)
        ensure
          container.lxc.stop
        end
        results
      end

      # Run a process
      #
      # @param command [String] command to run
      # @param pack [Hash]
      # @option pack [Rye::Box] :connection connection to container
      # @option pack [String] :cwd current working directory of process
      # @option pack [Hash] :environment custom environment to provide to process
      # @return [Integer] process exit status (returns -1 on exception)
      # @note need to update exception handling to nest error into
      #   logs for display
      def run_process(command, pack={})
        warn "Running command: #{command.inspect}"
        con = pack[:connection]
        con.cd pack.fetch(:cwd, '/tmp')
        pack[:environment].each do |key, value|
          con.setenv(key, value)
        end
        begin
          result = con.execute command
          result.exit_status
        rescue => e
          warn "Failed to run command: #{e.class} - #{e} (`#{command}`)"
          -1
        end
      end

    end
  end
end

Fission.register(:nellie, :melba, Fission::Nellie::Melba)
