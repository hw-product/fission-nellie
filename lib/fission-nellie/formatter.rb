require 'fission'
require 'jackal-nellie/formatter'

# Overloads to get expected content when running within fission
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
          failed_log = payload.get(:data, :nellie, :logs, :output)
          if(failed_log)
            msg << 'OUTPUT:' << '' << '```'
            log = asset_store.get(failed_log)
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

      class GithubCommitStatus

        # Format payload to provide output status to GitHub
        #
        # @param payload [Smash]
        def format(payload)
          if(payload.get(:data, :nellie, :status))
            payload.set(:data, :github_kit, :status,
              Smash.new(
                :repository => [
                  payload.get(:data, :code_fetcher, :info, :owner),
                  payload.get(:data, :code_fetcher, :info, :name)
                ].join('/'),
                :reference => payload.get(:data, :code_fetcher, :info, :commit_sha),
                :state => payload.get(:data, :nellie, :status) == 'success' ? 'success' : 'failure',
                :extras => {
                  :target_url => job_url(payload),
                  :context => 'shortorder/nellie',
                  :description => payload.get(:data, :nellie, :status) == 'success' ?
                    success_message(payload) :
                    failure_message(payload)
                }
              )
            )
          end
        end

      end
    end
  end
end
