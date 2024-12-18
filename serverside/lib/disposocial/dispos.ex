defmodule Disposocial.Dispos do
  @moduledoc """
  The Dispos context.
  """

  @radius_of_earth 3_959 # in miles (converted from 6_371 km)
  @dispo_radius 5 # in miles
  @lat_factor 0.006910164958 # see docs for `get_all_near` below
  @lng_factor 0.03368556573

  import Ecto.Query, warn: false
  alias Disposocial.Repo

  alias Disposocial.Util
  alias Disposocial.Dispos.Dispo
  alias Disposocial.PositionStack
  alias Disposocial.Posts
  alias Disposocial.Posts.Post

  require Logger

  @doc """
  Returns the list of dispos.

  ## Examples

      iex> list_dispos()
      [%Dispo{}, ...]

  """
  def list_dispos do
    Repo.all(Dispo)
  end

  @doc """
  Gets a single dispo.

  Raises `Ecto.NoResultsError` if the Dispo does not exist.

  ## Examples

      iex> get_dispo!(123)
      %Dispo{}

      iex> get_dispo!(456)
      ** (Ecto.NoResultsError)

  """
  def get_dispo!(id), do: Repo.get!(Dispo, id)

  def get_dispo(id), do: Repo.get(Dispo, id)

  def load_creator(dispo) do
    Repo.preload(dispo, [:user])
  end

  def exists?(id) do
    q = from d in Dispo, where: d.id == ^id
    Repo.exists?(q)
  end

  def get_name!(id) do
    q = from(d in Dispo, select: d.name)
    Repo.get!(q, id)
  end

  defp rad(deg) do
    deg * (:math.pi() / 180)
  end

  @doc """
  Calculates the Haversine distance between two points on Earth in feet.
  The Haversine distance is the distance between two points on a sphere.
  I use the accepted average radius of Earth (6,371 km) as the basis
  of conversion to US Customary feet.

  Adapted from a Python variation here:

  https://community.esri.com/t5/coordinate-reference-systems/distance-on-a-sphere-the-haversine-formula/ba-p/902128
  """
  def haversine_dist({lat1, lng1}, {lat2, lng2}) do
    phi_1 = rad(lat1)
    phi_2 = rad(lat2)
    delta_phi = rad(lat2 - lat1)
    delta_lam = rad(lng2 - lng1)
    a = :math.pow(:math.sin(delta_phi / 2), 2) + :math.cos(phi_1) * :math.cos(phi_2) * :math.pow(:math.sin(delta_lam / 2), 2)
    c = 2 * :math.atan2(:math.sqrt(a), :math.sqrt(1 - a))
    @radius_of_earth * c
  end

  def haversine_dist_mi({lat1, lng1}, {lat2, lng2}) do
    haversine_dist({lat1, lng1}, {lat2, lng2}) / 5_280
  end

  @doc"""
  Gets the Dispos with coordinates within a radius of @dispo_radius.
  Uses Haversine distance calculation formula.

  NOTE: the Ecto query api (to my knowledge) will not allow conditionally
  selecting based on the haversine distance function so an initial query
  for nearby dispos is done to get plausible candidates before filtering
  for Dispos within the haversine distance.

  Here are two example geographic coordinates. IRL, the distance between them
  (in a direct line) is ~76.63 miles (hypotenuse). Using Driver, AR
  as a horizontal point (~67.29 miles West), I derive a latitude constant (L_x)
  which is multiplied by the @dispo_radius to give a rough latitudinal mile
  radius. The longitudinal constant (L_y) is derived similarly after
  calculating the delta in miles for the final (vertical) side using the
  Pythagorean theorem.

  Memphis: (35.149532, -90.048981)
  Jackson: (35.614517, -88.813950)

  L_x ~= 0.006910164958
  L_y ~= 0.03368556573

  As a safe bet, the initial query selects Dispos with latitudes of
  delta_lat_max = @lat_factor * @dispo_radius and longitudes of
  delta_lng_max = @lng_factor * @dispo_radius

  All calculations here use miles with coordinate degrees.
  """
  def get_all_near(qlat, qlng) do
    # TODO lat and lng checking. fix this later
    query = cond do
      qlat > 0.0 && qlng > 0.0 -> from(d in Dispo, where: d.latitude > 0.0 and d.longitude > 0.0)
      qlat > 0.0 && qlng < 0.0 -> from(d in Dispo, where: d.latitude > 0.0 and d.longitude < 0.0)
      qlat < 0.0 && qlng > 0.0 -> from(d in Dispo, where: d.latitude < 0.0 and d.longitude > 0.0)
      qlat < 0.0 && qlng < 0.0 -> from(d in Dispo, where: d.latitude < 0.0 and d.longitude < 0.0)
      true -> nil
    end

    in_radius = fn(dispo) ->
      haversine_dist_mi({qlat, qlng}, {dispo.latitude, dispo.longitude}) <= @dispo_radius end

    query
    |> Repo.all()
    |> Enum.filter(in_radius)
  end

  def get_popular_posts(dispo_id) do
    q = from(
      d in Dispo,
      left_join: posts in subquery(from p in Post, where: p.dispo_id == ^dispo_id, order_by: [desc: :interactions], limit: 10),
      select_merge: %{popular_posts: posts}
    )
    Repo.all(q)
  end

  def present(dispo) do
    created = Util.convertUTC!(dispo.inserted_at)
    death = Util.convertUTC!(dispo.death)
    dispo
    |> Map.take([
        :id,
        :name,
        :location,
        :latitude,
        :longitude,
        :is_public
        ])
    |> Map.put(:created, created)
    |> Map.put(:death, death)
  end

  def create_dispo(%{"password" => password} = attrs) do
    attrs
    |> Map.merge(Argon2.add_hash(password))
    |> Map.drop(["password"])
    |> Util.stringify_keys()
    |> create_dispo()
  end

  @doc """
  Creates a dispo.

  ## Examples

      iex> create_dispo(%{field: value})
      {:ok, %Dispo{}}

      iex> create_dispo(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_dispo(attrs) do
    Logger.debug("Processing Dispo args")
    deathDate = unless is_nil(attrs["duration"]) do
      added_time =
        Float.round(String.to_float(attrs["duration"]), 2) * 3_600 # in seconds. duration received as hours
        |> trunc()
      DateTime.utc_now()
      |> DateTime.add(added_time, :second, Tzdata.TimeZoneDatabase)
    end

    not_worth_it = is_nil(deathDate) || is_nil(attrs["latitude"]) || is_nil(attrs["longitude"])
    geodata = unless not_worth_it do
      # do api reverse geocoding req
      PositionStack.get_location_by_coords(attrs["latitude"], attrs["longitude"])
    end

    Logger.debug("GOT LOCATION DATA --> #{inspect(geodata)}")

    attrs =
      attrs
      |> Map.put("user_id", attrs["user_id"])
      |> Map.put("location", geodata)
      |> Map.put("death", deathDate)

    Logger.debug("FINAL ATTRS --> #{inspect(attrs)}")

    %Dispo{}
    |> Dispo.changeset(attrs)
    |> Repo.insert()
  end

  def get_death(id) do
    q = from(d in Dispo, where: d.id == ^id, select: d.death)
    [death_dt] = Repo.all(q)
    death_dt
  end

  def authenticate(id, pass) do
    dispo = Repo.get_by!(Dispo, id: id)
    if dispo.is_public do
      :ok
    else
      Argon2.verify_pass(pass, dispo.password_hash)
    end
  end

  @doc """
  Updates a dispo.

  ## Examples

  iex> update_dispo(dispo, %{field: new_value})
  {:ok, %Dispo{}}

  iex> update_dispo(dispo, %{field: bad_value})
  {:error, %Ecto.Changeset{}}

  """
  def update_dispo(%Dispo{} = dispo, attrs) do
    dispo
    |> Dispo.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a dispo.

  ## Examples

  iex> delete_dispo(dispo)
  {:ok, %Dispo{}}

  iex> delete_dispo(dispo)
  {:error, %Ecto.Changeset{}}

  """
  def delete_dispo(%Dispo{} = dispo) do
    Repo.delete(dispo)
  end

  def delete_dispo_and_remnants(id) do
    dispo = get_dispo!(id)
    with({:ok, num_post_deleted, num_uploads_deleted, num_comm_deleted, num_reac_deleted} <- Posts.delete_posts_and_remnants(id)) do
      case delete_dispo(dispo) do
        {:ok, _} -> {:ok, dispo.id, dispo.name, num_post_deleted, num_uploads_deleted, num_comm_deleted, num_reac_deleted}
        error -> error
      end
    else
      _ -> Logger.alert("Dispo delete failed")
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking dispo changes.

  ## Examples

  iex> change_dispo(dispo)
  %Ecto.Changeset{data: %Dispo{}}

  """
  def change_dispo(%Dispo{} = dispo, attrs \\ %{}) do
    Dispo.changeset(dispo, attrs)
  end
end
