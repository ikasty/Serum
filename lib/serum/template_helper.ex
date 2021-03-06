defmodule Serum.TemplateHelper.Macros do
  @moduledoc false

  defmacro export_proj(prop) do
    quote do
      def unquote(:"#{prop}")(), do: Serum.get_data("proj", unquote(prop))
    end
  end
end

defmodule Serum.TemplateHelper do
  @moduledoc """
  This module provides shortcut functions for accessing various kind of files
  or pages in EEx templates.
  """

  require Serum.TemplateHelper.Macros
  import Serum.TemplateHelper.Macros

  @doc """
  Prepends the base URL (followed by a slash) in front of `path`.

  ## Example

  ```
  iex> base("assets/css/styles.css")
  "/base/url/assets/css/styles.css"
  ```
  """
  @spec base(String.t) :: String.t
  def base(path \\ ""), do: Serum.get_data("proj", "base_url") <> path

  @doc """
  Provides shortcut for accessing pages.

  ## Example

  ```
  # Please note that `.html` should not follow the `name`.
  iex> page("docs/example")
  "/base/url/docs/example.html"
  ```
  """
  @spec page(String.t) :: String.t
  def page(name), do: base(name <> ".html")

  @doc """
  Provides shortcut for accessing blog posts.

  ## Example

  ```
  # Please note that `.html` should not follow the `name`.
  iex> page("2016-11-07-1406-hello-world")
  "/base/url/posts/2016-11-07-1406-hello-world.html"
  ```
  """
  @spec post(String.t) :: String.t
  def post(name), do: base("posts/" <> name <> ".html")

  @doc """
  Provides shortcut for accessing asset files.

  ## Example

  ```
  iex> asset("css/global.css")
  "/base/url/assets/css/global.css"
  ```
  """
  @spec asset(String.t) :: String.t
  def asset(path), do: base("assets/" <> path)

  export_proj "site_name"
  export_proj "site_description"
  export_proj "author"
  export_proj "author_email"
end
