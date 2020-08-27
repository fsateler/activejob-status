require 'activejob-status/storage'
require 'activejob-status/status'
require 'activejob-status/progress'

module ActiveJob
  module Status
    extend ActiveSupport::Concern
    DEFAULT_EXPIRY = 60 * 30

    included do
      before_enqueue { |job| job.status.update(status: :queued) }
      before_perform { |job| job.status.update(status: :working) }
      after_perform  { |job| job.status.update(status: :completed) }
    end
    
    def perform_now(*)
      # We can't use rescue_from(Exception) because it is brittle:
      # it will miss non-StandardError, and may be preempted by another
      # rescue_from block
      begin
        super
      rescue Exception
        status.update(status: :failed)
        raise
      end
    end
        

    def status
      @status ||= Status.new(self)
    end

    def progress
      @progress ||= Progress.new(self)
    end

    class << self
      def options=(options)
        @@options = options
      end

      def options
        @@options ||= { expires_in: DEFAULT_EXPIRY }
      end

      def store=(store)
        store = ActiveSupport::Cache.lookup_store(store) if store.is_a?(Symbol)
        @@store = store
      end

      def store
        @@store ||= (defined?(Rails) && Rails.cache)
      end

      def get(id)
        Status.new(id)
      end
    end
  end
end
