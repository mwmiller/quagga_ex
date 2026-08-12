import Config

# Log level is tunable at runtime via the LOG_LEVEL env var so it can be
# flipped to :debug (and back to :info) without a code change. Set it with
# `fly secrets set LOG_LEVEL=debug --app <app>` and redeploy.
log_level =
  case System.get_env("LOG_LEVEL", "info") do
    "debug" ->
      :debug

    "info" ->
      :info

    l when l in ~w(warning warn) ->
      :warning

    "error" ->
      :error

    other ->
      IO.warn("Unknown LOG_LEVEL #{inspect(other)}, defaulting to :info")
      :info
  end

config :logger, level: log_level

# The same codebase is deployed as two fly.io apps. fly.io sets
# FLY_APP_NAME for each, so it selects this node's clump definition.
#
# Both nodes host the same "Quagga" clump and cry out to one another so
# the bamboo stays replicated across them. Each announces its own oasis
# facet (a distinct facet_id) so the two public announcements do not
# interleave in a single log.
#
# Be sure that all defined ports are properly mapped in the Dockerfile
# and in fly.toml.

# The two nodes cry out to one another only (prime periods so they don't
# phase-lock). See deploy scripts for the region each lives in.
node =
  case System.get_env("FLY_APP_NAME", "quagga") do
    "dazzle" ->
      %{
        identity: "dazzle",
        secret: System.get_env("DAZZLE_SECRET_KEY"),
        name: "Dazzle ORD",
        host: "dazzle.zebrine.net",
        facet_id: 1,
        cryouts: [
          [host: "quagga.zebrine.net", port: 8483, period: {13, :minute}]
        ]
      }

    _ ->
      %{
        identity: "quagga",
        secret: System.get_env("QUAGGA_SECRET_KEY"),
        name: "Quagga ORD",
        host: "quagga.zebrine.net",
        facet_id: 0,
        cryouts: [
          [host: "dazzle.zebrine.net", port: 8483, period: {11, :minute}]
        ]
      }
  end

spool_dir =
  case config_env() do
    # In production the Baobab spool lives on the persistent fly volume
    # mounted at /data (see [mounts] in fly.toml).
    :prod -> "/data/baobab"
    :test -> Path.join(System.tmp_dir!(), "baobab_test")
    _ -> Path.join(File.cwd!(), "tmp/baobab")
  end

config :quagga, spool_dir: spool_dir

# QUAGGA_FRESH_ANNOUNCE tells the Nicker whether this boot is a brand-new
# identity or a recovered one, which determines how it avoids forking its own
# oasis log.
#
# The oasis announcement is written under this node's own public key. On a
# normal boot the local Baobab spool is empty, but peers may still hold this
# node's *previous* oasis logs (replicated before the last restart). If the
# node started writing its oasis at sequence number 1 before those old logs
# came back, the late-arriving history would fork its log.
#
#   * set (any value) -> brand-new identity: no peer can possibly hold our logs
#                yet, so it is safe to announce at sequence number 1 immediately.
#                Set this ONLY on the first boot of a new identity/key, then
#                unset it.
#   * unset (default) -> recovered identity: the Nicker waits until our own
#                oasis logs have been gossiped back from the network
#                (max seqnum > 0) before continuing to write, which prevents a
#                fork. This is the safe default.
fresh_announce? = System.get_env("QUAGGA_FRESH_ANNOUNCE") != nil

# Only run a clump in production so that local dev and test boots stay
# side-effect free (no bound ports, no network cryouts).
if config_env() == :prod do
  config :quagga,
    clumps: [
      [
        id: "Quagga",
        controlling_identity: node.identity,
        controlling_secret: node.secret,
        # This identity will be used to maintain the peer social graph
        # and will be included in the public oasis info
        operator_key: "AxITounKOuR0Mz8x6usSAbo3xF8ZfSxq4gzvOYAvunX",
        port: 8483,
        announce_freq: {53, :hour},
        gossip_wait: {23, :minute},
        fresh_announce: fresh_announce?,
        cryouts: node.cryouts,
        public: %{
          "name" => node.name,
          "host" => node.host,
          "facet_id" => node.facet_id
        }
      ]
    ]
end
