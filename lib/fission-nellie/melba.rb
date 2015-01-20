require 'shellwords'
require 'fission/callback'
require 'fission-nellie/validators/validate'
require 'fission-nellie/validators/repository'
require 'fission-assets'
require 'fission-assets/packer'

module Fission
  module Nellie
    # Command executor
    class Melba < Callback

      # Name of file containing commands
      SCRIPT_NAME = '.nellie'

      # @return [Fission::Assets::Store] object store
      attr_reader :object_store
      # @return [String] working directory for execution
      attr_reader :working_directory

      # Setup object store and configure working directory
      def setup(*_)
        @object_store = Fission::Assets::Store.new
        @working_directory = Carnivore::Config.fetch(
          :fission, :nellie, :working_directory, '/tmp/nellie'
        )
      end

      # Validity of message
      #
      # @param message [Carnivore::Message]
      # @return [Truthy, Falsey]
      def valid?(message)
        super do |m|
          m.get(:data, :repository) &&
            !m.get(:data, :nellie)
        end
      end

      # Fire off commands until command list has been exhausted
      #
      # @param message [Carnivore::Message]
      def execute(message)
        failure_wrap(message) do |payload|
          process_pid = nil
          command = nil
          debug "Processing message for testing"
          repository_path = File.join(working_directory, File.basename(payload[:data][:repository][:path]))
          unless(payload[:data][:nellie])
            test_path = File.join(
              Fission::Assets::Packer.unpack(
                object_store.get(payload[:data][:repository][:path]),
                repository_path,
                :disable_overwrite
              ), SCRIPT_NAME
            )
            if(File.exists?(test_path))
              debug "Running test at path: #{test_path}"
              begin
                json = JSON.load(File.read(test_path))
                debug 'Nellie file is JSON. Populating commands into payload and tossing back to the queue.'
                payload[:data][:nellie] ||= {}
                payload[:data][:nellie][:commands] = json['commands']
                payload[:data][:nellie][:environment] = json.fetch('environment', {})
              rescue
                debug 'Looks like that wasn\'t JSON. Lets just execute it!'
                command = File.executable?(test_path) ? test_path : "/bin/bash #{test_path}"
              end
            else
              abort "No nellie file found! (checked: #{test_path})"
            end
          end
          if(commands = payload.get(:data, :nellie, :commands))
            container = Lxc::Ephemeral.new(
              :original => 'ubuntu_1204',
              :daemon => true,
              :bind => repository_path
            )
            begin
              container.start!(:detach)
              connection = container.lxc.connection
              commands.each do |command|
                process_pid = run_process(command,
                  :connection => connection,
                  :source => message[:source],
                  :payload => payload,
                  :cwd => repository_path,
                  :pending => enable_pending(payload),
                  :environment => Smash.new(
                    'NELLIE_GIT_COMMIT_SHA' => payload.get(:data, :github, :head_commit, :id),
                    'NELLIE_GIT_REF' => payload.get(:data, :github, :ref)
                  ).merge(payload.fetch(:data, :nellie, :environment, Smash.new))
                )
              end
            ensure
              container.lxc.stop
            end
          end
          message.confirm!
          [:commands, :environment].each do |key|
            payload[:data][:nellie].delete(key)
          end
          job_completed(:nellie, payload, message)
        end
      end

      # Enable pending status payload generation if configuration
      # has been defined
      #
      # @param payload [Hash]
      # @return [Smash, nil]
      def enable_pending(payload)
        if(false) #pending = Carnivore::Config.get(:fission, :nellie, :status))
          Smash.new.tap do |pending_config|
            pending_config[:interval] = pending[:interval]
            pending_config[:source] = pending[:source]
            pending_config[:reference] = payload[:message_id]
            pending_config[:data] = Smash.new(
              :repository => payload.get(:data, :github, :repository, :name),
              :reference => payload.get(:data, :github, :ref),
              :commit_sha => payload.get(:data, :github, :after)
            )
          end
        end
      end

      # Run a process
      #
      # @param command [String] command to run
      # @param pack [Hash]
      # @option pack [String] :cwd current working directory of process
      # @option pack [Hash] :environment custom environment to provide to process
      # @return [String] process ID (UUID not actual pid)
      def run_process(command, pack={})
        warn "Running command: #{command.inspect}"
        con = pack[:connection]
        con.cd pack.fetch(:cwd, '/tmp')
        pack[:environment].each do |key, value|
          con.setenv(key, value)
        end
        result = con.execute command
        unless(result.exit_status == 0)
          error "FAILED: #{result.stderr.join("\n")}"
          raise 'OMG NELLIE FAILED! WHY GOD WHY!?!?!?!!?!?!?!'
        else
          info "COMMAND SUCCESS!!!! #{result.stdout.join("\n")}"
        end
      end

      # Set payload data for mail type notifications
      # TODO: custom mail address provided via .nellie file?
      def set_success_email(payload)
        project_name = retrieve(payload, :data, :github, :repository, :name)
        completed_sha = retrieve(payload, :data, :github, :after)
        dest_email = [
          retrieve(payload, :data, :github, :repository, :owner, :email),
          retrieve(payload, :data, :github, :pusher, :email)
        ].compact
        details = retrieve(payload, :data, :github, :compare)
        notify = {
          :destination => dest_email.map{ |target|
            {:email => target}
          },
          :origin => {
            :email => origin[:email],
            :name => origin[:name]
          }
        }
        notify.merge!(
          :subject => "[#{origin[:name]}] SUCCESS #{project_name} build complete",
          :message => "Build of #{project_name} at SHA: #{completed_sha} has successfully built.\nComparision at: #{details}",
          :html => false
        )
        payload[:data][:notification_email] = notify
      end

    end
  end
end

Fission.register(:nellie, :melba, Fission::Nellie::Melba)
