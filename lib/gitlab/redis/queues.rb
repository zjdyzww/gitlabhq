# frozen_string_literal: true

# We need this require for MailRoom
require_relative 'wrapper' unless defined?(::Gitlab::Redis::Wrapper)

module Gitlab
  module Redis
    class Queues < ::Gitlab::Redis::Wrapper
      SIDEKIQ_NAMESPACE = 'resque:gitlab'
      MAILROOM_NAMESPACE = 'mail_room:gitlab'

      private

      def raw_config_hash
        super || { url: 'redis://localhost:6381' }
      end
    end
  end
end
