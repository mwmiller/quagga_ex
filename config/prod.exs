import Config

config :logger, level: :info

config :baobab,
  spool_dir: "/tmp/baobab"

config :baby,
  identity: "fly",
  port: 8483,
  cryouts: []
