defmodule Bardo.MixProject do
  use Mix.Project

  def project do
    [
      app: :bardo,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      test_coverage: [
        tool: ExCoveralls,
        exclude: excluded_modules()
      ],
      dialyzer: [plt_add_apps: [:ex_unit, :mix]],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications
  def application do
    [
      extra_applications: [:logger, :sasl],
      mod: {Bardo.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies
  defp deps do
    [
      # JSON parsing
      {:jason, "~> 1.4"},
      # HTTP client for API requests
      {:httpoison, "~> 2.0"},
      # UUID generation
      {:uuid, "~> 1.1"},
      # Ecto and PostgreSQL
      {:ecto_sql, "~> 3.9"},
      {:postgrex, "~> 0.16.0"},
      # Similar to meck for mocking in tests
      {:mock, "~> 0.3.0", only: :test},
      # CLI observer
      {:observer_cli, "~> 1.7"},
      # Diagnostic tools
      {:recon, "~> 2.5"},
      # Using built-in ETS instead of RocksDB for easier testing
      # {:rocksdb, "~> 1.6"},
      # {:shards, "~> 1.0"},
      # Code coverage and testing
      {:excoveralls, "~> 0.15", only: :test},
      # Property based testing
      {:stream_data, "~> 0.5", only: [:dev, :test]},
      # Static code analysis
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      # Dialyzer for type checking
      {:dialyxir, "~> 1.2", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      check: ["compile", "credo", "dialyzer", "test"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["test"]
    ]
  end

  defp excluded_modules do
    [
      Bardo.Tar.ErlTar,
      Bardo.Tar.Filename,
      Bardo.Tar.Tarball,
      Bardo.Tar.SafeErlTerm,
      Bardo.Applications.Flatland.FlatlandActuator,
      Bardo.Applications.Flatland.FlatlandSensor,
      Bardo.Applications.Flatland.FlatlandUtils,
      Bardo.Applications.Flatland.Flatland,
      Bardo.Applications.Flatland.Predator,
      Bardo.Applications.Flatland.Prey,
      Bardo.Applications.Fx.FxActuator,
      Bardo.Applications.Fx.FxMorphology,
      Bardo.Applications.Fx.FxSensor,
      Bardo.Applications.Fx.Fx,
      Bardo.Benchmarks.Dpb.DpbActuator,
      Bardo.Benchmarks.Dpb.DpbSensor,
      Bardo.Benchmarks.Dpb.DpbWDamping,
      Bardo.Benchmarks.Dpb.DpbWoDamping,
      Bardo.Benchmarks.Dpb.Dpb,
      Bardo.Benchmarks.Dtm.DtmActuator,
      Bardo.Benchmarks.Dtm.DtmMorphology,
      Bardo.Benchmarks.Dtm.DtmSensor,
      Bardo.Benchmarks.Dtm.Dtm,
      Bardo.Logger.Flatlog
    ]
  end
end
