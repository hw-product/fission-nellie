require 'fission/callback'

module Fission
  module Nellie
    # Process informationer
    class Bly
      # Provide log information
      class Log < Callback

        # Validity of message
        #
        # @param message [Carnivore::Message]
        # @return [TrueClass, FalseClass]
        def valid?(message)
          super do |m|
            m.get(:nellie, :request, :type) == 'log'
          end
        end

        # Add log information to payload
        #
        # @param message [Carnivore::Message]
        # @example
        #   payload data structure:
        #   {
        #     :nellie => {
        #       :request => {
        #         :type => 'log',
        #         :kind => 'stderr',
        #         :process_pid => 'UUID',
        #         :start => IntegerStartPoint,
        #         :limit => IntegerMaxBytes
        #       }
        #     }
        #   }
        def execute(message)
          failure_wrap(message) do |payload|
            request = payload[:nellie].delete(:request)
            set_log(payload, request)
            completed(payload)
          end
        end

        # Set log into payload
        #
        # @param payload [Hash]
        # @param request [Hash]
        # @option request [String] :process_pid process UUID
        # @option request [Numeric] :start start location in log
        # @option request [Numeric] :limit max number of bytes to read
        # @option request [String] :kind stdout or stderr
        def set_log(payload, request)
          p_lock = process_manager.lock(request[:process_pid], false)
          if(p_lock)
            content = ''
            start_pos = request[:start].to_i
            end_pos = nil
            limit = request[:limit].to_i
            File.open(p_lock[:process].io.send(request[:kind]).path, 'r') do |file|
              file.pos = start_pos
              content << file.read(limit > 0 ? limit : nil)
              end_pos = file.pos
            end
            process_manager.unlock(p_lock)
            payload[:response] = {
              :process_pid => request[:process_pid],
              :content => content,
              :end_position => end_pos
            }
          else
            raise Locked
          end
        end

      end

      # Provide status information
      class Status < Callback

        # Validity of message
        #
        # @param message [Carnivore::Message]
        # @return [TrueClass, FalseClass]
        def valid?(message)
          super do |m|
            m.get(:nellie, :request, :type) == 'status'
          end
        end

        # Add status information to payload
        #
        # @param message [Carnivore::Message]
        def execute(message)
          failure_wrap(message) do |payload|
            request = payload[:nellie].delete(:request)
            set_status(payload, request[:process_pid])
            completed(payload, message)
          end
        end

        # Set status into payload
        #
        # @param payload [Hash]
        # @param request [Hash]
        # @option request [String] :process_pid process UUID
        def set_status(payload, request)
          p_lock = process_manager(request[:process_pid], false)
          if(p_lock)
            status = nil
            if(p_lock[:process].alive?)
              status = :running
            else
              begin
                status = :failed if p_lock[:process].crashed?
              rescue ChildProcess::Error => e
                status = e.message.downcase.include?('not started') ? :waiting : :unknown
              end
            end
            payload[:nellie][:response] = {
              :process_pid => request[:process_pid],
              :type => request[:type],
              :data => status
            }
          else
            abort Locked.new("Unable to aquire lock on requested process: #{request[:process_pid]}")
          end
        end
      end

    end
  end
end

Fission.register(:nellie, :bly, Fission::Nellie::Bly::Status)
Fission.register(:nellie, :bly, Fission::Nellie::Bly::Log)
