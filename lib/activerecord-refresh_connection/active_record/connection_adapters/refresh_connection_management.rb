module ActiveRecord
  module ConnectionAdapters
    class RefreshConnectionManagement
      def initialize(app)
        @app = app
      end

      def call(env)
        testing = env.key?('rack.test')

        response = @app.call(env)
        response[2] = ::Rack::BodyProxy.new(response[2]) do
          # disconnect all connections on the connection pool
          ActiveRecord::Base.clear_all_connections! unless testing
        end

        response
      rescue Exception
        ActiveRecord::Base.clear_all_connections! unless testing
        raise
      end
    end
  end
end
