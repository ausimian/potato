defmodule Mix.Tasks.Potato.Full do
  @moduledoc """
  Prepare a full release.

  ## Command line options

  None

  ## Notes
  This task produces a full tar file from a previously run release task, but
  adds a shell script, `preboot.sh` to the releases folder. The task itself
  expects that `mix release` has already been run, e.g.

  ```
  MIX_ENV=prod mix do release, potato.full
  ```

  `preboot.sh` enables the system to be downgraded to its original installed state,
  and should be run _before_ the system is fully booted for the first time, e.g

  ```
  tar xzf myrel-1.0.0.tar.gz
  sh myrel/release/1.0.0/preboot.sh
  ```
  """
  use Mix.Task

  alias Mix.Project

  @shortdoc "Prepare a full (upgradeable) release."
  @impl Mix.Task
  def run(_args) do
    app = Keyword.fetch!(Project.config(), :app)
    ver = Keyword.fetch!(Project.config(), :version)

    build_path = Project.build_path()
    root_path = Path.join([build_path, "rel", to_string(app)])
    rel_path = Path.join([root_path, "releases"])
    ver_path = Path.join([rel_path, to_string(ver)])
    for path <- [build_path, root_path, rel_path, ver_path], do: Potato.check_exists(path)

    # rel file checking
    Potato.check_releases(root_path, app, [ver], ver)

    # Pretty much all we need to do for the initial release is copy and rename the rel file.
    rel_file_src = Path.join([ver_path, to_string(app) <> ".rel"])
    rel_file_dst = Path.join([rel_path, to_string(app) <> "-" <> to_string(ver) <> ".rel"])
    File.copy!(rel_file_src, rel_file_dst)

    # And write a script to help create the initial releases file
    File.write!(Path.join(ver_path, "preboot.sh"), preboot_script(app, ver))

    # Tar the release up
    tarfile = to_charlist(Path.join([build_path, "rel", "#{app}-#{ver}.tar.gz"]))
    tar_full_release(build_path, app, ver, tarfile)
    Mix.shell().info("Generated full release in #{tarfile}.")
  end

  defp tar_full_release(build_path, rel_name, rel_ver, tarfile) do
    rel_path = Path.join([build_path, "rel"])
    root_path = Path.join([rel_path, to_string(rel_name)])
    rel_file = Path.join([root_path, "releases", rel_ver, "#{rel_name}.rel"])

    rel_files =
      case :file.consult(rel_file) do
        {:ok, [{:release, _, {erts, erts_ver}, app_vers}]} ->
          [
            "bin",
            "#{erts}-#{erts_ver}",
            Path.join("releases", "#{rel_ver}"),
            Path.join("releases", "COOKIE"),
            Path.join("releases", "start_erl.data"),
            Path.join("releases", "#{rel_name}-#{rel_ver}.rel")
            | for(
                {app_name, app_ver, _} <- app_vers,
                do: Path.join(["lib", "#{app_name}-#{app_ver}"])
              )
          ]

        {:error, reason} ->
          Mix.raise("Could not read #{rel_file}. #{reason}")
      end

    abs_files = Enum.map(rel_files, fn f -> Path.join(root_path, f) end)

    tar_files =
      Enum.map(abs_files, fn f -> {to_charlist(Path.relative_to(f, rel_path)), to_charlist(f)} end)

    case :erl_tar.create(tarfile, tar_files, [:compressed, :dereference]) do
      :ok ->
        :ok

      {:error, reason} ->
        Mix.raise("Failed to create #{tarfile}. #{reason}")
    end
  end

  defp preboot_script(app, ver) do
    """
    #!/bin/sh
    SELF=$(readlink "$0" || true)
    if [ -z "$SELF" ]; then SELF="$0"; fi
    RR="$(cd "$(dirname "$SELF")/../.." && pwd -P)"

    $RR/erts-10.7/bin/erl \\
      -boot_var RELEASE_LIB "$RR/lib" \\
      -boot "$(dirname "$SELF")/start_clean" \\
      -noshell \\
      -eval "ok = application:start(sasl)." \\
      -eval "ok = release_handler:create_RELEASES(\\"$RR\\", \\"$RR/releases\\", \\"$RR/releases/#{
      app
    }-#{ver}.rel\\", [])." \\
      -eval "init:stop()."

    case $? in
      0)
        echo "Release initialized ok."
        ;;
      *)
        echo "Release initialization failed."
        ;;
    esac
    """
  end
end
