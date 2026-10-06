# frozen_string_literal: true

# A host app declares the credentials for the providers it has. Providers
# without credentials stay registered but report themselves unavailable, so a
# partially configured app still serves the engines that do work.
Omnisearch.configure do |config|
  config.providers = {
    google: {
      engine_id: ENV.fetch('GOOGLE_ENGINE_ID', nil),
      api_key: ENV.fetch('GOOGLE_API_KEY', nil)
    }
  }
end
