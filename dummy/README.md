# omnisearch dummy host app

This is not a project. It is the fixture that proves `omnisearch` is actually
mountable, and it exists so that claim is tested rather than asserted.

`omnisearch`'s unit tests run the engine's objects in isolation, which would
happily pass with a broken mount point, a namespace collision, or an engine
route that never resolves. None of those failures are visible without a host.

So this is a minimal Rails app with the gem added by relative path:

```ruby
# Gemfile
gem "omnisearch", path: ".."

# config/routes.rb
mount Omnisearch::Engine => "/search"

# config/initializers/omnisearch.rb
Omnisearch.configure do |config|
  config.providers = {
    google: { engine_id: ENV["GOOGLE_ENGINE_ID"], api_key: ENV["GOOGLE_API_KEY"] }
  }
end
```

The integration tests in `test/integration/search_flow_test.rb` go through this
app's real routing and middleware stack, so a regression in
`isolate_namespace`, the mount point, or the engine's routes fails here and
nowhere else.

```console
$ bundle install
$ bundle exec rails test      # 11 tests
```

It runs in CI as the "Mounted in a host app" job, so the claim is checked on
every push rather than trusted.
