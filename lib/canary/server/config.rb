require "optparse"

module Canary
  class Server
    # Resolves bin/canary-server's boot-time configuration from the
    # environment (flags override it) so the resolution itself - which
    # default wins, whether the token is present - is unit-testable without
    # binding a real socket. The bind default is 127.0.0.1, never
    # 0.0.0.0/[::] (README's own "not a defensible address space" warning
    # means the listener must not default to reachable-from-the-network).
    class Config
      DEFAULT_BIND = "127.0.0.1"
      DEFAULT_PORT = 9292

      MissingToken = Class.new(StandardError)

      attr_reader :bind, :port, :token, :concurrency

      def self.resolve(argv: [], env: ENV)
        new(argv: argv, env: env)
      end

      # +token+ is read only from the environment, never a flag, so it
      # never shows up in a process listing (`ps`) the way an argv value
      # would.
      def initialize(argv: [], env: ENV)
        @bind = env["CANARY_SERVER_BIND"] || DEFAULT_BIND
        @port = Integer(env["CANARY_SERVER_PORT"] || DEFAULT_PORT)
        @concurrency = Integer(env["CANARY_SERVER_CONCURRENCY"] || Server::DEFAULT_CONCURRENCY)

        parse_flags(argv.dup)

        @token = env["CANARY_SERVER_TOKEN"]
        raise MissingToken, "CANARY_SERVER_TOKEN must be set" if @token.to_s.empty?
      end

      private

      def parse_flags(argv)
        OptionParser.new do |parser|
          parser.on("--bind HOST", "Interface to bind (default #{DEFAULT_BIND})") { |v| @bind = v }
          parser.on("--port PORT", Integer, "Port to bind (default #{DEFAULT_PORT})") { |v| @port = v }
        end.parse!(argv)
      end
    end
  end
end
