defmodule DisposocialWeb.ReactionControllerTest do
  use DisposocialWeb.ConnCase

  alias Disposocial.Reactions
  alias Disposocial.Reactions.Reaction

  @create_attrs %{
    value: 42
  }
  @update_attrs %{
    value: 43
  }
  @invalid_attrs %{value: nil}

  def fixture(:reaction) do
    {:ok, reaction} = Reactions.create_reaction(@create_attrs)
    reaction
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all reactions", %{conn: conn} do
      conn = get(conn, Routes.reaction_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create reaction" do
    test "renders reaction when data is valid", %{conn: conn} do
      conn = post(conn, Routes.reaction_path(conn, :create), reaction: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.reaction_path(conn, :show, id))

      assert %{
               "id" => id,
               "value" => 42
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.reaction_path(conn, :create), reaction: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update reaction" do
    setup [:create_reaction]

    test "renders reaction when data is valid", %{conn: conn, reaction: %Reaction{id: id} = reaction} do
      conn = put(conn, Routes.reaction_path(conn, :update, reaction), reaction: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, Routes.reaction_path(conn, :show, id))

      assert %{
               "id" => id,
               "value" => 43
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, reaction: reaction} do
      conn = put(conn, Routes.reaction_path(conn, :update, reaction), reaction: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete reaction" do
    setup [:create_reaction]

    test "deletes chosen reaction", %{conn: conn, reaction: reaction} do
      conn = delete(conn, Routes.reaction_path(conn, :delete, reaction))
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, Routes.reaction_path(conn, :show, reaction))
      end
    end
  end

  defp create_reaction(_) do
    reaction = fixture(:reaction)
    %{reaction: reaction}
  end
end
