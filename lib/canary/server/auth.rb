require "protocol/http/middleware"

module Canary
  class Server
    # Shared-secret bearer check composed ahead of the handler (I18 verdict:
    # minimum bar, not hardening - every call still executes caller-supplied
    # Ruby on a host whose address space is not defensible). A missing or
    # wrong token is rejected here, before the handler ever reads the
    # request body - the cheapest possible reject: no JSON parsing, no task
    # lookup, nothing.
    class Auth < ::Protocol::HTTP::Middleware
      def initialize(app, token:)
        super(app)
        @expected = "Bearer #{token}"
      end

      def call(request)
        return unauthorized unless request.headers["authorization"] == @expected

        super
      end

      private

      def unauthorized
        ::Protocol::HTTP::Response[401, { "content-type" => "text/plain" }, ["unauthorized"]]
      end
    end
  end
end
