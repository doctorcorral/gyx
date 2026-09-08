import Config

config :phoenix, :json_library, Jason

config :gyx_ui, GyxUI.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  url: [host: "localhost"],
  http: [ip: {127, 0, 0, 1}, port: 4000],
  secret_key_base: "gyx-ui-dev-secret-key-base-please-change-in-production-64-bytes-minimum!!",
  live_view: [signing_salt: "gyx_ui_lv"],
  pubsub_server: GyxUI.PubSub,
  server: false,
  render_errors: [
    formats: [html: GyxUI.ErrorHTML],
    layout: false
  ]

config :logger, :console, format: "$time $metadata[$level] $message\n"

import_config "#{config_env()}.exs"
