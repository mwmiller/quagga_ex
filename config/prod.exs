import Config

config :logger, level: :info

config :baobab,
  spool_dir: "/tmp/baobab"

config :quagga,
  public: %{"host" => "quagga.nftease.online", "port" => 8483}

config :baby,
  identity: "fly",
  clump_id: "Quagga",
  port: 8483,
  cryouts: [[host: "moid2.fly.dev", port: 8483, period: {2, :hour}]]
