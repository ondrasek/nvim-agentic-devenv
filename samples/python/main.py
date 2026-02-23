"""Sample Python file for testing LSP, formatting, and linting."""

import os
import sys  # unused import — ruff should flag this

from dataclasses import dataclass
from typing import Optional


# TODO: Add more comprehensive examples
# FIXME: The greeting format should be configurable


@dataclass
class User:
    """A simple user model."""

    name: str
    email: str
    age: Optional[int] = None

    def greeting(self) -> str:
        """Return a greeting string."""
        if self.age:
            return f"Hello, {self.name} (age {self.age})!"
        return f"Hello, {self.name}!"


def find_user(users: list[User], name: str) -> Optional[User]:
    """Find a user by name. Test go-to-definition on User."""
    for user in users:
        if user.name == name:
            return user
    return None


def main() -> None:
    """Entry point — tests pyright hover and diagnostics."""
    users = [
        User(name="Alice", email="alice@example.com", age=30),
        User(name="Bob", email="bob@example.com"),
    ]

    for user in users:
        print(user.greeting())

    found = find_user(users, "Alice")
    if found:
        print(f"Found: {found.email}")

    # Test os import is used
    cwd = os.getcwd()
    print(f"Working directory: {cwd}")


if __name__ == "__main__":
    main()
