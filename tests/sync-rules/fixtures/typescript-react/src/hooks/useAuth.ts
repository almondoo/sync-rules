import { useState, useEffect } from 'react';

interface AuthState {
  user: { id: string; name: string } | null;
  loading: boolean;
}

export function useAuth(): AuthState {
  const [state, setState] = useState<AuthState>({ user: null, loading: true });

  useEffect(() => {
    fetch('/api/auth/me')
      .then((res) => res.json())
      .then((user) => setState({ user, loading: false }))
      .catch(() => setState({ user: null, loading: false }));
  }, []);

  return state;
}
