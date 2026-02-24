# Sample Elixir file for testing elixirls.

# TODO: Add GenServer example

defmodule Geometry do
  @moduledoc "Basic geometry calculations."

  defmodule Point do
    @moduledoc false
    defstruct [:x, :y]

    @type t :: %__MODULE__{x: float(), y: float()}
  end

  @spec distance(Point.t(), Point.t()) :: float()
  def distance(%Point{x: x1, y: y1}, %Point{x: x2, y: y2}) do
    :math.sqrt((x2 - x1) ** 2 + (y2 - y1) ** 2)
  end

  @spec midpoint(Point.t(), Point.t()) :: Point.t()
  def midpoint(%Point{x: x1, y: y1}, %Point{x: x2, y: y2}) do
    %Point{x: (x1 + x2) / 2, y: (y1 + y2) / 2}
  end
end

defmodule Shapes do
  @moduledoc "Shape area calculations using protocols."

  defprotocol Area do
    @spec area(t) :: float()
    def area(shape)
  end

  defmodule Circle do
    defstruct [:radius]
  end

  defmodule Rectangle do
    defstruct [:width, :height]
  end

  defimpl Area, for: Circle do
    def area(%Circle{radius: r}), do: :math.pi() * r * r
  end

  defimpl Area, for: Rectangle do
    def area(%Rectangle{width: w, height: h}), do: w * h
  end
end

# Main execution
origin = %Geometry.Point{x: 0.0, y: 0.0}
p = %Geometry.Point{x: 3.0, y: 4.0}

IO.puts("Distance: #{Geometry.distance(origin, p)}")
IO.puts("Midpoint: #{inspect(Geometry.midpoint(origin, p))}")

circle = %Shapes.Circle{radius: 5.0}
rect = %Shapes.Rectangle{width: 10.0, height: 5.0}

IO.puts("Circle area: #{Shapes.Area.area(circle)}")
IO.puts("Rectangle area: #{Shapes.Area.area(rect)}")
