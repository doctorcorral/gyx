import Config

config :gyx, :mj_backend, :nx

config :nx, default_backend: EXLA.Backend
config :nx, :default_defn_options, compiler: EXLA, client: :host

config :logger, :console, format: "$time $metadata[$level] $message\n"

import_config "#{config_env()}.exs"
