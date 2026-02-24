// Sample Go file for testing gopls, gofmt, and golangci-lint.
package main

import (
	"fmt"
	"math"
	"strings"
)

// TODO: Add concurrency examples

// Point represents a point in 2D space.
type Point struct {
	X, Y float64
}

// Distance returns the Euclidean distance to another point.
func (p Point) Distance(other Point) float64 {
	dx := p.X - other.X
	dy := p.Y - other.Y
	return math.Sqrt(dx*dx + dy*dy)
}

// String implements the Stringer interface.
func (p Point) String() string {
	return fmt.Sprintf("(%0.1f, %0.1f)", p.X, p.Y)
}

// Shape defines something that has an area and a name.
type Shape interface {
	Area() float64
	Name() string
}

// Circle is a shape defined by a center and radius.
type Circle struct {
	Center Point
	Radius float64
}

func (c Circle) Area() float64 { return math.Pi * c.Radius * c.Radius }
func (c Circle) Name() string  { return "Circle" }

// Rectangle is a shape defined by origin, width, and height.
type Rectangle struct {
	Origin        Point
	Width, Height float64
}

func (r Rectangle) Area() float64 { return r.Width * r.Height }
func (r Rectangle) Name() string  { return "Rectangle" }

func printShapeInfo(s Shape) {
	fmt.Printf("%s: area = %.2f\n", s.Name(), s.Area())
}

// Filter returns items matching a predicate.
func Filter[T any](items []T, fn func(T) bool) []T {
	var result []T
	for _, item := range items {
		if fn(item) {
			result = append(result, item)
		}
	}
	return result
}

func main() {
	origin := Point{0, 0}
	p := Point{3, 4}
	fmt.Printf("Distance from %s to %s: %.2f\n", origin, p, origin.Distance(p))

	shapes := []Shape{
		Circle{Center: origin, Radius: 5},
		Rectangle{Origin: origin, Width: 10, Height: 5},
	}
	for _, s := range shapes {
		printShapeInfo(s)
	}

	words := []string{"hello", "world", "go", "test", "gopher"}
	long := Filter(words, func(s string) bool { return len(s) > 3 })
	fmt.Println("Long words:", strings.Join(long, ", "))
}
