interface ApiResponse<T> {
  data: T;
  status: number;
}

export async function fetchJson<T>(url: string): Promise<ApiResponse<T>> {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`API error: ${response.status}`);
  }
  const data = await response.json();
  return { data, status: response.status };
}
