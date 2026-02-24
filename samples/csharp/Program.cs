// Sample C# file for testing omnisharp and csharpier.

// TODO: Add async/await examples

namespace Sample;

public record Point(double X, double Y)
{
    public double DistanceTo(Point other)
    {
        var dx = X - other.X;
        var dy = Y - other.Y;
        return Math.Sqrt(dx * dx + dy * dy);
    }

    public override string ToString() => $"({X}, {Y})";
}

public interface IShape
{
    double Area();
    string Name { get; }
}

public class Circle(Point center, double radius) : IShape
{
    public Point Center { get; } = center;
    public double Radius { get; } = radius;
    public double Area() => Math.PI * Radius * Radius;
    public string Name => "Circle";
}

public class Rectangle(Point origin, double width, double height) : IShape
{
    public Point Origin { get; } = origin;
    public double Width { get; } = width;
    public double Height { get; } = height;
    public double Area() => Width * Height;
    public string Name => "Rectangle";
}

public static class ShapeExtensions
{
    public static void PrintInfo(this IShape shape)
    {
        Console.WriteLine($"{shape.Name}: area = {shape.Area():F2}");
    }
}

public class Program
{
    public static void Main()
    {
        var origin = new Point(0, 0);
        var p = new Point(3, 4);
        Console.WriteLine($"Distance from {origin} to {p}: {origin.DistanceTo(p):F2}");

        IShape[] shapes = [new Circle(origin, 5), new Rectangle(origin, 10, 5)];

        foreach (var shape in shapes)
        {
            shape.PrintInfo();
        }

        // LINQ example
        var names = new[] { "Alice", "Bob", "Carol", "Dave" };
        var longNames = names.Where(n => n.Length > 3).Select(n => n.ToUpper());
        Console.WriteLine($"Long names: {string.Join(", ", longNames)}");
    }
}
