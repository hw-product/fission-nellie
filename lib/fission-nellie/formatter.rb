require 'fission'

module Jackal
  module Nellie
    module Formatter
      module MessageExtract

        # Message for successful results
        #
        # @param payload [Smash]
        # @return [String]
        def success_message(payload)
          repo = [
            payload.get(:data, :code_fetcher, :info, :owner),
            payload.get(:data, :code_fetcher, :info, :name)
          ].join('/')
          sha = payload.get(:data, :code_fetcher, :info, :commit_sha)
          ["[nellie]: Job completed successfully! (#{repo}@#{sha})",
            '',
            "* #{job_url(payload)}"].join("\n")
        end

        # Message for failure results
        #
        # @param payload [Smash]
        # @return [String]
        def failure_message(payload)
          msg = ['[nellie]: Failure encountered:']
          msg << ''
          failed_history = payload.fetch(:data, :nellie, :history, {}).detect do |i|
            i[:exit_code] != 0
          end
          if(failed_history)
            msg << 'OUTPUT:' << '' << '```'
            log = asset_store.get(failed_history.get(:logs, :stdout))
            content = []
            while(data = log.readpartial(4096))
              content << data
              content.shift if content.size > 2
            end
            msg << content.join('').slice(-2048, 2048)
            msg << '```'
          else
            msg << '```' << 'Failed to locate logs' << '```'
          end
          msg << ''
          msg << "* #{job_url(payload)}"
          msg.join("\n")
        end

      end
    end
  end
end
