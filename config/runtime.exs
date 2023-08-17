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
      announce_period: {23, :hour},
      gossip_wait: {59, :minute},
      cryouts: [
        [host: "moid2.fly.dev", port: 8483, period: {23, :minute}],
        [host: "zebra.zebrine.net", port: 8483, period: {7, :minute}]
      ],
      public: %{
        "name" => "Quagga ORD",
        "host" => "quagga.zebrine.net"
      }
    ]
  ]
