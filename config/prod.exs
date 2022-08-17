import Config

config :logger, level: :info

config :baobab,
  spool_dir: "/tmp/baobab"

config :baby,
  clump_id: "Quagga",
  identity: "fly",
  port: 8483,
  cryouts: [[host: "moid2.fly.dev", port: 8483, period: {2, :hour}]]
