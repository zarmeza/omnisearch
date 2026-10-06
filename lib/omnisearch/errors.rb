# frozen_string_literal: true

module Omnisearch
  # Errors raised by the engine itself. Provider failures are never raised —
  # they are reported in `status_by_provider` — so these are reserved for
  # genuine misconfiguration.
  class Error < StandardError; end

  class ProviderNotConfigured < Error; end
  class UnknownProvider < Error; end
end
