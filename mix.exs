defmodule Bardo.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/hibernatus-hacker/bardo"
  @description "A powerful and approachable neuroevolution library for Elixir"

  def project do
    [
      app: :bardo,
      version: @version,
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
      ],

      # Hex.pm package configuration
      package: package(),
      description: @description,
      docs: docs(),
      name: "Bardo",
      homepage_url: @source_url,
      source_url: @source_url
    ]
  end

  # Run "mix help compile.app" to learn about applications
  def application do
    [
      extra_applications: [:logger],
      mod: {Bardo.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies
  defp deps do
    [
      # Runtime dependencies
      {:jason, "~> 1.4"},
      {:uuid, "~> 1.1"},

      # Development/Build tools
      {:observer_cli, "~> 1.7", only: [:dev], runtime: false},

      # Documentation
      {:ex_doc, "~> 0.29", only: :dev, runtime: false},

      # Testing and Quality Assurance
      {:mock, "~> 0.3.0", only: :test},
      {:excoveralls, "~> 0.15", only: :test},
      {:stream_data, "~> 0.5", only: [:dev, :test]},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.2", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      check: ["compile", "credo", "dialyzer", "test"],
      test: ["test"]
    ]
  end

  defp package do
    [
      name: "bardo",
      files: ~w(lib mix.exs README.md LICENSE),
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @source_url,
        "Documentation" => "https://hexdocs.pm/bardo",
        "Examples" => "#{@source_url}/tree/main/lib/bardo/examples/simple"
      },
      maintainers: ["hibernatus-hacker"]
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "docs/advanced.md",
        "docs/api_reference.md",
        "docs/examples.md",
        "docs/extending.md",
        "docs/library_tutorial.md",
        "docs/quickstart.md",
        "docs/substrate_encoding.md",
        "RELEASE.md"
      ],
      groups_for_extras: [
        "Getting Started": [
          "README.md",
          "docs/quickstart.md",
          "docs/library_tutorial.md"
        ],
        "Guides": [
          "docs/api_reference.md",
          "docs/examples.md",
          "docs/extending.md"
        ],
        "Advanced Topics": [
          "docs/advanced.md",
          "docs/substrate_encoding.md"
        ],
        "Release Information": [
          "RELEASE.md"
        ]
      ],
      groups_for_modules: [
        "Core": [
          Bardo,
          Bardo.AgentManager,
          Bardo.Application,
          Bardo.AppConfig,
          Bardo.ExperimentManager,
          Bardo.Models,
          Bardo.PolisMgr,
          Bardo.ScapeManager
        ],
        "Agent Components": [
          Bardo.AgentManager.Actuator,
          Bardo.AgentManager.Cortex,
          Bardo.AgentManager.Neuron,
          Bardo.AgentManager.Sensor,
          Bardo.AgentManager.Substrate
        ],
        "Evolution": [
          Bardo.PopulationManager,
          Bardo.PopulationManager.GenomeMutator,
          Bardo.PopulationManager.Genotype,
          Bardo.PopulationManager.Morphology,
          Bardo.PopulationManager.SelectionAlgorithm
        ],
        "Examples": [
          Bardo.Examples.Simple.Xor,
          Bardo.Examples.Benchmarks.Dpb
        ],
        "Database": [
          Bardo.DB,
          Bardo.DBEts,
          Bardo.DBMock
        ],
        "Utilities": [
          Bardo.Functions,
          Bardo.Logger,
          Bardo.Utils
        ]
      ]
    ]
  end

  defp excluded_modules do
    [
      Bardo.Tar.ErlTar,
      Bardo.Tar.Filename,
      Bardo.Tar.Tarball,
      Bardo.Tar.SafeErlTerm,
      Bardo.Examples.Applications.Flatland.FlatlandActuator,
      Bardo.Examples.Applications.Flatland.FlatlandSensor,
      Bardo.Examples.Applications.Flatland.FlatlandUtils,
      Bardo.Examples.Applications.Flatland.Flatland,
      Bardo.Examples.Applications.Flatland.Predator,
      Bardo.Examples.Applications.Flatland.Prey,
      Bardo.Examples.Applications.Fx.FxActuator,
      Bardo.Examples.Applications.Fx.FxMorphology,
      Bardo.Examples.Applications.Fx.FxSensor,
      Bardo.Examples.Applications.Fx.Fx,
      # HTM modules were removed
      # No HTM modules to exclude
      Bardo.Examples.Benchmarks.Dpb.DpbActuator,
      Bardo.Examples.Benchmarks.Dpb.DpbSensor,
      Bardo.Examples.Benchmarks.Dpb.DpbWDamping,
      Bardo.Examples.Benchmarks.Dpb.DpbWoDamping,
      Bardo.Examples.Benchmarks.Dpb.Dpb,
      Bardo.Logger.Flatlog
    ]
  end
end
