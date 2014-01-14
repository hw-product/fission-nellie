require 'fission/callback'

module Fission
  module Nellie
    class Bly
      class Log < Callback

        def valid?(message)
          super do |m|
            m[:nellie] &&
              m[:nellie][:request] &&
              m[:nellie][:request][:type] == 'log'
          end
        end

        # {:nellie => :request => {:type => :stderr, :process_pid =>
        # uuid, :start => integer, :limit => integer}}
        def execute(message)
          failure_wrap(message) do |payload|
            request = payload[:nellie].delete(:request)
            set_log(payload, request)
            completed(payload)
          end
        end

        def set_log(payload, request)
          p_lock = process_manager.lock(request[:process_pid], false)
          if(p_lock)
            content = ''
            start_pos = request[:start].to_i
            end_pos = nil
            limit = request[:limit].to_i
            File.open(p_lock[:process].io.send(request[:type]).path, 'r') do |file|
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

      class Status < Callback
        def valid?(message)
          super
          m = unpack(message)
          m[:nellie] &&
            m[:nellie][:request] &&
            m[:nellie][:request][:type] == 'status'
        end

        def execute(message)
          payload = unpack(message)
          request = payload[:nellie].delete(:request)
          set_status(payload, request[:process_pid])
          completed(payload, message)
        end

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
