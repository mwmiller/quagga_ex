import Config

config :logger, level: :info

config :baobab,
  spool_dir: "/tmp/baobab"

config :baby,
  identity: "fly",
  port: 8483,
  # This will use the default `:period_ms` which is about 23m
  cryouts: [[host: "moid2.fly.dev", port: 8483]]
