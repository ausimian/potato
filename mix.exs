defmodule Potato.MixProject do
  use Mix.Project

  def project do
    [
      app: :potato,
      version: "0.1.2",
      elixir: "~> 1.9",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Documentation
      name: "Potato",
      description: "Mix tasks to support upgradeable releases.",
      source_url: repo(),
      docs: [extras: ["README.md"]],

      # Package
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    []
  end

  defp package do
    [
      name: :potato,
      maintainers: ["Nick Gunn"],
      licenses: ["MIT"],
      links: %{"Github" => repo()}
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
    ]
  end

  defp repo, do: "https://github.com/ausimian/potato"
end
