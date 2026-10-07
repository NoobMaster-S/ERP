/**
 * Strongly typed GraphQL Client for the Next.js Admin Panel.
 * Communicates with the Django GraphQL backend at /graphql/.
 */

export interface GraphQLResponse<T = any> {
  data?: T;
  errors?: Array<{
    message: string;
    extensions?: {
      code?: string;
      permissionRequired?: string;
      [key: string]: any;
    };
  }>;
}

const GRAPHQL_ENDPOINT =
  process.env.NEXT_PUBLIC_GRAPHQL_ENDPOINT || "http://localhost:8000/graphql/";

export async function executeGraphQL<T = any>(
  query: string,
  variables: Record<string, any> = {},
  token?: string | null,
  activeBusinessId?: string | null
): Promise<GraphQLResponse<T>> {
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
  };

  if (token) {
    headers["Authorization"] = `Bearer ${token}`;
  }

  if (activeBusinessId) {
    headers["X-Business-ID"] = activeBusinessId;
  }

  try {
    const res = await fetch(GRAPHQL_ENDPOINT, {
      method: "POST",
      headers,
      body: JSON.stringify({ query, variables }),
      cache: "no-store",
    });

    if (!res.ok) {
      throw new Error(`HTTP network error: status ${res.status}`);
    }

    return await res.json();
  } catch (err: any) {
    return {
      errors: [
        {
          message: err.message || "Failed to communicate with GraphQL server",
        },
      ],
    };
  }
}
