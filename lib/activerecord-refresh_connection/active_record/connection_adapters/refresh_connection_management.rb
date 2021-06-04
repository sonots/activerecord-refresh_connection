module ActiveRecord
  module ConnectionAdapters
    class RefreshConnectionManagement
      DEFAULT_OPTIONS = {max_requests: 1}

      def initialize(app, options = {})
        @app = app
        @options = DEFAULT_OPTIONS.merge(options)
        @mutex = Mutex.new

        resolve_clear_connections
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
        __send__(@clear_connections)
      end

      def resolve_clear_connections
        ar_version = ActiveRecord.gem_version.to_s

        @clear_connections =
          if ar_version >= "6.1"
            if ActiveRecord::Base.legacy_connection_handling
              :clear_legacy_compatible_connections
            else
              :clear_multi_db_connections
            end
          elsif ar_version >= "6.0"
            :clear_ar_6_0_connections
          else
            :clear_legacy_connections
          end
      end

      def clear_multi_db_connections
        if should_clear_all_connections?
          ActiveRecord::Base.connection_handler.all_connection_pools.each(&:disconnect!)
        else
          ActiveRecord::Base.connection_handler.all_connection_pools.each do |pool|
            pool.release_connection if pool.active_connection? && !pool.connection.transaction_open?
          end
        end
      end

      def clear_legacy_compatible_connections
        if should_clear_all_connections?
          ActiveRecord::Base.connection_handlers.each_value do |handler|
            handler.connection_pool_list.each(&:disconnect!)
          end
        else
          ActiveRecord::Base.connection_handlers.each_value do |handler|
            handler.connection_pool_list.each do |pool|
              pool.release_connection if pool.active_connection? && !pool.connection.transaction_open?
            end
          end
        end
      end

      def clear_ar_6_0_connections
        if should_clear_all_connections?
          ActiveRecord::Base.connection_handlers.each_value(&:clear_all_connections!)
        else
          ActiveRecord::Base.connection_handlers.each_value(&:clear_active_connections!)
        end
      end

      def clear_legacy_connections
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
