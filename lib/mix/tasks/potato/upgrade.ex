defmodule Mix.Tasks.Potato.Upgrade do
  @moduledoc """
  Prepare an upgrade release from an existing release.

  ## Command line options

  * --from - Specify the version to upgrade from.

  ## Notes

  Generates a minimal tar file capable of upgrading from the
  specified version to the current version. This task expects
  to be able to find both releases, and all their respective
  applications, along with any related appups.

  ```potato.upgrade``` requires:

  * A full release of the _previous_ version.
  * A full release of the _current_ version.

  One way to do this is to leverage the existing `mix release` and
  `mix potato.full` tasks, e.g:

  ```_
  rm -fr _build
  git checkout previous
  MIX_ENV=prod mix do release, potato.full
  ...
  git checkout current
  MIX_ENV=prod mix do release, potato.full, potato.upgrade --from previous
  ```

  The upgrade task will generate a relup file from the appup descriptions and place it into
  the releases/_current_ subfolder for use during installation.

  Additionally, it will add to the tarfile *only* those applications that have
  changed since the _previous_ release.

  The generated upgrade tar should be unpacked and installed using `:release_handler.unpack_release/1` and
  `:release_handler.install_release/1`
  """
  use Mix.Task

  alias Mix.Project

  @shortdoc "Prepare an upgrade release."
  @impl Mix.Task
  def run(args) do
    app = Keyword.fetch!(Project.config(), :app)

    old_ver =
      case OptionParser.parse(args, strict: [from: :string]) do
        {[from: f], [], []} -> f
        _ -> Mix.raise("Invalid arguments.")
      end

    new_ver = Keyword.fetch!(Project.config(), :version)

    build_path = Project.build_path()
    build_rel = Path.join([build_path, "rel"])
    root_path = Path.join([build_rel, to_string(app)])

    old_vers = [old_ver]
    Potato.check_releases(root_path, app, [new_ver | old_vers])

    # Generate a minimal tar file, including only those components in this release that have
    # changed since any of the older releases.
    updated = get_updated_components(root_path, app, new_ver, old_vers)
    new_erts = Keyword.has_key?(updated, :erts)

    # Generate the relup
    old_rels = for v <- old_vers, do: to_charlist(rel_path(root_path, app, v))
    new_rel = to_charlist(rel_path(root_path, app, new_ver))
    out_dir = to_charlist(rel_dir(root_path, new_ver))
    bin_path = to_charlist(Path.join([root_path, "lib", "*", "ebin"]))

    rel_opts =
      [outdir: out_dir, path: [bin_path]]
      |> prepend_if_true(new_erts, [:restart_emulator])

    case :systools.make_relup(new_rel, old_rels, old_rels, rel_opts) do
      :ok ->
        :ok

      {:ok, _relup, mod, warnings} ->
        for w <- warnings, do: Mix.shell().info("relup warning: #{mod}: #{w}")

      {:error, mod, error} ->
        Mix.raise("Relup error: #{mod}: #{error}]")

      _ ->
        Mix.raise("Relup error")
    end

    entries =
      build_tar_entries(updated)
      |> prepend([Path.join("releases", "#{new_ver}")])
      |> prepend([Path.join("releases", "#{app}-#{new_ver}.rel")])

    tarfile = Path.join([root_path, "releases", "#{app}-#{new_ver}.tar.gz"])
    tar_files = for e <- entries, do: {to_charlist(e), to_charlist(Path.join(root_path, e))}

    case :erl_tar.create(tarfile, tar_files, [:compressed, :dereference]) do
      :ok ->
        Mix.shell().info("Generated upgrade release in #{tarfile}.")

      {:error, reason} ->
        Mix.raise("Failed to create #{tarfile}. #{reason}")
    end
  end

  defp prepend(list, extra), do: prepend_if_true(list, true, extra)

  defp prepend_if_true(list, cond, extra) do
    if cond, do: extra ++ list, else: list
  end

  defp build_tar_entries(updated) do
    for {c, v} <- updated do
      case c do
        :erts ->
          "#{c}-#{v}"

        _app ->
          Path.join("lib", "#{c}-#{v}")
      end
    end
  end

  defp get_updated_components(root_path, app, new, olds) do
    new_components = get_component_vers(root_path, app, new)
    old_components = for old <- olds, do: get_component_vers(root_path, app, old)

    Enum.reject(new_components, fn nc -> Enum.all?(old_components, fn ocs -> nc in ocs end) end)
  end

  defp get_component_vers(root_path, app, ver) do
    case :file.consult(to_charlist("#{rel_path(root_path, app, ver)}.rel")) do
      {:ok, [{:release, _, {rel_erts, rel_erts_ver}, app_vers}]} ->
        [
          {rel_erts, rel_erts_ver}
          | for({app_name, app_ver, _} <- app_vers, do: {app_name, app_ver})
        ]
    end
  end

  defp rel_dir(root_path, ver), do: Path.join([root_path, "releases", ver])
  defp rel_path(root_path, app, ver), do: Path.join(rel_dir(root_path, ver), "#{app}")
end
