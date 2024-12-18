defmodule Disposocial.Tags.Tag do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tags" do
    field(:name, :string)

    many_to_many(:posts, Disposocial.Posts.Post, join_through: "posts-tags")

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> foreign_key_constraint(:dispo_id)
  end
end
