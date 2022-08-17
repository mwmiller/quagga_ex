import Config

config :quagga,
  public: %{"name" => "Zebra Homebase", "host" => "quagga.nftease.online", "port" => 8483},
  secret: System.get_env("QUAGGA_SECRET_KEY")
