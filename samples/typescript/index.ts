// Sample TypeScript file for testing ts_ls (Phase 3).

// TODO: Add generic utility type examples

interface User {
  id: number;
  name: string;
  email: string;
  createdAt: Date;
}

interface ApiResponse<T> {
  data: T;
  status: number;
  message: string;
}

function createUser(name: string, email: string): User {
  return {
    id: Math.floor(Math.random() * 10000),
    name,
    email,
    createdAt: new Date(),
  };
}

async function fetchUser(id: number): Promise<ApiResponse<User>> {
  // Simulated API call
  const user = createUser("Alice", "alice@example.com");
  return {
    data: { ...user, id },
    status: 200,
    message: "OK",
  };
}

function formatUser(user: User): string {
  return `${user.name} <${user.email}> (id: ${user.id})`;
}

async function main(): Promise<void> {
  const response = await fetchUser(42);

  if (response.status === 200) {
    console.log("User:", formatUser(response.data));
    console.log("Created:", response.data.createdAt.toISOString());
  }

  const users: User[] = [
    createUser("Bob", "bob@example.com"),
    createUser("Carol", "carol@example.com"),
  ];

  users.forEach((user) => {
    console.log(formatUser(user));
  });
}

main();
