module ActiveRecord
  module ConnectionAdapters
    class RefreshConnectionManagement
      DEFAULT_OPTIONS = {max_requests: 1}

      def initialize(app, options)
        @app = app
        @options = DEFAULT_OPTIONS.merge(options)
        @mutex = Mutex.new

        reset_remain_count
      end

      def call(env)
        testing = env.key?('rack.test')

        response = @app.call(env)

        clear_connections = should_clear_connections? && !testing

        response[2] = ::Rack::BodyProxy.new(response[2]) do
          # disconnect all connections on the connection pool
          ActiveRecord::Base.clear_all_connections! if clear_connections
        end

        response
      rescue Exception
        ActiveRecord::Base.clear_all_connections! if clear_connections
        raise
      end

      private

      def should_clear_connections?
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
