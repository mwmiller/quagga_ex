import Config

config :logger, level: :info

# Be sure that all defined ports are properly mapped in the
# Dockerfile.
config :quagga,
  spool_dir: "/tmp/baobab",
  clumps: [
    [
      id: "Quagga",
      controlling_identity: "fly",
      controlling_secret: System.get_env("QUAGGA_SECRET_KEY"),
      port: 8483,
      cryouts: [[host: "moid2.fly.dev", port: 8483, period: {23, :minute}]],
      public: %{
        "name" => "Quagga ORD",
        "host" => "quagga.nftease.online"
      }
    ]
  ]
