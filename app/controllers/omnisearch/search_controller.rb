# frozen_string_literal: true

module Omnisearch
  # GET /search?engine=google&text=ruby
  #
  # Returns the same shape as `Omnisearch::Query#results`:
  #
  #   { query:, status:, status_by_provider: [{ provider:, status:, error_messages: [] }], results: [] }
  #
  # 422 when the parameters are invalid, with the validation errors. Providers
  # that fail are reported per-provider in the body and do not fail the request:
  # one bad key should not take down a search that another engine could answer.
  class SearchController < ActionController::Base
    def index
      query = Omnisearch::Query.new(engine: params[:engine], text: params[:text])

      if query.valid?
        render json: query.results, status: :ok
      else
        render json: { errors: query.errors }, status: :unprocessable_entity
      end
    end
  end
end
