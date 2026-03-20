import { describe, it, expect, vi } from 'vitest';
import { getUsers } from '../users';

describe('getUsers', () => {
  it('returns users on success', async () => {
    global.fetch = vi.fn().mockResolvedValue({
      ok: true,
      json: () =>
        Promise.resolve([{ id: '1', name: 'Alice', email: 'alice@test.com' }]),
    });
    const users = await getUsers();
    expect(users).toHaveLength(1);
  });
});
