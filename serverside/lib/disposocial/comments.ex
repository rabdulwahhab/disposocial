defmodule Disposocial.Comments do
  @moduledoc """
  The Comments context.
  """

  import Ecto.Query, warn: false
  alias Disposocial.Repo

  alias Disposocial.Comments.Comment
  alias Disposocial.Util

  @doc """
  Returns the list of comments.

  ## Examples

      iex> list_comments()
      [%Comment{}, ...]

  """
  def list_comments do
    raise "TODO"
  end

  def present(comment) do
    comm = Repo.preload(comment, :user)
    username = comm.user.name
    Map.take(comm, [:id, :body, :inserted_at])
    |> Map.put(:username, username)
  end

  @doc """
  Gets a single comment.

  Raises if the Comment does not exist.

  ## Examples

      iex> get_comment!(123)
      %Comment{}

  """
  def get_comment!(id), do: raise "TODO"

  @doc """
  Creates a comment.

  ## Examples

      iex> create_comment(%{field: value})
      {:ok, %Comment{}}

      iex> create_comment(%{field: bad_value})
      {:error, ...}

  """
  def create_comment(attrs \\ %{}) do
    %Comment{}
    |> Comment.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a comment.

  ## Examples

      iex> update_comment(comment, %{field: new_value})
      {:ok, %Comment{}}

      iex> update_comment(comment, %{field: bad_value})
      {:error, ...}

  """
  def update_comment(%Comment{} = comment, attrs) do
    raise "TODO"
  end

  @doc """
  Deletes a Comment.

  ## Examples

      iex> delete_comment(comment)
      {:ok, %Comment{}}

      iex> delete_comment(comment)
      {:error, ...}

  """
  def delete_comment(%Comment{} = comment) do
    raise "TODO"
  end

  @doc """
  Returns a data structure for tracking comment changes.

  ## Examples

      iex> change_comment(comment)
      %Todo{...}

  """
  def change_comment(%Comment{} = comment, _attrs \\ %{}) do
    raise "TODO"
  end
end
