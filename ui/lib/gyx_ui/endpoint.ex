defmodule GyxUI.Endpoint do
  @moduledoc false
  use Phoenix.Endpoint, otp_app: :gyx_ui

  @session_options [
    store: :cookie,
    key: "_gyx_ui_key",
    signing_salt: "gyx_ui",
    same_site: "Lax"
  ]

  socket("/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]
  )

  plug(Plug.Static, at: "/phoenix", from: {:phoenix, "priv/static"}, gzip: false)
  plug(Plug.Static, at: "/live_view", from: {:phoenix_live_view, "priv/static"}, gzip: false)
  plug(Plug.Static, at: "/", from: {:gyx, "priv/static"}, gzip: false, only: ~w(images))

  plug(Plug.RequestId)
  plug(Plug.Telemetry, event_prefix: [:gyx_ui, :endpoint])

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)
  plug(Plug.Session, @session_options)
  plug(GyxUI.Router)
end
