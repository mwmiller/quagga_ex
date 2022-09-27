import Config

config :quagga,
  public: %{
    "name" => "Zebra Homebase",
    "host" => "quagga.nftease.online",
    "port" => 8483,
    "clump_id" => "Quagga"
  },
  secret: System.get_env("QUAGGA_SECRET_KEY")

config :logger, level: :info

config :baby,
  spool_dir: "/tmp/baobab",
  clumps: [
    [
      id: "Quagga",
      controlling_identity: "fly",
      controlling_secret: System.get_env("QUAGGA_SECRET_KEY"),
      port: 8483,
      cryouts: [[host: "moid2.fly.dev", port: 8483, period: {2, :hour}]]
    ]
  ]
