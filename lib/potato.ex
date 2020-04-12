defmodule Potato do
  @moduledoc false

  def check_exists(path) do
    unless File.exists?(path) do
      Mix.raise("Could not find #{path}. Have you run 'mix release'?")
    end
  end

  def check_releases(root_path, rel_name, versions, rel_ver \\ nil) do
    lib_path = Path.join([root_path, "lib"])
    rel_path = Path.join([root_path, "releases"])

    for ver <- versions do
      ver_path = Path.join([rel_path, to_string(ver)])
      rel_file = Path.join([ver_path, to_string(rel_name) <> ".rel"])
      for f <- [ver_path, rel_file], do: Potato.check_exists(f)

      case :file.consult(rel_file) do
        {:ok, [{:release, {rel_app, rel_app_ver}, {rel_erts, rel_erts_ver}, app_vers}]} ->
          unless to_string(rel_name) == to_string(rel_app) do
            Mix.raise("Project app (#{rel_name}) doesn't match release name (#{rel_app})")
          end

          if rel_ver do
            unless to_string(rel_ver) == to_string(rel_app_ver) do
              Mix.raise("Project ver (#{rel_ver}) doesn't match release ver (#{rel_app_ver})")
            end
          end

          # Check erts
          Potato.check_exists(Path.join(root_path, "#{rel_erts}-#{rel_erts_ver}"))

          # Check apps
          for {app_name, app_ver, _} <- app_vers,
              do: check_exists(Path.join(lib_path, "#{app_name}-#{app_ver}"))

        {:error, reason} ->
          Mix.raise("Could not read #{rel_file}. #{reason}")
      end
    end
  end
end
