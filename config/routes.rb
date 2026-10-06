# frozen_string_literal: true

Omnisearch::Engine.routes.draw do
  # A bare mount already routes GET / to the engine root; `search` gives a
  # predictable path regardless of where the host mounts us.
  get 'search', to: 'search#index', as: :search
  root to: 'search#index'
end
