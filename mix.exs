defmodule MarkdownTests.Mixfile do
  use Mix.Project

  def project do
    [ app: :markdown_tests,
      version: "0.0.1",
      elixir: "~> 0.12.4-dev",
      deps: deps ]
  end

  defp deps do
    [{ :markdown, github: "zambal/markdown", branch: "use_dirty_schedulers" }]
  end
end
