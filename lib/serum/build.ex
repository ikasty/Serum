defmodule Serum.Build do
  @moduledoc """
  This module contains functions for generating pages of your website.
  """

  import Serum.Util
  alias Serum.Error
  alias Serum.Build.{PageBuilder, PostBuilder, IndexBuilder, Renderer}

  @type build_mode :: :parallel | :sequential
  @type compiled_template :: tuple

  @spec build(String.t, String.t, build_mode) :: Error.result(String.t)
  def build(src, dest, mode) do
    src = String.ends_with?(src, "/") && src || src <> "/"
    dest = dest || src <> "site/"
    dest = String.ends_with?(dest, "/") && dest || dest <> "/"

    case check_access dest do
      :ok -> do_build_stage1 src, dest, mode
      err -> {:error, :file_error, {err, dest, 0}}
    end
  end

  @spec check_access(String.t) :: :ok | File.posix
  defp check_access(dest) do
    parent = dest |> String.replace_suffix("/", "") |> :filename.dirname
    case File.stat parent do
      {:error, reason} -> reason
      {:ok, %File.Stat{access: :none}} -> :eacces
      {:ok, %File.Stat{access: :read}} -> :eacces
      {:ok, _} -> :ok
    end
  end

  @spec do_build_stage1(String.t, String.t, build_mode)
    :: Error.result(String.t)
  defp do_build_stage1(src, dest, mode) do
    IO.puts "Rebuilding Website..."
    Serum.init_data
    Serum.put_data "pages_file", []

    clean_dest dest
    prep_results =
      [check_tz: [],
       load_info: [src],
       load_templates: [src],
       scan_pages: [src, dest]]
      |> Enum.map(fn {fun, args} ->
        apply Serum.Build.Preparation, fun, args
      end)
      |> Error.filter_results(:build_preparation)
    case prep_results do
      :ok -> do_build_stage2 src, dest, mode
      error -> error
    end
  end

  @spec do_build_stage2(String.t, String.t, build_mode)
    :: Error.result(String.t)
  defp do_build_stage2(src, dest, mode) do
    {time, result} =
      :timer.tc fn ->
        compile_nav()
        launch_tasks mode, src, dest
      end
    case result do
      :ok ->
        IO.puts "Build process took #{time/1000}ms."
        copy_assets src, dest
        {:ok, dest}
      error -> error
    end
  end

  @spec clean_dest(String.t) :: :ok
  defp clean_dest(dest) do
    File.mkdir_p! "#{dest}"
    IO.puts "Created directory `#{dest}`."

    # exclude dotfiles so that git repository is not blown away
    dest |> File.ls!
         |> Enum.filter(&(not String.starts_with?(&1, ".")))
         |> Enum.map(&("#{dest}#{&1}"))
         |> Enum.each(&File.rm_rf!(&1))
  end

  @spec launch_tasks(build_mode, String.t, String.t) :: Error.result
  defp launch_tasks(:parallel, src, dest) do
    IO.puts "⚡️  \x1b[1mStarting parallel build...\x1b[0m"
    t1 = Task.async fn -> PageBuilder.run src, dest, :parallel end
    t2 = Task.async fn -> PostBuilder.run src, dest, :parallel end
    results = [Task.await(t1), Task.await(t2)]
    # IndexBuilder must be run after PostBuilder has finished
    t3 = Task.async fn -> IndexBuilder.run src, dest, :parallel end
    results = results ++ [Task.await t3]
    Error.filter_results results, :launch_tasks
  end

  defp launch_tasks(:sequential, src, dest) do
    IO.puts "⌛️  \x1b[1mStarting sequential build...\x1b[0m"
    r1 = PageBuilder.run src, dest, :sequential
    r2 = PostBuilder.run src, dest, :sequential
    r3 = IndexBuilder.run src, dest, :sequential
    results = [r1, r2, r3]
    Error.filter_results results, :launch_tasks
  end

  @spec compile_nav() :: :ok
  defp compile_nav do
    IO.puts "Compiling main navigation HTML stub..."
    template = Serum.get_data "template", "nav"
    html = Renderer.render template, []
    Serum.put_data "navstub", html
  end

  @spec copy_assets(String.t, String.t) :: :ok
  defp copy_assets(src, dest) do
    IO.puts "Copying assets and media..."
    try_copy "#{src}assets/", "#{dest}assets/"
    try_copy "#{src}media/", "#{dest}media/"
  end

  @spec try_copy(String.t, String.t) :: :ok
  defp try_copy(src, dest) do
    case File.cp_r src, dest do
      {:error, reason, _} ->
        warn "Cannot copy #{src}: #{:file.format_error(reason)}. Skipping."
      {:ok, _} -> :ok
    end
  end
end
