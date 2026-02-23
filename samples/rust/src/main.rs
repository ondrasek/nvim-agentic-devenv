//! Sample Rust file for testing rust-analyzer (Phase 3).

// TODO: Add error handling examples

/// A simple point in 2D space.
#[derive(Debug, Clone)]
struct Point {
    x: f64,
    y: f64,
}

impl Point {
    fn new(x: f64, y: f64) -> Self {
        Self { x, y }
    }

    fn distance_to(&self, other: &Point) -> f64 {
        ((self.x - other.x).powi(2) + (self.y - other.y).powi(2)).sqrt()
    }
}

impl std::fmt::Display for Point {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "({}, {})", self.x, self.y)
    }
}

/// A shape that can compute its area.
trait Shape {
    fn area(&self) -> f64;
    fn name(&self) -> &str;
}

struct Circle {
    center: Point,
    radius: f64,
}

impl Shape for Circle {
    fn area(&self) -> f64 {
        std::f64::consts::PI * self.radius.powi(2)
    }

    fn name(&self) -> &str {
        "Circle"
    }
}

struct Rectangle {
    origin: Point,
    width: f64,
    height: f64,
}

impl Shape for Rectangle {
    fn area(&self) -> f64 {
        self.width * self.height
    }

    fn name(&self) -> &str {
        "Rectangle"
    }
}

fn print_shape_info(shape: &dyn Shape) {
    println!("{}: area = {:.2}", shape.name(), shape.area());
}

fn main() {
    let origin = Point::new(0.0, 0.0);
    let p = Point::new(3.0, 4.0);
    println!("Distance from {} to {}: {:.2}", origin, p, origin.distance_to(&p));

    let circle = Circle {
        center: origin.clone(),
        radius: 5.0,
    };
    let rect = Rectangle {
        origin,
        width: 10.0,
        height: 5.0,
    };

    print_shape_info(&circle);
    print_shape_info(&rect);
}
