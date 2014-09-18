module ActiveRecord
  module ConnectionAdapters
    class RefreshConnectionManagement
      DEFAULT_OPTIONS = {max_requests: 1}

      def initialize(app, options = {})
        @app = app
        @options = DEFAULT_OPTIONS.merge(options)
        @mutex = Mutex.new

        reset_remain_count
      end

      def call(env)
        testing = env.key?('rack.test')

        response = @app.call(env)

        response[2] = ::Rack::BodyProxy.new(response[2]) do
          # disconnect all connections on the connection pool
          clear_connections unless testing
        end

        response
      rescue Exception
        clear_connections unless testing
        raise
      end

      private

      def clear_connections
        if should_clear_all_connections?
          ActiveRecord::Base.clear_all_connections!
        else
          ActiveRecord::Base.clear_active_connections!
        end
      end

      def should_clear_all_connections?
        return true if max_requests <= 1

        @mutex.synchronize do
          @remain_count -= 1
          (@remain_count <= 0).tap do |clear|
            reset_remain_count if clear
          end
        end
      end

      def reset_remain_count
        @remain_count = max_requests
      end

      def max_requests
        @options[:max_requests]
      end
    end
  end
end
