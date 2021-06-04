module ActiveRecord
  module ConnectionAdapters
    class RefreshConnectionManagement
      DEFAULT_OPTIONS = {max_requests: 1}
      AR_VERSION_6_1 = "6.1".freeze
      AR_VERSION_6_0 = "6.0".freeze

      def initialize(app, options = {})
        @app = app
        @options = DEFAULT_OPTIONS.merge(options)
        @mutex = Mutex.new
        @ar_version = ActiveRecord.gem_version.to_s

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
        if @ar_version >= AR_VERSION_6_1
          if legacy_connection_handling?
            clear_legacy_compatible_connections
          else
            clear_all_roles_connections
          end
        elsif @ar_version >= AR_VERSION_6_0
          clear_legacy_compatible_connections
        else
          clear_legacy_connections
        end
      end

      def legacy_connection_handling?
        begin
          ActiveRecord::Base.legacy_connection_handling
        rescue NoMethodError
          false
        end
      end

      def all_roles
        roles = []
        ActiveRecord::Base.connection_handler.instance_variable_get(:@owner_to_pool_manager).each_value do |pool_manager|
          roles.concat(pool_manager.role_names)
        end
        roles.uniq
      end

      def clear_all_roles_connections
        if should_clear_all_connections?
          all_roles.each do |role|
            ActiveRecord::Base.clear_all_connections!(role)
          end
        else
          all_roles.each do |role|
            ActiveRecord::Base.clear_active_connections!(role)
          end
        end
      end

      def clear_legacy_compatible_connections
        if should_clear_all_connections?
          ActiveRecord::Base.connection_handlers.each_value do |connection_handler|
            connection_handler.clear_all_connections!
          end
        else
          ActiveRecord::Base.connection_handlers.each_value do |connection_handler|
            connection_handler.clear_active_connections!
          end
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
