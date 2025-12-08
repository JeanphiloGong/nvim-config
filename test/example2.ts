type User = {
  id: number;
  name: string;
};

export function formatUser(user: User): string {
  const { id, name } = user;
  return `${id}: ${name}`;
}
